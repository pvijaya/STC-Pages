<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfif not hasMasks("consultant")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfparam name="frmContactId" type="integer" default="0"> <!--- a list of username strings --->

<cfset response = StructNew()>

<cftry>

	<cfquery datasource="#application.applicationDatasource#" name="getContact">
		SELECT c.contact_id, c.created_ts, c.last_opened, c.user_id, u.username, 
		l.lab_id, l.instance_id, cs.status, 
			CASE
				WHEN l.lab_name IS NULL THEN b.short_building_name + c.room_number
				ELSE l.lab_name
			END AS lab_name
		FROM tbl_contacts c
		INNER JOIN tbl_users u ON u.user_id = c.user_id
		INNER JOIN tbl_contacts_statuses cs ON cs.status_id = c.status_id
		INNER JOIN vi_buildings b
			ON b.instance_id = c.instance_id
			AND b.building_id = c.building_id
		LEFT OUTER JOIN vi_labs l
			ON l.building_id = c.building_id
			AND l.room_number = c.room_number
		WHERE c.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
	</cfquery>
	
	<!--- if no contact with the given id is found, fail --->
	<cfif getContact.recordCount EQ 0>
		<cfthrow message="Invalid Contact" detail="The specified contact does not exist.">
	</cfif>
	
	<!--- get contact info --->
	<cfquery datasource="#application.applicationDatasource#" name="getUsernames">
		SELECT cc.customer_username
		FROM tbl_contacts_customers cc
		WHERE cc.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
	</cfquery>
	
	<cfquery datasource="#application.applicationDatasource#" name="getCategories">
		SELECT cc.category_id, cc.category_name 
		FROM tbl_contacts_categories_match ccm
		INNER JOIN tbl_contacts_categories cc ON cc.category_id = ccm.category_id
		WHERE ccm.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
	</cfquery>
	
	<cfquery datasource="#application.applicationDatasource#" name="getNotes">
		SELECT cn.note_id, u.username, cn.note_text, cn.note_ts
		FROM tbl_contacts_notes cn
		INNER JOIN tbl_users u ON u.user_id = cn.user_id
		WHERE cn.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
		ORDER BY cn.note_ts ASC
	</cfquery>
	
	<cfquery datasource="#application.applicationDatasource#" name="getLinksTo">
		SELECT cr.links_to
		FROM tbl_contacts_relationships cr
		WHERE cr.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
			  AND cr.active = 'True'
	</cfquery>
	
	<cfquery datasource="#application.applicationDatasource#" name="getLinksFrom">
		SELECT cr.contact_id
		FROM tbl_contacts_relationships cr
		WHERE cr.links_to = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
			  AND cr.active = 'True'
	</cfquery>
	
	<cfset userList = "">
	<cfloop query="getUsernames">
		<cfset userList = listAppend(userList, customer_username)>
	</cfloop>
	
	<cfset catList = "">
	<cfset catIdList = "">
	<cfloop query="getCategories">
		<cfset catList = listAppend(catList, category_name)>
		<cfset catIdList = listAppend(catIdList, category_id)>
	</cfloop>
	
	<cfset notes = ArrayNew(1)>
	<cfset i = 1>
	<cfloop query="getNotes">
		<cfset myNote = structNew()>
		
		<cfset myNote['note_id'] = note_id>
		<cfset myNote['username'] = username>
		<cfset myNote['note_text'] = note_text>
		<cfset myNote['note_ts'] = dateTimeFormat(note_ts, 'mmm dd, hh:nn tt')>
		
		<cfset arrayAppend(notes, myNote)>
	</cfloop>
	
	<cfset linkListTo = "">
	<cfloop query="getLinksTo">
		<cfset linkListTo = listAppend(linkListTo, links_to)>
	</cfloop>
	
	<cfset linkListFrom = "">
	<cfloop query="getLinksFrom">
		<cfset linkListFrom = listAppend(linkListFrom, contact_id)>
	</cfloop>
	
	<cfset response['message'] = "<p class='ok'>Contact found.</p>">
	<cfset response['contact_id'] = #contactId#>
	<cfset response['status'] = #getContact.status#>
	<cfset response['username'] = #getContact.username#>
	<cfset response['ts'] = #dateTimeFormat(getContact.created_ts, 'mmm dd, hh:nn tt')#>
	<cfset response['catList'] = #catList#>
	<cfset response['catIdList'] = #catIdList#>
	<cfset response['userList'] = #userList#>
	<cfset response['linkListTo'] = #linkListTo#>
	<cfset response['linkListFrom'] = #linkListFrom#>
	<cfset response['lab'] = #getContact.lab_name#>
	<cfset response['labId'] = "i#getContact.instance_id#l#getContact.lab_id#">
	<cfset response['noteArray'] = #notes#>
	
	<cfcatch>
		
		<cfset response['message'] = "<p class='alert'>#cfcatch.message# - #cfcatch.detail#</p>">
		<cfset response['contact_id'] = 0>
		
	</cfcatch>
	
</cftry>

<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>
