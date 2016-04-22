<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/header.cfm" title='Report Plot'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">

<h1>Report Plot</h1>

<cfparam name="granularity" type="integer" default="1"><!---0 for month, 1 for day, 2 for hour--->
<cfparam name="startDate" type="date" default="#dateAdd("m", -3, now())#">
<cfparam name="endDate" type="date" default="#now()#">
<cfparam name="lines" type="string" default="contacts,minutes">

<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
<fieldset>
	<legend>Report Parameters</legend>
	<cfoutput>
	<p>
		From: <input type="text" class="date" name="startDate" value="#dateFormat(startDate, "mmm d, yyyy")#">
		To: <input type="text"  class="date" name="endDate" value="#dateFormat(endDate, "mmm d, yyyy")#">
	</p>
	</cfoutput>
	
	<p>
		Granularity:
		<label>
			<input type="radio" name="granularity" value="0" <cfif granularity eq 0>checked="true"</cfif>> Month
		</label>
		<label>
			<input type="radio" name="granularity" value="1" <cfif granularity eq 1>checked="true"</cfif>> Day
		</label>
		<label>
			<input type="radio" name="granularity" value="2" <cfif granularity eq 2>checked="true"</cfif>> Hour
		</label>
	</p>
	
	<p>
		Lines:
		<label>
			<input type="checkbox" name="lines" value="contacts" <cfif listFind(lines, "contacts")>checked="true"</cfif>> Contacts
		</label>
		<label>
			<input type="checkbox" name="lines" value="minutes" <cfif listFind(lines, "minutes")>checked="true"</cfif>> Minutes
		</label>
	</p>
	
	<p>
		<input type="submit" value="Report">
	</p>
</fieldset>
</form>

<!---let's try to draw a second chart using a more object oriented approach.--->
<div id="chart2"></div>

<script type="text/javascript">
	x = new d3LineChart();//constructor came along with 
	x.init("#chart2", 1000, 400, [], ["contacts","minutes"]);
	
	
	$(document).ready(function(){
		//first draw the graph with the default values.
		updateGraph();
		
		//hijack form submissions and just call updateGraph() again.
		$("form").on("submit", function(e){
			e.preventDefault();//don't actuall submit the form
			
			updateGraph();
		});
		
		//also make the form's dates into date pickers.
		$("input.date").datepicker({dateFormat: "M d, yy"});
	});
	
	
	//x.debug();
	
	function updateGraph(){
		//snag the latest data based on the form's values and redraw the graph.
		/*Fetch our chart data from */
		$.ajax({
			dataType: "json",
			url: "report-plot-data.cfm",
			data: {
				"granularity": $("input[name='granularity']:checked").val(),
				"startDate": $("input[name='startDate']").val(),
				"endDate": $("input[name='endDate']").val()
			},
			async: false,/*wait for the results*/
			success: function(data){
				//armed with the resultant data we can now initialize our d3linChart
				
				//first add/remove items from our graphs lines to use.
				var useLines = new Array();
				
				$("input[name='lines']:checked").each(function(i,n){
					useLines.push($(this).val());
				})
				
				
				x.updateLines(useLines);
				x.data = data;
				
				x.draw();
			}
		});
	}
	
</script>

<p>
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm">