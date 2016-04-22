<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json">

<!---if the user isn't authorized to view it just return an empty object.--->
<cfif not hasMasks("cs")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<!---fetch the lab info.--->
<cfsetting showdebugoutput="false">
<cfparam name="frmlabId" type="string" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d", -30, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<cfparam name="itemsAllowed" type="string" default="">

<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!---parse frmLabId into a struct that contains instance and lab Id's.--->
<cfset labObj = parseLabName(frmLabId)>


<cfquery datasource="#application.applicationDataSource#" name="getlabInventories">
	SELECT sub.submission_id, u.username, sub.submitted_date AS submitted_date, si.item_id, si.quantity
	FROM tbl_inventory_submissions sub
	INNER JOIN tbl_users u ON u.user_id = sub.user_id
	INNER JOIN tbl_inventory_submission_items si
		ON si.submission_id = sub.submission_id
		/*only grab the last submission of the day*/
		AND si.submission_id = (
			SELECT TOP 1 submission_id
			FROM tbl_inventory_submissions
			WHERE CONVERT(varchar, submitted_date, 101) = CONVERT(varchar, sub.submitted_date, 101)
			AND instance_id = sub.instance_id
			AND lab_id = sub.lab_id
			ORDER BY submitted_date DESC)
	WHERE sub.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.instance#">
	AND sub.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.lab#">
	AND sub.submitted_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
	ORDER BY sub.submission_id
</cfquery>


<!---can we do a sub-query to get the distinct items?--->
<cfquery dbtype="query" name="getItems">
	SELECT DISTINCT item_id
	FROM getlabInventories
</cfquery>
<cfset filterItems = "">
<!---<cfsavecontent variable="chartOutput">
	<cfchart chartheight="800" chartwidth="760" show3d="no" format="png" showlegend="yes">
		<cfloop query="getItems">
			<cfset itemName = getFullItemName(item_id)>
			<cfif ListFindNoCase(itemsAllowed,getItems.item_id) NEQ 0 || itemsAllowed EQ "">
				<cfset filterItems = filterItems & "<label style='display:inline-block;width:45%;'> <input type='checkbox' name='itemsAllowed' value='#item_id#' checked='checked'> #itemName#</label>">

				<cfchartseries type="line" serieslabel="#itemName#">

					<!---now snag all inventories for this item--->
					<cfquery dbtype="query" name="getItemInventories">
						SELECT submitted_date, quantity
						FROM getlabInventories
						WHERE item_id = #item_id#
						ORDER BY submitted_date
					</cfquery>

					<cfloop query="getItemInventories">
						<cfchartdata item="#dateFormat(submitted_date, "mm/dd/yyyy")#" value="#quantity#">
					</cfloop>
				</cfchartseries>
			<cfelse>
			<cfset filterItems = filterItems & "<label style='display:inline-block;width:45%;'> <input type='checkbox' name='itemsAllowed' value='#getItems.item_id#'> #itemName# </label>">
			</cfif>
		</cfloop>
	</cfchart>
</cfsavecontent>
<cfoutput>#chartOutput#</cfoutput>--->
<cfset countArray = arrayNew(1)>
<!---cfdump var="#getLabInventories#"><cfabort--->
<cfloop query="getlabInventories" group="submission_id">
	<!---cfset useDate = dateFormat(date, dateFormatString)--->

	<!---javascript can use an ISO 8601 date to create a Date object.--->
	<cfset utcDate = dateConvert("local2utc", submitted_date)>
	<cfset useDate = dateFormat( utcDate, "yyyy-mm-dd" ) & "T" & timeFormat( utcDate, "HH:mm:ss" ) & "Z">

	<!---we need to make the structure to append to the array.--->
	<cfset myCount = structNew()>

	<cfset myCount['Date'] = useDate>
	<cfset myCount['User'] = username>
	<cfloop>
		<cfset myCount['#getFullItemName(item_id)#'] = quantity>
	</cfloop>

	<cfset arrayAppend(countArray, myCount)>
</cfloop>

<cfset countJson = serializeJSON(countArray)>

<cfoutput>#countJson#</cfoutput>


<!---<fieldset>
<legend>Filter Items</legend>
<cfoutput>
<form action="#cgi.script_name#" method="post">
	<div id="filters">#filterItems#</div>
	<br/>
	<input id="filterItemsBtn" type="button" value="Submit">
</form>
</fieldset>
</cfoutput>
<script>
						<cfoutput>
						var filterData = {
										frmInstanceId: #frmInstanceId#,
										frmlabId: #frmlabId#,
										frmStartDate: "#frmStartDate#",
										frmEndDate: "#frmEndDate#",
									}
						</cfoutput>
						$( "#filterItemsBtn" ).click(function( event ) {
							var checks = $.map($(':checkbox[name=itemsAllowed]:checked'), function(n, i){
							      return n.value;
							}).join(',');
							filterData.itemsAllowed = checks;
							console.log(filterData);

							$.ajax({
								type: "POST",
								url: "report_site_graph_ajax.cfm",
								data: filterData,
								success: function(data)
							    {
							    	console.log("I sent somethings");
							    	$('#inventoryGraph').html(data);
							    },
							    error: function (data)
							    {
							 		$('#inventoryGraph').html(data);
							    }
							});
							event.preventDefault();
						});
						--->

</script>
</div>