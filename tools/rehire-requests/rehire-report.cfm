<cfmodule template="#application.appPath#/header.cfm" title='Rehire Request Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="frmDeadlineId" type="integer" default="0">

<!--- HEADER / NAVIGATION --->
<h1>Rehire Request Report</h1>
<cfif frmDeadlineId GT 0>
	<a href="rehire-report.cfm">Go Back</a> |
</cfif>
<a href="rehire-deadlines.cfm">Manage Deadlines</a> |
<a href="rehire-options-editor.cfm">Edit Reasons</a> |
<a href="rehire-request.cfm">Request</a>

<!--- fetch existing deadlines --->
<cfquery datasource="#application.applicationDataSource#" name="getDeadlines">
	SELECT rd.deadline_id, rd.mask_list, s.semester_name, s.start_date, i.instance_mask
	FROM tbl_rehire_deadlines rd
	INNER JOIN vi_semesters s
		ON s.instance_id = rd.instance_id
		AND s.semester_id = rd.semester_id
	INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
	LEFT OUTER JOIN tbl_rehire_responses rr 
		ON rr.deadline_id = rd.deadline_id
		AND rr.consultant_uid = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	LEFT OUTER JOIN tbl_rehire_options ro ON ro.reason_id = rr.reason_id
	
	WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)<!---limit us to instances the user can use--->
	<!---fetch only semesters that have not ended yet.--->
	AND GETDATE() <= s.end_date
	ORDER BY i.instance_name, rd.deadline_date DESC, s.start_date
</cfquery>

<!--- if no deadline is selected, display a table of the available ones --->
<cfif frmDeadlineId EQ 0>

	<cfif getDeadlines.recordCount GT 0>
		
		<p>Choose a deadline below to view its report.</p>
		
		<table class="stripe">
			
			<tr class="titlerow">
				<th>Semester</th>
				<th>Campus</th>
				<th>Group</th>
				<th>Report</th>
			</tr>
			
			<cfloop query="getDeadlines">
				
				<cfoutput>
					<tr>
						<td>#semester_name# #dateFormat(start_date,'yyyy')#</td>
						<td>#instance_mask#</td>
						<td>#mask_list#</td>
						<td><a href="#cgi.script_name#?frmDeadlineId=#deadline_id#">Link</a></td>
					</tr>
				</cfoutput>
				
			</cfloop>
			
		</table>
		
	<cfelse> <!--- if no valid deadlines exist, just display a message --->
		No deadlines found. Deadlines can be added / edited from Manage Deadlines.
	</cfif>
	
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
	
</cfif>

<!---fetch the details about the deadline--->
<cfquery datasource="#application.applicationDataSource#" name="getDeadline">
	SELECT i.instance_name, s.semester_name, s.start_date, rd.deadline_date, rd.email_contact, rd.mask_list
	FROM tbl_rehire_deadlines rd
	INNER JOIN vi_semesters s ON s.instance_id = rd.instance_id AND s.semester_id = rd.semester_id
	INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
	WHERE rd.deadline_id = #frmDeadlineId#
</cfquery>

<cfoutput query="getDeadline">
	<h2 style="margin-bottom: 0;">#instance_name# #semester_name# #dateFormat(start_date, "yyyy")# for #mask_list#</h2>
	<p>Deadline: #dateFormat(deadline_date, "mmm d, yyyy")# Late Submissions sent to: #email_contact#</p>
</cfoutput>

<!--- probably have to split out into two queries, 1.) for all those who did respond, regardless of masks, 
	  2.) all those who could have responded, based on current masks.--->
<cfquery datasource="#application.applicationDataSource#" name="getResponses">
	SELECT rr.response_id, u.last_name, u.first_name, u.username, rr.response, ro.reason, rr.other_notes, 
		   rr.time_submitted, rd.deadline_date
	FROM tbl_rehire_responses rr
	INNER JOIN tbl_rehire_deadlines rd ON rd.deadline_id = rr.deadline_id
	INNER JOIN tbl_users u ON u.user_id = rr.consultant_uid
	LEFT OUTER JOIN tbl_rehire_options ro ON ro.reason_id = rr.reason_id
	WHERE rr.deadline_id = #frmDeadlineId#
	ORDER BY rr.response DESC, u.last_name, u.first_name, u.username
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getDeadbeats">
	SELECT u.username, u.first_name, u.last_name, u.email
	FROM tbl_rehire_deadlines rd
	INNER JOIN vi_semesters s ON s.instance_id = rd.instance_id  AND s.semester_id = rd.semester_id
	INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
	INNER JOIN tbl_users u 
		ON u.date_added <= rd.deadline_date/*only users who were around before the deadline*/
		AND dbo.userHasMasksExplicite(u.user_id, rd.mask_list+','+i.instance_mask) = 1/*user explicitly has rd.mask_list and the mask for the instance of PIE the semester comes from*/
	LEFT OUTER JOIN tbl_rehire_responses rr ON rr.deadline_id = rd.deadline_id AND rr.consultant_uid = u.user_id
	WHERE rd.deadline_id = #frmDeadlineId#
	AND rr.response_id IS NULL/*we only want the folks who did not respond*/
	ORDER BY u.last_name, u.first_name, u.username
</cfquery>

<h3>Responses</h3>

<cfif getResponses.recordCount eq 0>

	<p>No responses found.</p>
	
<cfelse>

	<cfset yesCount = 0>
	<Cfset noCount = 0>

	<!---there are records, draw a table of the rehire requests.--->
	<table class="stripe">
	<cfset prevResponse = -1><!---group the responses by if they wish to return or not--->
	
	<cfoutput query="getResponses">
		<cfif response neq prevResponse>
			<tr class="titlerow">
				<td colspan="6"><cfif not response>Not</cfif> Requesting Rehire</td>
			</tr>
			<tr class="titlerow2">
				<th></th>
				<th>Name</th>
				<th>Response</th>
				<th>Reason</th>
				<th>Notes</th>
				<th>Date</th>
			</tr>
		</cfif>
		
		<tr valign="top">
			
			<td>
				<cfif response>
					<cfset yesCount = yesCount + 1> #yesCount#
				<cfelse>
					<cfset noCount = noCount + 1> #noCount#
				</cfif>
			</td>
			
			<td>#last_name#, #first_name# (#username#)</td>
			
			<td>
				<cfif response>Yes<cfelse>No</cfif>
			</td>
			
			<td>
				#reason#
			</td>
			
			<td class="tinytext">
				<!---strip out any user entered HTML, and preserve newlines--->
				<cfset tidyNote = nl2br(stripTags(other_notes))>
				<!---if the note is too long display it in an expanding box.--->
				<cfif len(stripTags(tidyNote)) gt 50>
					<span class="trigger">#left(stripTags(tidyNote), 40)#...</span>
					<div>#tidyNote#</div>
				<cfelse>
					#tidyNote#
				</cfif>
			</td>
			
			<!---lastly, if they submitted their request late, highlight it in red.--->
			<td <cfif dateCompare(deadline_date, time_submitted) lte 0>class="red-light" title="Late Submission"</cfif>>
				#dateFormat(time_submitted, "mmm d, yyyy")# #timeFormat(time_submitted, "short")#<br>
			</td>
		</tr>
		
		<!---reset prevResponse for the next pass--->
		<cfset prevResponse = response>
	</cfoutput>
	</table>
</cfif>

<h3 style="margin-bottom: 0;">Did Not Respond</h3>
<!---display a disclaimer if this is after the deadline date--->
<p class="tinytext">
	<b>NOTE:</b> Users' permissions change over time, so the longer <u>after the deadline</u> you look at this report the less correct this list will be. 
</p>

<cfif getDeadbeats.recordCount eq 0>
	<p>No missing responses.</p>
<cfelse>
	
	<cfset naCount = 0>
	
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="3">Did Not Respond</td>
		</tr>
		<tr class="titlerow2">
			<th></th>
			<th>Name</th>
			<th>Email</th>
		</tr>
		
	<cfoutput query="getDeadbeats">
		<tr>
			<td><cfset naCount = naCount + 1>#naCount#</td>
			<td>
				#last_name#, #first_name#(username)
			</td>
			<td>
				#email#
			</td>
		</tr>
	</cfoutput>
	</table>
</cfif>

<!--- This struck me as a bit unnecessary, but I'd rather keep it until I know for sure the admins won't ask for it. --->
<!---
<h3>Summary</h3>

	<cfoutput>
		<table class="stripe">
			<tr class="titlerow">
				<th>Response</th>
				<th>Count</th>
			</tr>			
			<tr><td>Yes</td><td>#YesCount#</td></tr>
			<tr><td>No</td><td>#NoCount#</td></tr>
			<tr><td>N/A</td><td>#getDeadbeats.recordCount#</td></tr>
		</table>
	</cfoutput>
--->

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>