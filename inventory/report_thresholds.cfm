<cfmodule template="#application.appPath#/header.cfm" title='Inventory' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!--- cfparams --->
<cfparam name="frmItemId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">
 
<!--- Header / Navigation --->
<h1>Inventory Threshold Levels</h1>
<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Inventory Management</a>
<br/><br/>

<!--- Fetch routes. --->
<cfquery datasource="#application.applicationDataSource#" name="getAllRoutes">
	SELECT r.instance_id, i.instance_name, r.route_id, r.route_name, r.sort_order
	FROM vi_routes r
	INNER JOIN tbl_instances i ON i.instance_id = r.instance_id
	ORDER BY i.instance_name, r.sort_order, r.route_id
</cfquery>

<cfif frmAction EQ "Clear">
	<cfset frmItemId = "0">
	<cfset frmAction = "">
</cfif>

<!--- Item selector to filter results by a particular item. --->
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	
	<fieldset>
		<cfset drawItemSelectBox("frmItemId", #frmItemId#)>	
		<input type="submit" value="Submit" name="frmAction">
		<input type="submit" value="Clear" name="frmAction">	
	</fieldset>

</form> 

<!--- Build up an array of routes from the route query. --->
<cfset routesArray = arrayNew(1)>
<cfloop query="getAllRoutes">
	<cfset routeStruct = structNew()>
	<cfset routeStruct.instanceId = instance_id>
	<cfset routeStruct.routeId = route_id>	
	<cfset arrayAppend(routesArray, routeStruct)>
</cfloop>

<!--- Loop over and draw the routes. --->
<cfset prevInstanceId = 0>
<cfloop query="getAllRoutes">
	<cfloop array="#routesArray#" index="route">
		<cfif route.instanceid eq instance_id AND route.routeId eq route_id>
			<cfoutput>
				<!--- If our instance changed, write the new header. --->
				<cfif prevInstanceId neq instance_id>
					<h3>#instance_name# Routes</h3>
				</cfif>
				<h4>#route_name#</h4>
				<cfset drawlabInventoriesByRoute(instance_id, route_id)>
			</cfoutput>
			<!--- Store the current instance. --->
			<cfset prevInstanceId = instance_id>
		</cfif>
	</cfloop>
</cfloop>

<!--- functions --->

<!--- Given a route, draws its lab inventories. --->
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

	<cfset drawnLab = 0>
	
	<!--- Armed with our labId we can fetch the valid items, types, and current levels for this lab. --->
	<cfloop query="getRoutelabs">
	
		<cfset labAllItemList = getItemsListBylab(instance_id, lab_id)>
		<cfset labItemList = "">
		<cfset labTypeList = "">
		
		<cfloop list="#labAllItemList#" index="n">
			<cfif frmItemId EQ 0 OR frmItemID EQ n>
				<!---This list may end up with duplicates, but that isn't a problem for the queries it'll be used in.--->
				<cfset labItemList = listAppend(labItemList, n)>
				<cfset labTypeList = listAppend(labTypeList, getAncestorTypesByItemId(n))>
			</cfif>
		</cfloop>
		
		<!--- If the user picked an item and the lab does not contain it, don't draw it. --->
		<cfif labItemList NEQ "">
			
			<cfset drawnLab = 1>
				
			<!---at this point we have a list of legit items and types, loop over all types and draw the types and items that apply.--->
			<fieldset class="report-lab">
				<cfoutput>
					<legend>#building_name# #lab_name#</legend>
				
					<cfset drawListItemThresholds(instance_id, lab_id, labItemList, labTypeList, 0)>
					<cfset labId = "i#instance_id#l#lab_id#">
					<a href="#application.appPath#/inventory/manage-site-items.cfm?frmlabId=#labId#" target="_blank">Manage Lab Items</a>
				</cfoutput>
			</fieldset>
		</cfif>
		
	</cfloop>
	
	<!--- If we didn't draw any labs for this route, write a message. --->
	<cfif not drawnLab>
		<em>No labs with specified item for this route.</em>
	</cfif>
	
</cffunction>

<!--- Given a lab's inventory information, draw the thresholds. --->
<cffunction name="drawListItemThresholds">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="itemsList" type="string" required="true">
	<cfargument name="typesList" type="string" required="true">
	<cfargument name="parentTypeId" type="numeric" required="true">
	
	<!--- Prevents rather impressive-looking crazed duplication of drawn data. --->
	<cfset var childTypes = ""> <!--- A query of all child types for this type_id --->
	<cfset var labItems = ""> <!--- A query of items for this type in this lab. --->
	
	<!--- Fetch the child types --->
	<cfquery datasource="#application.applicationDataSource#" name="childTypes">
		SELECT item_type_id, item_type_name, parent_type_id
		FROM tbl_inventory_item_types
		WHERE parent_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentTypeId#">
		AND item_type_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#typesList#" list="true">)
		ORDER BY item_type_name
	</cfquery>
	
	<!--- Fetch the items, and their current levels, for the current parentTypeId. --->
	<cfquery datasource="#application.applicationDataSource#" name="labItems">
		SELECT si.item_id, i.item_name, si.warn_level, si.critical_level, si.sort_order
		FROM tbl_inventory_site_items si
		INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
		WHERE si.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND si.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
		AND i.retired = 0
		AND i.item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentTypeId#">
		AND i.item_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#itemsList#" list="true">)/*restrict the items we draw based on itemsList*/
		ORDER BY si.sort_order, i.item_name
	</cfquery>
	
	<!--- Display our types and items for parentTypeId. --->
	<ul class="inventory">
	<cfoutput query="childTypes">
		<li><b>#item_type_name#</b></li>
		<!--- Recursively display child types. --->
		<cfset drawListItemThresholds(instanceId, labId, itemsList, typesList, item_type_id)>
	</cfoutput>
	
	<!--- Now draw the actual items for this type and lab. --->
	<cfoutput query="labItems">
		<li>#item_name#: <span class="warn">#warn_level#</span> <span class="crit">#critical_level#</span></li>
	</cfoutput>
		
	</ul>
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">