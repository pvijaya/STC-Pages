<cfsetting showdebugoutput="false" enablecfoutputonly="true">

<cfset curSem = getSemesterByDate(session.primary_instance, now())>
<cfset curInstance = getInstanceById(session.primary_instance)>

<!---find the contacts created by the viewing user--->
<cfset myDay = makeStats(session.cas_uid, "#dateFormat(now(), "yyyy-mm-dd")# 00:00", now())>
<cfset TCCDay = makeStats(0, "#dateFormat(now(), "yyyy-mm-dd")# 00:00", now())>


<cfset mySem = makeStats(session.cas_uid, curSem.start_date, now())>
<cfset TCCSem = makeStats(0, curSem.start_date, now())>

<cfset myConsArray = arrayNew(1)>
<cfset arrayAppend(myConsArray, session.cas_username)>
<cfset allConsArray = arrayNew(1)>

<cfoutput>
	<h3>Day Statistics</h3>
	<dl>
		<dt>TCC</dt>
		<dd>
			<a target="_blank" href="#application.appPath#/tools/contacts/search.cfm?consArray=#urlEncodedFormat(serializeJSON(allConsArray))#&frmStartDate=#urlEncodedFormat(dateFormat(now(), "yyyy-mm-dd"))#&End-Date=#urlEncodedFormat(dateFormat(now(), "yyyy-mm-dd"))#&statusList=[1,2]">
				Contacts Opened
			</a>:
			#numberFormat(TCCDay.count, "9,999")#
		</dd>
		<dd>Users Assisted: #numberFormat(TCCDay.users, "9,999")#</dd>
	</dl>

	<dl>
		<dt>Me</dt>
		<dd>
			<a target="_blank" href="#application.appPath#/tools/contacts/search.cfm?consArray=#urlEncodedFormat(serializeJSON(myConsArray))#&frmStartDate=#urlEncodedFormat(dateFormat(now(), "yyyy-mm-dd"))#&End-Date=#urlEncodedFormat(dateFormat(now(), "yyyy-mm-dd"))#&statusList=[1,2]">
				Contacts Opened
			</a>:
			 #numberFormat(myDay.count, "9,999")#
		</dd>
		<dd>Users Assisted: #numberFormat(myDay.users, "9,999")#</dd>
	</dl>

	<h3>#curInstance.instance_name# #curSem.semester_name# #datePart("yyyy", curSem.start_date)#</h3>
	<dl>
		<dt>TCC</dt>
		<dd>
			<a target="_blank" href="#application.appPath#/tools/contacts/search.cfm?consArray=#urlEncodedFormat(serializeJSON(allConsArray))#&frmStartDate=#urlEncodedFormat(dateFormat(curSem.start_date, "yyyy-mm-dd"))#&End-Date=#urlEncodedFormat(dateFormat(curSem.end_date, "yyyy-mm-dd"))#&statusList=[1,2]">
				Contacts Opened:
			</a>
			#numberFormat(TCCSem.count, "9,999")#
		</dd>
		<dd>Users Assisted: #numberFormat(TCCSem.users, "9,999")#</dd>
	</dl>

	<dl>
		<dt>Me</dt>
		<dd>
			<a target="_blank" href="#application.appPath#/tools/contacts/search.cfm?consArray=#urlEncodedFormat(serializeJSON(myConsArray))#&frmStartDate=#urlEncodedFormat(dateFormat(curSem.start_date, "yyyy-mm-dd"))#&End-Date=#urlEncodedFormat(dateFormat(curSem.end_date, "yyyy-mm-dd"))#&statusList=[1,2]">
				Contacts Opened:
			</a>
			#mySem.count#
		</dd>
		<dd>Users Assisted: #mySem.users#</dd>
	</dl>
</cfoutput>

<cffunction name="makeStats">
	<cfargument name="userId" type="numeric" required="true"><!---0 means all users--->
	<cfargument name="startTime" type="date" required="true">
	<cfargument name="endTime" type="date" required="true">

	<cfset var myCount = 0>
	<cfset var myUsers = 0>

	<cfset var myCountQuery = "">
	<cfset var myUsersQuery = "">

	<cfset var myObj = structNew()>

	<cfquery datasource="#application.applicationDataSource#" name="myCountQuery">
		SELECT contact_id
		FROM tbl_contacts c
		WHERE c.created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startTime#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endTime#">
		AND c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		<cfif userId gt 0>
			AND c.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.CAS_Uid#">
		</cfif>
	</cfquery>
	<cfset myCount = myCountQuery.recordCount>

	<cfquery datasource="#application.applicationDataSource#" name="myUsersQuery">
		SELECT COUNT(c.contact_id) AS customer_count
		FROM tbl_contacts c
		LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = c.contact_id
		WHERE c.created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startTime#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endTime#">
		AND c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		<cfif userId gt 0>
			AND c.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.CAS_Uid#">
		</cfif>
	</cfquery>
	<cfset myUsers = myUsersQuery.customer_count>

	<cfset myObj.count = myCount>
	<cfset myObj.users = myUsers>

	<cfreturn myObj>
</cffunction>