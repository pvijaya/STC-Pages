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
	<cfparam name="frmAction" type="string" default="Add Link">
	<cfparam name="frmContactId" type="integer"><!---the contact we are (un)linking to another ticket.--->
	<cfparam name="frmLinkContactId" type="integer"><!---the contact we are (un)linking to.--->
	
	<cfif frmAction eq "Add Link">
		<!---make sure our target contact actually exists.--->
		<cfquery datasource="#application.applicationDatasource#" name="getContact">
			SELECT c.contact_id
			FROM tbl_contacts c
			WHERE c.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkContactId#">
		</cfquery>
		
		<cfif getContact.recordCount EQ 0>
			<cfthrow message="Invalid Contact" detail="No contact with specified ID, #frmLinkContactId#, exists.">
		</cfif>	
		
		<cfif frmContactId EQ frmLinkContactId>
			<cfthrow message="Invalid Contact" detail="You cannot link a contact to itself.">
		</cfif>
		
		<!---also prevent the user from creating duplicate links--->
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT *
			FROM tbl_contacts_relationships
			WHERE active = 1
			AND contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
			AND links_to = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkContactId#">
		</cfquery>
		
		<cfif getDupes.recordCount gt 0>
			<cfthrow message="Already Linked" detail="Contact #frmContactId# is already linked with contact #frmLinkContactId#">
		</cfif>
		
		<cfquery datasource="#application.applicationDatasource#" name="getContact">
			INSERT INTO tbl_contacts_relationships (contact_id, links_to, user_id)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkContactId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			)
		</cfquery>
		
		<!---also audit the change--->
		<cfset auditText = "Linked to contact <i>#frmLinkContactId#</i>.">
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_contacts_notes (contact_id, user_id, note_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		
		<cfset response['status'] = 1>
		<cfset response['message'] = "Link added successfully.">
	
	<cfelseif frmAction eq "Remove Link">
		
		<!---make sure a link exists--->
		<cfquery datasource="#application.applicationDatasource#" name="getContactLink">
			SELECT cr.contact_id
			FROM tbl_contacts_relationships cr
			WHERE cr.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
			AND cr.links_to = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkContactId#">
		</cfquery>
		
		<cfif getContactLink.recordCount EQ 0>
			<cfthrow message="Invalid Contact" detail="Contact #frmContactId# is not currently linked to #frmLinkContactId#">
		</cfif>	
	
		<cfquery datasource="#application.applicationDatasource#" name="updateContact">
			UPDATE tbl_contacts_relationships
			SET active = 'False'
			OUTPUT inserted.contact_id
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
			AND links_to = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkContactId#">
		</cfquery>
		
		<!---add an audit for having un-linked this contact--->
		<cfif updateContact.recordCount gt 0>
			<cfset auditText = "Un-Linked from contact <i>#frmLinkContactId#</i>.">
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
		<cfset response['message'] = "Link removed successfully.">
		
	</cfif>
	
<cfcatch>
	<cfset response['status'] = 0>
	<cfset response['message'] = "#cfcatch.message# - #cfcatch.detail#">
</cfcatch>
</cftry>


<!---now we can output our JSON response.--->
<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>