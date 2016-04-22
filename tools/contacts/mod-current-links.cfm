<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<!---this returns information about tickets that are linked together that have at least one open contact.--->

<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfif not hasMasks("consultant")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfset response = StructNew()>

<cftry>
	<!---first a query to grab all contacts that have other contacts linking to them, and one of those "related" contacts is still open.--->
	<cfquery datasource="#application.applicationDataSource#" name="getLinkSuggestions">
		SELECT DISTINCT c2.contact_id, c2.created_ts, cs.status, u.username, cc.category_name
		FROM tbl_contacts_relationships cr
		/*this join gets us any relationships that have an 'open' contact in them*/
		INNER JOIN tbl_contacts c
			ON (c.contact_id = cr.contact_id OR c.contact_id = cr.links_to)
			AND c.status_id = 1
			AND c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#"> /*limit the results to the user's instance, too*/
		/*since that was an inner join we can do another inner join to just return the "parent" contact for this active relationship*/
		INNER JOIN tbl_contacts c2 ON c2.contact_id = cr.links_to
		/*now we can get details about our "parent" contact.*/
		INNER JOIN tbl_contacts_statuses cs ON cs.status_id = c2.status_id
		INNER JOIN tbl_users u ON u.user_id = c2.user_id
		LEFT OUTER JOIN tbl_contacts_categories_match cm ON cm.contact_id = c2.contact_id
		LEFT OUTER JOIN tbl_contacts_categories cc ON cc.category_id = cm.category_id
		WHERE cr.active = 1
		ORDER BY c2.contact_id
	</cfquery>
	
	<cfset parentList = "">
	<cfloop query="getLinkSuggestions">
		<cfif not listFind(parentList, contact_id)>
			<cfset parentList = listAppend(parentList, contact_id)>
		</cfif>
	</cfloop>
	
	<!---now also snag the first note for each of these "parent" contacts so we can draw some summary text--->
	<cfquery datasource="#application.applicationDataSource#" name="getNote">
		SELECT cn.contact_id, cn.note_text
		FROM tbl_contacts_notes cn
		WHERE cn.contact_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#parentList#" list="true">)
		AND cn.note_id = (SELECT TOP 1 note_id FROM tbl_contacts_notes WHERE contact_id = cn.contact_id ORDER BY note_ts ASC)
	</cfquery>
	
	<!---now we can build-up a struct of each parent's data--->
	<cfset linkArray = arrayNew(1)>
	<cfloop query="getLinkSuggestions" group="contact_id"><!---categories have a one-to-many matching, so group by contact_id and use a nested loop to build catList--->
		<cfset parentStruct = structNew()>
		
		<cfset parentStruct['contactId'] = contact_id>
		<cfset parentStruct['ts'] = created_ts>
		<cfset parentStruct['username'] = username>
		<cfset parentStruct['status'] = status>
		
		<cfset parentStruct['catList'] = "">
		<cfloop>
			<cfset parentStruct['catList'] = listAppend(parentStruct['catList'], category_name)>
		</cfloop>
		
		<!---now snag the notes for this contact--->
		<cfset parentStruct['summary'] = "">
		<cfloop query="getNote">
			<cfif getNote.contact_id eq getLinkSuggestions.contact_id>
				<cfset parentStruct['summary'] = trimString(stripTags(note_text), 65)>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---we've finished building parentStruct, added it to linkArray--->
		<cfset arrayAppend(linkArray, parentStruct)>
	</cfloop>
	
	<!---we're in the clear, add linkArray to response.--->
	<cfset response['linkArray'] = linkArray>
	
	<cfset response['message'] = "Fetched open links.">
	<cfset response['status'] = 1>
	
<cfcatch>
	<cfset response['message'] = "<p class='alert'>#cfcatch.message# - #cfcatch.detail#</p>">
	<cfset response['status'] = 0>
</cfcatch>
</cftry>

<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>