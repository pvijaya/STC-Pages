<cfmodule template="#application.appPath#/header.cfm" title='Staff Evaluation Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/staff-evaluation/staff-eval-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmUserId" type="integer" default="-1">
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmSemester" default="i0s0" type='string'><!---this will be in the form "i#instance_id#s#semester_id#"--->
<cfparam name="frmInstanceId" default="0" type='integer'><!---the instance_id parsed out from frmSemester--->
<cfparam name="frmSemesterId" default="0" type="integer"><!---the semester_id parsed out from frmSemester--->

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
<h1>Staff Evaluation Report</h1>
<a href='staff-evaluation.cfm'>Staff Evaluation Form</a> |
<a href='staff-evaluation-editor.cfm'>Staff Evaluation Options Editor</a>
<br/>

<!---queries--->
<cfquery name='getForm' datasource="#application.applicationDataSource#">
	SELECT f.form_id
	FROM tbl_forms f
	WHERE f.form_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="Staff Evaluation">
</cfquery>

<cfset evalFormId = getForm.form_id>

<cfquery name="getSummaryQuestions" datasource="#application.applicationDataSource#">
	SELECT question_id, question
	FROM tbl_evaluation_questions
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
	      AND type_id = 1
	      AND active = 1
</cfquery>

<cfquery name="getEvaluations" datasource="#application.applicationDataSource#">
	SELECT *
	FROM tbl_evaluation_responses r
	JOIN tbl_users u ON u.user_id = r.evaluator_id
	JOIN tbl_evaluation_questions q ON q.question_id = r.question_id
	WHERE r.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
	      AND r.semester_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmSemesterId#">
	      AND r.member_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">
	      AND type_id = 2
	      AND q.active = 1
</cfquery>

<cfquery name='getFixedAnswers' datasource="#application.applicationDataSource#">
	SELECT option_name
	FROM tbl_evaluation_question_options
</cfquery>

<cfquery name="getEvaluationQuestions" datasource="#application.applicationDataSource#">
	SELECT fi.form_item_id, fi.item_type, fi.item_text, fit.type_text
	FROM tbl_forms_items fi
	INNER JOIN tbl_forms_items_types fit ON fit.type_id = fi.item_type
	WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#evalFormId#">
	ORDER BY fi.item_type, fi.sort_order
</cfquery>

<cfquery name="getEvaluationAnswers" datasource="#application.applicationDataSource#">
	SELECT fui.form_item_id, fui.user_answer, fio.option_text, fui.user_text, u.username
	FROM tbl_forms_submissions fs
	INNER JOIN tbl_forms_items fi ON fi.form_id = fs.form_id
	INNER JOIN tbl_forms_users_items fui ON fui.form_item_id = fi.form_item_id AND fui.submission_id = fs.submission_id
	INNER JOIN tbl_users u ON u.user_id = fs.submitted_by
	LEFT OUTER JOIN tbl_forms_items_options fio ON fio.form_item_option_id = fui.user_answer
	WHERE fs.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#evalFormId#">
		  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">
		  AND fs.semester_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmSemesterId#">
		  AND fs.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
</cfquery>

<!--- FORM RESET --->
<cfif frmAction EQ "Reset">
	<cfset frmUserId = 0>
	<cfset frmSemester = "i0s0">
	<cfset frmSemesterId = 0>
	<cfset frmInstanceId = 0>
	<cfset frmAction = "">
</cfif>

<!--- DRAW FORMS --->

<cfoutput>
	
	<fieldset style="margin-top: 2em;">	
		<legend>Staff Evaluation Report</legend>
		
		<form action='<cfoutput>#cgi.script_name#</cfoutput>' method='get'>
			
			<br/>
			
			<table>
			
				<tr>
					<td><label for="currentSemesters">Semester:</label></td>
					<!--- in the report, the user needs access to all past semesters --->
					<td>#drawSemesterSelect("past", frmInstanceId, frmSemesterId, "frmSemester")#</td>
				</tr>
				
				<cfset blackList = "Logistics"> <!--- don't display Logistics folks here.--->
				<cfset maskList = listAppend("CS", myInstance.instance_mask)>
				
				<tr>
					<td><label for="currentUsers">User:</label></td>
					<td>#drawConsultantSelect(maskList, blackList, frmUserId, "frmUserId")#</td>
				</tr>
			
			</table>
			
			<br/>
			
			<input type="submit" name="frmAction" value="Select" />
			<input type="submit" name="frmAction" value="Reset">
			
		</form>
		
	</fieldset>

	<cfif frmAction EQ "Select">
	
		#displayUserSpecial(frmUserId)#
	
		<!--- check for inputs from the new form first --->
		<!--- data still exists from the old system, so check that if there aren't any new submissions --->
		<cfif getEvaluationAnswers.recordCount NEQ 0>
		
			<h2>Response Summary</h2>
		
			<table class="stripe">
						
				<tr class="titlerow">
					<th>Question</th>
					<th>Yes</th>
					<th>No</th>
					<th>N/A</th>
				</tr>
				
				<cfloop query="getEvaluationQuestions">
					<cfif type_text EQ 'multiple choice'>
						<cfset formItemId = form_item_id>
						<tr>
							<td>#item_text#</td>
							<cfset yes = 0>
							<cfset no = 0>
							<cfset na = 0>
							<cfloop query="getEvaluationAnswers">
								<cfif form_item_id EQ formItemId>
									<cfif option_text EQ "Yes">
										<cfset yes = yes + 1>
									<cfelseif option_text EQ "No">
										<cfset no = no + 1>
									<cfelseif option_text EQ "N/A">
										<cfset na = na + 1>
									</cfif>
								</cfif>
							</cfloop>
							<td>#yes#</td>
							<td>#no#</td>
							<td>#na#</td>
						</tr>
					</cfif>
				</cfloop>
				
			</table>
			
			<h2 style="margin-bottom:0em;">Individual Responses</h2>	
			
			<span class="names"><a id="hideNames" href="##" onclick="return false;">Hide Usernames</a></span>
			<span class="hidden" style="display:none;"><a id="showNames" href="##" onclick="return false;">Show Usernames</a></span>
			
			<table class="stripe">
				<tr class="titlerow">
					<th class="names">By</th>
					<th>Additional Comments</th>
				</tr>
				<cfloop query="getEvaluationQuestions">
					<cfif type_text EQ 'large text field'>
						<cfset formItemId = form_item_id>
						<cfloop query="getEvaluationAnswers">
							<cfif form_item_id EQ formItemId>
								<tr>
									<td class="names">#username#</td>
									<td>#user_text#</td>
								</tr>
							</cfif>
						</cfloop>
					</cfif>
				</cfloop>
			</table>
			
		<cfelseif getEvaluations.recordCount NEQ 0>
			
			<h2>Response Summary</h2>
	
			<table class='stripe'>
				
				<tr class='titlerow'>
					<th>Question</th>
					<cfloop query='getFixedAnswers'>
						<td>#option_name#</td>
					</cfloop>
				</tr>
				
				<cfloop query='getSummaryQuestions'>
					<tr>
						<td>#question#</td>
						#summarizeResponses(question_id)#
					</tr>
				</cfloop>
				
			</table>

			
			<h2 style="margin-bottom:0em;">Individual Responses</h2>
				
			<span class="names"><a id="hideNames" href="##" onclick="return false;">Hide Usernames</a></span>
			<span class="hidden" style="display:none;"><a id="showNames" href="##" onclick="return false;">Show Usernames</a></span>
			
			<table class='stripe'>
				
				<tr class='titlerow'>
					<th class="names">By</th>
					<th>Additional Comments</th>
				</tr>
				
				<cfloop query='getEvaluations'>
					<tr>
						<td class="names">#username#</td>
						<cfif trim(response) NEQ "">
							<td>#response#</td>
						<cfelse>
							<td>N/A</td>
						</cfif>
					</tr>
				</cfloop>
				
			</table>
		
		<cfelse>
		
			<h2>Response Summary</h2>
			<p><em>None found.</em></p>
				
			<h2 style="margin-bottom:0em;">Individual Responses</h2>	
			<p><em>None found.</em></p>
		
		</cfif>
		
	</cfif>

</cfoutput>

<!--- JQUERY --->
<!--- these two functions allow the user to hide / show the username column of this table --->
<!--- this makes for easier copy-pasting when it comes to compiling the information --->
<cfoutput>
	
	<script type="text/javascript">
		
		$(document).ready(function() {
			
			var fading = false;
			
			$(document).on('click', '##hideNames', (function() {
				if(!fading) {
					fading = true;
					$('.names').fadeOut('slow', function() {
						$('.hidden').fadeIn('slow', function() {
							fading = false;
						});
					});
				}
			}));
			
			$(document).on('click', '##showNames', (function() {
				if(!fading) {
					fading = true;
					$('.hidden').fadeOut('slow', function() {
						$('.names').fadeIn('slow', function() {
							fading = false;
						});
					});
				}
			}));
			
		});
		
	</script>
	
</cfoutput>

<!--- CFFUNCTIONS --->
<cffunction name='summarizeResponses'>
	<cfargument name='questionId'>
	<cfloop query='getFixedAnswers'>
		
		<cfquery name='getQuestionResponses' datasource="#application.applicationDataSource#">
			SELECT count(qo.option_name) as option_total
			FROM tbl_evaluation_responses r
			JOIN tbl_evaluation_questions q ON q.question_id = r.question_id
			JOIN tbl_evaluation_question_options qo ON r.response = qo.option_name
			WHERE r.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
			      AND r.semester_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmSemesterId#">
			      AND q.question_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#questionId#">
			      AND qo.option_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#option_name#">
			      AND r.member_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">
		</cfquery>

		<cfoutput query='getQuestionResponses'>
			<td style='text-align:center;'>
				#option_total#
			</td>
		</cfoutput>
		
	</cfloop>
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>