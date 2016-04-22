<cfmodule template="#application.appPath#/header.cfm" title='View Form Submission' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<!--- cfparams --->
<cfparam name="submissionId" type="integer" default="0">
<cfparam name="formId" type="integer" default="0">
<cfparam name="userFor" type="integer" default="0">
<cfparam name="userBy" type="integer" default="0">
<cfparam name="labId" type="integer" default="0">
<cfparam name="instanceId" type="integer" default="0">
<cfparam name="checks" type="string" default=""> <!--- user form is submitted by --->
<cfparam name="formUserId" type="integer" default="0">
<!--- attribute paramaters --->
<cfparam name="formAttributes" type="string" default="">
<cfparam name="isAllLabs" type="boolean" default="0">
<cfparam name="isScored" type="boolean" default="0">
<cfparam name="isTrainingChecklist" type="boolean" default="0">
<cfparam name="isTrainingQuiz" type="boolean" default="0">
<cfparam name="isNumbered" type="boolean" default="0">

<!--- if provided this is where the user should be taken upon clicking 'Go Back' or getting a dropped ID.--->
<!--- this is necessary because we could be accessing our forms from several different places --->
<cfparam name="referrer" type="string" default="">

<!--- If you reload the page by resubmitting the URL, it tends to drops the formID --->
<cfif submissionId EQ 0>
	<p class="warning">
		Invalid ID - The given submission ID is invalid.
		<cfif trim(referrer) neq "">Please <a href="#referrer#">go back</a> and try again.</cfif>
	</p>
	<cfabort>
</cfif>

<!--- retrieve appropriate submission information --->
<cfquery datasource="#application.applicationDataSource#" name="getFormSubmission">
	SELECT a.user_id, a.form_id, a.user_id, a.submitted_by, a.submission_date,
		   a.score, a.lab_id, a.instance_id
	FROM tbl_forms_submissions a
	WHERE a.submission_id = <cfqueryparam cfsqltype="cf_sql_int" value="#submissionId#">
</cfquery>

<cfset formId = "#getFormSubmission.form_id#">
<cfset userFor = "#getFormSubmission.user_id#">
<cfset userBy = "#getFormSubmission.submitted_by#">
<cfset labid = "#getFormSubmission.lab_id#">
<cfset instanceId = "#getFormSubmission.instance_id#">

<cfquery datasource="#application.applicationDataSource#" name="getUserFor">
	SELECT a.username
	FROM tbl_users a
	WHERE a.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#userFor#">
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getUserBy">
	SELECT a.username
	FROM tbl_users a
	WHERE a.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#userBy#">
</cfquery>

<!--- based on the formId, grab our form, items, and attributes --->
<cfquery datasource="#application.applicationDataSource#" name="getForm">
	SELECT a.form_name, a.form_description
	FROM tbl_forms a
	WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getFormAttributes">
	SELECT a.attribute_id, b.attribute_name, b.attribute_details, b.attribute_text
	FROM tbl_forms_attributes a
	INNER JOIN tbl_attributes b ON b.attribute_id = a.attribute_id
	WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
	      AND b.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
	ORDER BY a.attribute_id ASC
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getItems">
	SELECT fi.form_item_id, fi.item_text, fit.type_text, fi.item_answer, fi.parent_id, fi.parent_answer
	FROM tbl_forms_items fi
	INNER JOIN tbl_forms_items_types fit On fit.type_id = fi.item_type
	WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
	      AND fi.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
	ORDER BY fi.sort_order
</cfquery>

<cfset getLab = getLabsById("i#instanceId#l#labId#")>

<!--- fetch all existing attributes for this form --->
<cfif formAttributes EQ "">

	<cfloop query="getFormAttributes">
		<cfset formAttributes = listappend(formAttributes, #attribute_id#)>
	</cfloop>
	<!--- set up params for each attribute for easier reading --->
	<cfset isAllLabs = hasAttribute("All Labs", formAttributes)>
	<cfset isScored = hasAttribute("Scored", formAttributes)>
	<cfset isTrainingChecklist = hasAttribute("Training - Checklist", formAttributes)>
	<cfset isTrainingQuiz = hasAttribute("Training - Quiz", formAttributes)>
	<cfset isNumbered = hasAttribute("Numbered", formAttributes)>

</cfif>

<!--- form viewing permissions --->
<!--- consultants may view only their own forms --->
<cfif hasMasks('Consultant', Session.cas_uid) AND NOT hasMasks('CS', Session.cas_uid)>
	<cfif userBy GT 0 AND userBy NEQ Session.cas_uid>
		<p class="warning">
			<cfoutput>Error - You do not have the necessary permissions to view this page.</cfoutput>
		</p>
		<cfabort>
	</cfif>
</cfif>

<!--- cs may view consultant forms, but no cs forms other than their own --->
<cfif hasMasks('CS', Session.cas_uid) AND NOT hasMasks('Admin', Session.cas_uid)>
	<cfif userBy GT 0 AND userBy NEQ Session.cas_uid>
		<cfif hasMasks('CS', userBy)>
			<p class="warning">
				<cfoutput>Error - You do not have the necessary permissions to view this page.</cfoutput>
			</p>
			<cfabort>
		</cfif>
	</cfif>
</cfif>

<!--- heading / navigation --->
<cfoutput>
	<h1>View Form Submission</h1>
	<cfif trim(referrer) neq "">[<a href="#referrer#">Go Back</a>]</cfif>
	<h2>#getForm.form_name#</h2>
	<cfif isTrainingQuiz>
		<p>#getFormSubmission.score# correct out of #maxScoreQuiz(formId)#</p>
	</cfif>
	<p class="tinytext">
		Submitted
		<cfif getLab.recordCount GT 0>
			for #getLab.lab_name#
		<cfelseif userFor GT 0>
			for #getUserFor.username#
		</cfif> by #getUserBy.username# on #dateFormat(getFormSubmission.submission_date, "MMM d, yyyy")# at #timeFormat(getFormSubmission.submission_date, "h:mm tt")#.</p>
</cfoutput>

<!--- draw form --->

<cfset drawItems()>

<cffunction name="drawItems">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="parentAnswer" type="numeric" default="0">
	<cfargument name="fieldset" type="boolean" default="0">
	<cfargument name="header" type="boolean" default="0">
	<cfargument name="first" type="boolean" default="1">
	<cfargument name="recursive" type="boolean" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getAllItems">
		SELECT a.form_item_id, a.item_text, a.item_type, a.item_answer, a.parent_id, a.parent_answer
		FROM tbl_forms_items a
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
		      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
		      AND a.parent_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentId#">
		      AND a.parent_answer = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentAnswer#">
		ORDER BY a.sort_order
	</cfquery>

	<cfloop query="getAllItems">

		<cfquery datasource="#application.applicationDataSource#" name="getAnswer">
			SELECT TOP 1 fut.user_answer, fut.user_text, fut.row_id, fut.col_id
			FROM tbl_forms_users_items fut
			WHERE fut.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
			      AND fut.submission_id <= <cfqueryparam cfsqltype="cf_sql_int" value="#submissionId#">
			ORDER BY fut.submission_id DESC
		</cfquery>

		<cfset item_type_text = getItemType(item_type)>

		<cfif item_type_text EQ "Header"
			  OR item_type_text EQ "Legend">

			<cfif fieldset AND NOT header>
				<cfif isNumbered></ol><cfset numbered = 0></cfif>
				</fieldset>
				<cfset fieldset = 0>
			</cfif>

			<cfif item_type_text EQ "Legend">
				<cfif not header>
					<br/>
				</cfif>
				<fieldset>
				<cfset fieldset = 1>
				<cfset first = 1>
				<legend><cfoutput>#item_text#</cfoutput></legend>
				<cfif isNumbered><ol><cfset numbered = 1></cfif>
			</cfif>

			<cfset header = 1>

		<cfelseif isInputType(item_type)>

			<cfif NOT fieldset>
				<fieldset>
				<cfset fieldset = 1>
				<cfif isNumbered><ol><cfset numbered = 1></cfif>
				<cfset first = 1>
			</cfif>
			<cfset header = 0>

		</cfif>

		<cfset drawItem(parentId, parent_answer, form_item_id, item_type, item_type_text,
			item_text, item_answer, fieldset, header, first, getAnswer)>

		<cfif first AND item_type_text NEQ "Header"
			  AND item_type_text NEQ "Legend">
			<cfset first = 0>
		</cfif>

	</cfloop>

	<cfif fieldset AND NOT recursive>
		<cfif isNumbered></ol></cfif>
		</fieldset>
	</cfif>

</cffunction>

<cffunction name="drawItem">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="parentValue" type="numeric" default="0">
	<cfargument name="form_item_id" type="numeric" default="0">
	<cfargument name="item_type" type="numeric" default="0">
	<cfargument name="item_type_text" type="string" default="">
	<cfargument name="item_text" type="string" default="">
	<cfargument name="item_answer" type="numeric" default="0">
	<cfargument name="fieldset" type="boolean" default="0">
	<cfargument name="header" type="boolean" default="0">
	<cfargument name="first" type="boolean" default="1">
	<cfargument name="getAnswer" type="query" required="yes">

	<cfoutput>

		<div class="formItem" formItemId="#form_item_id#"
			 parentId="#parentId#" parentValue="#parentValue#">

			<cfset inputType = isInputType(item_type)>

			<cfif NOT first AND inputType><br/></cfif>
			<cfif isNumbered AND inputType><li></cfif>

			<!--- based on type, draw the correct input (make params if necessary) --->
			<!--- header --->
			<cfif item_type_text EQ "Header">

				<h3>#item_text#</h3>

			<cfelseif item_type_text EQ "Paragraph">

				#item_text#

			<!--- checkbox --->
			<cfelseif item_type_text EQ "Checkbox">

				<cfif isTrainingChecklist>
					<cfquery datasource="#application.applicationDataSource#" name="getCheckInfo">
						SELECT TOP 1 fs.submission_date, u.username
						FROM tbl_forms_users_items fut
						INNER JOIN tbl_forms_submissions fs ON fs.submission_id = fut.submission_id
						INNER JOIN tbl_users u ON u.user_id = fs.submitted_by
						WHERE fut.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
							  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#userFor#">
			     			  AND fs.submission_id <= <cfqueryparam cfsqltype="cf_sql_int" value="#submissionId#">
			     		ORDER BY fs.submission_id DESC
					</cfquery>
				</cfif>

				<label>
					<input type="checkbox" name="checks" value="#form_item_id#"
							<cfif getAnswer.recordCount GT 0 AND getAnswer.user_answer EQ 1>checked="true"</cfif>
							readonly="true" disabled="true" >
							#item_text# <cfif isTrainingChecklist>
											<cfif getCheckInfo.recordCount GT 0 AND getAnswer.user_answer EQ 1>
												<span class="tinytext">(#getCheckInfo.username# - #dateFormat(getCheckInfo.submission_date, "MMM d, yyyy")# #timeFormat(getCheckInfo.submission_date, "h:mm tt")#)</span>
											</cfif>
										</cfif>
				</label>

				<br/>

			<!--- multiple choice (first task is to fetch the options) --->
			<cfelseif item_type_text EQ "Multiple Choice">

				<cfquery datasource="#application.applicationDataSource#" name="getOptions">
					SELECT a.form_item_option_id, a.option_text, a.retired
					FROM tbl_forms_items_options a
					WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
					      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
					ORDER BY a.option_order ASC, a.form_item_option_id ASC
				</cfquery>

				#item_text#
				<br/>
				<cfloop query="getOptions">
					<label>
						<span <cfif isTrainingQuiz AND getAnswer.user_answer EQ form_item_option_id>
						     	  <cfif item_answer EQ form_item_option_id>
							   	   	   style="color:green;"
						     	  <cfelse>
								   	   style="color:red;"
								  </cfif>
							 </cfif>>
							<input type="radio" name="radio#form_item_id#" value="#form_item_option_id#"
								   <cfif getAnswer.user_answer EQ form_item_option_id>
								   	   checked="true"
									</cfif>
								   readonly="true" disabled="true" >#option_text#
						</span>
					</label>

					<br/>
				</cfloop>

				<!--- recur over children --->
				<!--- if new items have been added to the form the answer query might be empty --->
				<!--- no answer means no children for this submission --->
				<cfif getAnswer.recordCount GT 0>
					<cfif isNumbered><ol></cfif>
					<cfset drawItems(form_item_id, getAnswer.user_answer, fieldset, header, 0, 1)>
					<cfif isNumbered></ol></cfif>
				</cfif>

			<cfelseif item_type_text EQ "Multiple Check">

				<cfquery datasource="#application.applicationDataSource#" name="getOptions">
					SELECT a.form_item_option_id, a.option_text, a.retired
					FROM tbl_forms_items_options a
					WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
					      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
					ORDER BY a.option_order ASC, a.form_item_option_id ASC
				</cfquery>

				<cfquery datasource="#application.applicationDataSource#" name="getAnswers">
					SELECT fia.item_answer
					FROM tbl_forms_items_answers fia
					WHERE fia.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
				</cfquery>

				<cfquery datasource="#application.applicationDataSource#" name="getUserAnswers">
					SELECT fui.user_answer
					FROM tbl_forms_users_items fui
					WHERE fui.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
						  AND fui.submission_id = <cfqueryparam cfsqltype="cf_sql_int" value="#submissionId#">
				</cfquery>

				<cfset answers = "">
				<cfloop query="getAnswers">
					<!--- scoped to query, not variable --->
					<cfset answers = listAppend(answers, getAnswers.item_answer)>
				</cfloop>

				<cfset userAnswers = "">
				<cfloop query="getUserAnswers">
					<cfset userAnswers = listAppend(userAnswers, user_answer)>
				</cfloop>

				#item_text#
				<cfif len(userAnswers) LT len(answers)> (<span style="color:red;">incomplete answer</span>)</cfif>
				<br/>

				<cfloop query="getOptions">
					<label>
						<span
							<cfif isTrainingQuiz AND listFindNoCase(userAnswers, form_item_option_id)>
						     	  <cfif listFindNoCase(answers, form_item_option_id)>
							   	   	   style="color:green;"
						     	  <cfelse>
								   	   style="color:red;"
								  </cfif>
							 </cfif>>
							<input type="checkbox" name="multi#form_item_id#" value="#form_item_option_id#"
								   <cfif listFindNoCase(userAnswers, form_item_option_id)>
								   	   checked="true"
									</cfif>
								   readonly="true" disabled="true" >#option_text#
						</span>
					</label>

					<br/>
				</cfloop>

			<!--- text field --->
			<cfelseif item_type_text EQ "Small Text Field">

				<label for="text#form_item_id#"><cfoutput>#item_text#</cfoutput></label>
				<input id="text#form_item_id#" type="text" name="text#form_item_id#" value="#getAnswer.user_text#"
				       readonly="true" disabled="true" >

			<cfelseif item_type_text EQ "Large Text Field">

				<label><cfoutput>#item_text#</cfoutput>
					<textarea name="text#form_item_id#" readonly="true" disabled="true">
						<cfoutput>#htmlEditFormat(getAnswer.user_text)#</cfoutput>
					</textarea>
				</label>

				<!--- replace the default textarea above with a prettier one --->
				<cfoutput>
					<script type="text/javascript">
						//a custom configuration for this ckeditor textarea
						var contactNote = CKEDITOR.replace('text#form_item_id#',{
							toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
							toolbar:  'Basic',
							height: '200px',
							width: '500px',
							removePlugins: 'contextmenu,tabletools', /*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
						});
					</script>
				</cfoutput>

			<cfelseif item_type_text EQ "Table">

				<cfset getRows = getTableCells(form_item_id, 1, 0)>
				<cfset getCols = getTableCells(form_item_id, 0, 0)>

				<cfoutput>

					<cfquery datasource="#application.applicationDataSource#" name="getTableAnswer">
						SELECT fut.user_answer, fut.user_text, fut.row_id, fut.col_id
						FROM tbl_forms_users_items fut
						WHERE fut.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
						      AND fut.submission_id = <cfqueryparam cfsqltype="cf_sql_int" value="#submissionId#">
						ORDER BY fut.submission_id DESC
					</cfquery>

					<table class="stripe" style="padding:0px;">
						<tr class="titlerow" style="padding:5px;">
							<td></td>
							<cfloop query="getCols">
								<td>#cell_text#</td>
							</cfloop>
						</tr>
						<cfloop query="getRows">
							<tr><td>#cell_text#</td>
								<cfset rowi = #getRows.form_table_cell_id#>
								<cfloop query="getCols">
									<cfset coli = #getCols.form_table_cell_id#>

									<cfloop query="getTableAnswer">
										<cfif row_id EQ rowi AND col_id EQ coli>
											<td><label>
													<input type="text" name="table#form_item_id#c#coli#r#rowi#" value="#user_answer#" size="10"
														   readonly="true" disabled="true">
												</label>
											</td>
										</cfif>
									</cfloop>

								</cfloop>
							</tr>
						</cfloop>
					</table>
				</cfoutput>

			</cfif>

			<cfif isNumbered and isInputType(item_type)></li></cfif>

		</div>

	</cfoutput>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>