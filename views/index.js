$(function() {
	$("#newest").click(newest);
	$("#soon").click(soon);
	$("#filling").click(filling);
	$("#mine").click(mine);
})

function newest() {
	$("#storiesNewest").show();
	$("#storiesSoon").hide();
	$("#storiesFilling").hide();
	$("#storiesMine").hide();
}

function soon() {
	$("#storiesSoon").show();
	$("#storiesNewest").hide();
	$("#storiesFilling").hide();
	$("#storiesMine").hide();
}

function filling() {
	$("#storiesFilling").show();
	$("#storiesNewest").hide();
	$("#storiesSoon").hide();
	$("#storiesMine").hide();
}

function mine() {
	$("#storiesMine").show();
	$("#storiesNewest").hide();
	$("#storiesSoon").hide();
	$("#storiesFilling").hide();
}