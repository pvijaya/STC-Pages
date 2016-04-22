<cfmodule template="#application.appPath#/header.cfm" title='Staff Evaluations' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/staff-evaluation/staff-eval-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmUserId" type="integer" default="0">
<cfparam name="frmSemester" default="i0s0" type="string"><!---this will be in the form "i#instance_id#s#semester_id#"--->
<cfparam name="frmInstanceId" default="0" type="integer"><!---the instance_id parsed out from frmSemester--->
<cfparam name="frmSemesterId" default="0" type="integer"><!---the semester_id parsed out from frmSemester--->
<cfparam name="frmAction" type="string" default="">
<cfparam name="comment" type="string" default="">

<!---Determines what instance_id they have--->
<cfset myInstance = getInstanceById(session.primary_instance)>

<!---parse frmSemester to populate frmInstanceId and frmSemesterId--->
<cfloop list="#frmSemester#" index="n">
	
	<!---find the instanceId--->
	<cfset instanceId = mid(n, find("i", n)+1, (find("s", n) - 1 - find("i", n)))>
	
	<!---find the semesterId, depending where it is in the list--->
	<cfset semesterId = right(n, len(n) - find("s", n))>
	
	<cfif isNumeric(instanceId) AND isNumeric(semesterId)>
		<cfset frmInstanceId = instanceId>
		<cfset frmSemesterId = semesterId>
	</cfif>
	
</cfloop>

<!--- HEADER / NAVIGATION --->
<h1>Staff Evaluation </h1>
<cfif frmSemester NEQ "i0s0" AND frmUserId GT 0>
	<a href='<cfoutput>#cgi.script_name#</cfoutput>'>Go Back</a> |
</cfif>
<cfif hasMasks('admin')>
	<a href='staff-evaluation-report.cfm'>Staff Evaluation Report</a> | 
	<a href='staff-evaluation-editor.cfm'>Staff Evaluation Options Editor</a>
	<br/><br/>
</cfif>

<!--- QUERIES --->
<cfif frmUserId NEQ 0>
	
	<!---fetch the questions for the viewer for each instance they have.--->
	<cfquery name='getQuestions' datasource="#application.applicationDataSource#">
		SELECT q.question_id, q.question, q.mask_required, q.instance_id, i.instance_name, q.type_id, qt.type_name
		FROM tbl_evaluation_questions q
		INNER JOIN tbl_evaluation_question_types qt ON q.type_id = qt.type_id
		INNER JOIN tbl_instances i ON i.instance_id = q.instance_id
		WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)/*limit to instances the user can view*/
			  AND q.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#"><!---we can also use the instance_id for the semester to narrow the number of questions asked.--->
			  AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, q.mask_required)/*limit to questions the user can view*/
			  AND q.active = 1
		ORDER BY i.instance_name, q.question_id
	</cfquery>
	
	<!--- fetch the questions answered --->
	<cfloop query='getQuestions'>
		<cfparam name="varquestion#question_id#" type="string" default="">
	</cfloop>
	
</cfif>

<cfquery name='getForm' datasource="#application.applicationDataSource#">
	SELECT f.form_id
	FROM tbl_forms f
	WHERE f.form_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="Staff Evaluation">
</cfquery>

<!--- make sure the form has been created properly --->
<cfif getForm.form_id EQ 0>
	<p class="alert">No form with the name 'Staff Evaluation' exists. Please create one and try again.</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>

<cfif frmUserId NEQ 0 AND frmSemester NEQ "i0s0">
	<cfoutput>
		<cflocation url="#application.appPath#/tools/forms/form_viewer.cfm?formId=#getForm.form_id#&formUserId=#frmUserId#&semesterId=#frmSemesterId#&referrer=#application.appPath#/tools/staff-evaluation/staff-evaluation.cfm" 
			        addtoken="false">
	</cfoutput>
</cfif>

<!---insert responses into table--->
<cfif frmAction EQ "Submit Evaluation">

	<cftry>
		
		<cfloop query='getQuestions'>
			
			<cfset tempQuestion = evaluate('varquestion#question_id#')>
			
			<cfquery name='insertEvaluation' datasource="#application.applicationDataSource#">
				INSERT INTO tbl_evaluation_responses(member_id, semester_id, evaluator_id, instance_id, response, question_id)
				VALUES(
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">, 
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmSemesterId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					<cfif hasMasks('IUB', frmUserId)>1<cfelse>2</cfif>,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#tempQuestion#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#question_id#">)		
			</cfquery>
			
		</cfloop>
		
		<p class="ok">
			Evaluation submitted successfully.
		</p>
		
		<cfoutput>
			<a href='<cfoutput>#cgi.script_name#</cfoutput>'>Start a new evaluation!</a>
		</cfoutput>
		
		<cfcatch type="any">
			<cfoutput>
				<p class="warning">
					#cfcatch.message# - #cfcatch.detail#
				</p>
			</cfoutput>
		</cfcatch>
		
	</cftry>
	
</cfif>

<!---Start html--->

<fieldset>
	<legend>Staff Evaluation</legend>
	
	<form action='<cfoutput>#cgi.script_name#</cfoutput>' method='POST'>
		
		<cfoutput>
		
			<p>Please select a semester and a member of the staff to evaluate.</p>
			
			<table>
			
				<tr>
					<td><label for="currentSemesters">Semester:</label></td>
					<!--- in the report, the user needs access to all past semesters --->
					<td>#drawSemesterSelect("past", frmInstanceId, frmSemesterId, "frmSemester")#</td>
				</tr>
				
				<cfset blackList = "Logistics"> <!--- don't display Logistics folks here.--->
				<cfset maskList = listAppend("CS", myInstance.instance_mask)>
				
				<tr>
					<td><label for="currentUsers">Staff Member:</label></td>
					<td>#drawConsultantSelect(maskList, blackList, frmUserId, "frmUserId")#</td>
				</tr>
			
			</table>
			
			<br/>
			
		</cfoutput>
		
		<input type='submit'  name='frmAction' value='Select'/>
		
	</form>
	
</fieldset>

<!--->	
<cfelseif frmAction NEQ "">
		
	<cfoutput>#displayUserSpecial(frmUserId)#</cfoutput>
		
	<form action='<cfoutput>#cgi.script_name#</cfoutput>' method='POST'>
		
		<cfoutput>
			<input type='hidden' name='frmUserId' value='#frmUserId#'/>
			<input type='hidden' name='frmSemester' value='#frmSemester#'/>
		</cfoutput>

		<table class="stripe">
			<cfoutput query='getQuestions' group="instance_id">
				
				<tr class="titlerow">
					<td colspan="2">#instance_name#</td>
				</tr>
				<cfoutput>
					<tr>
						<cfif type_id EQ 1>
							<td><label for='#question_id#'>#question#</label></td>
							<td>
								<select  id='#question_id#' name='varquestion#question_id#'>
									<option value='Yes'>Yes</option>
									<option value='No'>No</option>
									<option value='N/A'>N/A</option>
								</select>
							</td>
						<cfelseif type_id EQ 2>
							<td><label for='#question_id#'>#question#</label></td>
							<td><textarea class='special' id='#question_id#' name='varquestion#question_id#' ></textarea></td>
						</cfif>
					</tr>
				</cfoutput>
				
			</cfoutput>
		</table>
		
		<input type='submit' style="float:right;margin:10px 10% 0px 0px;" name='frmAction' value='Submit Evaluation' class=' '/>
		
	</form>

--->

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>