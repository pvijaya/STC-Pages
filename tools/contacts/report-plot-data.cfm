<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json">

<!---if the user isn't authorized to view it just return an empty object.--->
<cfif not hasMasks("cs")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfparam name="granularity" type="integer" default="1"><!---0 for month, 1 for day, 2 for hour--->
<cfparam name="startDate" type="date" default="#dateAdd("m", -3, now())#">
<cfparam name="endDate" type="date" default="#now()#">

<cfquery datasource="#application.applicationDataSource#" name="getContacts">
	SELECT COUNT(contact_id) AS contacts, SUM(minutes_spent) AS minutes,
		<!---the faux date we create depends upon our granularity setting.--->
		<cfswitch expression="#granularity#">
			<cfcase value="0">
				CONCAT(DATEPART(year, created_ts), '-', DATEPART(month, created_ts), '-1 00:00')
			</cfcase>
			<cfcase value="1">
				CONCAT(DATEPART(year, created_ts), '-', DATEPART(month, created_ts), '-', DATEPART(day, created_ts), ' 00:00')
			</cfcase>
			<cfdefaultcase>
				CONCAT(DATEPART(year, created_ts), '-', DATEPART(month, created_ts), '-', DATEPART(day, created_ts), ' ', DATEPART(hour, created_ts), ':00')
			</cfdefaultcase>
		</cfswitch> AS date

	FROM tbl_contacts c
	WHERE created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
	<!---our group by clause also depends on our granularity setting--->
	<cfswitch expression="#granularity#">
		<cfcase value="0">
			GROUP BY DATEPART(year, created_ts), DATEPART(month, created_ts)
			ORDER BY DATEPART(year, created_ts), DATEPART(month, created_ts)
		</cfcase>
		<cfcase value="1">
			GROUP BY DATEPART(year, created_ts), DATEPART(month, created_ts), DATEPART(day, created_ts)
			ORDER BY DATEPART(year, created_ts), DATEPART(month, created_ts), DATEPART(day, created_ts)
		</cfcase>
		<cfdefaultcase>
			GROUP BY DATEPART(year, created_ts), DATEPART(month, created_ts), DATEPART(day, created_ts), DATEPART(hour, created_ts)
			ORDER BY DATEPART(year, created_ts), DATEPART(month, created_ts), DATEPART(day, created_ts), DATEPART(hour, created_ts)
		</cfdefaultcase>
	</cfswitch>
</cfquery>

<cfswitch expression="#granularity#">
	<cfcase value="0">
		<cfset dateFormatString = "MMM yyyy">
	</cfcase>
	<cfcase value="1">
		<cfset dateFormatString = "MMM d, yyyy">
	</cfcase>
	<cfdefaultcase>
		<cfset dateFormatString = "MMM d, yyyy HH:00">
	</cfdefaultcase>
</cfswitch>

<cfset contactsArray = arrayNew(1)>


<cfloop query="getContacts">
	<!---cfset useDate = dateFormat(date, dateFormatString)--->

	<!---javascript can use an ISO 8601 date to create a Date object.--->
	<cfset utcDate = dateConvert("local2utc", date)>
	<cfset useDate = dateFormat( utcDate, "yyyy-mm-dd" ) & "T" & timeFormat( utcDate, "HH:mm:ss" ) & "Z">

	<!---we need to make the structure to append to the array.--->
	<cfset myContact = structNew()>
	<cfset myContact['Date'] = useDate>
	<cfset myContact['contacts'] = contacts>
	<cfset myContact['minutes'] = minutes>

	<cfset arrayAppend(contactsArray, myContact)>
</cfloop>

<cfset contactsJson = serializeJSON(contactsArray)>

<cfoutput>#contactsJSON#</cfoutput>