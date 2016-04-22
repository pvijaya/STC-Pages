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
	<cfparam name="frmStatusId" type="integer" default="1"><!---default to setting it open.--->
	<cfparam name="frmCategoryList" type="string" default="">
	<!--- check inputs --->
	<cfif frmContactId EQ 0>
		<cfthrow message="Invalid Contact" detail="The specified contact cannot be found.">
	</cfif>
	
	<!---fetch all active statuses, so we can make sure the user provided status is valid.--->
	<cfquery datasource="#application.applicationDataSource#" name="getStatuses">
		SELECT status_id, status, active
		FROM tbl_contacts_statuses
	</cfquery>
	
	<cfset foundStatus = 0>
	<cfset statusText = "">
	<cfloop query="getStatuses">
		<cfif frmStatusId eq status_id>
			<cfset foundStatus = 1>
			<cfset statusText = status>
			<!---but don't allow use of retired statuses--->
			<cfif not active>
				<cfthrow message="Invalid Contact" detail="The status ""#status#"" has been retired.">
			</cfif>
			
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfif not foundStatus>
		<cfthrow message="Invalid Contact" detail="The status_id you provided, ""#frmStatusId#"", does not appear to be valid.">
	</cfif>
	
	<cfif frmStatusId eq 2>
		<cfif trim(frmCategoryList) EQ "">
			<cfthrow message="Invalid Input" detail="You must provide at least one category.">
		</cfif>
	</cfif>
	
	
	<!--- close the contact --->
	<cfquery datasource="#application.applicationDataSource#" name="updateStatus">
		UPDATE tbl_contacts
		SET status_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmStatusId#">,
		<cfif frmStatusId eq 2><!---if we're closing the contact update how much time we've spent working on it.--->
			minutes_spent = minutes_spent + DATEDIFF(minute, last_opened, GETDATE())
		<cfelseif frmStatusId eq 1><!---if we're re-opening a ticket revise the last_opened date--->
			last_opened = GETDATE()
		</cfif>
		OUTPUT inserted.contact_id
		WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
		AND status_id <> <cfqueryparam cfsqltype="cf_sql_integer" value="#frmStatusId#"><!---don't let them update when the status doesn't change.--->
	</cfquery>
	
	<!---add an audit for having changed the contact's status--->
	<cfif updateStatus.recordCount gt 0>
		<cfset auditText = "Set Status to <i>#statusText#</i>.">
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_contacts_notes (contact_id, user_id, note_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
	</cfif>
	
	
	<cfset response['status'] = 1>
	<cfset response['message'] = "Contact status set to ""#statusText#"" successfully.">
	
	<cfcatch>
		<cfset response['status'] = 0>
		<cfset response['message'] = "#cfcatch.message# - #cfcatch.detail#">
	</cfcatch>
</cftry>

<!---now we can output our JSON response.--->
<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>