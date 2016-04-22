<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/header.cfm" title='Contact Sunburst'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">

<h1>Contact Sunburst</h1>

<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
<fieldset style="width:17em;float:left;">
	<legend>Report Parameters</legend>
		From: <input type="text" name="startDate" id="startDate" value="<cfoutput>#DateFormat(DateAdd('m',-1,Now()),'mm/dd/yy')#</cfoutput>">
		<script>$("#startDate").datepicker({dateFormat: "mm/dd/yy"});</script>
		<br/><br/>
		To: <input type="text" name="startDate" id="endDate" value="<cfoutput>#DateFormat(Now(),'mm/dd/yy')#</cfoutput>">
		<script>$("#endDate").datepicker({dateFormat: "mm/dd/yy"});</script>
		<br/><br/>
	
		View By:
		<label>
			<input type="radio" name="contactType" value="1" checked="true"> Category
		</label>
		<label>
			<input type="radio" name="contactType" value="0"> Location
		</label>

	
	<p>
		<input type="button" id="submitButton" value="Report" >
	</p>
</fieldset>
</form>

<style>
	
	.xaxis{
	    fill:none;
	    stroke:gray;
	    font-size: 0.75em;
	}
	
	path.line {
		stroke: black;
		stroke-width: 1.5px;
		stroke-opacity: 0.8;
		fill: none;
	}
	
	circle.line {
		stroke: black;
		fill-opacity: 0.8;
	}
	
	.tip {
		font-size: 10px;
		font-family: monospace;
	}
	
	.yaxis{
	    fill:none;
	    stroke:gray;
	    font-size: 0.75em;
	}
</style>


<!---let's try to draw a second chart using a more object oriented approach.--->
<div style="width:70%;float:right;text-align:center;">
<div id="sunburstChart" style="margin: 0em auto;" ></div>
	</div>
<script type="text/javascript">

	
	$( "#submitButton" ).click(function() {
		$( "#sunburstChart" ).html("");
		$( "#submitButton" ).val("loading...");
		getData();
	});
	
	/*Fetch our chart data from */
	function getData() {
		$.ajax({
			dataType: "json",
			url: "report-sunburst-data.cfm",
			data: { startDate: $("#startDate").val(), endDate: $("#endDate").val(), frmSubject: $('input:radio[name=contactType]:checked').val()},
			success: function(data){
				x.rcg = new randomColorGenerator();
				x.init("#sunburstChart", 500, 500, data);
				$( "#submitButton" ).val("Report");
			}
		});
	}
	x = new d3SunBurst();
	console.log();
	getData();
	
	
</script>

<div style="clear: both;">&nbsp;</div>
<p>
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm">