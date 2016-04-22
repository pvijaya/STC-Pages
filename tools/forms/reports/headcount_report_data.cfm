<cfsetting enablecfoutputonly="true" showdebugoutput="false">
<cfcontent type="application/json">

<!---if the user isn't authorized to view it just return an empty object.--->
<cfif not hasMasks("cs")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfparam name="granularity" type="integer" default="0"><!---0 for month, 1 for day, 2 for hour--->
<cfparam name="startDate" type="date" default="#dateAdd("m", -3, now())#">
<cfparam name="endDate" type="date" default="#now()#">
<!---since we use BETWEEN we always want to add one extra day to endDate.--->
<cfset endDate = dateAdd("d", 1, endDate)>


<cfquery datasource="#application.applicationDataSource#" name="getHeadCounts">


	<cfswitch expression="#granularity#">
		<cfcase value="0">
			SELECT  tr.cell_text AS row_text, SUM(fui.user_answer) AS user_answer,
			CAST( DATEADD(DAY, (-1 * DATEPART(day, fs.submission_date)) + 1, fs.submission_date) AS DATE )
		</cfcase>
		<cfcase value="1">
			SELECT  tr.cell_text AS row_text, SUM(fui.user_answer) AS user_answer,
			CAST(DATEADD(day, 1-DATEPART(weekday,fs.submission_date), fs.submission_date) AS date)
		</cfcase>
		<cfcase value="3">
			SELECT  tr.cell_text AS row_text, fui.user_answer,
			CAST(
				CAST(
					CAST(fs.submission_date AS date)
					AS varchar
				) + ' ' + td.cell_text + 'am'
				AS datetime
			)
		</cfcase>
		<cfdefaultcase>
			SELECT  tr.cell_text AS row_text, SUM(fui.user_answer) AS user_answer,
			CAST(fs.submission_date AS DATE)
		</cfdefaultcase>
	</cfswitch> AS submission_date

	FROM tbl_forms_submissions fs
	INNER JOIN tbl_users u ON u.user_id = fs.submitted_by
	INNER JOIN tbl_forms_users_items fui
		ON fui.submission_id = fs.submission_id
		AND fui.form_item_id = 46
	INNER JOIN tbl_forms_items_tables_cells tr
		ON tr.form_item_id = fui.form_item_id
		AND tr.form_table_cell_id = fui.row_id
	INNER JOIN tbl_forms_items_tables_cells td
		ON td.form_item_id = fui.form_item_id
		AND td.form_table_cell_id = fui.col_id
	WHERE fs.form_id = 3
	AND fs.submission_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
	/*This prevents double-counting days where more than one GYAR was submitted*/
	AND fs.submission_id = (
		SELECT TOP 1 submission_id
		FROM tbl_forms_submissions
		WHERE form_id = 3
		AND CAST(submission_date AS date) = CAST(fs.submission_date AS date)
		ORDER BY submission_date DESC
	)
	<cfswitch expression="#granularity#">
		<cfcase value="0">
			GROUP BY CAST( DATEADD(DAY, (-1 * DATEPART(day, fs.submission_date)) + 1, fs.submission_date) AS DATE ),tr.cell_text
			ORDER BY submission_date DESC
		</cfcase>
		<cfcase value="1">
			GROUP BY CAST(DATEADD(day, 1-DATEPART(weekday,fs.submission_date), fs.submission_date) AS date),tr.cell_text
			ORDER BY submission_date ASC
		</cfcase>
		<cfcase value="3">
			ORDER BY submission_date ASC, tr.cell_order, td.cell_order
		</cfcase>
		<cfdefaultcase>
			GROUP BY CAST(fs.submission_date AS DATE), tr.cell_text
			ORDER BY submission_date ASC
		</cfdefaultcase>
	</cfswitch>
</cfquery>

<cfset headCountArray = arrayNew(1)>

<cfloop query="getHeadCounts" group="submission_date">
	<!---cfset useDate = dateFormat(date, dateFormatString)--->

	<!---javascript can use an ISO 8601 date to create a Date object.--->
	<cfset utcDate = dateConvert("local2utc", submission_date)>
	<cfset useDate = dateFormat( utcDate, "yyyy-mm-dd" ) & "T" & timeFormat( utcDate, "HH:mm:ss" ) & "Z">

	<!---we need to make the structure to append to the array.--->
	<cfset myheadCount = structNew()>
	<cfset myheadCount['Date'] = useDate>
	<cfloop>
		<cfset myheadCount['#row_text#'] = user_answer>
	</cfloop>

	<cfset arrayAppend(headCountArray, myheadCount)>
</cfloop>

<cfset headCountJson = serializeJSON(headCountArray)>

<cfoutput>#headCountJson#</cfoutput>