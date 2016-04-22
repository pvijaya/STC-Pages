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

<!---now we can actually process the user's input--->
<cftry>
	<cfparam name="frmContactId" type="integer" default="0">
	<cfparam name="usernameList" type="string" default="">
	<cfparam name="categoryList" type="string" default="">
	<cfparam name="labId" type="string" default="">
	
	<cfset labStruct = parseLabName(labId)>
	
	<!---verify our user's input--->
	
	<cfset customUsers = "##unknown"><!---this is a list of "hashtags" for special users we want to record, the most common being #unknown, but there could be more in the future.  The rest of the time "#" is an invalid character.--->
	<cfloop list="#usernameList#" index="tempUsername">
		<cfif tempUsername EQ "unknown">
			<cfthrow message="Invalid Input" detail="Unknown is not a user. Did you mean to type ##unknown to refer to an unknown person?">
		<cfelseif findNoCase("##", tempUsername) AND not listFindNoCase(customUsers, tempUsername)><!---make sure if someone provides a hashtag make sure it's one of our legit hashtags.--->
			<cfthrow message="Invalid Input" detail="#tempUsername# is not a valid username.">
		</cfif>
	</cfloop>
	
	<cfif trim(usernameList) eq "">
		<cfthrow message="Missing Input" detail="You must provide at least one customer for this contact.">
	</cfif>
	
	<cfif trim(categoryList) eq "">
		<cfthrow message="Missing Input" detail="You must provide at least one category for this contact.">
	</cfif>
	
	<cfset auditText = "">
	
	<!---first, see about adding/removing users--->
	<cfset addedUsers = "">
	<cfset removedUsers = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getContactusers">
		SELECT LOWER(customer_username) AS customer_username
		FROM tbl_contacts_customers
		WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
	</cfquery>
	
	<cfloop query="getContactUsers">
		<cfif not listFindNoCase(usernameList, customer_username)>
			<cfset removedUsers = listAppend(removedUsers, customer_username)>
		</cfif>
	</cfloop>
	
	<cfloop list="#usernameList#" index="uname">
		<cfset found = 0>
		<cfset uname = trim(lcase(uname))><!---get uname as just a lowercase username.--->
		<cfloop query="getContactusers">
			<cfif uname eq customer_username>
				<cfset found = 1>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<cfif not found>
			<cfset addedUsers = listAppend(addedUsers, uname)>
		</cfif>
	</cfloop>
	<cfset response['addedUsers'] = addedUsers>
	
	<!---now add/remove the users in the database with the lists we just created--->
	<cfif listLen(addedUsers) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="addUsers">
			INSERT INTO tbl_contacts_customers (contact_id, customer_username)
			VALUES
			<cfset cnt = 1>
			<cfloop list="#addedUsers#" index="uname">
				(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#uname#">)<cfif cnt lt listLen(addedUsers)>,</cfif>
				<cfset cnt = cnt + 1>
			</cfloop>
		</cfquery>
		
		<cfset auditText = auditText & "<p>Added customer" & iif(listLen(addedUsers) gt 1, de("s"), "") & " <i>" & replace(addedUsers, ",", ", ", "all") & "</i></p>">
	</cfif>
	
	<cfif listLen(removedUsers) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="removeUsers">
			DELETE FROM tbl_contacts_customers
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
			AND customer_username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#removedUsers#" list="true">)
		</cfquery>
		
		<cfset auditText = auditText & "<p>Removed customer" & iif(listLen(removedUsers) gt 1, de("s"), "") & " <i>" & replace(removedUsers, ",", ", ", "all") & "</i></p>">
	</cfif>
	
	<cfset response['removedUsers'] = removedUsers>
	
	<!--- handle category changes --->
	<!--- get the old categories for this contact --->
	<cfquery datasource="#application.applicationDataSource#" name="getExistingCats">
		SELECT ccm.category_id
		FROM tbl_contacts_categories_match ccm
		WHERE ccm.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
	</cfquery>
	
	<cfset oldCats = "">
	<cfset removeCats = "">
	<cfloop query="getExistingCats">
		
		<cfset oldCats = listAppend(oldCats, category_id)>
		
		<!--- if one of these cats doesn't appear in categoryList, we need to remove it later --->
		<cfif NOT listFindNoCase(categoryList, category_id)> 
			<cfset removeCats = listAppend(removeCats, category_id)>
		</cfif>
		
	</cfloop>
	
	<cfset addCats = "">
	<cfloop list="#categoryList#" index="cat">
	
		<!--- if one of our new cats doesn't exist in oldCats, we need to add it later --->
		<cfif NOT listFindNoCase(oldcats, cat)>
			<cfset addCats = listAppend(addCats, cat)>
		</cfif>
	
	</cfloop>
	
	<!--- now get the names of our categories for a better audit message --->
	<cfquery datasource="#application.applicationDataSource#" name="getAddCats">
		SELECT cc.category_name
		FROM tbl_contacts_categories cc
		WHERE cc.category_id In (<cfqueryparam cfsqltype="cf_sql_integer" value="#addCats#" list="yes">)
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getRemoveCats">
		SELECT cc.category_name
		FROM tbl_contacts_categories cc
		WHERE cc.category_id In (<cfqueryparam cfsqltype="cf_sql_integer" value="#removeCats#" list="yes">)
	</cfquery>
	
	<cfset addCatNames = "">
	<cfloop query="getAddCats">
		<cfset addCatNames = listAppend(addCatNames, category_name)>
	</cfloop>
	
	<cfset removeCatNames = "">
	<cfloop query="getRemoveCats">
		<cfset removeCatNames = listAppend(removeCatNames, category_name)>
	</cfloop>
	
	<cfset response['addedCats'] = addCatNames>
	<cfset response['removedCats'] = removeCatNames>
	
	<!--- remove and add the cats based on our lists --->
	<cfif listLen(removeCats) GT 0>
		<cfquery datasource="#application.applicationDataSource#" name="removeCategories">
			DELETE FROM tbl_contacts_categories_match
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
				  AND category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#removeCats#" list="true">)
		</cfquery>
		<cfset auditText = auditText & "<p>Removed categor" 
						   & iif(listLen(removeCatNames) gt 1, de("ies"), de("y")) & " <i>" 
						   & replace(removeCatNames, ",", ", ", "all") & "</i></p>">
	</cfif>
	
	<cfif listLen(addCats) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="addCategories">
			INSERT INTO tbl_contacts_categories_match (contact_id, category_id)
			VALUES
			<cfset cnt = 1>
			<cfloop list="#addCats#" index="cat">
				(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">, 
				<cfqueryparam cfsqltype="cf_sql_integer" value="#cat#">)
				<cfif cnt lt listLen(addCats)>,</cfif>
				<cfset cnt = cnt + 1>
			</cfloop>
		</cfquery>	
		<cfset auditText = auditText & "<p>Added categor" 
						   & iif(listLen(addCatNames) gt 1, de("ies"), de("y")) & " <i>" 
						   & replace(addCatNames, ",", ", ", "all") & "</i></p>">
	</cfif>
	
	<!--- update the lab --->
	<cfquery datasource="#application.applicationDataSource#" name="getOldBuildingInfo">
		SELECT l.lab_name, l.lab_id
		FROM tbl_contacts c
		INNER JOIN vi_labs l ON 
			l.instance_id = c.instance_id
			AND l.building_id = c.building_id
			AND l.room_number = c.room_number
		WHERE c.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
			  AND c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['instance']#">
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getBuildingInfo">
		SELECT l.building_id, l.room_number, l.lab_name, l.lab_id
		FROM vi_labs l
		WHERE l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['lab']#">
			  AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['instance']#">
	</cfquery>
	
	<!--- if they submitted a nonzero lab id and found no building info, error out --->
	<cfif getBuildingInfo.recordCount EQ 0 AND labStruct['lab'] GT 0>
		<cfthrow message="Error" detail="Cannot find building info for the provided lab.">
	</cfif>
	
	<cfset oldLab = getOldBuildingInfo.lab_name>
	<cfset newLab = getBuildingInfo.lab_name>
	
	<!--- if there is no lab associated with this contact and the user hasn't selected one, make them --->
	<cfif labId EQ "i0l0" AND oldLab EQ "i0l0">
		<cfthrow message="Invalid Input" detail="You must choose a lab.">
	</cfif>
	
	<!--- if the user submitted ---, leave the lab data alone --->
	<cfif oldLab NEQ newLab AND newLab NEQ "i0l0">
	
		<cfquery datasource="#application.applicationDataSource#" name="updateLabInfo">
			UPDATE tbl_contacts
			SET building_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getBuildingInfo.building_id#">,
				room_number = <cfqueryparam cfsqltype="cf_sql_varchar" value="#getBuildingInfo.room_number#">
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
		</cfquery>
		
		<cfif oldLab NEQ "">
			<cfset auditText = auditText & "<p>Lab changed" & " from " & oldLab & " to " & newLab & ".</p>">
		<cfelse>
			<cfset auditText = auditText & "<p>Lab changed" & " to " & newLab & ".</p>">
		</cfif>
	
	</cfif>
	
	<!---if we've done any audits add a note--->
	<cfif auditText neq "">
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_contacts_notes (contact_id, user_id, note_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
	</cfif>
	
	<cfcatch>
		<cfset response['status'] = 0>
		<cfset response['message'] = "#cfcatch.message# - #cfcatch.detail#">
	</cfcatch>
</cftry>

<!---now we can output our JSON response.--->
<cfset contactResponse = serializeJSON(response)>
<cfoutput>#contactResponse#</cfoutput>