<!---
	NOTE NOTE NOTE!
	This file runs as a cron-job, and could be run by just about anyone.
	Make sure that the page does not generate any output.
	When this file runs it first updates users' access to match their access levels in PIE.
	Then use their V4 masks to put people in our ADS groups.
	Then the big one, add and remove folks from Mailing Lists.
--->

<!---first define a bunch of variables, especially credentials for the systems we'll be talking to.--->
<cfset mail_to = 'tccwm@iu.edu,tccpie@indiana.edu'>
<cfset sender = 'tccwm@indiana.edu'><!---IU List still thinks of tccwm@indiana.edu, instead of @iu.edu, as the owner of our mailing lists.--->
<cfset list_password = 'ma1l_th1s_$tuff'>
<cfset confirmEmailBody = ""><!---start generating our confirmation email--->

<!---build a custom query of all v4 users--->
<cfquery datasource="#application.applicationDataSource#" name="getAllUsers">
	SELECT user_id, username, last_name, first_name, preferred_name, email
	FROM tbl_users
</cfquery>

<cfset v4Users = queryNew("user_id,username,last_name,first_name,preferred_name,email,pie_level,is_techteam", "integer,varchar,varchar,varchar,varchar,varchar,integer,bit")>
<cfloop query="getAllUsers">
	<cfset queryAddRow(v4Users)>
	<cfset querySetCell(v4Users, "user_id", user_id)>
	<cfset querySetCell(v4Users, "username", username)>
	<cfset querySetCell(v4Users, "last_name", last_name)>
	<cfset querySetCell(v4Users, "first_name", first_name)>
	<cfset querySetCell(v4Users, "preferred_name", preferred_name)>
	<cfset querySetCell(v4Users, "email", email)>
	<cfset querySetCell(v4Users, "pie_level", -1)><!---negative one indicates no matching PIE account--->
	<cfset querySetCell(v4Users, "is_techteam", 0)><!---default to not listed as part of the tech team in a PIE.--->
</cfloop>

<cftry>
<!--- snag our V4 instances, so we can grab new users and then update the masks of our users.--->
<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT instance_id, instance_name, instance_mask, datasource
	FROM tbl_instances
	ORDER BY instance_name
</cfquery>

<cfset confirmEmailBody = confirmEmailBody & "<h2>Fetch Pie User Data</h2>">
<cfloop query="getInstances">
	<cfset confirmEmailBody = confirmEmailBody & "<p>#instance_name#: ">
	
	<!---Add a column to v4Users marking if the user is in this instance's PIE.--->
	<cfset queryAddColumn(v4Users, "instance_#instance_id#","Bit", arrayNew(1))>
	
	<!---Now fetch all the users matched from V4 and this instances of PIE.  Checkoff their instance in v4Users and set their highest pie level.--->
		
	<cfquery datasource="#application.applicationDataSource#" name="getInstanceUsers">
		SELECT u.user_id, u.username, c.access_level, c.last_name, c.first_name,
			CASE 
				WHEN ci.nickname IS NULL OR ci.nickname = '' THEN c.first_name
				ELSE ci.nickname
			END AS preferred_name,
			CASE
				WHEN c.group_name = 'TECH TEAM' OR c.group_name = 'TECHTEAM' THEN 1
				ELSE 0
			END AS is_techteam
		FROM tbl_users u
		INNER JOIN [#datasource#].dbo.tbl_consultants c ON LOWER(c.username) = LOWER(u.username)
		LEFT OUTER JOIN [#datasource#].dbo.tbl_coninfo ci ON ci.ssn = c.ssn
		WHERE u.ignore_pie_level = 0/*We don't want users that we're supposed to ignore.*/
		AND c.access_level > 0/*limit to actually active users in PIE*/
	</cfquery>
	
	<cfloop query="getInstanceUsers">
		<cfset userId = user_id>
		<cfset accessLevel = access_level>
		<cfset instanceId = getInstances.instance_id>
		<cfset isTechTeam = is_techteam>
		
		<cfset cnt = 1>
		
		<cfloop query="v4Users">
			<cfif user_id eq userId>
				<!---mark off this instance for the user.--->
				<cfset querySetCell(v4Users, "instance_#instanceId#", 1, cnt)>
				
				<cfif accessLevel gt pie_level>
					<cfset querySetCell(v4Users, "pie_level", accessLevel, cnt)>
					
					<!---use the name data from the PIE where they have the highest level.--->
					<cfset querySetCell(v4Users, "last_name", getInstanceUsers.last_name, cnt)>
					<cfset querySetCell(v4Users, "first_name", getInstanceUsers.first_name, cnt)>
					<cfset querySetCell(v4Users, "preferred_name", getInstanceUsers.preferred_name, cnt)>
				</cfif>
				
				<cfif isTechTeam AND not is_techteam>
					<cfset querySetCell(v4Users, "is_techteam", 1, cnt)>
				</cfif>
				
				<!---we're done, we can bust out of the inner loop--->
				<cfbreak>
			</cfif>
			
			<!---itterate cnt to be the next row we hit.--->
			<cfset cnt = cnt + 1>
		</cfloop>
	</cfloop>
	<cfset confirmEmailBody = confirmEmailBody & "Done.</p>">
</cfloop>

<!---find users that should be governed by their PIE access--->
<cfquery dbtype="query" name="getGovernedUsers">
	SELECT *
	FROM v4Users
	WHERE pie_level >= 0
</cfquery>

<!---now update users' name information --->
<cfset confirmEmailBody = confirmEmailBody & "<p>Updating last name, first name, and preferred name: ">

<cfloop query="getAllUsers">
	<cfloop query="getGovernedUsers">
		<cfif getAllUsers.username eq getGovernedUsers.username>
			<cfif getGovernedUsers.last_name neq getAllUsers.last_name OR getGovernedUsers.first_name neq getAllUsers.first_name OR getGovernedUsers.preferred_name neq getAllUsers.preferred_name>
				<cfquery datasource="#application.applicationDataSource#" name="updateName">
					UPDATE tbl_users
					SET last_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#getGovernedUsers.last_name#">,
						first_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#getGovernedUsers.first_name#">,
						preferred_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#getGovernedUsers.preferred_name#">
					WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getGovernedUsers.user_id#">
				</cfquery>
			</cfif>
			<cfbreak><!---we hit our user, and can break from the internal loop--->
		</cfif>
	</cfloop>
</cfloop>

<cfset confirmEmailBody = confirmEmailBody & "Done</p>">

<!---at this point we've added new users, and built up a complete v4Users--->
<cfset confirmEmailBody = confirmEmailBody & "<h2>Match Levels & Masks</h2>">
<cfset confirmEmailBody = confirmEmailBody & "<p>Reset Governed Masks for PIE Users: ">

<!---these are the masks that are "governed" for our "governed users."  Remove these masks for these users, and then re-add the apropriate masks.--->
<cfset gMasks = "IUB,IUPUI,Consultant,Logistics,CS,Admin,Tech Team">

<!---now turn our governed masks into more usable struct of masks and maskIds.--->
<cfquery datasource="#application.applicationDataSource#" name="getMaskIds">
	SELECT mask_id, mask_name
	FROM tbl_user_masks
	WHERE mask_name IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#gMasks#" list="true">)
</cfquery>

<cfset gMasksStruct = structNew()>
<cfloop query="getMaskIds">
	<cfset gMasksStruct[mask_id] = mask_name>
</cfloop>


<!---armed with the governed masks and governed users, remove ALL governed masks for ALL governed users.  This way we don't end up with stragglers having permissions left over.--->
<cfquery datasource="#application.applicationDataSource#">
	DELETE umm
	FROM tbl_users_masks_match umm
	INNER JOIN tbl_users u ON u.user_id = umm.user_id
	WHERE u.ignore_pie_level = 0
	AND mask_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#structKeyList(gMasksStruct)#" list="true">)
</cfquery>
<cfset confirmEmailBody = confirmEmailBody & "Done</p>">


<!---With those cleared out, now re-add our user's masks.--->
<cfset confirmEmailBody = confirmEmailBody & "<p>Update Governed Masks for PIE Users: ">
<cfset userMaskValues = arrayNew(1)>

<cfloop query="getGovernedUsers">
	<!---now apply the correct masks based on their PIE level.--->
	<!---people with level 0 should have no access--->
	<cfif pie_level gt 0>
		<!---handle instances first.--->
		<cfif instance_1 eq 1>
			<cfset arrayAppend(userMaskValues, "(#user_id#, #maskToId('IUB')#)")>
		</cfif>
		<cfif instance_2 eq 1>
			<cfset arrayAppend(userMaskValues, "(#user_id#, #maskToId('IUPUI')#)")>
		</cfif>
		
		<cfswitch expression="#pie_level#">
			<cfcase value="4">
				<!---admins--->
				<cfset arrayAppend(userMaskValues, "(#user_id#, #maskToId('Admin')#)")>
			</cfcase>
			<cfcase value="3">
				<!---consultant supervisors--->
				<cfset arrayAppend(userMaskValues, "(#user_id#, #masktoId('CS')#)")>
			</cfcase>
			<cfcase value="2">
				<!---guests--->
				<cfset arrayAppend(userMaskValues, "(#user_id#, #masktoId('Logistics')#)")>
			</cfcase>
			<cfcase value="1">
				<!---guests--->
				<cfset arrayAppend(userMaskValues, "(#user_id#, #masktoId('Consultant')#)")>
			</cfcase>
		</cfswitch>
		
		<!---are they listed as part of the tech team?--->
		<cfif is_techteam>
			<cfset arrayAppend(userMaskValues, "(#user_id#, #maskToId('Tech Team')#)")>
		</cfif>
	</cfif>
</cfloop>

<!---having put userMaskValues together we can now insert it in the database--->
<cfif arrayLen(userMaskValues) gt 0>
	<cfquery datasource="#application.applicationDataSource#" name="addGovernedMasks">
		INSERT INTO tbl_users_masks_match (user_id, mask_id)
		VALUES 
		<cfloop from="1" to="#arrayLen(userMaskValues)#" index="i">
			#userMaskValues[i]#<cfif i lt arrayLen(userMaskValues)>,</cfif>
		</cfloop>
	</cfquery>
	
	<!---now having added everyone's top-level mask, run a quick query to recursively add all the child masks they should get, too--->
	<cfquery datasource="#application.applicationDataSource#" name="addInheritedMasks">
		INSERT INTO tbl_users_masks_match (user_id, mask_id)
		SELECT u.user_id, amu.mask_id
		FROM vi_all_masks_users_old amu
		INNER JOIN tbl_users u ON u.user_id = amu.user_id
		LEFT OUTER JOIN tbl_users_masks_match umm
			ON umm.user_id = amu.user_id
			AND umm.mask_id = amu.mask_id
		WHERE umm.matchId IS NULL
	</cfquery>
</cfif>
<cfset confirmEmailBody = confirmEmailBody & "Done</p>">


<!---ADS Groups---->
<cfset confirmEmailBody = confirmEmailBody & "<h2>ADS Groups</h2>">
<cfset gUsernames = ""><!---build a list of usernames for use with our bulk mask checking tools.--->
<cfloop query="getGovernedUsers">
	<cfif pie_level gt 0>
		<cfset gUsernames = listAppend(gUsernames, username)>
	</cfif>
</cfloop>

<!---fetch the list of masks each user we're interested in has.--->
<cfset bulkMasks = bulkGetUserMasks(gUsernames)>



<!---fetch all our ADS groups, then loop through them, adding users as needed.--->
<!---thanks to our use of masks we no long have to wrangle with inheritance, we just put everybody in every group they belong in.--->
<cfquery datasource="#application.applicationDataSource#" name="getGroups">
	SELECT group_name, masks
	FROM tbl_ads_groups
</cfquery>

<cfloop query="getGroups">
	<cfset confirmEmailBody = confirmEmailBody & "<p>#group_name#: ">
	
	<cfset groupDn = "CN=#group_name#, OU=IUB, OU=Groups, OU=STCON, OU=BL-UITS, OU=BL, dc=ads, dc=iu, dc=edu"><!---used by our LDAP query--->
	<cfset newMembers = ""><!---where we'll store the individual persons being added.--->
	
	<cfloop list="#gUsernames#" index="u">
		<cfif bulkHasMasks(bulkMasks, u, masks)>
			<cfset newMembers = newMembers & "$CN=#u#, ou=accounts, dc=ads, dc=iu, dc=edu">
		</cfif>
	</cfloop>
	
	<!---ONLY MAKE THIS LDAP CALL ON PRODUCTION
	<cfldap action="MODIFY"
		modifytype="REPLACE"
		server="ads.iu.edu"
		port="389"
		username="#application.ldap_user#" 
		password="#application.ldap_password#" 
		dn="#groupDn#"
		separator="$" 
		rebind="yes"
		attributes="member=#newMembers#">
	--->
	
	<!---DEBUGGING OUTPUT FOR DEV DO NOT LEAVE UNCOMMENTED ON PROD.
	<cfset confirmEmailBody= confirmEmailBody & "#groupDn# #masks#">
	<cfset confirmEmailBody = confirmEmailBody & "<ul>">
	<cfloop list="#newMembers#" delimiters="$" index="i">
		<cfset confirmEmailBody = confirmEmailBody & "<li>#i#</li>">
	</cfloop>
	<cfset confirmEmailBody = confirmEmailBody & "</ul>">
	<!---End of dev debug.--->
	--->
	
	
	<cfset confirmEmailBody = confirmEmailBody & "Done</p>">
</cfloop>


<!---Mailing Lists--->
<cfset confirmEmailBody = confirmEmailBody & "<h2>Mailing Lists</h2>">

<!---fetch our mailing list info from the database.--->
<cfset confirmEmailBody = confirmEmailBody & "<p>Synchronize Email Addresses with LDAP: "> 

<!---build our list of users to pull data from ldap.--->
<cfset cnString = "">
<cfloop query="getGovernedUsers">
	<cfif pie_level gt 0>
		<cfset cnString = cnString & "(cn=#username#)">
	</cfif>
</cfloop>
<cfset cnString = "(|#cnString#)">

<!---commenting out for now to not hammer the server while testing.--->
<!---fetch their active email addresses from ADS using LDAP.--->
<cfldap name="user_email" 
	username="#application.ldap_user#" 
	password="#application.ldap_password#" 
	action="query" 
	server="ads.iu.edu"
	start="ou=accounts,dc=ads,dc=iu,dc=edu"
	filter="#cnString#"
	attributes="cn,mail"
	port="389"
	timeout="5000"
>

<!---where the email address in tbl_users doesn't match the one from ADS, update our value.--->
<cfloop query="user_email">
	<cfloop query="getGovernedUsers">
		<cfif getGovernedUsers.username eq user_email.cn>
			<cfif getGovernedUsers.email neq user_email.mail>
				<cfquery datasource="#application.applicationDataSource#" name="updateAddress">
					UPDATE tbl_users
					SET email = <cfqueryparam cfsqltype="cf_sql_varchar" value="#user_email.mail#">
					WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#user_email.cn#">
				</cfquery>
			</cfif>
			<!---we're done, break out of our inner loop.--->
			<cfbreak>
		</cfif>
	</cfloop>
</cfloop>

<cfset confirmEmailBody = confirmEmailBody & "Done</p>">


<cfquery datasource="#application.applicationDataSource#" name="getLists">
	SELECT list_id, list_name, list_server, address, required_mask_list, mask_black_list, mandatory_users, blacklist_users
	FROM tbl_mailing_lists
	ORDER BY list_server, list_name
</cfquery>

<cfloop query="getLists" group="list_server"><!---group the results by list_server so we don't fetch more cookies than we need to talk to the sympa list server.--->
	<cfset sympaCookie = getCookieStruct(list_server)>
	<cfset sympaCookie = sympaCookie[1]['sympa_session']>
	
	<cfset mailCommands = ""><!---the commands we will email off to the sympa server.--->
	<cfloop>
		<cfset confirmEmailBody = confirmEmailBody & "<p>Compile #list_name# on #list_server#: ">
		
		<cfset mailCommands = mailCommands & updateMailList(list_name,list_server,sympaCookie, required_mask_list, mask_black_list, mandatory_users, blacklist_users)>
		
		<cfset confirmEmailBody = confirmEmailBody & "Done</p>">
	</cfloop>
	
	<cfset confirmEmailBody = confirmEmailBody & "<p>Sending commands to #list_server#: ">
	<!---on production the address will be #address#--->
	<cfif len(trim(mailCommands)) gt 0>
		<cfmail from="#sender#" to="tccpie@indiana.edu" cc="tccpie@indiana.edu" subject="IU List Update" type="text/plain">
			#mailCommands#
		</cfmail>
		<cfset confirmEmailBody = confirmEmailBody & "Done</p>">
	<cfelse>
		<cfset confirmEmailBody = confirmEmailBody & "No Changes</p>">
	</cfif>
	
</cfloop>

<!---if we got this far all tasks completed successfully.--->
<cfset confirmEmailBody = "<p>All tasks completed.</p>" & confirmEmailBody>

<cfcatch type="any">
	<cfset confirmEmailBody = "<span style='color: Red;'>Errors were encountered.</span>" & confirmEmailBody>
	<cfset confirmEmailBody = confirmEmailBody & "<b>Error!</b> #cfcatch.Message# - #cfcatch.Detail#">
</cfcatch>
</cftry>



<cfmail from="tccwm@iu.edu" to="tccwm@iu.edu,tccpie@indiana.edu" subject="V4 Nightly Updates" type="html">
	#confirmEmailBody#
</cfmail>

<!---this function uses the gMasksStruct created above--->
<cffunction name="maskToId">
	<cfargument name="maskName" type="string" required="true">
	
	<cfset var myMaskId = -1>
	<cfset var findId = structFindValue(gMasksStruct, maskName)>
	
	<cfif arrayLen(findId) gt 0>
		<cfset myMaskId = findId[1].key>
	</cfif>
	
	<cfreturn myMaskId>
</cffunction>
<cffunction name="updateMailList">
	<cfargument name="listName" type="string" required="true">
	<cfargument name="listServer" type="string" required="true">
	<cfargument name="listCookie" type="string" required="true">
	
	<cfargument name="requiredMasks" type="string" default=""><!---include only users who satisfy these masks.--->
	<cfargument name="blacklistMasks" type="string" default=""><!---exclude users that have any of these masks.--->
	
	<cfargument name="forceUsers" type="string" default=""><!---include these users regardless of their masks.--->
	<cfargument name="excludeUsers" type="string" default=""><!---exclude these users regardless of their masks.--->
	
	<!---there's a lot going on here, we want to limit the people we add to the provided mailing list to those who satisfy ALL requiredMasks, but don't have ANY blackListMasks.--->
	
	<cfset var i = "">
	<cfset var tempList = "">
	<cfset var getUsers = "">
	<cfset var usersList = "">
	<cfset var bulkMasks = "">
	<cfset var passes = "">
	<cfset var usersQuery = queryNew("user_id,username,last_name,first_name,email","integer,varchar,varchar,varchar,varchar")>
	<cfset var currentUsers = fetchList(listName, listServer, listCookie)><!---fetch the current members of the list.--->
	<cfset var removeUsers = "">
	<cfset var newUsers = "">
	<cfset var mailCommands = ""><!---the actual commands for adding and removing email addresses from the mailserver.--->
	
	<!---clean up whitespace from required masks list--->
	<cfloop list="#requiredMasks#" index="i">
		<cfset i = trim(i)>
		<cfif not listFindNoCase(tempList, i)>
			<cfset tempList = listAppend(tempList, i)>
		</cfif>
	</cfloop>
	<cfset requiredMasks = tempList>
	
	<!---clean up whitespace from blackListMasks.--->
	<cfset tempList = "">
	<cfloop list="#blacklistMasks#" index="i">
		<cfset i = trim(i)>
		<cfif not listFindNoCase(tempList, i)>
			<cfset tempList = listAppend(tempList, i)>
		</cfif>
	</cfloop>
	<cfset blacklistMasks = tempList>
	
	<!---fetch the users who satisfy requiredMasks--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name, u.email
		FROM tbl_users u
		WHERE 1 = dbo.userHasMasks(u.user_id, <cfqueryparam cfsqltype="cf_sql_varchar" value="#requiredMasks#">)
	</cfquery>
	
	<!---now build a list of those users so we can use the bulkHasMasks functions to remove everyone who has ANY of the blackListMasks.--->
	<cfloop query="getUsers">
		<cfif not listFindNoCase(usersList, username)>
			<cfset usersList = listAppend(usersList, username)>
		</cfif>
	</cfloop>
	
	<cfset bulkMasks = bulkGetUserMasks(usersList)>
	
	
	<!---now, loop over each user and if they don't have a blacklisted mask add them to usersQuery--->
	<cfloop query="getUsers">
		<cfset passes = 1><!---assume they've passed.--->
		
		<cfloop list="#blackListMasks#" index="i">
			<cfif bulkHasMasks(bulkMasks, username, i)>
				<cfset passes = 0>
				<cfbreak><!---they have this mask, don't use them.--->
			</cfif>
		</cfloop>
		
		<cfif passes>
			<cfset queryAddRow(usersQuery)>
			<cfset querySetCell(usersQuery, "user_id", user_id)>
			<cfset querySetCell(usersQuery, "username", username)>
			<cfset querySetCell(usersQuery, "last_name", last_name)>
			<cfset querySetCell(usersQuery, "first_name", first_name)>
			<cfset querySetCell(usersQuery, "email", email)>
		</cfif>
	</cfloop>
	
	<!---now we have the correct users based on masks, add on anyone from forceUsers--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name, u.email
		FROM tbl_users u
		WHERE username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#forceUsers#" list="true">)
	</cfquery>
	
	<cfloop query="getUsers">
		<cfset passes = 1><!---assume they are not already in usersQuery--->
		
		<!---make sure they are not already in usersQuery, so we don't add any duplicates.--->
		<cfloop query="usersQuery">
			<cfif getUsers.username eq usersQuery.username>
				<cfset passes = 0>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<cfif passes>
			<cfset queryAddRow(usersQuery)>
			<cfset querySetCell(usersQuery, "user_id", user_id)>
			<cfset querySetCell(usersQuery, "username", username)>
			<cfset querySetCell(usersQuery, "last_name", last_name)>
			<cfset querySetCell(usersQuery, "first_name", first_name)>
			<cfset querySetCell(usersQuery, "email", email)>
		</cfif>
	</cfloop>
	
	
	<!---this is maybe a bit less elegant, but it will remove users from usersQuery that are in excludeUsers--->
	<cfquery dbtype="query" name="usersQuery">
		SELECT user_id, username, last_name, first_name, email
		FROM usersQuery
		WHERE username NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#excludeUsers#" list="true">)
	</cfquery>
	
	
	<!---at this point usersQuery is complete, we need only to update the email list to match it.--->
	
	<cfset removeUsers = findDiffs(usersQuery, currentUsers)>
	<cfset newUsers = findDiffs(currentUsers, usersQuery)>
	<!---cfdump var="#removeUsers#" label="Remove From #listName#"--->
	<!---cfdump var="#newUsers#" label="Add To #listName#"--->
	
	<cfloop array="#removeUsers#" index="i">
		<cfset mailCommands = mailCommands & "QUIET DEL #listName# " & i & chr(10) & chr(13)>
	</cfloop>
	
	<cfloop array="#newUsers#" index="i">
		<cfset mailCommands = mailCommands & "QUIET ADD #listName# " & i & chr(10) & chr(13)>
	</cfloop>
	
	<cfreturn mailCommands>
</cffunction>


<!---talk to IU List.  take a cfhttp response , and return the cookie parsed as a struct.--->
<cffunction name="getCookieStruct">
	<cfargument name="serverName" type="String" required="true">
	<cfset var response = "">
	<cfset var cookieArray = arrayNew(1)>
	<cfset var cookieStruct = structNew()>
	<cfset var myCookie = "">
	<cfset var n = "">
	<cfset var cPart = "">
	<cfset var key = "">
	<cfset var value = "">
	
	<!---Connect to IU List to get a cookie--->
	<cfhttp method="post" url="#serverName#" redirect="false" result="response"><!---if you follow the redirect it negates our cookie from logging in.--->
		<cfhttpparam type="formfield" name="previous_action" value="">
		<cfhttpparam type="formfield" name="previous_list" value="">
		<cfhttpparam type="formfield" name="referer" value="">
		<cfhttpparam type="formfield" name="list" value="">
		<cfhttpparam type="formfield" name="action" value="login">
		<cfhttpparam type="formfield" name="email" value="#sender#">
		<cfhttpparam type="formfield" name="passwd" value="#list_password#">
		<cfhttpparam type="formfield" name="action_login" value="Login">
	</cfhttp>
	
	<cfif structKeyExists(response.ResponseHeader, "Set-Cookie")>
		<cfset myCookie = response.ResponseHeader["Set-Cookie"]>
		
		<!---each item is a list of values--->
		<cfloop list="#myCookie#" delimiters=";" index="cPart">
			<!---cPart is then a key=value pair--->
			<cfset key = listFirst(cPart, "=")>
			<cfset value = listLast(cPart, "=")>
			
			<cfset cookieStruct[key] = value>
		</cfloop>
		
		<!---add the struct to our array of cookies--->
		<cfset arrayAppend(cookieArray, cookieStruct)>
		
	</cfif>
	
	<cfreturn cookieArray>
</cffunction>

<!---talks to the sympa server and returns the members of a list--->
<cffunction name="fetchList">
	<cfargument name="listName" type="string" required="true">
	<cfargument name="serverName" type="string" required="true">
	<cfargument name="cookie" type="string" required="true">
	
	<cfset var response = "">
	<cfset var item = "">
	<cfset var usersQuery = queryNew("email","varchar")>
	<cfset var prevString = "the first item"><!---A string for keeping track of the previous email encountered in our loop.  Helps with finding bad users--->
	
	<cfhttp url="#serverName#/dump/#urlEncodedFormat(listName)#/light" method="get" result="response">
		<cfhttpparam type="cookie" name="sympa_session" value="#cookie#">
	</cfhttp>
	
	
	<cfloop list="#response.filecontent#" delimiters="#chr(10)#" index="item">
		<cfif not isValid("email", item)>
			<cfthrow type="custom" message="Invalid Email Found" detail="Failure encountered when parsing IU List's #listName# with #prevString#.">
		</cfif>
		
		<!---at this point we are looking at a valid email, pare it down to just the username and add it to usersQuery--->
		<cfset queryAddRow(usersQuery)>
		<cfset querySetCell(usersQuery, "email", item)>
		
		<cfset prevString = "the item after #item#"><!---update prevString for our next pass--->
	</cfloop>
	
	<cfreturn usersQuery>
</cffunction>

<!---find items that are in query2, but not in query1--->
<cffunction name="findDiffs">
	<cfargument name="query1" type="query" required="true">
	<cfargument name="query2" type="query" required="true">
	
	<cfset var found = 0>
	<cfset var curUser = "">
	<cfset var unmatched = arrayNew(1)>
	
	<cfloop query="query2">
		<cfset found = 0>
		<cfset curUser = trim(lcase(email))>
		
		<cfloop query="query1">
			<cfif trim(lcase(email)) eq curUser>
				<cfset found = 1>
				<cfbreak><!---we found it, we can break this inner loop--->
			</cfif>
		</cfloop>
		
		<cfif found eq 0>
			<cfset arrayAppend(unmatched, curUser)>
		</cfif>
	</cfloop>
	
	<cfreturn unmatched>
</cffunction>