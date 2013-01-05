require "sinatra"
require "mogli"
require "fb_graph"
require "date"

enable :sessions
set :raise_errors, false
set :show_exceptions, false

# Scope defines what permissions that we are asking the user to grant.
# In this example, we are asking for the ability to publish stories
# about using the app, access to what the user likes, and to be able
# to use their pictures.  You should rewrite this scope with whatever
# permissions your app needs.
# See https://developers.facebook.com/docs/reference/api/permissions/
# for a full list of permissions

FACEBOOK_SCOPE = 'create_event,rsvp_event,read_friendlists,read_stream,publish_stream,user_photos'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
end

helpers do
  def url(path)
    base = "#{request.scheme}://#{request.env['HTTP_HOST']}"
    base + path
  end

  def post_to_wall_url
    "https://www.facebook.com/dialog/feed?redirect_uri=#{url("/close")}&display=popup&app_id=#{@app.id}";
  end

  def send_to_friends_url
    "https://www.facebook.com/dialog/send?redirect_uri=#{url("/close")}&display=popup&app_id=#{@app.id}&link=#{url('/')}";
  end

  def authenticator
    @authenticator ||= Mogli::Authenticator.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end

  def auth
    @auth ||= FbGraph::Auth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"])
    # , url("/auth/facebook/callback"))
  end

  def first_column(item, collection)
    return ' class="first-column"' if collection.index(item)%4 == 0
  end

  def escape(string)
    Rack::Utils::escape_html(string)
  end

  def token
    session[:at]
  end

  def auth(path)
    session[:return] = path
    redirect "/auth/facebook"
  end

  def preserve(*params)
    return if session[:scratch]
    session[:scratch] = {}
    params.each do |param|
      session[:scratch][param] = request[param]
    end
  end

  def thaw
    session[:scratch].each do |key, value|
      request[key] = value
    end unless session[:scratch].nil?
    session[:scratch] = nil
  end
end

# the facebook session expired! reset ours and restart the process
error(Mogli::Client::HTTPException) do
  session[:at] = nil
  redirect "/auth/facebook"
end

get "/" do
  auth "/" unless session[:at]
  @client = Mogli::Client.new(session[:at])

  # limit queries to 15 results
  @client.default_params[:limit] = 15

  @app  = Mogli::Application.find(ENV["FACEBOOK_APP_ID"], @client)
  # @user = Mogli::User.find("me", @client)
  @user = FbGraph::User.me(token)

  # access friends, photos and likes directly through the user instance
  # @friends = @user.friends[0, 4]
  # @photos  = @user.photos[0, 16]
  # @likes   = @user.likes[0, 4]

  @friends_using_app = FbGraph::Query.new("
    SELECT uid, name, is_app_user, pic_square
    FROM user
    WHERE
      uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND
      is_app_user = 1
  ").fetch(token)

  twitter = 2231777543

  @other_posts = FbGraph::Query.new("
    SELECT message
    FROM stream
    WHERE filter_key = 'app_#{@app.id}'
  ").fetch(token)

  erb :index
end

get "/dropin" do
  preserve "start_time", "end_time", "name", "location"
  auth "/dropin" unless session[:at]
  thaw

  @user = FbGraph::User.me(token)

  start_time, end_time = request["start_time"], request["end_time"]
  name, location = request["name"], request["location"]

  if [start_time, end_time, name, location].any? { |field| field.nil? }
    error 400, {:error => "Incomplete parameters"}.to_json
  end

=begin
  date = DateTime.strptime(event_date, '%m/%d/%Y').to_time.to_i
  start_time = date + start_time.to_i * 60
  end_time = start_time + event_duration.to_i * 60
=end

  begin
    start_time = DateTime.parse(start_time).to_time
    end_time = DateTime.parse(end_time).to_time
  rescue Exception => e
    error 400, {:error => "Incorrect time format"}.to_json
  end

  begin
    @event = @user.event!(
      :name => name, :location => location,
      :start_time => start_time, :end_time => end_time
    )
    @event.attending!(:access_token => token)
  rescue FbGraph::InvalidRequest, FbGraph::Unauthorized => e
    error 400, {:error => e.message}.to_json
  end

  event_url = "https://www.facebook.com/event.php?eid=#{@event.identifier}"

  feed = @user.feed!(
    :message => "Come hang out with me at #{location}!",
    :link => event_url
  )

  # {:success => true}.to_json
  redirect event_url
end

# used to close the browser window opened to post to wall/send to friends
get "/close" do
  "<body onload='window.close();'/>"
end

get "/auth/facebook" do
  session[:at] = nil
  redirect authenticator.authorize_url(:scope => FACEBOOK_SCOPE, :display => 'page')
end

get '/auth/facebook/callback' do
  client = Mogli::Client.create_from_code_and_authenticator(params[:code], authenticator)
  session[:at] = client.access_token
  redirect session[:return]
end

