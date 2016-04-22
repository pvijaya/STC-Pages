<cfmodule template="#application.appPath#/header.cfm" title='Inventory' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfsetting showdebugoutput="false">

<!--- include common inventory functions --->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmRoutes" default="">
<cfparam name="frmRouteId" type="string" default="i0r0">

<!--- STYLE / CSS --->
<style type="text/css">
	fieldset {
		margin-top:2em;
	}
</style>

<!--- HEADER / NAVIGATION --->
<h1>Inventory Levels</h1>
[<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Inventory Management</a>]
<br/>


<!--->
<!--- draw route selector --->
<cfquery datasource="#application.applicationDataSource#" name="getAllRoutes">
	SELECT r.instance_id, i.instance_name, r.route_id, r.route_name, r.sort_order
	FROM vi_routes r
	INNER JOIN tbl_instances i ON i.instance_id = r.instance_id
	WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		  AND r.access_level >= 3
	ORDER BY i.instance_name, r.sort_order, r.route_id
</cfquery>

<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	<fieldset>
		<legend>Choose Routes</legend>
		<cfoutput query="getAllRoutes" group="instance_id">
				<cfoutput>
					<label><input type="checkbox" name="frmRoutes" value="i#instance_id#r#route_id#" <cfif listFind(frmRoutes, "i#instance_id#r#route_id#") OR listLen(frmRoutes) eq 0>checked</cfif>>#route_name#</label> 
					<br/>
				</cfoutput>
		</cfoutput>
		<br/>
		<input  type="submit" value="Limit">
	</fieldset>
</form>


<!--- build-up an array of routes from the data in frmRoutes. --->
<cfset routesArray = arrayNew(1)>
<cfloop query="getAllRoutes">
	<cfif listFind(frmRoutes, "i#instance_id#r#route_id#")>
		<cfset routeStruct = structNew()>
		<cfset routeStruct.instanceId = instance_id>
		<cfset routeStruct.routeId = route_id>
		
		<cfset arrayAppend(routesArray, routeStruct)>
	</cfif>
</cfloop>
<!--- if no routes were selected, include all routes --->
<cfif arrayLen(routesArray) eq 0>
	<cfloop query="getAllRoutes">
		<cfset routeStruct = structNew()>
		<cfset routeStruct.instanceId = instance_id>
		<cfset routeStruct.routeId = route_id>
		
		<cfset arrayAppend(routesArray, routeStruct)>
	</cfloop>
</cfif>
<!---routesArray is complete.--->
--->

<cfset routeStruct = parseRoute(frmRouteId)>
<cfset instanceId = routeStruct.instance>
<cfset routeId = routeStruct.route>

<!--- if the user currently has a shift on a route, select that one by default --->
<cfif instanceId eq 0 OR routeId eq 0>

	<!--- fetch the rich info for the instances that the user has access to, --->
	<!--- in particular we need the instance_id and datasource to pull info from the correct PIE. --->
	<!--- use the primary instance only to coincide with the rest of tetra --->
	<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
		SELECT i.instance_id, i.instance_name, i.instance_mask, i.datasource
		FROM tbl_instances i
		WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#"> 
	</cfquery>
	
	<!--- 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask) --->
	
	<cfloop query="getUserInstances">
		<!--- reach into this instance's PIE and look for a current shift for our user.  --->
		<!--- Specifically a shift that has a route, all others will be ignored. --->
		<cfquery datasource="#application.applicationDataSource#" name="getShift">
			SELECT TOP 1 sb.site_id, si.site_name, r.route_id, r.retired
			FROM [#datasource#].dbo.shift_blocks sb
			/*this could restrict us to folks who are currently checked in.
			INNER JOIN tbl_checkins ci ON ci.checkin_id = sb.checkin_id
			*/
			INNER JOIN [#datasource#].dbo.tbl_consultants c ON c.ssn = sb.ssn
			INNER JOIN [#datasource#].dbo.tbl_sites si ON si.site_id = sb.site_id
			INNER JOIN [#datasource#].dbo.tbl_routes r ON r.mentor_site_id = sb.site_id
			WHERE LOWER(c.username) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">)
			AND GETDATE() BETWEEN sb.shift_time AND DATEADD(hour, 1, sb.shift_time)
		</cfquery>
		
		<cfloop query="getShift">
			<!---we've hit a shift on a route, set the global values and bust out of these loops.--->
			<cfset instanceId = getUserInstances.instance_id>
			<cfif not retired><!---don't try to work with sites on retired routes--->
				<cfset routeId = route_id>
			<cfelse>
				<cfset routeId = 0>
			</cfif>
		</cfloop>
		
		<cfif instanceId neq 0 AND routeId neq 0>
			<!---we've got legit values, break out of the loop.--->
			<cfbreak>	
		</cfif>
		
	</cfloop>	
</cfif>

<!--- draw route select --->

<cfquery datasource="#application.applicationDataSource#" name="getRoutes">
	SELECT i.instance_id, i.instance_name, i.datasource, r.route_id, r.route_name, r.color, r.sort_order
	FROM vi_routes r
	INNER JOIN tbl_instances i ON i.instance_id = r.instance_id
	/*limit to instances the user has masks to view.*/
	WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#"> 	
		  AND r.access_level >= 3
	ORDER BY i.instance_name, r.sort_order
</cfquery>

<!--- if at this point we still don't have a route for our user default to the first one available --->
<!--- if user is IUB admin AND in IUB instance, default to Supervisor Route --->
<cfif instanceId eq 0 AND routeId eq 0 AND hasMasks('ADMIN') AND hasMasks('IUB')
	  AND session.primary_instance eq 1>
		<cfset instanceId = 1>
		<cfset routeId = 7>
<cfelseif instanceId eq 0 AND routeId eq 0>
	<cfloop query="getRoutes">
		<cfset instanceId = instance_id>
		<cfset routeId = route_id>
		<cfbreak> <!---leave the loop, we're done.--->
	</cfloop>
</cfif>

<cfif getRoutes.recordCount eq 0>
	<p class="warning">You do not have access to any Routes to Review</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>

<!---if the user has provided a route they'd like to view make sure they have access to view it.--->
<cfset canViewRoute = 0>
<cfloop query="getRoutes">
	<cfif instance_id eq instanceId>
		<cfset canViewRoute = 1>
		<cfbreak>
	</cfif>
</cfloop>

<cfif not canViewRoute>
	<p class="warning">The route you selected either does not exist or is not available to you.</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>

<!---if at this point we still don't have a route selected default to the first one available--->
<cfif instanceId eq 0 OR routeId eq 0>
	<cfset instanceId = getRoutes.instance_id[1]>
	<cfset routeId = getRoutes.route_id[1]>
</cfif>

<br/>

<cfset routeName = "">
<cfloop query="getRoutes">
	<cfif route_id EQ routeId AND instance_id EQ instanceId>
		<cfset routeName = route_name>
	</cfif>
</cfloop>

<form>
	<label>Select a Route:
	<select name="frmRouteId">
		<cfoutput query="getRoutes" group="instance_id">
			<optgroup label="#htmlEditFormat(instance_name)#">
				<cfoutput>
					<option value="i#instance_id#r#route_id#" style="color: #color#;" 
						<cfif instanceId eq instance_id AND routeId eq route_id>selected="selected"</cfif>>
							#route_name#
					</option>
				</cfoutput>
			</optgroup>
		</cfoutput>
	</select>
	</label>
	<input type="submit"  value="Go">
</form>

<!---
	Route Selection Ends.  We now have a valid instanceId and routeId to use.
--->


<!---loop over all routes, and if they are found in our routesArray draw them.--->
<cfoutput><h2 style="margin-bottom:0em;">#routeName#</h2></cfoutput>
<cfset drawlabInventoriesByRoute(instanceId, routeId)>

<!--- CFFUNCTIONS --->
<!---this function takes a route, and draws all the labs that have inventory items in that route.--->
<cffunction name="drawlabInventoriesByRoute">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="routeId" type="numeric" required="true">
	
	<cfset var getRoutelabs = "">
	<cfset var labItemList = "">
	<cfset var labTypeList = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getRoutelabs">		
		SELECT DISTINCT ls.instance_id, ls.lab_id, l.lab_name, b.building_name
		FROM vi_routes_sites rs
		INNER JOIN vi_labs_sites ls
			ON ls.instance_id = rs.instance_id
			AND ls.site_id = rs.site_id
		INNER JOIN vi_labs l
			ON l.instance_id = ls.instance_id
			AND l.lab_id = ls.lab_id
			AND l.active = 1
		/*I hate to use a subquery, but this will be faster than doing an external query and looping in code.*/
		INNER JOIN (
			SELECT DISTINCT instance_id, lab_id
			FROM tbl_inventory_site_items
			) si ON si.instance_id = rs.instance_id AND si.lab_id = ls.lab_id
		LEFT OUTER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		WHERE rs.instance_id = #instanceId#
		AND rs.route_id = #routeId#
		ORDER BY b.building_name, l.lab_name
	</cfquery>
	<cfif getRoutelabs.recordCount eq 0>
		<em>No labs with inventory for this route.</em>
	</cfif>
	
	<cfset allItems = getAllItems()>
	<cfset allItemTypes = getAllItemTypes()>
	
	<!---armed with our labId we can fetch the valid items, types, and current levels for this lab.--->
	<cfloop query="getRoutelabs">
		
		<div style="width:40%; display:inline-block;">
			<fieldset class="report-lab">
				<cfoutput>
					<legend>#building_name# #lab_name#</legend>
					<cfset drawLabInventory(lab_id, 0, "", allItems, allItemTypes)>
					<a href="#application.appPath#/inventory/report_site_graph.cfm?frmInstanceId=#instance_id#&frmlabId=#lab_id#" target="_blank">Supply Graph</a>
				</cfoutput>
			</fieldset>
		</div>
		
		<!--->
		<cfset labItemList = getItemsListBylab(instance_id, lab_id, allItems)>
		<cfset labTypeList = "">
		
		<cfloop list="#labItemList#" index="n">
			<cfset labTypeList = listAppend(labTypeList, getAncestorTypesByItemId(n, allItems, allItemTypes))><!---this list may end up with duplicates, but that isn't a problem for the queries it'll be used in.--->
		</cfloop>
		
		<!---at this point we have a list of legit items and types, loop over all types and draw the types and items that apply.--->
		<fieldset class="report-lab">
			<cfoutput>
				<legend>#building_name# #lab_name#</legend>
			
				<cfset drawListItems(instance_id, lab_id, labItemList, labTypeList, 0, 1)>
				
				<a href="#application.appPath#/inventory/report_site_graph.cfm?frmInstanceId=#instance_id#&frmlabId=#lab_id#" target="_blank">Supply Graph</a>
			</cfoutput>
		</fieldset>
		--->
	</cfloop>
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">