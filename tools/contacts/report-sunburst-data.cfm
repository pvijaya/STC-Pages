<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json">

<!---if the user isn't authorized to view it just return an empty object.--->
<cfif not hasMasks("cs")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>


<cfparam name="frmSubject" type="integer" default="0"><!---0 for campus/building/lab, 1 for category--->
<cfparam name="startDate" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">
	<cfparam name="endDate" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">

<cfquery datasource="#application.applicationDataSource#" name="getContacts">
	SELECT COUNT(c.contact_id) AS contacts, SUM(c.minutes_spent) AS minutes,
		<!---the faux date we create depends upon our granularity setting.--->
		<cfswitch expression="#frmSubject#">
			<cfcase value="0">
				c.instance_id, i.instance_name, b.building_name, b.short_building_name, c.room_number
			</cfcase>
			<cfcase value="1">
				cc.category_id, cc.category_name, cc.parent_category_id
			</cfcase>
		</cfswitch>
		
	FROM tbl_contacts c
	
	<cfswitch expression="#frmSubject#">
		<cfcase value="0">
			INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
			INNER JOIN vi_buildings b
				ON b.instance_id = c.instance_id
				AND b.building_id = c.building_id
		</cfcase>
		<cfcase value="1">
			INNER JOIN tbl_contacts_categories_match ccm ON ccm.contact_id = c.contact_id
			INNER JOIN tbl_contacts_categories cc ON cc.category_id = ccm.category_id
		</cfcase>
	</cfswitch>
	
	WHERE created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
	<!---our group by clause also depends on our granularity setting--->
	<cfswitch expression="#frmSubject#">
		<cfcase value="0">
			GROUP BY c.instance_id, i.instance_name, b.building_name, b.short_building_name, c.room_number
			ORDER BY i.instance_name, b.building_name, c.room_number
		</cfcase>
		<cfcase value="1">
			GROUP BY cc.category_id, cc.category_name, cc.parent_category_id
			ORDER BY cc.parent_category_id, cc.category_name
		</cfcase>
	</cfswitch>
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getCategories">
	SELECT category_id, category_name, parent_category_id
	FROM tbl_contacts_categories
	ORDER BY parent_category_id, category_name
</cfquery>


<cfset contactsObj = structNew()>
<cfset contactsObj['name'] = "Contacts">
<cfset contactsObj['children'] = arrayNew(1)>


<!--- if we're just doing buildings we can use grouping to generate our object--->
<cfswitch expression="#frmSubject#">
	<cfcase value="0">
		<cfloop query="getContacts" group="instance_id">
			<cfset instanceObj = structNew()>
			<cfset instanceObj['name'] = instance_name>
			<cfset instanceObj['children'] = arrayNew(1)>
			
			<cfloop group="short_building_name">
				<cfset buildObj = structNew()>
				<cfset buildObj['name'] = short_building_name>
				<cfset buildObj['children'] = arrayNew(1)>
				
				<cfloop>
					<cfset labObj = structNew()>
					<cfset labObj['name'] = "#short_building_name# #room_number#">
					<cfset labObj['contacts'] = contacts>
					<cfset labObj['minutes'] = minutes>
					
					<cfset arrayAppend(buildObj['children'], labObj)>
				</cfloop>
				
				<cfset arrayAppend(instanceObj['children'], buildObj)>
			</cfloop>
			
			<cfset arrayAppend(contactsObj['children'], instanceObj)>
		</cfloop>
	</cfcase>
	<cfcase value="1">
		<cfset contactsObj['children'] = getChildObj(0)>
	</cfcase>
</cfswitch>


<cfset contactsJson = serializeJSON(contactsObj)>

<cfoutput>#contactsJSON#</cfoutput>


<cffunction name="getChildObj" output="false">
	<cfargument name="parentId" type="numeric" required="true">
	
	<cfset var childArray = arrayNew(1)>
	<cfset var childObj = structNew()>
	
	<!---because of the fact our parent categories may have children of their own, if the parent has contacts it should be its own first child--->
	<cfloop query="getContacts">
		<cfif category_id eq parentId>
			<cfset childObj = structNew()>
			<cfset childObj['name'] = category_name>
			<cfset childObj['contacts'] = contacts>
			<cfset childObj['minutes'] = minutes>
			
			<cfset arrayAppend(childArray, childObj)>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<!---now for each child category generate a childObj apropriate for it.--->
	<cfloop query="getCategories">
		<cfif parent_category_id eq parentId>
			<cfset childObj = structNew()>
			<cfset childObj['name'] = category_name>
			
			<!---here stuff gets a little interesting, a childObj can either return an array of children, OR the number of contacts it has, never both.  So we need to take a different course of action if our current category has children with contacts--->
			<cfif hasChildCatContacts(category_id)>
				<cfset childObj['children'] = getChildObj(category_id)>
			<cfelse>
				<cfloop query="getContacts">
					<cfif getCategories.category_id eq getContacts.category_id>
						<cfset childObj['contacts'] = contacts>
						<cfset childObj['minutes'] = minutes>
						
						<cfbreak>
					</cfif>
				</cfloop>
			</cfif>
			
			<!---at this point we have a properly structured childObj, append it to childArray and move on.--->
			<cfset arrayAppend(childArray, childObj)>
		</cfif>
	</cfloop>
	
	<cfreturn childArray>
</cffunction>

<cffunction name="hasChildCatContacts" output="false">
	<cfargument name="parentId" type="numeric" required="true">
	
	<cfloop query="getCategories">
		<cfif parent_category_id eq parentId>
			<cfloop query="getContacts">
				<cfif getCategories.category_id eq getContacts.category_id>
					<cfreturn 1>
				</cfif>
			</cfloop>
		</cfif>
	</cfloop>
	
	<cfreturn 0>
</cffunction>