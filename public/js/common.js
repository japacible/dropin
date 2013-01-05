
jQuery.noConflict();
jQuery(function($) {
  $('#event_date').datepicker();

  var today = new Date();
  var formattedToday = (today.getMonth() + 1) + "/" +
                       today.getUTCDate() + "/" +
                       today.getFullYear();
  $('#event_date').val(formattedToday);
  var todayMinutes = today.getHours() * 60 + today.getMinutes();
  todayMinutes += (30 - (todayMinutes % 30));
  $('#event_time').val(todayMinutes);
  
  $('#create-dropin').submit(function() {
    var data = {}, $this = $(this);
    $.each($this.serializeArray(), function(i, o) {
      data[o.name] = o.value;
    });

    var fields = data.date.split("/");
    var start = new Date(fields[2], fields[0] - 1, fields[1]);
    var minutes = parseInt(data.start_time, 10);
    start.setHours(Math.floor(minutes / 60));
    start.setMinutes(minutes % 60);

    var end = new Date(start.valueOf() + data.event_duration * 60 * 1000);
    
    var url = $this.attr('action') + '?' + $.param({
      start_time: start.toISOString(), end_time: end.toISOString(),
      name: data.name, location: data.location
    });
    window.location = url;

    return false;
  });
});

