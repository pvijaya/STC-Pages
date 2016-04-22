<cfmodule template="#application.appPath#/header.cfm" title='Rehire Request' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- HEADER / NAVIGATION --->
<h1>Rehire Requests</h1>
<cfif hasMasks('admin')>
	<a href="rehire-deadlines.cfm">Manage Deadlines</a> |
	<a href="rehire-options-editor.cfm">Edit Reasons</a> |
	<a href="rehire-report.cfm">Report</a>
</cfif>

<!--- CFPARAMS --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmDeadlineId" type="integer" default="0">
<cfparam name="frmResponse" type="boolean" default="1">
<cfparam name="frmReasonId" type="integer" default="0">
<cfparam name="frmNotes" type="string" default="">

<!---now determine which instances the user can pick semesters from.--->
<cfset instanceList = "0">

<!---I wish this was more dynamic, but we need to determine the correct mask(s) for this user to pull from the table of deadlines.--->
<cfset maskList = "consultant">
<cfif hasMasks("CS")>
	<cfset maskList = "CS">
</cfif>

<!---Get the list of reasons--->
<cfquery datasource="#application.applicationdatasource#" name='getReasons'>
	SELECT * FROM tbl_rehire_options
</cfquery>

<!---a function to return a users responses for a given deadline_id, along with information about the semester.--->
<cffunction name="getUserRehireByDeadline">
	<cfargument name="deadlineId" type="numeric" required="true">
	
	<cfset var getRR = "">
	
	<!---this query fetches the deadline information, and rehire request information(if there is any).--->
	<cfquery datasource="#application.applicationDataSource#" name="getRR">
		SELECT rd.deadline_id, i.instance_name, rd.instance_id, rd.semester_id, rd.deadline_date, rd.mask_list, rd.email_contact, s.semester_name, s.start_date, s.end_date, rr.*
		FROM tbl_rehire_deadlines rd
		INNER JOIN vi_semesters s ON s.instance_id = rd.instance_id AND s.semester_id = rd.semester_id
		INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
		LEFT OUTER JOIN tbl_rehire_responses rr 
			ON rr.deadline_id = rd.deadline_id
			AND rr.consultant_uid = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		WHERE rd.deadline_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#deadlineId#">
		ORDER BY i.instance_name, rd.deadline_date, s.start_date
	</cfquery>
	
	<cfreturn getRR>
</cffunction>


<!---handle user input--->
<cfif frmAction eq "editSubmit">
	<cftry>
		
		<!---verify that they have provided all the information we need.--->
		<!---if they answered they do not want rehired they must provide a reason--->
		<cfif not frmResponse>
			<cfif frmReasonId eq 0>
				<cfthrow message="Missing Input" detail="If you do not wish to be rehired you must provide a ""Reason for Leaving.""">
			</cfif>
			
			<!---if they select the "other" reason they must provide a note.--->
			<cfif frmReasonId eq 5 and trim(frmNotes) eq "">
				<cfthrow message="Missing Input" detail="If you select ""Other"" as your ""Reason for Leaving"" you must provide ""Other Notes""">
			</cfif>
			
			<!---there's a limit on how long a note can be--->
			<cfif len(frmNotes) gt 500>
				<cfthrow message="Excessive Input" detail="Field ""Other Notes"" may only be 500 characters long.">
			</cfif>
		</cfif>
		
		<!---all the input looks good, we're ready to insert/update the record in the database.--->
		<cfset getRR = getUserRehireByDeadline(frmDeadlineId)><!---fetch values from the database for this deadline--->
		
		<cfloop query="getRR">
			<cfif isValid("integer", response_id)>
				<!---update the existing record--->
				<cfquery datasource="#application.applicationDataSource#" name="updateRequest">
					UPDATE tbl_rehire_responses
					SET	response = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmResponse#">,
						reason_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmReasonId#">,
						other_notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNotes#">,
						time_submitted = GETDATE()
					WHERE response_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#response_id#">
				</cfquery>
			<cfelse>
				<!---No record exists, so we need to insert it.--->
				<cfquery datasource="#application.applicationDataSource#" name="insertRequest">
					INSERT INTO tbl_rehire_responses (deadline_id, consultant_uid, response, reason_id, other_notes, time_submitted)
					VALUES (
						#frmDeadlineId#,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
						<cfqueryparam cfsqltype="cf_sql_bit" value="#frmResponse#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#frmReasonId#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNotes#">,
						GETDATE()
					)
				</cfquery>
			</cfif>
			
			<cfset emailSent = 0>
			<!---if they are late submitting their request for this semester email email_contact--->
			<cfif dateCompare(deadline_date, now()) lte 0>
				<cfmail to="#email_contact#" from="tccwm@iu.edu" subject="Late Rehire Request - #session.cas_display_name# (#session.cas_username#)" type="html">
					Greetings!<br/>
					This is an automatically generated message to inform you that #session.cas_display_name# (#session.cas_username#)
					has submitted their rehire request after the deadline date of #dateFormat(deadline_date, "mm/dd/yyyy")#. 
					<br/><br/>
					#instance_name# #semester_name# #dateFormat(start_date, "yyyy")#: <cfif frmResponse EQ 0>No<cfelseif frmResponse EQ 1>Yes</cfif>
					<!---><a href="#cgi.http_host##application.appPath#/tools/rehire-requests/rehire-report.cfm">Rehire Report</a>--->
				</cfmail>
				
				<cfset emailSent = 1>
			</cfif>
			
			<!---if we got this far we've updated the request.--->
			<p class="ok">
				<cfoutput>
					Your #instance_name# #semester_name# #dateFormat(start_date, "yyyy")# Rehire Request has been recorded.
					<cfif emailSent>
						An email notification was sent to #email_contact#, since this was submitted after the Rehire Request Deadline.
					</cfif>
				</cfoutput>
			</p>
		</cfloop>
	<cfcatch type="any">
		<!---throw them back to the form--->
		<cfset frmAction = "edit">
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
</cfif>


<!---draw a form for the user to update their rehire request.--->
<cfif frmAction eq "edit">
	<!---we want to preserve user input, but by default seed values from the database.--->
	<cfset getRR = getUserRehireByDeadline(frmDeadlineId)><!---fetch values from the database for this deadline--->
	
	<!---if we don't have a user submitted value use the one from the database.--->
	<cfloop query="getRR">
		<cfif not isDefined("url.frmResponse") AND not isDefined("form.frmResponse")>
			<cfif response neq "">
				<cfset frmResponse = response>
			</cfif>
		</cfif>
		
		<cfif not isDefined("url.frmReasonId") AND not isDefined("form.frmReasonId") AND reason_id neq "">
			<cfset frmReasonId = reason_id>
		</cfif>
		
		<cfif not isDefined("url.frmNotes") AND not isDefined("form.frmNotes") and other_notes neq "">
			<cfset frmNotes = other_notes>
		</cfif>
	</cfloop>
	
	<cfoutput query="getRR">
		<h2>#instance_name# #semester_name# #dateFormat(start_date, "yyyy")# Rehire Request</h2>
			
			<form action="#cgi.script_name#" method="post">
				<input type="hidden" name="frmAction" value="editSubmit">
				<input type="hidden" name="frmDeadlineId" value="#deadline_id#">
				
				<fieldset>
					<legend>Would you like to be rehired for this semester?</legend>
					
					<label><input type="radio" name="frmResponse" value="1" <cfif frmResponse>checked</cfif>> Yes</label><br/>
					<label><input type="radio" name="frmResponse" value="0" <cfif not frmResponse>checked</cfif>> No</label>
				</fieldset>
				
				<p/>
				
				<label>
					Reason for leaving:
					<select  name="frmReasonId">
						<option value="0"></option>
					<cfloop query="getReasons">
						<option value="#reason_id#" <cfif reason_id eq frmReasonId>selected</cfif>>#htmlEditFormat(reason)#</option>
					</cfloop>
					</select>
				</label>
				
				<p/>
				
				<label>
					Other Notes:
					<textarea name="frmNotes" style="width: 20em; height: 8em; vertical-align: text-top;">#htmlEditFormat(frmNotes)#</textarea>
				</label>
				
				<cfif dateCompare(deadline_date, NOW()) lte 0>
					<p class="tinytext warning">
						The rehire deadline for this semester has already passed, an email will be sent to #email_contact# updating your request when you submit this form.
					</p>
				</cfif>
				
				<p>
					<input  type="submit" value="submit">
				</p>
			</form>
	</cfoutput>
</cfif>


<!---fetch the currently applicable deadlines, as well as the user's responses--->
<cfquery datasource="#application.applicationDataSource#" name="getDeadlines">
	SELECT rd.deadline_id, i.instance_name, rd.instance_id, rd.semester_id, rd.deadline_date, rd.mask_list, s.semester_name, s.start_date, s.end_date, rr.*, ro.reason
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
	AND rd.mask_list = <cfqueryparam cfsqltype="cf_sql_varchar" value="#maskList#"><!---mask_list isn't a real use of masks, CS always trumps Consultant rather than someone having both.--->
	<!---fetch only semesters that have not ended yet.--->
	AND s.start_date >= GETDATE()
	ORDER BY i.instance_name, rd.deadline_date DESC, s.start_date
</cfquery>

<cfoutput query="getDeadlines" group="instance_id">
	<h2>#instance_name#</h2>
	
	<cfset prevMask = ""><!---split up results by instance and mask_list--->
	
	<table class="stripe">
	
	<!---draw individual semesters/responses.--->
	<cfoutput>
		<cfif prevMask neq mask_list>
			<tr class="titlerow">
				<td colspan="7">
					#mask_list#
				</td>
			</tr>
			<tr class="titlerow2">
				<th>Semester</th>
				<th>Deadline</th>
				<th>Response</th>
				<th>Reason</th>
				<th>Notes</th>
				<th>Submitted</th>
				<th>Link</th>
			</tr>
		</cfif>
		
		<tr>
			<td>
				#semester_name# #dateFormat(start_date, "yyyy")#
			</td>
			
			<td>
				#dateFormat(dateAdd("d", -1, deadline_date), "mmm d, yyyy")#
			</td>
			
			<td>
				<cfif response_id eq "">
					<em>n/a</em>
				<cfelse>
					<cfif response>
						Yes
					<cfelse>
						No
					</cfif>
				</cfif>
				
			</td>
			
			<td>
				<cfif response_id eq ""><em>n/a</em></cfif>
				#reason#
			</td>
			
			<td>
				<cfif response_id eq ""><em>n/a</em></cfif>
				#left(stripTags(other_notes), 50)#<cfif len(stripTags(other_notes)) gt 50>...</cfif>
			</td>
			
			<td>
				<cfif response_id eq ""><em>n/a</em></cfif>
				#dateFormat(time_submitted, "mmm d, yyyy")# #timeFormat(time_submitted, "short")#
			</td>
			
			<td>
				<cfif isNumeric(response_id)>
					[<a href="#cgi.script_name#?frmAction=edit&frmDeadlineId=#deadline_id#">Update</a>]
				<cfelse>
					[<a href="#cgi.script_name#?frmAction=edit&frmDeadlineId=#deadline_id#">Submit</a>]
				</cfif>
			</td>
		</tr>
		
		<!---update prevMask for the next pass--->
		<cfset prevMask = mask_list>
	</cfoutput>
	</table>
</cfoutput>
<cfif getDeadlines.recordCount EQ 0>
	<h2>No Rehire Deadline Exists</h2>
	<div style="max-width:700px;padding:10px;" class="shadow-border">
		<p>The Admin team has not set a rehire requests deadline for you. Please wait for the deadline to be set before submitting a rehire request. 
		If you believe that you need to submit a rehire request at this very moment, please contact a member of the Admin team.</p>
	</div>
</cfif>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>