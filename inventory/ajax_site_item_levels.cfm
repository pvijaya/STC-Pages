<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfif not hasMasks("admin")>
	<cfoutput>{[]}</cfoutput>
	<cfabort>
</cfif>

<cfparam name="frmInstanceId" type="integer" default="0">
<cfparam name="frmlabId" type="integer" default="0">
<cfparam name="frmItemId" type="integer" default="0">

<cfparam name="frmWarnLevel" type="integer" default="0">
<cfparam name="frmCritLevel" type="integer" default="0">

<cfparam name="frmMailIds" type="string" default=""><!---a list of mail_id's that this lab now uses.--->

<cfparam name="frmAction" type="string" default="view">

<cfif frmAction eq "update">
	<cfquery datasource="#application.applicationDataSource#" name="updateItemLevels">
		UPDATE tbl_inventory_site_items
		SET warn_level = #frmWarnLevel#, critical_level = #frmCritLevel#
		WHERE instance_id = #frmInstanceId#
		AND lab_id = #frmlabId#
		AND item_id = #frmItemId#
	</cfquery>
	
	<!---now remove any mails for this lab and item, then add the ones found in frmMailIds--->
	<cfquery datasource="#application.applicationDataSource#" name="removeMails">
		DELETE FROM tbl_inventory_site_items_emails
		WHERE instance_id = #frmInstanceId#
		AND lab_id = #frmlabId#
		AND item_id = #frmItemId#
	</cfquery>
	
	<cfloop list="#frmMailIds#" index="id">
		<cfif isValid("integer", id)>
			<cfquery datasource="#application.applicationDataSource#" name="addMail">
				INSERT INTO tbl_inventory_site_items_emails (instance_id, lab_id, item_id, mail_id)
				VALUES (#frmInstanceId#, #frmlabId#, #frmItemId#, #id#)
			</cfquery>
		</cfif>
	</cfloop>
</cfif>

<!---we're done storing things in the database, return the current values---->

<!---default output values--->
<cfset warnLevel = 0>
<cfset critLevel = 0>

<cfquery datasource="#application.applicationDataSource#" name="getItemLevels">
	SELECT warn_level, critical_level
	FROM tbl_inventory_site_items
	WHERE instance_id = #frmInstanceId#
	AND lab_id = #frmlabId#
	AND item_id = #frmItemId#
</cfquery>

<cfloop query="getItemLevels">
	<cfset warnLevel = warn_level>
	<cfset critLevel = critical_level>
</cfloop>

<!---find any emails for this item in this lab.--->
<cfquery datasource="#application.applicationDataSource#" name="getMailStatuses">
	SELECT e.mail_id, e.mail_name, 
		CASE
			WHEN sie.site_item_email_id IS NULL THEN 0
			ELSE 1
		END AS enrolled
		
	FROM tbl_inventory_emails e
	LEFT OUTER JOIN tbL_inventory_site_items_emails sie
		ON	sie.mail_id = e.mail_id
		AND sie.instance_id = #frmInstanceId#
		AND sie.lab_id = #frmlabId#
		AND sie.item_id = #frmItemId#
	WHERE e.active = 1
</cfquery>

<cfoutput>
	{
		"warnLevel": "#warnLevel#",
		"critLevel": "#critLevel#",
		"emails": [
		<cfset cnt = 1>
		<cfloop query="getMailStatuses">
			{
				"mailId": "#mail_id#",
				"mailName": "#htmlEditFormat(mail_name)#",
				"enrolled": "#enrolled#"
			}<cfif cnt lt getMailStatuses.recordCount>,</cfif>
			<cfset cnt = cnt + 1>
		</cfloop>
		]
	}
</cfoutput>