<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfif not hasMasks("consultant")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfparam name="frmUsernameList" type="string" default=""> <!--- a list of username strings --->
<cfparam name="frmCategoryList" type="string" default=""> <!--- a list of category ids --->
<cfparam name="frmLabId" type="string" default="i0l0">
<cfparam name="frmDetails" type="string" default="">
<cfparam name="frmStatusId" type="integer" default="1">

<cfset response = StructNew()>

<cfquery datasource="#application.applicationDatasource#" name="getIP">
	SELECT TOP 1 ip_address 
	FROM tbl_chat_last_active ta 
	WHERE ta.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	ORDER BY date_seen DESC
</cfquery>

<cfset ipAddress = getIP.ip_address>

<cfquery datasource="#application.applicationDatasource#" name="getCategories">
	SELECT cc.category_name 
	FROM tbl_contacts_categories cc
	WHERE cc.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmCategoryList#" list="yes">)
</cfquery>

<cfset catList = "">
<cfloop query="getCategories">
	<cfset catList = listAppend(catList, category_name)>
</cfloop>

<!--- parse the provided lab id into building id and room number --->
<cfset labStruct = parseLabName(frmLabId)>
<cfset labId = labStruct['lab']>
<cfset instanceId = labStruct['instance']>

<cfquery datasource="#application.applicationDataSource#" name="getLocation">
	SELECT l.room_number, l.building_id, l.lab_name
	FROM vi_labs l
	WHERE l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		  AND l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
</cfquery>

<cftry>

	<!--- check inputs --->
	<cfset customUsers = "##unknown"><!---this is a list of "hashtags" for special users we want to record, the most common being #unknown, but there could be more in the future.  The rest of the time "#" is an invalid character.--->
	<cfloop list="#frmUsernameList#" index="tempUsername">
		<cfif tempUsername EQ "unknown">
			<cfthrow message="Invalid Input" detail="Unknown is not a user. Did you mean to type ##unknown to refer to an unknown person?">
		<cfelseif findNoCase("##", tempUsername) AND not listFindNoCase(customUsers, tempUsername)><!---make sure if someone provides a hashtag make sure it's one of our legit hashtags.--->
			<cfthrow message="Invalid Input" detail="#tempUsername# is not a valid username.">
		</cfif>
	</cfloop>
	
	<!--- if the user doesn't provide a username, default to #unknown --->
	<cfif trim(frmUsernameList) EQ "">
		<!---
			<cfthrow message="Invalid Input" detail="You must provide at least one customer username.">
		--->
		<cfset frmUsernameList = "##unknown">
	</cfif>
	
	
	
	<cfif trim(frmUsernameList) EQ "##unknown">
		<cfif trim(frmDetails) EQ "">
			<cfthrow message="Invalid Input" detail="You must provide a valid username or detail for this contact.">
		</cfif>
	</cfif>
	
	<cfif labId EQ 0>
		<cfthrow message="Invalid Input" detail="The specified lab cannot be found.">
	</cfif>
	
	<!--- insert new contact into the database --->
	<cfquery datasource="#application.applicationDataSource#" name="addContact">
		INSERT INTO tbl_contacts (instance_id, building_id, room_number, 
							 	  user_id, status_id, ip_address, minutes_spent)
		OUTPUT inserted.contact_id, inserted.created_ts
		VALUES (
			<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
			<cfqueryparam cfsqltype="cf_sql_integer" value="#getLocation.building_id#">,
			<cfqueryparam cfsqltype="cf_sql_varchar" value="#getLocation.room_number#">,
			<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
			<cfqueryparam cfsqltype="cf_sql_integer" value="#frmStatusId#">,
			<cfqueryparam cfsqltype="cf_sql_varchar" value="#ipAddress#">,
			1
		)
	</cfquery>
	
	<!--- insert categories for this contact --->
	<cfset cnt = 1>
	<cfif frmCategoryList NEQ "">
		<cfquery datasource="#application.applicationDataSource#" name="addContactCategories">
			INSERT INTO tbl_contacts_categories_match (contact_id, category_id)
			VALUES 
				<cfloop list="#frmCategoryList#" index="catId">
					(<cfqueryparam cfsqltype="cf_sql_integer" value="#addContact.contact_id#">,
					 <cfqueryparam cfsqltype="cf_sql_integer" value="#catId#">)
					<cfif cnt LT listLen(frmCategoryList)>,</cfif>
					<cfset cnt = cnt + 1>
				</cfloop>
		</cfquery>
	</cfif>
	<!--- insert usernames for this contact --->
	<cfset cnt = 1>
	<cfquery datasource="#application.applicationDataSource#" name="addContactUsernames">
		INSERT INTO tbl_contacts_customers (contact_id, customer_username)
		VALUES 
			<cfloop list="#frmUsernameList#" index="username">
				(<cfqueryparam cfsqltype="cf_sql_integer" value="#addContact.contact_id#">,
				 <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">)
				<cfif cnt LT listLen(frmUsernameList)>,</cfif>
				<cfset cnt = cnt + 1>
			</cfloop>
	</cfquery>
	
	<!--- insert contact details as a note --->
	<cfif trim(frmDetails) NEQ "">
		<cfquery datasource="#application.applicationDataSource#" name="addContactNote">
			INSERT INTO tbl_contacts_notes (contact_id, user_id, note_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#addContact.contact_id#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmDetails#">)
		</cfquery>
	</cfif>

	<cfif frmStatusId EQ 1>
		<cfset response['message'] = "<p class='ok'>New contact opened.</p>">
	<cfelseif frmStatusId EQ 2>
		<cfset response['message'] = "<p class='ok'>New contact completed.</p>">
	</cfif>
	<cfset response['contact_id'] = #addContact.contact_id#>
	<cfset response['ts'] = #dateTimeFormat(addContact.created_ts, 'mmm dd, hh:nn tt')#>
	<cfset response['status_id'] = frmStatusId>
	<cfset response['catList'] = #catList#>
	<cfset response['userList'] = #frmUsernameList#>
	<cfset response['lab'] = #getLocation.lab_name#>
	<cfset response['details'] = #frmDetails#>
	
	<cfcatch>
		
		<cfset response['message'] = "<p class='alert'>#cfcatch.message# - #cfcatch.detail#</p>">
		<cfset response['contact_id'] = 0>
		
	</cfcatch>
	
</cftry>

<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>
