<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfparam name="instanceSelected" type="integer" default="1">
<cfinclude template="chat_functions.cfm">

<cfset usersArray = arrayNew(1)><!---the array of users we will ultimately return.--->

<!---wrap our work in a cftry so we can get useful JSON output when we fail.--->
<cftry>
	
	<!---to spare db calls later check the users masks here, once.--->
	<cfset myMasks = bulkGetUserMasks()>
	<cfset isAdmin = bulkHasMasks(myMasks, session.cas_username, "Admin")>
	<cfset isCS = bulkHasMasks(myMasks, session.cas_username, "CS")>
	<cfset isLogistics = bulkHasMasks(myMasks, session.cas_username, "Logistics")>
	<cfset isConsultant = bulkHasMasks(myMasks, session.cas_username, "Consultant")>
	
	<cfif not isConsultant>
		<cfthrow message="Not Authorized" detail="You must have the Consultant mask to view active users.">
	</cfif>
	
	<cfquery name="UpdateActivity" datasource="#application.applicationDatasource#">
		INSERT INTO tbl_chat_last_active(user_id, ip_address, instance_id)
		VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#HTTP.REMOTE_ADDR#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
		)
	</cfquery>
	
	<!---before we check who is active we should remove folks who have been inactive.--->
	<cfquery name="DeleteOldActive" datasource="#application.applicationDatasource#">
		DELETE FROM  tbl_chat_last_active  
		WHERE DATEDIFF(second, date_seen, GETDATE()) > 300 
		AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	
	<cfquery name="GetActive" datasource="#application.applicationDatasource#">
		SELECT  DISTINCT u.user_id, u.Username, (SELECT TOP 1 ip_address 
												FROM tbl_chat_last_active ta 
												WHERE ta.user_id = u.user_id 
												ORDER BY date_seen DESC) AS last_active_ip
												, u.preferred_name, u.picture_source
		FROM  tbl_chat_last_active a
		INNER JOIN tbl_users u ON u.user_id = a.user_id 
		WHERE DATEDIFF(second, a.date_seen, GETDATE()) < 220
		AND a.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
		ORDER BY u.Username ASC
	</cfquery>
	
	
	
	<cfquery name="getPieDatabase" datasource="#application.applicationDatasource#">
		SELECT datasource
		FROM tbl_instances
		WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	<cfloop query ="getPieDatabase">
		<cfset pieDatabase= getPieDatabase.datasource>
	</cfloop>
	
	<!---fetch all active shifts and check-ins, so we can list users by where they're working or if they are clocked-in.--->
	<cfquery datasource="#pieDatabase#" name="getShifts" cachedWithin="#CreateTimeSpan(0,0,0,30)#">
		/*attempting slight optimization*/
		SELECT si.site_id, c.username, si.site_name, cs.checkin_id,
			CASE 
				WHEN cs.checkin_id IS NULL THEN 0 /*not clocked-in*/
				WHEN EXISTS (SELECT stepout_id FROM tbl_stepouts WHERE checkin_id = cs.checkin_id AND return_time IS NULL) THEN 2 /*stepped out*/
				WHEN EXISTS (SELECT break_id FROM tbl_breaks WHERE checkin_id = cs.checkin_id AND return_time IS NULL) THEN 3 /*on break*/
				WHEN EXISTS (SELECT checkin_id FROM tbl_checkins WHERE checkin_id = cs.checkin_id AND checkout_time IS NOT NULL) THEN 0 /*early check-out*/
				ELSE 1 /*checked in*/
			END AS status_id
		FROM shift_blocks cs
		INNER JOIN tbl_consultants c ON cs.ssn = c.ssn
		INNER JOIN tbl_sites si ON si.site_id = cs.site_id
	
		WHERE DATEPART(hh, cs.shift_time) = DATEPART(hh,getdate())
		AND cs.SHIFT_DATE  = CONVERT(date, GETDATE())
		AND si.site_name <> 'PROJ'/*project hours can clobber real shifts*/
	</cfquery>
	
	<!---loop through our two queries and build a structure containing the site and checkin status for each user--->
	<cfset userStruct = structNew()>
	<cfloop query="getActive">
		<cfset shiftStruct = structNew()><!---store shift details, by default they have no shift.--->
		<cfset shiftStruct["shift"] = "">
		<cfset shiftStruct["statusId"] = 0>
		<cfloop query="getShifts">
			<cfif lcase(getActive.username) eq lcase(getShifts.username)>
				<!---update shiftStruct with their shift details--->
				<cfset shiftStruct["shift"] = site_name>
				<cfset shiftStruct["statusId"] = status_id><!---0 means not checked in, 1 means checked in, 2 means stepped-out, 3 means on break.--->
				<cfbreak><!---we're done with this loop.--->
			</cfif>
		</cfloop>
		<!---populate userStruct--->
		<cfset userStruct[getActive.username] = shiftStruct>
	</cfloop>
	
	
	<!---there are places where we need a list of the usernames of active folks.--->
	<cfset usersList = ValueList(GetActive.username)>
	
	<cfset activeUsersMasks = bulkGetUserMasks(usersList) ><!---for bulk checking the masks for our active users--->
	<!---
		Here things get a little wild.  We want to sort our users by their mask first, and then alphabetical order.
		We're going to build up a query that has a column for whether or not they have the masks we're ordering by
		and then replacing getActive with that.
		
		This has the added virtue of just running bulkHasMasks for each active user once per mask we're interested in.
	--->
	
	<cfset sortActive = queryNew("user_id,username,last_active_ip,preferred_name,picture_source,is_admin,is_cs,is_logistics,is_techteam,is_consultant,is_cos,is_com","integer,varchar,varchar,varchar,varchar,bit,bit,bit,bit,bit,bit,bit")>
	
	<cfloop query="getActive">
		<cfset userIsAdmin = bulkHasMasks(activeUsersMasks, username, "Admin")>
		<cfset userIsCS = bulkHasMasks(activeUsersMasks, username, "CS")>
		<cfset userIsLogistics = bulkHasMasks(activeUsersMasks, username, "Logistics")>
		<cfset userIsTechTeam	= bulkHasMasks(activeUsersMasks, username, "Tech Team")>
		<cfset userIsConsultant = bulkHasMasks(activeUsersMasks, username, "Consultant")>
		<cfset userIsCOS = bulkHasMasks(activeUsersMasks, username, "COS")>
		<cfset userIsCOM = bulkHasMasks(activeUsersMasks, username, "COM")>
		
		<cfset queryAddRow(sortActive)>
		<cfset querySetCell(sortActive, "user_id", user_id)>
		<cfset querySetCell(sortActive, "username", username)>
		<cfset querySetCell(sortActive, "last_active_ip", last_active_ip)>
		<cfset querySetCell(sortActive, "preferred_name", preferred_name)>
		<cfset querySetCell(sortActive, "picture_source", picture_source)>
		<cfset querySetCell(sortActive, "is_admin", userIsAdmin)>
		<cfset querySetCell(sortActive, "is_cs", userIsCS)>
		<cfset querySetCell(sortActive, "is_logistics", userIsLogistics)>
		<cfset querySetCell(sortActive, "is_techteam", userIsTechTeam)>
		<cfset querySetCell(sortActive, "is_consultant", userIsConsultant)>
		<cfset querySetCell(sortActive, "is_cos", userIsCOS)>
		<cfset querySetCell(sortActive, "is_com", userIsCOM)>
	</cfloop>
	
	
	<!---now replace the existing getActive with the one we created, sorting the users by the masks we're interested in, THEN by username.--->
	<cfquery dbtype="query" name="getActive">
		SELECT *
		FROM sortActive
		ORDER BY is_admin DESC, is_cs DESC, is_logistics DESC, is_techteam DESC, is_consultant DESC, username ASC
	</cfquery>
	
	<!---now also fetch all the badges for all of our active users, as we'll be displaying them in their profile summary.--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsersBadges">
		SELECT u.user_id, u.username, b.badge_id, b.badge_name, b.description, b.image_url
		FROM tbl_badges_users_matches bm
		INNER JOIN tbl_badges b
			ON b.badge_id = bm.badge_id
			AND b.active = 1
		INNER JOIN tbl_users u ON u.user_id = bm.user_id
		WHERE u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#usersList#" list="true">)
		ORDER BY bm.user_id, b.badge_name, b.badge_id
	</cfquery>
	<!---cfdump var="#getUsersBadges#"><cfabort--->
	
	
	<cfloop query="GetActive">
		<cfset userObj = structNew()>
		
		<cfset userObj["currentShift"] = "">
		<cfif isConsultant AND is_cs><!---if our viewer is a consultant, and our current user is CS draw which "route" they are working.--->
			<cfset userObj["currentShift"] = currentSSShift(userStruct[GetActive.username]["shift"])>
		</cfif>
		
		<cfset userObj["image"] = picture_source>
		<cfset userObj["name"] = preferred_name>
		<cfset userObj["username"] = username>
		<cfset userObj["CoS"] = is_cos>
		<cfset userObj["CoM"] = is_com>
		
		<cfset userObj["profileLink"] = "">
		<cfif not is_admin AND not is_logistics><!---only show profile links for people who aren't admins or logistics members.--->
			<cfset userObj["profileLink"] = "#application.appPath#/tools/profile/profiles.cfm?currentUserId=#getActive.user_id#">
		</cfif>
		
		<!---now come the God awful badges.--->
		<cfset badgeArray = arrayNew(1)>
		
		<!---loop over getUsersBadges, which has been ordered very carefully so we can use looping & grouping to get the information and totals we want--->
		<cfif not is_admin><!---don't list badges for admin users.--->
			<cfset badgeArray = getBadgesArray(getActive.username)>
		</cfif>
		
		<cfset userObj["badges"] = badgeArray>
		<!---end of God awful badges--->
		
		<!---
			what color should the shift-status roundel beside the user be?
			Green: checked-in
			Yellow: On break
			Orange: Stepped out
			Red: Not clocked in
			Purple: Admin
		--->
		
		<cfswitch expression="#userStruct[GetActive.username]["statusId"]#">
			<cfcase value="1">
				<cfset userObj["statusColor"] = "##090"><!---Green for on shift.--->
			</cfcase>
			<cfcase value="2">
				<cfset userObj["statusColor"] = "##FF8308"><!---Orange for stepped out.--->
			</cfcase>
			<cfcase value="3">
				<cfset userObj["statusColor"] = "##FFE100"><!---Yellow for on break.--->
			</cfcase>
			<cfdefaultcase>
				<cfset userObj["statusColor"] = "##900"><!---Red for not on shift.--->
			</cfdefaultcase>
		</cfswitch>
		
		<!---admins always show a status of purple--->
		<cfif is_admin>
			<cfset userObj["statusColor"] = "##800080"><!---Pupple for not tracked.--->
		</cfif>
		
		<!---what class color codes the user's name for display?--->
		<cfset userObj["userClass"] = "">
		
		<cfif is_admin>
			<cfset userObj["userClass"] = "adminColor">
		<cfelseif is_cs>
			<cfset userObj["userClass"] = "csColor">
		<cfelseif is_logistics>
			<cfset userObj["userClass"] = "logisticsColor">
		<cfelseif is_techteam>
			<cfset userObj["userClass"] = "techColor">
		<cfelseif is_consultant>
			<cfset userObj["userClass"] = "conColor">
		</cfif>
		
		<cfset userObj["location"] = "---">
		
		<cfif isAdmin OR isLogistics><!---Admins and logistics get to see where everyone is.--->
			<cfset userObj["location"] = ipToLabs(last_active_ip)>
		<cfelseif isCS AND not is_admin><!---cs get to see everyone's location, except for admins.--->
			<cfset userObj["location"] = ipToLabs(last_active_ip)>
		<cfelseif isConsultant AND not is_cs><!---consultants only get to see the location of orther consultants, not CS or Admins.--->
			<cfset userObj["location"] = ipToLabs(last_active_ip)>
		</cfif>
		
		<cfset arrayAppend(usersArray, userObj)>
	</cfloop>

<cfcatch type="any">
	<cfset errorObj = structNew()>
	<cfset errorObj["error"] = cfcatch.Message & " - " & cfcatch.Detail>
	
	<cfset arrayAppend(usersArray, errorObj)>
	
</cfcatch>
</cftry>

<cfoutput>#serializeJSON(usersArray)#</cfoutput>

<!---
	there is a bug in CF10 that breaks on the inner most loop of grouped cfloop. https://bugbase.adobe.com/index.cfm?event=bug&id=3820049
	Scope makes all the difference, so we had to shunt our work of generating badge data into a function.
--->
<cffunction name="getBadgesArray" output="false">
	<cfargument name="user" type="string" required="true">
	
	<cfset var badgeArray = arrayNew(1)>
	<cfset var badgeObj = structNew()>
	<cfset var count = 0>
	
	<cfloop query="getUsersBadges" group="user_id">
		<cfif getUsersBadges.username eq user>
			
			<cfloop group="badge_id">
				<cfset badgeObj = structNew()>
				
				<cfset count = 0>
				
				<cfset badgeObj["id"] = badge_id>
				<cfset badgeObj["name"] = badge_name>
				<cfset badgeObj["description"] = description>
				<cfset badgeObj["imageUrl"] = image_url>
				
				<cfloop><cfset count = count + 1></cfloop>
				
				
				<cfset badgeObj["count"] = count>
				
				<cfset arrayAppend(badgeArray, badgeObj)>
			</cfloop>
			
			<!---the query was carefully grouped by user, so we're done here.--->
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn badgeArray>
</cffunction>