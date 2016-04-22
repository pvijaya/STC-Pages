<cfmodule template="#application.appPath#/header.cfm" title='Inventory' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="consultant">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">
<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">

<cfparam name="frmInstanceId" type="integer" default="0">
<cfparam name="frmlabId" type="integer" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d", -30, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<!---if the instanceId and labId weren't provided try out the lab string.--->
<cfparam name="frmlab" type="string" default="i#frmInstanceId#l#frmlabId#">
<cfparam name="itemsAllowed" type="string" default="">
<cfparam name="lines" type="string" default="">


<cfif frmInstanceId eq 0 AND frmlabId eq 0>
	<cfset labsQuery = getlabsById(frmlab)>

	<cfloop query="labsQuery">
		<cfset frmInstanceId = instance_id>
		<cfset frmlabId = lab_id>
	</cfloop>
</cfif>


<!---now trim out extraneous time portions from start date and end date.--->
<cfset frmStartDate = dateFormat(frmStartDate, "mm/dd/yyyy 00:00")>
<cfset frmEndDate = dateFormat(frmEndDate, "mm/dd/yyyy 23:59:59.999")>


<h1>Lab Inventory Graph</h1>
<fieldset>
<legend>Graph Lab</legend>
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	<!---we can't just use drawlabsSelector() here, because we only want sites we have inventory information for.--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllLabs">
		SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name
		FROM vi_labs l
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = l.instance_id
		INNER JOIN tbl_inventory_site_items si
			ON si.instance_id = l.instance_id
			AND si.lab_id = l.lab_id
		WHERE l.active = 1
		AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
	</cfquery>

	<label for="frmLab">
		Lab:
	</label>
	<select id="frmlab"  name="frmlab" class="siteSelector">
	<cfoutput query="getAllLabs" group="instance_id">
		<optgroup label="#instance_name#">
		<cfoutput group="building_name">
			<optgroup label="&nbsp;&nbsp;&nbsp;&nbsp;#htmlEditFormat(building_name)#">
			<cfoutput>
				<cfset curvalue = "i#instance_id#l#lab_id#">
				<option value="#curvalue#" <cfif listFind(frmlab, curvalue)>selected</cfif>>&nbsp;&nbsp;&nbsp;&nbsp;#lab_name#</option>
			</cfoutput>
			</optgroup>
		</cfoutput>
		</optgroup>
	</cfoutput>
	</select>
	<br/>

	<label>
		Starting: <input type="text" class="date" name="frmStartDate" value="<cfoutput>#dateFormat(frmStartDate, 'mmm d, yyyy')#</cfoutput>">
	</label>
	&nbsp;&nbsp;
	<label>
		Through: <input type="text" class="date" name="frmEndDate" value="<cfoutput>#dateFormat(frmEndDate, 'mmm d, yyyy')#</cfoutput>">
	</label><br/>
	<input  type="submit" value="Submit">
</form>
</fieldset>
<script type="text/javascript">
	$(document).ready(function(){
		$("input.date").datepicker({dateFormat: "M d, yy"});
	});
</script>
<cfif frmLabId NEQ 0>
<div id="chart2"></div>
<div id="filteritems"></div>
<br/>
<div id="table2"></div>

<script type="text/javascript">
				<!---	<cfoutput>
					var labData = {
									frmInstanceId: #frmInstanceId#,
									frmlabId: #frmlabId#,
									frmStartDate: "#frmStartDate#",
									frmEndDate: "#frmEndDate#"
								}
					</cfoutput>
					$.ajax({
						type: "POST",
						url: "report_site_graph_ajax.cfm",
						data: labData,
						success: function(data)
					    {
					    	console.log("I sent somethings");
					    	$('#inventoryGraph').html(data);
					    },
					    error: function (data)
					    {
					 		$('#inventoryGraph').html(data);
					    }
					});--->
	x = new d3LineChart();//constructor came along with
	x.init("#chart2", 1000, 400, [], ["Paper, Plain, Letter"]);
	$(document).ready(function(){
		//first draw the graph with the default values.
		updateGraph();

		//hijack form submissions and just call updateGraph() again.
		$("form").on("submit", function(e){
			e.preventDefault();//don't actuall submit the form
			updateGraph();
		});

		//add listener for the filter checkboxes we'll draw for each graph.
		$(document).on("click", "input[name='lines']", function(evt){
			var newLines = [];

			$("input[name='lines']").each(function(n){
				var line = $(this);

				if(line.prop("checked")){
					newLines.push( line.val() );
				}
			});

			//the graph blows up if there are no lines are provided, so only updateLines() if we have some values for it.
			if( newLines.length > 0 ){
				x.updateLines( newLines );
				x.draw();
			}
		});
	});
	function updateGraph(){
		//snag the latest data based on the form's values and redraw the graph.
		/*Fetch our chart data from */
		<!---<cfoutput>
		var labData = {
					frmInstanceId: #frmInstanceId#,
					frmlabId: #frmlabId#,
					frmStartDate: "#frmStartDate#",
					frmEndDate: "#frmEndDate#"
				}
		</cfoutput>--->
		$.ajax({
			dataType: "json",
			url: "report_site_graph_ajax.cfm",
			data: {
				"frmStartDate": $("input[name='frmStartDate']").val(),
				"frmEndDate": $("input[name='frmEndDate']").val(),
				"frmLabId": $("#frmlab").val(),
				"users": $("#").val()
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

				var gData=JSON.parse(JSON.stringify(data));
				for(var d in gData){
					for(var n in gData[d]){
						if(n != "Date" && n != "User" && lines.indexOf(n) < 0){
							lines.push(n);
						}
					}
				}

				//update the lines, the data, and redraw the graph.
				//There's an issue with passing updateLines an empty array, so prevent that.
				if( lines.length > 0 ){
					x.updateLines(lines);
				}
				x.data = gData;
				x.draw();


				//Update the table of data, too.
				var tData=JSON.parse(JSON.stringify(data));
				for(var d in tData){
					for(var n in tData[d]){
						if(n == "Date"){
							var tDate=new Date(tData[d][n]);
							tData[d][n]=tDate.dateFormat("yyyy-mm-dd HH:nn");
						}
					}
				}
				lines.unshift("User");
				lines.unshift("Date");
				var t=d3Table(tData, lines, "#table2")

				var checkbox=drawFilter();
				function drawFilter()
				{
					/*
					for(var n in lines)
					{
					console.log(lines[n]);
					var input = $( document.createElement('input') );
					input.attr("type", "checkbox");
					input.attr("name", "lines");
					input.val( lines[n] );
					var label = $( document.createElement('label') );
					label.html( input );
						for(var i=2;i<=n;i++)
					{
					label.append( lines[n--] );
					$("#filteritems").append(label);
					}

					}*/

					//empty out #filteritems for our new values.
					$("#filteritems").html("");

					for(var n in x.lines){
						var input = $( document.createElement('input') );
						input.attr("type", "checkbox");
						input.attr("name", "lines");
						input.val( x.lines[n].name );
						input.attr("checked", true);

						var label = $( document.createElement('label') );
						label.html( input );
						label.append( x.lines[n].name );

						$("#filteritems").append(" ");
						$("#filteritems").append(label);
					}

				}

			}

		});
		}

</script>

<br/><br/>
</cfif>



<!---TABLE of all user submissions.--->

<!---this query looks very similar to the one above, except we want all the submissions, not just the last one of the day--->
<!---<cfquery datasource="#application.applicationDataSource#" name="getAllInventories">
	SELECT sub.submission_id, u.username, sub.submitted_date, si.item_id, si.quantity
	FROM tbl_inventory_submissions sub
	INNER JOIN tbl_users u ON u.user_id = sub.user_id
	INNER JOIN tbl_inventory_submission_items si
		ON si.submission_id = sub.submission_id
		/*only grab the last submission of the day*/
	WHERE sub.instance_id = #frmInstanceId#
	AND sub.lab_id = #frmlabId#
	AND sub.submitted_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
	ORDER BY sub.submission_id
</cfquery>

<!---find all the items submitted--->
<cfset itemList = "">
<cfloop query="getAllInventories">
	<cfif not listFind(itemList, item_id)>
		<cfset itemList = listAppend(itemList, item_id)>
	</cfif>
</cfloop>

<!---build a struct matching id's to full names--->
<cfset itemStruct = structNew()>
<cfloop list="#itemList#" index="itemId">
	<cfset itemStruct[itemId] = getFullItemName(itemId)>
</cfloop>

<cfset sortOrder = structSort(itemStruct, "textnocase", "asc")>
<cfif getAllInventories.recordCount neq 0>
	<table class="stripe">
		<tr class="titlerow">

			<td colspan="<cfoutput>#2 + arrayLen(sortOrder)#</cfoutput>">Inventory Submissions</td>
		</tr>
		<tr class="titlerow2" style="font-size: 8pt;">
			<th>
				User
			</th>
			<th>
				Date
			</th>
			<cfloop array="#sortOrder#" index="i">
				<th>
					<cfoutput>#itemStruct[i]#</cfoutput>
				</th>
			</cfloop>
		</tr>
	<!---now we start printing out each inventory--->
	<cfloop query="getAllInventories" group="submission_id">
		<!---find our submission_id--->
		<cfset subId = submission_id>

		<tr style="text-align: center; font-size: 8pt;">
			<cfoutput>
			<td>#getAllInventories.username#</td>
			<td style="min-width: 60px;">
				#dateFormat(submitted_date, "mmm d, yyyy")#<br/>
				#timeFormat(submitted_date, "short")#
			</td>
			</cfoutput>
		<!---now we have to loop through and find the correct item for this submission--->
		<cfloop array="#sortOrder#" index="itemId">
			<cfset value = "-">
			<cfloop query="getAllInventories">
				<cfif submission_id eq subId and itemId eq item_id>
					<cfset value = quantity>
					<!---we've hit it, break out of this loop.--->
					<cfbreak>
				</cfif>
			</cfloop>
			<cfoutput>
				<td>#value#</td>
			</cfoutput>
		</cfloop>
		</tr>
	</cfloop>

	</table>
</cfif>--->


<cfmodule template="#application.appPath#/footer.cfm">