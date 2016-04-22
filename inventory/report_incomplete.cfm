<cfmodule template="#application.appPath#/header.cfm" title='Supply Report - Incomplete' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfsetting showdebugoutput="false">

<!--- include common inventory functions --->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">


<!--- STYLE / CSS --->
<style type="text/css">
	fieldset {
		margin-top:2em;
	}
</style>
<h1>Incomplete Supply Report for the Day</h1>

[<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Inventory Management</a>]
<br/>

<!--- get Incomplete Supply Report --->
<cfquery datasource="#application.applicationDataSource#" name="getIncompleteSR">
DECLARE @instance int = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">,
		@startDate datetime ;
SET @startDate=<cfqueryparam cfsqltype="cf_sql_timestamp" value="#dateFormat(now(), 'yyyy-mm-dd')#">
DECLARE @endDate datetime = DATEADD(day, 1, @startDate)


SELECT DISTINCT b.instance_id, b.building_name, l.lab_id, l.lab_name
FROM tbl_inventory_site_items sii /*we want to limit results to labs that have Inventory items*/
INNER JOIN vi_labs l
	ON l.instance_id = sii.instance_id
	AND l.lab_id = sii.lab_id
INNER JOIN vi_buildings b
	ON b.instance_id = l.instance_id
	AND b.building_id = l.building_id
LEFT OUTER JOIN tbl_inventory_submissions ism /*now we're interested in sites that did not have submissions, during the time so an outer join is required*/
	ON ism.instance_id = l.instance_id
	AND ism.lab_id = l.lab_id
	AND ism.submitted_date BETWEEN @startDate AND @endDate

WHERE sii.instance_id = @instance
AND ism.submission_id IS NULL /*only rows without submission data*/

ORDER BY b.building_name, l.lab_name
</cfquery>
<cfloop query="getIncompleteSR">
<div style="width:40%; display:inline-block;">
			<fieldset class="report-lab">
				<cfoutput>
					<legend>#building_name# #lab_name#</legend>
					<div class="alert alert-warning" role="alert">Supply Report not submitted</div>
					<a href="#application.appPath#/inventory/report_site_graph.cfm?frmInstanceId=#instance_id#&frmlabId=#lab_id#" target="_blank">Supply Graph</a>
				</cfoutput>
			</fieldset>
		</div>
</cfloop>

<cfmodule template="#application.appPath#/footer.cfm">