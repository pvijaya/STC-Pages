<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<!---it's a module, so we might need to include common-functions.cfm--->
<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<!---do nothing for unauthorized users.--->
<cfif not hasMasks("consultant")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfset response = structNew()>
<cfset response['status'] = 1><!---1 for ok 0 for error--->
<cfset response['message'] = "">

<cftry>
	<cfparam name="frmContactId" type="integer" default="0">
	<cfparam name="frmNoteText" type="string" default="">
	
	<cfif trim(frmNoteText) EQ "">	
   		<cfthrow message="Missing Input" detail="You must provide note text.">
	</cfif>
	
	<cfquery datasource="#application.applicationDatasource#" name="getContact">
		INSERT INTO tbl_contacts_notes (contact_id, user_id, note_text)
		VALUES (
			<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">,
			<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
			<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNoteText#">
		)
	</cfquery>
	
	<cfset response['status'] = 1>
	<cfset response['message'] = "Note added successfully.">
	
	<cfcatch>
		<cfset response['status'] = 0>
		<cfset response['message'] = "Failed to add note.  #cfcatch.message# - #cfcatch.detail#">
	</cfcatch>
</cftry>

<!---now we can output our JSON response.--->
<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>