<!--- get a consultant's shifts for a specific date --->
<cffunction name="getDayShifts">
	<cfargument name="username" type="string" required="yes">
	<cfargument name="dayDate" type="date" required="yes">
	<cfargument name="datasource" type="string" required="yes">

	<cfset var getDayShiftsQ = "">

	<!--- fetch the shifts this consultant worked today --->
	<cfquery datasource="#datasource#" name="getDayShiftsQ">
		SELECT cs.site_id, si.site_name, cs.shift_time
		FROM shift_blocks cs
		INNER JOIN tbl_consultants c
			ON c.ssn = cs.ssn
			AND c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		INNER JOIN tbl_sites si ON si.site_id = cs.site_id
		WHERE cs.shift_date = <cfqueryparam cfsqltype="cf_sql_date" value="#dayDate#">
		ORDER BY cs.time_id
	</cfquery>

	<!--- loop over the shifts and find the point where they started/stopped working a particular shift. --->
	<!--- once we have our data tack it on to userInfo.dayShifts --->
	<cfset var curStartTime = '1900-01-01 00:00'><!--- when did the shift start? --->
	<cfset var prevEndTime = '1900-01-01 00:00'><!--- when did the last row we pulled from PIE end? --->
	<cfset var curSiteName = ""> <!--- where are they working?--->

	<cfset var dayShifts = "">
	<cfset var dayShiftsSites = "0"><!---a leading 0 for the list so queries don't choke on the data.--->

	<cfloop query="getDayShiftsQ">

		<!--- first, check if we've hit a new shift. --->
		<cfif prevEndTime neq shift_time OR curSiteName neq site_name>

			<!--- only add the info if it isn't our first pass --->
			<cfif curSiteName neq "">
				<cfset dayShifts = listAppend(dayShifts, "#curSiteName# #timeFormat(curStartTime, 'hh:nn tt')# - #timeFormat(prevEndTime, 'hh:nn tt')#")>
				<cfset dayShiftsSites = listAppend(dayShiftsSites, site_id)>
			</cfif>

			<!--- we're starting a new block, update the start time. --->
			<cfset curStartTime = shift_time>

		</cfif>

		<!--- now update our tracking parts for the next pass. --->
		<cfset curSiteName = site_name>
		<cfset prevEndTime = dateAdd("h", 1, shift_time)>

	</cfloop>

	<!--- catch any stragglers, and add them as well. --->
	<cfif prevEndTime neq curStartTime AND curSiteName neq "">

		<cfset dayShifts = listAppend(dayShifts, "#curSiteName# #timeFormat(curStartTime, 'hh:nn tt')# - #timeFormat(prevEndTime, 'hh:nn tt')#")>
		<cfset dayShiftsSites = listAppend(dayShiftsSites, getDayShiftsQ.site_id)><!---this is a little hacky, but it should get us the last site_id from the query.--->

	</cfif>

	<cfif getDayShiftsQ.recordCount eq 0>

		<cfset dayShifts = "No shifts">

	</cfif>

	<cfset userInfo['dayShifts'] = dayShifts>
	<cfset userInfo['dayShiftsSites'] = dayShiftsSites>

</cffunction>

<!--- draw a consultant's training form progress --->
<cffunction name="drawTrainingForms">
	<cfargument name="userId" type="numeric" required="yes">

	<!--- get form functions --->
	<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

	<!--- only show the quizzes / checklist the consultant being viewed can access --->
	<!--- fetch all the masks the user explicitly has--->
	<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
		SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
		FROM tbl_users u
		INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
		INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
		WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
	</cfquery>

	<!---fetch the table of masks' parent->child relationships so we can get all the user's inherited masks--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelationships">
		SELECT um.mask_id, um.mask_name,
			CASE
				WHEN mr.mask_id IS NULL THEN 0
				ELSE mr.mask_id
			END AS parent_id
		FROM tbl_user_masks um
		LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
		LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
		ORDER BY um.mask_id
	</cfquery>

	<!---now use our helper function to build get a query of all masks the user has, both explicitly and inheritted.--->
	<cfset getUserMasks = buildMyMasks(getMyMasks, getAllMaskRelationships)>

	<!---now turn that into a list of mask_id's for use in the readership query below.--->
	<cfset maskList = "0"><!---a placeholder so we never have a list of length 0--->
	<cfloop query="getUserMasks">
		<cfset maskList = listAppend(maskList, mask_id)>
	</cfloop>

	<!--- fetch training checklist and quiz forms --->
	<!--- 4 = checklist, 5 = quiz --->
	<cfquery datasource="#application.applicationDataSource#" name="getForms">
		SELECT f.form_id, f.form_name, fa.attribute_id
		FROM tbl_forms f
		INNER JOIN tbl_forms_attributes fa on fa.form_id = f.form_id
		WHERE (fa.attribute_id = 4 OR fa.attribute_id = 5)
			  AND f.retired = 0
			  AND NOT EXISTS (
				SELECT fm.mask_id
				FROM tbl_forms_masks fm
				WHERE fm.form_id = f.form_id
				AND fm.edit = 0 /*Only need to know they can view the form*/
				AND fm.mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#maskList#" list="true">)
			  )
	</cfquery>

	<cfoutput>

		<cfset var charLimit = 30>
		<!--- Training Checklists --->
		<strong>Checklists</strong><hr/>

		<cfloop query="getForms">
			<cfif attribute_id EQ 4>
				<cfquery datasource="#application.applicationDataSource#" name="getLastSubmission">
					SELECT TOP 1 fs.status
					FROM tbl_forms_submissions fs
					WHERE fs.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_id#">
						  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userInfo.userId#">
					ORDER BY fs.submission_date DESC
				</cfquery>

					<a href="#application.appPath#/tools/forms/form_viewer.cfm?referrer=#urlEncodedFormat(cgi.script_name & "?currentUserId=" & session.cas_uid)#&formUserId=#userInfo.userId#&formId=#form_id#"
					 style="float:left;">
						<cfif len(form_name) GT charLimit>
							<span title="#form_name#">#left(form_name, charLimit)#...</span>
						<cfelse>
							#form_name#
						 </cfif>
					</a>

					<span style="float:right;" class="tinytext">
						(<cfif #getLastSubmission.status# EQ 1>complete<cfelseif #getLastSubmission.status# EQ 0>started<cfelse>not started</cfif>)
					</span>
					<br/>

			</cfif>
		</cfloop>
		<!--- --->

		<br/>

		<cfset charLimit = 30>

		<!--- Training Quizzes --->
		<strong>Quizzes</strong><hr/>

		<cfloop query="getForms">
			<cfif attribute_id EQ 5>
				<cfquery datasource="#application.applicationDataSource#" name="getLastSubmission">
					SELECT TOP 1 fs.score
					FROM tbl_forms_submissions fs
					WHERE fs.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_id#">
						  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userInfo.userId#">
					ORDER BY fs.submission_date DESC
				</cfquery>
				<cfif getLastSubmission.recordCount EQ 0>
					<cfset score = 0>
				<cfelse>
					<cfset score = getLastSubmission.score>
				</cfif>
				<cfquery datasource="#application.applicationDataSource#" name="getItems">
					SELECT fi.form_item_id
					FROM tbl_forms_items fi
					INNER JOIN tbl_forms_items_types fit ON fit.type_id = fi.item_type
					WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_id#">
					      AND fi.retired = 0
					      AND fit.type_text = 'Multiple Choice'
				</cfquery>

					<a href="#application.appPath#/tools/forms/form_viewer.cfm?referrer=#urlEncodedFormat(cgi.script_name & "?currentUserId=" & session.cas_uid)#&formUserId=#userInfo.userId#&formId=#form_id#"
					   style="float:left;">
					<cfif len(form_name) GT charLimit>
							<span title="#form_name#">#left(form_name, charLimit)#...</span>
						<cfelse>
							#form_name#
					</cfif>
					</a>
					<span style="float:right;" class="tinytext">
						(#score# / #maxScoreQuiz(form_id)#)
					</span>
					<br/>

			</cfif>
		</cfloop>

	</cfoutput>

</cffunction>

<!--- fetch contacts by date --->
<cffunction name="getMonthlyContacts">
	<cfargument name="username" required="true">
	<cfargument name="startDate" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')# 00:00">
	<cfargument name="endDate" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')# 23:59:59.999">

	<!--- using the semester dates, retrieve a contact sum for each month --->
	<cfquery datasource="#application.applicationDataSource#" name="getContacts">
		SELECT DATEPART(YEAR, c.created_ts) ts_year, DATEPART(MONTH, c.created_ts) ts_month,
			COUNT(c.contact_id) AS 'total_contact_users', COUNT(DISTINCT c.contact_id) AS 'total_contacts'
		FROM tbl_contacts c
		INNER JOIN tbl_users u ON u.user_id = c.user_id
		LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = c.contact_id

		WHERE u.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		AND c.created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">

		GROUP BY DATEPART(YEAR, c.created_ts), DATEPART(MONTH, c.created_ts)
		ORDER BY ts_year, ts_month
	</cfquery>

	<cfreturn getContacts>

</cffunction>

<!--- draw this semester's monthly contact counts --->
<cffunction name="drawUserMonthContacts">
	<cfargument name="username" required="true">
	<cfargument name="startDate" type="date" default="#dateFormat(now(), 'mm/dd/yyyy')# 00:00">
	<cfargument name="endDate" type="date" default="#dateFormat(now(), 'mm/dd/yyyy')# 23:59:59.999">

	<cfset var monthStart = startDate>
	<cfset var dayCnt = dateDiff("d", startDate, endDate)>
	<cfset var theDate = "">
	<cfset var monthContacts = "">
	<cfset var monthTotal = "">

	<p>
		<cfset monthContacts = getMonthlyContacts(username, startDate, endDate)>
		<cfloop query="monthContacts">
			<div><cfoutput>#dateFormat(createDate(ts_year, ts_month, 1), 'mmm yyyy')#</cfoutput></div>
			<div style="padding-left:1em;"><cfoutput>Contacts: #total_contacts#</cfoutput></div>
			<div style="padding-left:1em;"><cfoutput>Customers: #total_contact_users#</cfoutput></div>
			<br/>
		</cfloop>
	</p>

</cffunction>


<!--- fetch contacts by date --->
<cffunction name="getUserContactsByDate">
	<cfargument name="username" required="true">
	<cfargument name="startDate" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')# 00:00">
	<cfargument name="endDate" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')# 23:59:59.999">

	<cfset var getContacts = "">
	<cfquery datasource="#application.applicationDataSource#" name="getContacts">
		SELECT c.contact_id, c.created_ts, cs.status, cc.customer_username, ct.category_name
		FROM tbl_contacts c
		INNER JOIN tbl_contacts_statuses cs ON cs.status_id = c.status_id
		INNER JOIN tbl_users u ON u.user_id = c.user_id
		LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = c.contact_id
		LEFT OUTER JOIN tbl_contacts_categories_match cm ON cm.contact_id = c.contact_id
		LEFT OUTER JOIN tbl_contacts_categories ct ON ct.category_id = cm.category_id

		WHERE u.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		AND c.created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">

		/*carefuly order our results so we can use grouping with cfoutput*/
		ORDER BY c.contact_id, cc.customer_username, ct.category_name
	</cfquery>

	<cfreturn getContacts>

</cffunction>

<!--- draw a user's customer contacts for the chosen date range --->
<cffunction name="drawUserContacts">
	<cfargument name="username" required="true">
	<cfargument name="piePath" type="string" default="#userInfo.pie_path#">
	<cfargument name="startDate" type="date" default="#dateFormat(now(), 'mm/dd/yyyy')# 00:00">
	<cfargument name="endDate" type="date" default="#dateFormat(now(), 'mm/dd/yyyy')# 23:59:59.999">
	<cfargument name="contactPath" type="string" default="">

	<!---fetch the contacts for the user over the provided time span--->
	<cfset var getContacts = getUserContactsByDate(username, "#dateFormat(dayDate, 'mm-dd-yyyy')# 00:00", "#dateFormat(dateAdd('d', 1, dayDate), 'mm-dd-yyyy')# 00:00")>
	<cfset var myUsers = "">
	<cfset var MyCats = "">
	<cfset var firstPass = 1>

	<br/>
	<cfoutput query="getContacts" group="contact_id">
		<cfset myUsers = "">
		<cfset myCats = "">
		<cfset firstPass = 1>
		<div style="opacity: 1; display: inline-block; width: 20em; border: 1px solid gray;">
			<!---generate a list of customers--->
			<cfoutput group="customer_username">
				<cfset myUsers = listAppend(myUsers, customer_username)>

				<!---each customer is loaded up with all the categories, so we only need to loop over categories once.--->
				<cfif firstPass>
					<cfoutput>
						<!---prevent duplicate categories when we have multiple users with the same username, eg "unknown"--->
						<cfif not listFindNoCase(myCats, category_name)>
							<cfset myCats = listAppend(myCats, category_name)>
						</cfif>
					</cfoutput>
					<cfset firstPass = 0>
				</cfif>
			</cfoutput>
			<a href="#application.appPath#/tools/contacts/view-contact.cfm?contactId=#contact_id#" class="contactLink" contactId="#contact_id#">#contact_id#</a>
			<span class="tinytext">#myUsers#</span><br/>
			#myCats#
		</div>
	</cfoutput>

</cffunction>


<!--- get a user's supply reports for a chosen date range --->
<cffunction name="getSupplyReports">
	<cfargument name="userId" required="true">
	<cfargument name="startDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="endDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="request" default="day">

	<cfquery name="getSupplyReportsQ" datasource="#application.applicationDataSource#">
		SELECT l.lab_name, sub.submitted_date
		FROM tbl_inventory_submissions sub
		INNER JOIN vi_labs l
			ON l.instance_id = sub.instance_id
			AND l.lab_id = sub.lab_id
		INNER JOIN tbl_users u ON u.user_id = sub.user_id
		WHERE sub.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
		<cfif request EQ "semester">
			AND convert(varchar(10), sub.submitted_date, 121) BETWEEN '#startDate#' AND '#endDate#'
		<cfelse>
			AND convert(varchar(10), sub.submitted_date, 121) = <cfqueryparam cfsqltype="cf_sql_date" value="#startDate#">
		</cfif>
			ORDER BY sub.submitted_date ASC
	</cfquery>

	<cfoutput>
		<cfif request EQ "semester">
			#getSupplyReportsQ.recordCount#
		<cfelse>
			<cfif getSupplyReportsQ.recordCount GTE 1>
				<table class="stripe">
					<tr class="titlerow">
						<th>Lab</th>
						<th>Time</th>
					</tr>
					<cfloop query="getSupplyReportsQ">
							<tr>
								<td>#getSupplyReportsQ.lab_name#</td>
								<td>#TimeFormat(getSupplyReportsQ.submitted_date, "hh:nn tt")#</td>
							</tr>
					</cfloop>
				</table>
				<br/>
			<cfelse>
				<div style="text-align:center;">
				<p>(None)</p>
				</div>
			</cfif>
		</cfif>
	</cfoutput>

</cffunction>


<!--- get a user's lab observations for a chosen date range --->
<cffunction name="getLabObs">
	<cfargument name="username" required="true">
	<cfargument name="startDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="endDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="request" default="day">

	<cfset var getLabObsQ = "">

	<cfquery name="getLabObsQ" datasource="#userInfo.datasource#">
		SELECT c.username, qa.answer_group, si.site_name, qa.ts, qa.answer, qa.question_id, w.workstation_name
		FROM tbl_consultants c
		INNER JOIN tbl_questions_answers qa ON qa.answered_by = c.ssn
		INNER JOIN tbl_questions_variables qv
			ON qv.var_name = 'ObsMachineId' /*this gets us the 'which machine?' question for which ever PIE we're looking in.*/
			AND qv.question_id = qa.question_id
		INNER JOIN tbl_sites si ON si.site_id = qa.answered_about
		LEFT OUTER JOIN tbl_workstations w ON w.workstation_id = qa.answer
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		<cfif request EQ "semester">
			AND convert(varchar(10), qa.ts, 121) BETWEEN '#startDate#' AND '#endDate#'
		<cfelse>
			AND convert(varchar(10), qa.ts, 121) = <cfqueryparam cfsqltype="cf_sql_date" value="#startDate#">
		</cfif>
			ORDER BY qa.ts ASC, qa.question_id ASC
	</cfquery>

	<cfif request EQ "semester">

		<cfoutput>#getLabObsQ.recordCount#</cfoutput>

	<cfelse>
		<cfif getLabObsQ.recordCount GTE 1>

			<!--- since we're fetching two questions per submission, make sure we get the right info --->
			<!--- the right number of times --->
			<table class="stripe">
				<tr class="titlerow">
					<th>Lab Observed</th>
					<th>Time Observed</th>
					<th>Workstation</th>
					<th>Link</th>
				</tr>
				<cfoutput query="getLabObsQ">
					<tr>
						<td>#getLabObsQ.site_name#</td>
						<td>#TimeFormat(getLabObsQ.ts, "hh:nn tt")#</td>
						<td>
							#shortWorkstationName(workstation_name)#
						</td>
						<td>
							<a href="https://#cgi.server_name##userInfo.pie_path#/obs/obs_lab_view.cfm?AG=#answer_group#">Link</a>
						</td>
					</tr>
				</cfoutput>
			</table>

		<cfelse>
			<div style="text-align:center;">
			<p>(None)</p>
			</div>
		</cfif>
	</cfif>

</cffunction>


<!--- get the observations of a user for a chosen date range --->
<cffunction name="getConObs">
	<cfargument name="username" required="true">
	<cfargument name="startDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="endDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="request" default="day">

	<cfset var getConObsQ = "">

	<cfquery name="getConObsQ" datasource="#userInfo.datasource#">
		SELECT DISTINCT a.answer_group, c.username AS about, s.site_name, s.site_id, cs.username AS observer, a.ts
		FROM tbl_questions_answers a
		INNER JOIN tbl_questions q ON q.question_id = a.question_id
		INNER JOIN tbl_consultants c ON c.ssn = a.answered_about
		INNER JOIN tbl_consultants cs ON cs.ssn = a.answered_by
		LEFT OUTER JOIN tbl_sites s ON s.site_id = a.link_integer

		WHERE q.group_id = 8
		AND c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">

		<cfif request EQ "semester">
			AND convert(varchar(10), a.ts, 121) BETWEEN <cfqueryparam cfsqltype="cf_sql_date" value='#startDate#'> AND <cfqueryparam cfsqltype="cf_sql_date" value='#endDate#'>
		<cfelseif request eq "range">
			AND convert(varchar(10), a.ts, 121) BETWEEN <cfqueryparam cfsqltype="cf_sql_date" value='#startDate#'> AND <cfqueryparam cfsqltype="cf_sql_date" value='#endDate#'>
		<cfelse>
			AND convert(varchar(10), a.ts, 121) = <cfqueryparam cfsqltype="cf_sql_date" value="#startDate#">
		</cfif>

		ORDER BY a.answer_group
	</cfquery>

	<cfif request EQ "semester">

		<cfoutput>#getConObsQ.recordCount#</cfoutput>

	<cfelse>
		<cfif getConObsQ.recordCount GTE 1>

			<!--- since we're fetching two questions per submission, make sure we get the right info --->
			<!--- the right number of times --->
			<table class="stripe">
				<tr class="titlerow">
					<th>Observed By</th>
					<th>Location</th>
					<th>Time Observed</th>
					<th>Link</th>
				</tr>
				<cfoutput query="getConObsQ">
					<tr>
						<td>#observer#</td>
						<td>#getConObsQ.site_name#</td>
						<td>#TimeFormat(getConObsQ.ts, "hh:nn tt")#</td>
						<td>
							<a href="https://#cgi.server_name##userInfo.pie_path#/obs/obs_view.cfm?AG=#answer_group#">Link</a>
						</td>
					</tr>
				</cfoutput>
			</table>

		<cfelse>
			<div style="text-align:center;">
			<p>(None)</p>
			</div>
		</cfif>
	</cfif>
</cffunction>


<!--- get the lead/mentor comments for a user for a chosen date range --->
<cffunction name="getMentorComments">
	<cfargument name="username" required="true">
	<cfargument name="startDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="endDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="request" default="day">

	<cfset var getConObsQ = "">

	<cfquery name="getConObsQ" datasource="#userInfo.datasource#">
		SELECT DISTINCT a.answer_group, c.username AS about, cs.username AS observer, a.ts, q.group_id
		FROM tbl_questions_answers a
		INNER JOIN tbl_questions q ON q.question_id = a.question_id
		INNER JOIN tbl_consultants c ON c.ssn = a.answered_about
		INNER JOIN tbl_consultants cs ON cs.ssn = a.answered_by

		WHERE q.group_id IN <cfif userInfo.instance eq 1>(45,7) <cfelseif userInfo.instance eq 2> (7,57) <cfelse> (0) </cfif>
		AND c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">

		<cfif request EQ "semester">
			AND convert(varchar(10), a.ts, 121) BETWEEN <cfqueryparam cfsqltype="cf_sql_date" value='#startDate#'> AND <cfqueryparam cfsqltype="cf_sql_date" value='#endDate#'>
		<cfelseif request eq "range">
			AND convert(varchar(10), a.ts, 121) BETWEEN <cfqueryparam cfsqltype="cf_sql_date" value='#startDate#'> AND <cfqueryparam cfsqltype="cf_sql_date" value='#endDate#'>
		<cfelse>
			AND convert(varchar(10), a.ts, 121) = <cfqueryparam cfsqltype="cf_sql_date" value="#startDate#">
		</cfif>

		ORDER BY a.answer_group
	</cfquery>

	<cfif request EQ "semester">

		<cfoutput>#getConObsQ.recordCount#</cfoutput>

	<cfelse>
		<cfif getConObsQ.recordCount GTE 1>

			<!--- since we're fetching two questions per submission, make sure we get the right info --->
			<!--- the right number of times --->
			<table class="stripe">
				<tr class="titlerow">
					<th>Observed By</th>
					<th>Type</th>
					<th>Time Observed</th>
					<th>Link</th>
				</tr>
				<cfoutput query="getConObsQ">
					<tr>
						<td>#observer#</td>
						<td>
							<cfif group_id eq 7>
								Mentor Comments
							<cfelse>
								Lead Comments
							</cfif>
						</td>
						<td>#TimeFormat(getConObsQ.ts, "hh:nn tt")#</td>
						<td>
							<a href="https://#cgi.server_name##userInfo.pie_path#/rave/rave_view.cfm?AG=#answer_group#">Link</a>
						</td>
					</tr>
				</cfoutput>
			</table>

		<cfelse>
			<div style="text-align:center;">
			<p>(None)</p>
			</div>
		</cfif>
	</cfif>
</cffunction>


<!--- get a user's step-ins/outs for a chosen date range --->
<cffunction name="getStepOuts">
	<cfargument name="username" required="true">
	<cfargument name="startDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="endDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">

	<cfquery datasource="#userInfo.datasource#" name="getStepOutsQ">
		/* have to use a sub query with a case to find any orphaned stepouts when a checkin is edited or deleted. */
		SELECT *
		FROM
			(SELECT s.stepout_id, s.stepout_time, so.description, s.STEPOUT_COMMENT, s.return_time, sow.workstation_name AS stepout_workstation, siw.workstation_name AS stepin_workstation,
				CASE
					WHEN EXISTS (SELECT ssn FROM tbl_checkins WHERE checkin_id = s.checkin_id) THEN (SELECT TOP 1 ssn FROM tbl_checkins WHERE checkin_id = s.checkin_id)
					WHEN EXISTS (SELECT ssn FROM TBL_DEL_CHECKINS_LOG WHERE checkin_id = s.checkin_id) THEN (SELECT TOP 1 ssn FROM TBL_DEL_CHECKINS_LOG WHERE checkin_id = s.checkin_id)
					ELSE NULL
				END AS ssn
			FROM TBL_STEPOUTS s
			INNER JOIN vi_stepout_options so
				ON so.category_id = s.category_id
				AND so.category_element_id = s.category_element_id
			LEFT OUTER JOIN tbl_workstations sow ON sow.workstation_id = s.stepout_workstation_id
			LEFT OUTER JOIN tbl_workstations siw ON siw.workstation_id = s.stepin_workstation_id
			WHERE s.stepout_time BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
									AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
			) so
		INNER JOIN tbl_consultants c ON c.ssn = so.ssn
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		ORDER BY so.stepout_time ASC
	</cfquery>

	<cfreturn getStepOutsQ>

</cffunction>

<!--- draw stepout information for a particular date --->
<cffunction name="drawStepOuts">
	<cfargument name="username" required="true">
	<cfargument name="date" required="true">

	<cfset getStepOutsQ = getStepOuts(userInfo.username, #DateFormat(date,'yyyy-mm-dd')# + '00:00', #DateFormat(date,'yyyy-mm-dd')# + '23:59:50.999')>

	<cfif getStepOutsQ.recordCount NEQ 0>
		<cfoutput>
			<table class="stripe">
				<tr class="titlerow">
					<th>Start Time</th>
					<th>Return Time</th>
					<th>Description</th>
					<th>Comment</th>
				</tr>
				<cfloop query="getStepOutsQ">
					<tr>
						<td>
							#TimeFormat(getStepOutsQ.stepout_time, "hh:nn tt")#<br/>
							<span class="tinytext">#shortWorkstationName(stepout_workstation)#</span>
						</td>
						<td>
							#TimeFormat(getStepOutsQ.return_time, "hh:nn tt")#<br/>
							<span class="tinytext">#shortWorkstationName(stepin_workstation)#</span>
						</td>
						<td>#getStepOutsQ.description#</td>
						<td>
							<cfif getStepOutsQ.STEPOUT_COMMENT EQ "">
								<div style="text-align:center;">
								None
								</div>
							<cfelse>
								#getStepOutsQ.STEPOUT_COMMENT#
							</cfif>
						</td>
					</tr>
				</cfloop>
			</table>
		</cfoutput>
		<br/>
	<cfelse>
		<div style="text-align:center;">
			<p>(None)</p>
		</div>
	</cfif>

</cffunction>



<cffunction name="getCleanings" output="false">
	<cfargument name="username" required="true">
	<cfargument name="startDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">
	<cfargument name="endDate" required="true" type="date" default="#dateFormat(dayDate, 'mm/dd/yyyy')#">

	<cfset var getCleaningsByDate = "">

	<cfquery datasource="#application.applicationDataSource#" name="getCleaningsByDate">
		SELECT cs.submission_id, l.lab_name, cls.section_description, u.username, cs.comments, cs.date_cleaned
		FROM tbl_cleaning_submissions cs
		INNER JOIN tbl_users u ON u.user_id = cs.user_id
		INNER JOIN tbl_cleaning_labs_sections cls
			ON cls.cleaning_id = cs.cleaning_id
			AND cls.section_id = cs.section_id
		INNER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cs.cleaning_id
		INNER JOIN vi_labs l
			ON l.instance_id = cl.instance_id
			AND l.lab_id = cl.lab_id
		WHERE u.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		AND cs.date_cleaned BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
		ORDER BY cs.date_cleaned
	</cfquery>

	<cfreturn getCleaningsByDate>
</cffunction>

<cffunction name="drawCleanings">
	<cfargument name="username" required="true">
	<cfargument name="date" required="true">

	<cfset var myCleanings = getCleanings(username, DateFormat(date,'yyyy-mm-dd') & ' 00:00', DateFormat(date,'yyyy-mm-dd') & ' 23:59:50.999')>

	<cfif myCleanings.recordCount gt 0>
		<table class="stripe">
			<tr class="titlerow">
				<th>Lab</th>
				<th>Section</th>
				<th>By</th>
				<th>Date</th>
				<th>Comments</th>
			</tr>
		<cfoutput query="myCleanings">
			<tr>
				<td>#lab_name#</td>
				<td>#section_description#</td>
				<td>#myCleanings.username#</td>
				<td>#dateTimeFormat(date_cleaned, "MMM d, yyyy h:nn aa")#</td>
				<td>#comments#</td>
			</tr>
		</cfoutput>
		</table>
	<cfelse>
		<div style="text-align:center;">
		<p>(None)</p>
		</div>
	</cfif>
</cffunction>


<cffunction name="getChatMessages">
	<cfargument name="username" required="true">
	<cfargument name="dayDate" required="true" type="date">

	<cfset var startDate = dayDate + " 00:00">
	<cfset var endDate = dayDate + " 23:59:59.999">

	<cfquery datasource="#application.applicationDataSource#" name="getChatMessages">
		SELECT u.username, cm.Date_Time, cm.From_IP, cm.Message_ID, cm.Visible, cm.Message
		FROM tbl_chat_messages cm
		INNER JOIN tbl_users u ON u.user_id = cm.user_id
		INNER JOIN tbl_instances i ON i.instance_id = cm.instance
		WHERE cm.Date_Time BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
				AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
			AND u.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		ORDER BY cm.Date_Time DESC
	</cfquery>

	<cfif getChatMessages.recordCount EQ 0>
		<div style="text-align:center;">
			<p>(None)</p>
		</div>
	<cfelse>
		<table class="stripe">
			<tr class="titlerow">
				<th style="min-width:15%">Time</th>
				<th>Message</th>
			</tr>
			<cfloop query="getChatMessages">

				<cfoutput>
					<tr>
						<td style="min-width:15%;">#dateTimeFormat(Date_Time, 'hh:nn tt')#</td>
						<td>#Message#</td>
					</tr>
				</cfoutput>

			</cfloop>
		</table>
	</cfif>

</cffunction>