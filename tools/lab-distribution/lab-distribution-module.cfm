<!---Due to common-functions conflict this is just an include--->
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant" showMaskPermissions="False">

<!---Queries--->
<cffunction name="getTicketsByRoute">
	<cfargument name="routeFormElement" default="i0r0">

	<cfset var routeObj = parseRoute(routeFormElement)><!---get a usable struct of our route based on the user's input.--->
	<cfset var getTickets = "">

	<cfquery datasource="#application.applicationDataSource#" name="getTickets">
		SELECT DISTINCT t.ticket_id, t.item_id, t.comment, ti.item_name
		FROM tbl_lab_dist_ticket t
		INNER JOIN tbl_lab_dist_item_list ti ON t.item_id = ti.item_id
		INNER JOIN vi_lab_dist_ticket_entries te /*is the item both active for this ticket and not currently completed?*/
			ON te.ticket_id = t.ticket_id
			AND te.active = 1
			AND te.is_complete = 0
		/*from here we're getting information to check if this ticket is on a particular route*/
		INNER JOIN vi_labs l
			ON l.instance_id = te.instance_id
			AND l.lab_id = te.lab_id
		LEFT OUTER JOIN vi_labs_sites ls
			ON ls.instance_id = l.instance_id
			AND ls.lab_id = l.lab_id
		LEFT OUTER JOIN vi_routes_sites rs
			ON rs.instance_id = ls.instance_id
			AND rs.site_id = ls.site_id
		WHERE l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			  <cfif routeObj.instance neq 0 AND routeObj.route neq 0>
				AND rs.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#routeObj.instance#">
				AND rs.route_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#routeObj.route#">
			  </cfif>
		ORDER BY ti.item_name
	</cfquery>

	<cfreturn getTickets>
</cffunction>

<!--- Functions --->
<cffunction name="getLabsForTicket">
	<cfargument name="ticketId">

	<cfset var ticketLabs = "">

	<cfquery datasource="#application.applicationDataSource#" name="ticketLabs">
		SELECT b.building_name, l.lab_name
		FROM vi_lab_dist_ticket_entries vte
		INNER JOIN vi_labs l
			ON l.instance_id = vte.instance_id
			AND l.lab_id = vte.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		WHERE vte.ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ticketId#">
		      AND vte.is_complete = 0 /* don't list labs that have already had stuff delivered. */
		      AND vte.active = 1 /* don't list retired labs */
	</cfquery>

	<cfreturn ticketLabs>
</cffunction>


<cffunction name="showRoutes">
	<cfargument name="routeFormElement" default="i0r0">

	<cfset var routeObj = parseRoute(routeFormElement)><!---get a usable struct of our route based on the user's input.--->
	<cfset var getRoutes = "">

	<cfquery datasource="#application.applicationDataSource#" name="getRoutes">
		SELECT i.instance_name, r.*
		FROM vi_routes r
		INNER JOIN tbl_instances i ON i.instance_id = r.instance_id
		WHERE r.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY i.instance_id, r.sort_order
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method='post'>
		By Route:
		<select name="frmRouteId"  onchange='this.form.submit()'>
			<option SELECTED value="">All</option>

			<cfoutput query='getRoutes' group="instance_id">
				<optgroup label="#instance_name#">
				<cfoutput>
					<cfif routeObj.route EQ route_id AND routeObj.instance EQ instance_id>
						<option SELECTED value="i#instance_id#r#route_id#">#route_name#</option>
					<cfelse>
						<option value="i#instance_id#r#route_id#">#route_name#</option>
					</cfif>
				</cfoutput>
				</optgroup>
			</cfoutput>
		</select>
	</form>
</cffunction>