<cfmodule template="#application.appPath#/header.cfm" title='Submission Report'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<cfset myInstance = getInstanceById(Session.primary_instance)>
<cfset semesterObj = getSemesterByDate(Session.primary_instance)>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<!--- if there is no active contest, they shouldn't be here. kick 'em back to the welcome page --->
<cfif getContest.recordCount EQ 0>
	<cflocation url="welcome.cfm" addtoken="false">
</cfif>

<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>
<cfset drawNavigation()>

<h2 style="margin-bottom:0em;">Submission Report</h2>

<cfquery datasource="#application.applicationDataSource#" name="getInstanceMask">
	SELECT um.mask_id
	FROM tbl_user_masks um
	WHERE mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
</cfquery>

<!--- we have two sets of mask and negMask lists to pass to getUsers --->
<cfset conMaskList = listAppend("consultant", myInstance.instance_mask)>
<cfset csMaskList = listAppend("cs", myInstance.instance_mask)>

<cfset consultants = getUsers(conMaskList, "cs,admin,logistics")>
<cfset cs = getUsers(csMaskList, "admin,logistics")>

<!--- since we only need the mentor info for consultants, use two seperate queries --->
<cfquery datasource="#application.applicationDataSource#" name="getConsultantEntries">
	SELECT u.user_id, u.username, u.first_name, u.last_name, COUNT(pe.entry_id) AS entries,
		   c2.username AS mentor_username, m.start_date
	FROM tbl_users u
	LEFT OUTER JOIN tbl_psc_entries pe ON pe.user_id = u.user_id 
					AND pe.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getcontest.contest_id#">
					AND pe.rejected = 0
	INNER JOIN [#myInstance.datasource#].dbo.tbl_consultants c ON 	
					c.first_name = u.first_name
			   		AND c.last_name = u.last_name
	INNER JOIN [#myInstance.datasource#].dbo.tbl_obs_mentors m ON m.mentee_id = c.ssn
					AND m.start_date = (
			   			SELECT TOP 1 start_date
			   			FROM [#myInstance.datasource#].dbo.tbl_obs_mentors
			   			WHERE mentee_id = c.ssn
			   				  AND end_date > <cfqueryparam cfsqltype="cf_sql_date" value="#createODBCDate(now())#">
			   			ORDER BY start_date DESC
			   		)
	INNER JOIN [#myInstance.datasource#].dbo.tbl_consultants c2 ON c2.ssn = m.mentor_id
	WHERE u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#consultants#" list="yes">)
	GROUP BY u.user_id, u.username, u.first_name, u.last_name, c2.username, m.start_date
	ORDER BY entries DESC, u.last_name, u.username
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getCSEntries">
	SELECT u.user_id, u.username, u.first_name, u.last_name, COUNT(pe.entry_id) AS entries
	FROM tbl_users u
	LEFT OUTER JOIN tbl_psc_entries pe ON pe.user_id = u.user_id 
					AND pe.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getcontest.contest_id#">
					AND pe.rejected = 0
	WHERE u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#cs#" list="yes">)
	GROUP BY u.user_id, u.username, u.first_name, u.last_name
	ORDER BY entries DESC, u.last_name, u.username
</cfquery>

<cfset conTotal = 1>
<cfset csTotal = 1>
<cfset conCnt = 1>
<cfset csCnt = 1>
<cfloop query="getConsultantEntries">
	<cfset conTotal = conTotal + 1>
	<cfif entries NEQ 0>
		<cfset conCnt = conCnt + 1>
	</cfif>
</cfloop>

<p style="margin-bottom:0em;margin-top:0em;" class="tinytext">
	<cfoutput>
		#conCnt# of #conTotal# consultants have submitted entries. (#numberFormat((conCnt/conTotal)*100, 99.9)#%)
	</cfoutput>
</p>

<!--- only admin see cs info --->
<cfif hasMasks('admin')>
	
	<cfloop query="getCSEntries">
		<cfset csTotal = csTotal + 1>
		<cfif entries NEQ 0>
			<cfset csCnt = csCnt + 1>
		</cfif>
	</cfloop>
	
	<p style="margin-bottom:0em;margin-top:0em;" class="tinytext">
		<cfoutput>
			#csCnt# of #csTotal# CS have submitted entries. (#numberFormat((csCnt/csTotal)*100, 99.9)#%)
		</cfoutput>
	</p>
	
</cfif>

<p style="margin-bottom:0em;margin-top:0em;"><em>Note: Counts are based on non-rejected submissions only.</em></p>

<div style="float:left; width=50%; margin:auto">

	<h3>Consultants with No Submissions</h3>
	
	<cfset cnt = 1>
	
	<table class="stripe">
		
		<tr class="titlerow">
			<th></th>
			<th>Name</th>
			<th>Username</th>
			<th>Mentor</th>
		</tr>
		
		<cfloop query="getConsultantEntries">
			<cfif entries EQ 0>
				<cfoutput>
					<tr>
						<td>#cnt#</td>
						<td>#last_name#, #first_name#</td>
						<td>#username#</td>
						<td>#mentor_username#</td>
					</tr>
				</cfoutput>
				<cfset cnt = cnt + 1>
			</cfif>
		</cfloop>
	</table>
	
</div>

<!--- only allow admins to view cs submission information --->
<cfif hasMasks('admin')>

	<div style="float:right; width: 50%; margin: auto;">
	
		<h3>CS with No Submissions</h3>
	
		<cfset cnt = 1>
	
		<table class="stripe">
			<tr class="titlerow">
				<th></th>
				<th>Name</th>
				<th>Username</th>
			</tr>
			<cfloop query="getCSEntries">
				<cfif entries EQ 0>
					<cfoutput>
						<tr>
							<td>#cnt#</td>
							<td>#last_name#, #first_name#</td>
							<td>#username#</td>
						</tr>
					</cfoutput>
					<cfset cnt = cnt + 1>
				</cfif>
			</cfloop>
		</table>
	
	</div>
	
</cfif>

<!--- I'm not certain that this bit is even being used. 
      I'll pull it out and see if anyone notices --->

<!--->
<h3>Number of Submissions</h3>

<table class="stripe">
	<tr class="titlerow">
		<th>Name</th>
		<th>Username</th>
		<th>Submissions</th>
	</tr>
	<cfloop query="getEntries">
		<cfif entries GT 0>
			<cfif (hasMasks('admin')) OR 
				  (hasMasks('cs') AND NOT hasMasks('cs', user_id))>
				<cfoutput>
					<tr>
						<td>#first_name# #last_name#</td>
						<td>#username#</td>
						<td>#entries#</td>
					</tr>
				</cfoutput>
			</cfif>
		</cfif>
	</cfloop>
</table>
--->

<!--- this is an alternative way of approaching a big scary query I didn't want to write --->
<cffunction name="getUsers">
	<cfargument name='maskList'><!---masks the user must have to be listed--->
	<cfargument name='negMaskList'><!---masks the user must NOT have to be listed--->

	<cfset var getUsers = "">
	<cfset var getNegUsers = "">
	<cfset var userList = ""><!---list of users from getUsers--->
	<cfset var bulkMasks = "">
	<cfset var passes = ""><!---has the user passed he tests of both maskList and negMaskList?--->
	<cfset var myMask = ""><!---used when looping over maskLists--->
	
	<!--- use a query to fetch all the users who satisfy the requirements of maskList, 
		  then use bulkGetUserMasks() and bulkHasMasks() to check if they violate negMaskList --->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
		FROM tbl_users u
		LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
		<cfif listLen(maskList) gt 0>
			WHERE 1 = 1
			<cfloop list="#maskList#" index="myMask">
				AND EXISTS (
				 SELECT um.mask_id
				 FROM vi_all_masks_users amu
				 INNER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id 
				 WHERE um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myMask#">
				 	   AND amu.user_id = u.user_id
				 )
			</cfloop>
		</cfif>
		ORDER BY last_name, first_name, username
	</cfquery>
	
	<!--- build a list of users who have the masks we do want to know about. --->
	<cfloop query="getUsers">
		<cfset userList = listAppend(userList, user_id)>
	</cfloop>
	
	<!--- now, if we have a negMaskList, we want to make sure none of our users have masks we don't want. Run a query to find the undesired users. --->
	<cfif listLen(negMaskList) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="getNegUsers">
			SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
			FROM tbl_users u
			LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
			LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
			<cfif listLen(negMaskList) gt 0>
				WHERE 0 = 1
				<cfloop list="#negMaskList#" index="myMask">
					OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#trim(myMask)#">
				</cfloop>
			</cfif>
			AND u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userList#" list="true">)
			ORDER BY last_name, first_name, username
		</cfquery>
	</cfif>
	
	<cfset goodUsers = "">
	
	<cfloop query="getUsers">
		<cfset passes = 1><!---assume they've passed--->
		
		<!---if we have a negative mask list we need to make sure this user doesn't have any of those masks--->
		<cfif listLen(negMaskList) gt 0>
			<cfloop query="getNegUsers">
				<cfif getNegUsers.user_id eq getUsers.user_id>
					<cfset passes = 0>
					<cfbreak>
				</cfif>
			</cfloop>
		</cfif>
		
		<cfif passes>
			<cfset goodUsers = listAppend(goodUsers, user_id)>
		</cfif>
	</cfloop>
	
	<cfreturn goodUsers>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>