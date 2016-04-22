<cfmodule template="#application.appPath#/header.cfm" title='List of Badges' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">

<!--- cfparams --->
<cfparam name="instanceId" type="integer" default="#Session.primary_instance#">
<cfparam name="currentUserId" type="integer" default="#session.cas_uid#"><!---  --->


<!---now find the details of the current instance based on instanceId--->
<cfset myInstance = getInstanceById(instanceId)>

<cfquery name="getPieDatabase" datasource="#application.applicationDatasource#">
	SELECT datasource
	FROM tbl_instances
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
</cfquery>
<cfloop query ="getPieDatabase">
	<cfset pieDatabase= getPieDatabase.datasource>
</cfloop>

<cfset consultantUsername = ''>
<cfset consultantFirst = ''>
<cfquery name="getUsernameFromId" datasource="#application.applicationDatasource#">
	SELECT username, preferred_name
	FROM tbl_users
	WHERE user_id  = <cfqueryparam cfsqltype="cf_sql_integer" value="#currentUserId#">
</cfquery>
<cfloop query ="getUsernameFromId">
	<cfset consultantUsername= getUsernameFromId.username>
	<cfset consultantFirst= getUsernameFromId.preferred_name>
</cfloop>
<!---we also want to fetch shift counts and RAVEs for all our active users, make a list of users, and try to get that info in two big queries--->
<cfset raveGroupList = "1,2"><!---1 and 2 are gold stars and PDIs, but based on instance there are other types we may be interested in.--->

<cfquery datasource="#pieDatabase#" name="getRaves">
	SELECT x.username, x.group_id, x.description, COUNT(x.answer_group) AS cnt
	FROM (
		SELECT DISTINCT c.username, q.group_id, qg.description, qa.answer_group
		FROM tbl_consultants c
		INNER JOIN tbl_questions_answers qa ON qa.answered_about = c.ssn
		INNER JOIN tbl_questions q ON q.question_id = qa.question_id
		INNER JOIN tbl_questions_groups qg ON qg.group_id = q.group_id
		INNER JOIN tbl_questions_reviewed qr ON qr.answer_group = qa.answer_group
		INNER JOIN tbl_questions_reviewed_status qrs ON qrs.status_id = qr.status_id
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#consultantUsername#" >
		AND q.group_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#raveGroupList#" list="true">)/*only the kinds of RAVEs we are interested in*/
		AND qr.status_id = 6/*only approved RAVEs*/
	) x
	GROUP BY x.username, x.group_id, x.description
</cfquery>

<!---now snag the hour worked by each of our active users.--->

<!---this query is fairly expensive and sees a lot of use, let's cache it to save stress on the DB.--->
<cfset cachedLimit = createTimeSpan(0,0,6,0)><!---reuse the results if they were pulled in the last 6 minutes, which is fine since we only count to 1/10th of an hour.--->

<cfquery datasource="#pieDatabase#" name="getHours" cachedwithin="#cachedLimit#">
	SELECT x.username, COUNT(x.username) AS shifts, SUM(DATEDIFF(minute, x.started, x.ended)/60.0) AS hours_worked
	FROM (
		SELECT DISTINCT c.username,
		/*find hours worked*/
		CASE
			WHEN ci.checkin_time >= ci.start_time THEN ci.checkin_time
			ELSE ci.start_time
		END AS started,
		CASE
			WHEN ci.checkout_time <= ci.end_time THEN ci.checkout_time
			ELSE ci.end_time
		END AS ended
		FROM tbl_consultant_schedule cs
		INNER JOIN tbl_consultants c ON c.ssn = cs.ssn
		INNER JOIN tbl_checkins ci ON ci.checkin_id = cs.checkin_id
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#consultantUsername#" >
	) x
	GROUP BY x.username
</cfquery>

<cfset goldStars =  numberFormat(getRaveCount(consultantUsername, 1,pieDatabase) ,"9,999")>
<cfset pdis = numberFormat(getRaveCount(consultantUsername, 2,pieDatabase) ,"9,999")>
<cfset shiftsWorked = getUserShifts(consultantUsername, pieDatabase)>

<cfset blackList = 'Admin,Logistics'>

<h1>User Profiles</h1>
<fieldset>
	<legend>Select User</legend>
	<!---our default form to select a user.--->
	<form action='<cfoutput>#cgi.script_name#</cfoutput>' method="POST">
		<!---draw all users, past and present, in case we ever want to re-activate someone.--->

		<cfoutput>#drawConsultantSelector(myInstance.instance_mask, blackList, currentUserId, 0, "currentUserId")#</cfoutput>
		
		<input type="submit"  name="action" value="Select">
	</form>
</fieldset>
<cfoutput>
	<div style="display:inline-block; width:200px;">
	#displayUserSpecial(currentUserId)#
	</div>
</cfoutput>		
<cfoutput>
	<div style="display:inline-block; width:400px; vertical-align:top;">
		<br/>
		<h2>#consultantFirst#'s TCC Stats</h2>
			Gold Stars: #goldStars# 
			<!---(If the selected user is not a cs AND I am) OR (if I am an admin), let me see the pdis--->

		<cfif (NOT hasMasks("CS", currentUserId) AND hasMasks("CS")) OR hasMasks("admin") > 	<!--- only show pdis when a cs views a consultant, or when an admin views a cs --->
		<br/>
			PDIs: #pdis#
		</cfif>	
		<br/>
			Shifts worked: #numberFormat(shiftsWorked.shifts, "9,999")#
		<br/>
			Hours worked: #numberFormat(shiftsWorked.hours, "9,999")#
		<br/><br/>
			<a href="#application.apppath#/tools/badges/search-badges.cfm?frmAction=Find Badges&frmUserId=#currentUserId#">See badges earned</a>
	</div>
</cfoutput>






<cffunction name="getRaveCount">
	<cfargument name="username" type="string" default="#session.cas_username#">
	<cfargument name="raveType" type="numeric" default="1">
	<cfargument name="pieDatabase" type="string" default="">
	
	<cfset var raveCount = 0>
	
	<cfloop query="getRaves">
		<cfif username eq getRaves.username AND group_id eq raveType>
			<cfset raveCount = cnt>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn raveCount>
</cffunction>


<cffunction name="getUserShifts">
	<cfargument name="username" type="string" default="#session.cas_username#">
	<cfargument name="pieDatabase" type="string" default=""><!---just a parameter leftover from the original--->
	
	<cfset var shiftsObj = structNew()>
	
	<cfset shiftsObj.shifts = 0>
	<cfset shiftsObj["hours"] = 0>
	
	
	<cfloop query="getHours">
		<cfif username eq getHours.username>
			<cfset shiftsObj.shifts = shifts>
			<cfset shiftsObj.hours = hours_worked>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn shiftsObj>
</cffunction>
