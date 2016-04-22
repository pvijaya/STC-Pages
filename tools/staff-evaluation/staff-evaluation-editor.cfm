<cfmodule template="#application.appPath#/header.cfm" title='Staff Evaluation Options Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="questionText" type="string" default="">
<cfparam name="questionType" type="integer" default="0">
<cfparam name="questionId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">

<cfset myInstance = getInstanceById(session.primary_instance)>

<!--- HEADER / NAVIGATION --->
<h1>Staff Evaluation Options Editor </h1> 
<a href='staff-evaluation-report.cfm'>Staff Evaluations Report</a> |
<a href='staff-evaluation.cfm'>Staff Evaluation Form</a>

<!---Logic--->
<cfif frmAction EQ 'Create'>
	<cftry>
		<cfquery datasource="#application.applicationdatasource#" name='insertHeaderCat'>
			INSERT INTO tbl_evaluation_questions(question, instance_id, type_id)
			VALUES(<cfqueryparam cfsqltype="cf_sql_varchar" value="#questiontext#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#questionType#">)
		</cfquery>
		
		<p class="ok">Question created successfully.</p>
		
		<cfcatch>
			<cfoutput>
				<p class="warning">
					#cfcatch.message# - #cfcatch.Detail#
				</p>
			</cfoutput>
		</cfcatch>
	</cftry>

<cfelseif frmAction EQ 'Delete'>
	<cftry>
		
		<cfquery datasource="#application.applicationdatasource#" name='insertHeaderCat'>
			UPDATE tbl_evaluation_questions
			SET active = 0
			WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			AND question_id =  <cfqueryparam cfsqltype="cf_sql_integer" value="#questionId#">
		</cfquery>
		
		<p class="ok">
			Question removed successfully.
		</p>
		
		<cfcatch>
			<cfoutput>
				<p class="warning">
					#cfcatch.message# - #cfcatch.Detail#
				</p>
			</cfoutput>
		</cfcatch>
	</cftry>
</cfif>


<!---Queries--->
<cfquery name='getQuestionTypes' datasource="#application.applicationdatasource#" >
	SELECT *
	FROM tbl_evaluation_question_types
</cfquery>

<h2>Select an Action</h2>

<cfoutput>		
	<fieldset style="margin-top:2em;">
		<legend>Create a Question</legend>
		
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
			
			<table>
				<tr>
					<td><label for='questionType1Id'>Question Type:</label></td>
					
					<td><select id='questionType1Id'  name='questionType'>
							<cfloop query='getQuestionTypes'>
								<option value='#type_id#'>#type_name#</option>
							</cfloop>
					    </select></td>
				</tr>
				<tr>
					<td><label for='questionText1'>Question Text:</label></td>
					<td><textarea id='questionText1' class="special" style='max-width:90%;' type="text" 
							  name="questionText">#questionText#</textarea></td>
				</tr>	
			</table>
			
			<br/>
			
			<input  type="submit" name="frmAction" value="Create"/> 
		
		</form>
		
	</fieldset>
	
	<fieldset style="margin-top:2em;">
		<legend>Delete a Question</legend>
		
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
			
			<cfquery name='getQuestions' datasource="#application.applicationdatasource#" >
				SELECT *
				FROM tbl_evaluation_questions
				WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.primary_instance#">
				AND active = 1
			</cfquery>

			<table>
			
			<cfloop query='getQuestions'>
				<tr>
					<td><input type="radio" name="questionId" value='#question_id#' id="#question_id#"/></td>
					<td><label for="#question_id#">#question#</label></td>
				</tr>
			</cfloop>
			
			</table>
			
			<br/>
			
			<input type="submit" name="frmAction" value="Delete" /> 
			
		</form>
		
	</fieldset>
	
</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>