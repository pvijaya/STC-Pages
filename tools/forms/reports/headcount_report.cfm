<cfmodule template="#application.appPath#/header.cfm" title='Headcount Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<h1>The Graveyard Head-Count Report</h1>

<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">
<cfparam name="granularity" type="integer" default="0"><!---0 for month, 1 for week, 2 for day, 3 for hour--->
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
			<input type="radio" name="granularity" value="1" <cfif granularity eq 1>checked="true"</cfif>> Week
		</label>
		<label>
			<input type="radio" name="granularity" value="2" <cfif granularity eq 2>checked="true"</cfif>> Day
		</label>
		<label>
			<input type="radio" name="granularity" value="3" <cfif granularity eq 3>checked="true"</cfif>> Hour
		</label>
	</p>
	<p>
		<input type="submit" value="Report">
	</p>
</fieldset>
</form>


<div id="chart2"></div>

<div id="table2"></div>

<script type="text/javascript">
	x = new d3LineChart();//constructor came along with
	x.init("#chart2", 1000, 400, [], ["Learning Commons"]);


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
			url: "headcount_report_data.cfm",
			data: {
				"granularity": $("input[name='granularity']:checked").val(),
				"startDate": $("input[name='startDate']").val(),
				"endDate": $("input[name='endDate']").val()
			},
			async: false,/*wait for the results*/
			success: function(data){
				//armed with the resultant data we can now initialize our d3linChart

				//first add/remove items from our graphs lines to use.
				<!---var useLines = new Array();

				$("input[name='lines']:checked").each(function(i,n){
					useLines.push($(this).val());
				})

				x.updateLines(useLines);--->

				//make a new array of the names of the lines for re-drawing the legend.
				var lines = [];
				for(var d in data){
					for(var n in data[d]){
						if(n != "Date" && lines.indexOf(n) < 0){
							lines.push(n);
						}
					}
				}

				//update the lines, the data, and redraw the graph.
				x.updateLines(lines);
				x.data = data;
				x.draw();

				//Update the table of data, too.
				//Start by making the date human readable.
				var tData = JSON.parse( JSON.stringify(data) );//make a deep copy of data that we can manipulate without changing the original data.

				for(var d in tData){
					for(var n in tData[d]){
						if(n == "Date"){
							var tDate = new Date(tData[d][n]);
							tData[d][n] = tDate.dateFormat("yyyy-mm-dd HH:nn");
						}
					}
				}

				lines.unshift("Date");//Need the date for the table to work.

				var t = d3Table(tData, lines, "#table2");
			}
		});
	}

</script>


<cfmodule template="#application.appPath#/footer.cfm">
