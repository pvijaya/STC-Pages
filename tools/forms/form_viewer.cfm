<cfmodule template="#application.appPath#/header.cfm" title='View Form' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<!--- cfparams --->
<cfparam name="formId" type="integer" default="0">
<cfparam name="formUserId" type="integer" default="0"> <!--- user form is submitted for --->
<cfparam name="formAttributes" type="string" default="">
<cfparam name="radioAnswers" type="string" default="">
<cfparam name="multiAnswers" type="string" default="">
<cfparam name="checkCount" type="integer" default="0">
<cfparam name="status" type="integer" default="0">
<cfparam name="submitted" type="boolean" default="0">
<cfparam name="frmLabId" type="string"
         default="<cfoutput>i#session.primary_instance#l#ipToLabId(cgi.remote_addr)#</cfoutput>">
<cfparam name="semesterId" type="integer" default="0">
<cfparam name="workstationId" type="integer" default="#ipToWorkstation(cgi.remote_addr)#">
<!--- checkbox parameters --->
<cfparam name="oldChecks" type="string" default="">
<cfparam name="newchecks" type="string" default="">
<!--- form submission parameters --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmChecks" type="string" default="">
<!--- attribute parameters --->
<cfparam name="isAllLabs" type="boolean" default="0">
<cfparam name="isAllStaff" type="boolean" default="0">
<cfparam name="isAllSemesters" type="boolean" default="0">
<cfparam name="isScored" type="boolean" default="0">
<cfparam name="isTrainingChecklist" type="boolean" default="0">
<cfparam name="isTrainingQuiz" type="boolean" default="0">
<cfparam name="isNumbered" type="boolean" default="0">
<cfparam name="isSaveProgess" type="boolean" default="0">
<cfparam name="isSubmitForAnyone" type="boolean" default="0">

<!--- if provided this is where the user should be taken upon clicking 'Go Back' or getting a dropped ID.--->
<!--- this is necessary because we could be accessing our forms from several different places --->
<cfparam name="referrer" type="string" default="">

<cfif semesterId GT 0>
	<cfset semesterObj = getSemesterById(session.primary_instance, semesterId)>
</cfif>

<!--- If you reload the page by resubmitting the URL, it sometimes drops the formID --->
<cfif formId EQ 0>
	<p class="warning">
		Invalid ID - The given form ID is invalid.
		<cfif trim(referrer) neq "">Please <a href="#referrer#">go back</a> and try again.</cfif>
	</p>
	<cfabort>
</cfif>

<!--- queries --->

<cfset submitMasks = "">
<cfset viewMasks = "">

<!--- first things first, check the masks for this form --->
<cfquery datasource="#application.applicationDataSource#" name="getMasks">
	SELECT a.mask_id, a.edit
	FROM tbl_forms_masks a
	WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
</cfquery>

<cfloop query="getMasks">
	<cfif edit>
		<cfset submitMasks = listAppend(submitMasks, #mask_id#)>
	<cfelse>
		<cfset viewMasks = listAppend(viewMasks, #mask_id#)>
	</cfif>
</cfloop>

<!--- if they don't have the masks to view this form, kick 'em out --->
<cfif NOT hasMasks(viewMasks)>
	<p class="warning">
		<cfoutput>Permission - You do not have the masks necessary to view this page.</cfoutput>
	</p>
	<cfabort>
</cfif>

<!--- fetch all existing attributes for this form --->
<cfif formAttributes EQ "">
	<cfquery datasource="#application.applicationDataSource#" name="getFormAttributes">
		SELECT a.attribute_id, b.attribute_name, b.attribute_details, b.attribute_text
		FROM tbl_forms_attributes a
		INNER JOIN tbl_attributes b ON b.attribute_id = a.attribute_id
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		      AND b.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
		ORDER BY a.attribute_id ASC
	</cfquery>
	<cfloop query="getFormAttributes">
		<cfset formAttributes = listappend(formAttributes, #attribute_id#)>
	</cfloop>
	<!--- set up params for each attribute for easier reading --->
	<cfset isAllLabs = hasAttribute("All Labs", formAttributes)>
	<cfset isAllStaff = hasAttribute("All Staff", formAttributes)>
	<cfset isAllSemesters = hasAttribute("All Semesters", formAttributes)>
	<cfset isScored = hasAttribute("Scored", formAttributes)>
	<cfset isTrainingchecklist = hasAttribute("Training - Checklist", formAttributes)>
	<cfset isTrainingQuiz = hasAttribute("Training - Quiz", formAttributes)>
	<cfset isNumbered = hasAttribute("Numbered", formAttributes)>
	<cfset isSaveProgress = hasAttribute("Save Progress", formAttributes)>
	<cfset isSubmitForAnyone = hasAttribute("Submit for Anyone", formAttributes)>
</cfif>

<!--- form viewing permissions --->
<cfif NOT isSubmitForAnyone>

	<!--- consultants may view only their own forms --->
	<cfif hasMasks('Consultant', Session.cas_uid) AND NOT hasMasks('CS', Session.cas_uid)>
		<cfif formUserId GT 0 AND formUserId NEQ Session.cas_uid>
			<p class="warning">
				<cfoutput>Error - You do not have the necessary permissions to view this form for the selected user that is a CS.</cfoutput>
			</p>
			<cfabort>
		</cfif>
	</cfif>

	<!--- cs may view consultant forms, but no cs forms other than their own --->
	<cfif hasMasks('CS', Session.cas_uid) AND NOT hasMasks('Admin', Session.cas_uid)>
		<cfif formUserId GT 0 AND formUserId NEQ Session.cas_uid>
			<cfif hasMasks('CS', formUserId)>
				<p class="warning">
					<cfoutput>Error - You do not have the necessary permissions to view this form for a user that is an Admin.</cfoutput>
				</p>
				<cfabort>
			</cfif>
		</cfif>
	</cfif>

</cfif>

<!--- there is a problem where CS come to submit a checklist or quiz for a consultant, but don't come prepared with a formUserId.  Make them select one.--->
<cfif (isTrainingchecklist OR isTrainingQuiz) AND formUserId eq 0>
	<!---for non-CS users just use the user_id for their session.--->
	<cfif not hasMasks('CS', Session.cas_uid)>
		<cfset formUserId = session.cas_uid>
	<cfelse>
		<h2>Select User</h2>
		<p>
			This form is submitted about a particular user, who are you submitting this form about?
		</p>
		<!---draw a form to select the user the form is for.--->
		<form method="get" class="form-horizontal" action="<cfoutput>#cgi.script_name#</cfoutput>">
			<!---make hidden fields for all existing values.--->
			<cfloop collection="#url#" item="key">
				<cfset bootstrapHiddenField(key, url[key])>
			</cfloop>

			<!--- we need the user's current instance to know which set of users to list.--->
			<cfquery datasource="#application.applicationDataSource#" name="getInstance">
				SELECT i.instance_mask
				FROM tbl_instances i
				WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			</cfquery>

			<cfset maskList  = "Consultant" >

			<!--- add our current instances to the required masks. --->
			<cfloop query="getInstance">
				<cfset maskList = ListAppend(maskList, instance_mask)>
			</cfloop>

			<cfset drawConsultantSelector(maskList, 'Logistics', formUserId, 0, "formUserId")>
			<cfset bootstrapSubmitField("userSubmit", "Go")>
		</form>

		<!--we need a formUserId before we continue, so abort.--->
		<cfmodule template="#application.appPath#/footer.cfm">
		<cfabort>
	</cfif>
</cfif>


<!--- based on the formId, grab our form, items, and attributes --->
<cfquery datasource="#application.applicationDataSource#" name="getForm">
	SELECT a.form_name, a.form_description
	FROM tbl_forms a
	WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getFormItems">
	SELECT a.form_item_id, a.item_text, a.item_type, a.item_answer, b.form_item_id, b.option_text
	FROM tbl_forms_items a
	LEFT OUTER JOIN tbl_forms_items_options b on b.form_item_id = a.form_item_id
	WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
	      AND a.retired = 0
	ORDER BY a.sort_order, a.form_item_id, b.form_item_option_id
</cfquery>

<!--- this gets us the username associated with this form, if one exists --->
<cfquery datasource="#application.applicationDataSource#" name="getFormUser">
	SELECT a.username
	FROM tbl_users a
	WHERE a.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formUserId#">
	AND a.user_id > 0
</cfquery>

<!--- heading and navigation --->
<cfoutput>
	<h1>#getForm.form_name#</h1>
	<cfif trim(referrer) neq ""><a href="#referrer#">Go Back</a></cfif>
</cfoutput>

<!--- form information --->
<cfif (isAllSemesters AND semesterId GT 0)OR formUserId GT 0>
	<p class="tinytext">
		<cfoutput>
			Submitting
			<cfif formUserId GT 0>
				for #getFormUser.username#.
			</cfif>
			<cfif isAllSemesters AND semesterId GT 0>
				(#semesterObj.semester_name# #dateFormat(semesterObj.start_date, 'yyyy')#)
			</cfif>
		</cfoutput>
	</p>
</cfif>

<!--- handle user input --->
<cfif frmAction EQ "save">

	<cftry>

		<cfif NOT hasMasks(submitMasks)>
			<cfthrow message="Permission" detail="You do not have permission to perform that action.">
		</cfif>

		<cfif NOT isSaveProgress>
			<cfthrow message="Invalid Action" detail="That action cannot be performed on this form.">
		</cfif>

		<!--- fetch the lab id value if this is an all-sites form --->
		<cfif isAllLabs>
			<cfset lab = parseLabName(frmLabId)>
			<cfset labId = lab['lab']>
			<cfset instanceId = lab['instance']>
		<cfelse>
			<cfset labId = 0>
			<cfset instanceId = session.primary_instance>
		</cfif>

		<!---make sure we've got a legit user--->
		<cfif isAllStaff AND formUserId lte 0>
			<cfthrow message="Missing Input" detail="You must select a user before submitting this form.">
		</cfif>

		<!--- delete previous saved values; we only want one set of inputs saved per form at a time --->
		<cfquery datasource="#application.applicationDataSource#" name="deleteSubmission">
			DELETE FROM tbl_forms_saved_submissions
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="deleteSubmission">
			DELETE FROM tbl_forms_saved_users_items
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
		</cfquery>

		<!--- add a submission record. --->
		<cfquery datasource="#application.applicationDataSource#" name="addSubmission">
			INSERT INTO tbl_forms_saved_submissions (form_id, user_id, lab_id, submitted_by, status, instance_id, semester_id)
			OUTPUT inserted.submission_id
			VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#status#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#semesterId#">)
		</cfquery>

		<!--- submit the items. --->
		<cfset submitItems(0, 0, addSubmission.submission_id)>
		<cfset submitted = 1>

		<p class="ok"> Form saved successfully. The inputs will be preserved until the next submission or save.</p>

		<cfif NOT isTrainingChecklist AND NOT isSaveProgress>
			<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
			<cfabort>
		</cfif>

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>

	</cftry>

<cfelseif frmAction EQ "recover">

	<cftry>

		<cfif NOT hasMasks(submitMasks)>
			<cfthrow message="Permission" detail="You do not have permission to perform that action.">
		</cfif>

		<cfif NOT isSaveProgress>
			<cfthrow message="Invalid Action" detail="That action cannot be performed on this form.">
		</cfif>

		<cfset recoverItems()>

		<p class="ok">Progress recovered.</p>

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
			<br/>
		</cfoutput>
	</cfcatch>

	</cftry>

<cfelseif frmAction EQ "Submit">

	<cftry>

		<cfif NOT hasMasks(submitMasks)>
			<cfthrow message="Permission" detail="You do not have permission to perform that action.">
		</cfif>

		<!--- ensure all questions are answered --->
		<cfset checkItems()>

		<!--- fetch the lab id value if this is an all-sites form --->
		<cfif isAllLabs>
			<cfset lab = parseLabName(frmLabId)>
			<cfset labId = lab['lab']>
			<cfset instanceId = lab['instance']>
		<cfelse>
			<cfset labId = 0>
			<cfset instanceId = session.primary_instance>
		</cfif>

		<!---make sure we've got a legit user--->
		<cfif isAllStaff AND formUserId lte 0>
			<cfthrow message="Missing Input" detail="You must select a user before submitting this form.">
		</cfif>

		<!--- if we're dealing with a lab based form, make sure they are submitting from that lab --->
		<cfif isAllLabs AND labId NEQ ipToLabId(cgi.remote_addr)>
			<cfthrow message="Invalid Location" detail="You can only submit this form for the lab you are currently in.">
		</cfif>

		<!--- delete previous saved values; we only want one set of inputs saved per form at a time --->
		<cfquery datasource="#application.applicationDataSource#" name="deleteSubmission">
			DELETE FROM tbl_forms_saved_submissions
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="deleteSubmission">
			DELETE FROM tbl_forms_saved_users_items
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
		</cfquery>

		<!--- if all inputs check out, add a submission record. --->
		<cfquery datasource="#application.applicationDataSource#" name="addSubmission">
			INSERT INTO tbl_forms_submissions (form_id, user_id, lab_id, submitted_by, status, instance_id, semester_id, workstation_id)
			OUTPUT inserted.submission_id
			VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#status#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#semesterId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#workstationId#">)
		</cfquery>

		<!--- submit the items. --->
		<cfset submitItems(0, 0, addSubmission.submission_id)>
		<cfset submitted = 1>

		<p class="ok"> Form submitted successfully. Your submission id is <cfoutput>#addSubmission.submission_id#</cfoutput>.</p>

		<cfif NOT isTrainingChecklist AND NOT isSaveProgress>
			<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
			<cfabort>
		</cfif>

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
			<br/>
		</cfoutput>
	</cfcatch>

	</cftry>

</cfif>

<!--- draw form --->
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

	<!--- if this form allows saved progress, and a saved submission exists, let the user know --->
	<cfif isSaveProgress>

		<cfquery datasource="#application.applicationDataSource#" name="getSavedSubmission">
			SELECT fss.submission_id, fss.submitted_by, fss.submission_date
			FROM tbl_forms_saved_submissions fss
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_integer" value=#formId#>
		</cfquery>

		<cfif getSavedSubmission.recordCount GT 0>
			<cfquery datasource="#application.applicationDataSource#" name="getUser">
				SELECT u.username
				FROM tbl_users u
				WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getSavedSubmission.submitted_by#">
			</cfquery>
			<p>
				<input type="submit" name="frmAction" value="Recover">
				<cfoutput>
					<span class="tinytext">Progress last saved by #getUser.username# on #dateTimeFormat(getSavedSubmission.submission_date, 'mmmm dd, yyyy at hh:nn tt')#
				</cfoutput>
			</p>
		</cfif>

	</cfif>

	<!--- get the past answers and submission information --->
	<cfquery datasource="#application.applicationDataSource#" name="getLastSubmissions">
		SELECT TOP 100 fs.comment, fs.submission_id, fs.submitted_by, fs.submission_date, fs.status,
		               u.username, fs.score
		FROM tbl_forms_submissions fs
		INNER JOIN tbl_users u ON u.user_id = fs.submitted_by
		WHERE fs.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
			  <cfif isSubmitForAnyone OR isTrainingQuiz> <!--- Submit for Anyone forms tend to be sensitive, so only show the user's own submissions --->
		      	AND fs.submitted_by = <cfqueryparam cfsqltype="cf_sql_int" value="#session.cas_uid#">
		      <cfelse> <!--- default behavior is that you can see all past submissions - this is fine for trainings and reports --->
		      	AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formUserId#">
			  </cfif>
		ORDER BY fs.submission_date DESC
	</cfquery>

	<!--- draw the lab selector if one is needed --->
	<cfif isAllLabs>
		<p><label>Select a Lab: <cfset drawLabsSelector("frmLabId", frmLabId)></label></p>
	</cfif>

	<!---draw the user selector if one is needed --->
	<cfif isAllStaff>
		<p><cfset drawConsultantSelector("consultant","",formUserId, 0, "formUserId")></p>
	</cfif>

	<cfset drawItems()>

	<!---now add some jQuery event handlers to show and hide child questions based on the answers provided to their parents.--->
	<script type="text/javascript">
		$(document).ready(function(){
			$(document).on("change", "input.formItem", function(evt){
				var myFormItem = $(this).attr("formItemId");
				var myVal = $(this).val();

				//we have the formItemId and curent answer, loop through all the divs that contain questions and hide the ones that have myFormItem for a parent and another answer for the required value
				$("div.formItem").each(function(n){
					var curParent = $(this).attr("parentid");
					var curParentVal = $(this).attr("parentValue");

					if(curParent == myFormItem){
						//hide divs that require another answer
						if(curParentVal != myVal){
							$(this).fadeOut('slow');
						}

						//show dives that require our user's answer.
						if(curParentVal == myVal){
							$(this).fadeIn('slow');
						}
					}
				});
			});
		});
	</script>

	<!--- only show the submit button if the user has edit masks --->
	<cfif hasMasks(submitMasks)>

		<p>
			<input type="submit" value="Submit" name="frmAction">
			<cfif isSaveProgress>
				<input type="submit" value="Save" name="frmAction">
			</cfif>
		</p>

		<br/>

	</cfif>

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT a.form_item_id
		FROM tbl_forms_items a
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		      AND a.retired = 0
	</cfquery>

	<!--- a collapsible table that shows all past submissions to this form --->
	<span class="trigger">Past Submissions</span>
	<div>
		<cfif getLastSubmissions.recordCount GT 0>
			<table class="stripe" style="padding:0px;" border="1px">
				<tr class="titlerow" style="padding:5px;">
					<th>Link</th>
					<th>Submitted By</th>
					<th>Date</th>
					<cfif isScored><th>Score</th></cfif>
				</tr>
				<cfloop query="getLastSubmissions">
					<cfoutput>
						<tr>
							<td><a href="#application.appPath#/tools/forms/form_view_submission.cfm?submissionId=#submission_id#">#submission_id#</a></td>
							<td>#username#</td>
							<td class="tinytext">#dateFormat(submission_date, "MMM d, yyyy")# #timeFormat(submission_date, "h:mm tt")#</td>
							<cfif isScored><td>#score# / #getItems.recordCount#</td></cfif>
						</tr>
					</cfoutput>
				</cfloop>
			</table>
		<cfelse>
			No submissions currently exist.
		</cfif>
	</div>

	<!--- keep track of all of our non-form variables --->
	<cfoutput>
		<input type="hidden" name="formId" value="#formId#">
		<input type="hidden" name="semesterId" value="#semesterId#">
		<input type="hidden" name="workstationId" value="#workstationId#">
		<input type="hidden" name="oldChecks" value="#oldChecks#">
		<input type="hidden" name="checkCount" value="#checkCount#">
		<input type="hidden" name="referrer" value="#referrer#">
		<input type="hidden" name="submitted" value="#submitted#">
		<input type="hidden" name="radioAnswers" value="#radioAnswers#">
		<input type="hidden" name="multiAnswers" value="#multiAnswers#">
		<!---don't duplicate formUserId if we have the All Staff attribute set.--->
		<cfif not isAllStaff>
			<input type="hidden" name="formUserId" value="#formUserId#">
		</cfif>

	</cfoutput>

</form>

<cffunction name="checkItems">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="parentValue" type="numeric" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT a.form_item_id, a.item_text, a.item_type, a.item_answer, b.form_item_id, b.option_text
		FROM tbl_forms_items a
		LEFT OUTER JOIN tbl_forms_items_options b on b.form_item_id = a.form_item_id
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
		      AND a.parent_id = <cfqueryparam cfsqltype="cf_sql_int" value="#parentId#">
		      AND a.parent_answer = <cfqueryparam cfsqltype="cf_sql_int" value="#parentValue#">
		ORDER BY a.sort_order, a.form_item_id, b.form_item_option_id
	</cfquery>

	<cfoutput query="getItems" group="form_item_id">
		<cfset checkItem(#item_type#, #form_item_id#)>
	</cfoutput>

</cffunction>

<cffunction name="checkItem">
	<cfargument name="item_type" type="numeric" default="0">
	<cfargument name="form_item_id" type="numeric" default="0">

	<cfset item_type_text = getItemType(item_type)>

	<cfif item_type_text EQ "Multiple Choice">
		<cfif not isDefined("radio#form_item_id#")>
			<cfthrow message="Missing Input (Multiple Choice)" detail="All fields are required.">
		</cfif>
		<cfset val = evaluate("radio#form_item_id#")>
		<cfif val EQ 0>
			<cfthrow message="Missing Input (Multiple Choice)" detail="All fields are required.">
		</cfif>
		<cfset checkItems(form_item_id, val)>

	<cfelseif item_type_text EQ "Multiple Check">
		<cfif not isDefined("multi#form_item_id#")>
			<cfthrow message="Missing Input (Multiple Choice)" detail="All fields are required.">
		</cfif>
		<cfset val = evaluate("multi#form_item_id#")>
		<cfif val EQ "">
			<cfthrow message="Missing Input (Multiple Choice)" detail="All fields are required.">
		</cfif>

	<cfelseif item_type_text EQ "Table">

		<!--- get table rows and cols --->
		<cfset getRows = getTableCells(form_item_id, 1, 0)>
		<cfset getCols = getTableCells(form_item_id, 0, 0)>

		<!--- run through the text inputs and ensure the user submitted each one --->
		<cfloop query="getRows">
			<cfset rowi = getRows.form_table_cell_id>
			<cfloop query="getCols">
				<cfset coli = getCols.form_table_cell_id>
				<cfif not isDefined("table#form_item_id#c#coli#r#rowi#")>
					<cfthrow message="Missing Input (Table)" detail="All fields are required.">
				</cfif>
				<cfset val = evaluate("table#form_item_id#c#coli#r#rowi#")>
				<cfif val EQ "">
					<cfthrow message="Missing Input (Table)" detail="All fields are required.">
				</cfif>
				<cfset numVal = val(val)>
			</cfloop>
		</cfloop>

	<cfelseif item_type_text EQ "Large Text Field"
			  OR item_type_text EQ "Small Text Field">
		<cfset val = evaluate("text#form_item_id#")>
		<cfif val EQ "">
			<cfthrow message="Missing Input (Text Box)" detail="All fields are required.">
		</cfif>
	</cfif>

</cffunction>

<cffunction name="recoverItems">

	<cfquery datasource="#application.applicationDataSource#" name="getSavedSubmission">
		SELECT fss.submission_id
		FROM tbl_forms_saved_submissions fss
		WHERE fss.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
	</cfquery>

	<cfquery datasource="#application.applicationDataSource#" name="getSavedItems">
		SELECT fsui.form_item_id, fi.item_type, fsui.user_answer, fsui.user_text,
			   fsui.row_id, fsui.col_id
		FROM tbl_forms_saved_users_items fsui
		INNER JOIN tbl_forms_items fi ON fi.form_item_id = fsui.form_item_id
		WHERE submission_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getSavedSubmission.submission_id#">
	</cfquery>

	<cfloop query="getSavedItems">
		<cfset recoverItem(#item_type#, #form_item_id#, #user_answer#, #col_id#, #row_id#)>
	</cfloop>

</cffunction>

<cffunction name="recoverItem">
	<cfargument name="item_type" type="numeric" default="0">
	<cfargument name="form_item_id" type="numeric" default="0">
	<cfargument name="user_answer" type="numeric" default="0">
	<cfargument name="col_id" type="numeric" default="0">
	<cfargument name="row_id" type="numeric" default="0">

	<cfset item_type_text = getItemType(item_type)>

	<cfif item_type_text EQ "Checkbox">

		<cfset "check#form_item_id#" = #user_answer#>

	<cfelseif item_type_text EQ "Multiple Choice">

		<cfset "radio#form_item_id#" = #user_answer#>

	<cfelseif item_type_text EQ "Multiple Check">

		<cfset val = evaluate("multi#form_item_id#")>
		<cfset "multi#form_item_id#" = val & "," & user_answer>	<!--- jury-rigged list append --->

	<cfelseif item_type_text EQ "Table">

		<cfset "table#form_item_id#c#col_id#r#row_id#" = #user_answer#>

	<cfelseif item_type_text EQ "Large Text Field"
			  OR item_type_text EQ "Small Text Field">

		<cfset "text#form_item_id#" = #user_text#>

	</cfif>

</cffunction>

<cffunction name="submitItems">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="parentValue" type="numeric" default="0">
	<cfargument name="submissionId" type="numeric" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT a.form_item_id, a.item_text, a.item_type, a.item_answer
		FROM tbl_forms_items a
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
		      AND a.parent_id = <cfqueryparam cfsqltype="cf_sql_int" value="#parentId#">
		      AND a.parent_answer = <cfqueryparam cfsqltype="cf_sql_int" value="#parentValue#">
		ORDER BY a.sort_order, a.form_item_id
	</cfquery>

	<cfif isSaveProgress AND frmAction EQ "save">

		<cfloop query="getItems">
			<cfset submitSavedItem(form_item_id)>
		</cfloop>

	<cfelse>

		<cfloop query="getItems">
			<cfset submitItem(form_item_id)>
		</cfloop>

		<cfif isTrainingQuiz>

			<cfset score = scoreQuiz(submissionId, formId, formUserId)>

			<cfquery datasource="#application.applicationDataSource#" name="updateScore">
				UPDATE tbl_forms_submissions
				SET score = <cfqueryparam cfsqltype="cf_sql_integer" value="#score#">
				WHERE submission_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#submissionId#">
			</cfquery>

		</cfif>

		<cfif isTrainingChecklist>

			<cfset status = 1>

			<cfloop query="getItems">

				<cfset item_type_text = getItemType(item_type)>
				<cfif item_type_text EQ "Checkbox">

					<cfquery datasource="#application.applicationDataSource#" name="getCheckInfo">
						SELECT TOP 1 fui.user_answer
						FROM tbl_forms_users_items fui
						WHERE fui.form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">
						ORDER BY fui.submission_id DESC
					</cfquery>

					<cfif getCheckInfo.user_answer EQ 0>
						<cfset status = 0>
					</cfif>

				</cfif>

				<cfquery datasource="#application.applicationDataSource#" name="updateScore">
					UPDATE tbl_forms_submissions
					SET status = <cfqueryparam cfsqltype="cf_sql_integer" value="#status#">
					WHERE submission_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#submissionId#">
				</cfquery>

			</cfloop>

		</cfif>
	</cfif>

</cffunction>

<!--- enters an item as part of an official submission --->
<cffunction name="submitItem">
	<cfargument name="form_item_id" type="numeric" default="0">

	<cfset item_type_text = getItemType(item_type)>

	<cfif isInputType(item_type)>

		<cfset insert = 1>

		<!--- insert checkbox  --->
		<cfif item_type_text EQ "Checkbox">

			<cfif NOT isDefined("check#form_item_id#")>
				<cfset val = 0>
			<cfelse>
				<cfset val = evaluate("check#form_item_id#")>
			</cfif>

			<!--- if we are dealing with a training checklist, we want to retain old values --->
			<!--- basically, only submit a new entry to the database if the value of an answer has changed --->
			<cfif isTrainingChecklist>

				<cfquery datasource="#application.applicationDataSource#" name="getCheck">
					SELECT a.user_answer
					FROM tbl_forms_users_items a
					INNER JOIN tbl_forms_submissions b ON b.submission_id = a.submission_id
					WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">
						  AND b.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">
					ORDER BY a.submission_id DESC
				</cfquery>

				<cfif getCheck.recordCount GT 0>

					<cfif getCheck.user_answer EQ val>
						<cfset insert = 0>
					</cfif>
				</cfif>
			</cfif>

		<cfelseif item_type_text EQ "Multiple Choice">
			<cfset val = evaluate("radio#form_item_id#")>
			<cfif not listFindNoCase(radioAnswers, form_item_id)>
				<cfset radioAnswers = listAppend(radioAnswers, form_item_id)>
			</cfif>
			<input type="hidden" name="radio#form_item_id#" value="#val#">

		<cfelseif item_type_text EQ "Multiple Check">

			<cfset valList = evaluate("multi#form_item_id#")>

			<cfset cnt = 1>
			<cfquery datasource="#application.applicationDataSource#" name="addMultiAnswers">
				INSERT INTO tbl_forms_users_items (submission_id, form_id, user_id, form_item_id, user_answer)
				VALUES
			        <cfloop list="#valList#" index="i">
			            (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#i#">)
			            /* ensure a comma gets inserted between each list */
			            <cfif cnt LT listLen(valList)>,</cfif>
			            <cfset cnt = cnt + 1>
			        </cfloop>
			</cfquery>

		<!--- insert text field --->
		<cfelseif item_type_text EQ "Large Text Field"
				  OR item_type_text EQ "Small Text Field">
			<cfset val = evaluate("text#form_item_id#")>

		<cfelseif item_type_text EQ "Table">

			<!--- get table rows and cols --->
			<cfset getRows = getTableCells(form_item_id, 1, 0)>
			<cfset getCols = getTableCells(form_item_id, 0, 0)>

			<!--- run through the text inputs and ensure the user submitted each one --->
			<cfloop query="getRows">
				<cfset rowi = getRows.form_table_cell_id>
				<cfloop query="getCols">
					<cfset coli = getCols.form_table_cell_id>

					<cfset val = evaluate("table#form_item_id#c#coli#r#rowi#")>
					<cfset numVal = val(val)>

					<cfquery datasource="#application.applicationDataSource#" name="addCellAnswer">
						INSERT INTO tbl_forms_users_items (submission_id, form_id, user_id, form_item_id, user_answer, row_id, col_id)
						OUTPUT inserted.form_user_item_id
						VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#numVal#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#rowi#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#coli#">
								)
					</cfquery>

				</cfloop>
			</cfloop>

		</cfif>

		<!--- now insert the user's answer into the table --->
		<!--- the insert query for text fields is different than other input types --->
		<cfif item_type_text EQ "Large Text Field" OR item_type_text EQ "Small Text Field">
			<cfquery datasource="#application.applicationDataSource#" name="addAnswer">
				INSERT INTO tbl_forms_users_items (submission_id, form_id, user_id, form_item_id, user_text)
				OUTPUT inserted.form_user_item_id
				VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#val#">)
			</cfquery>
		<cfelseif item_type_text NEQ "Table" AND item_type_text NEQ "Multiple Check" AND insert>
			<cfquery datasource="#application.applicationDataSource#" name="addAnswer">
				INSERT INTO tbl_forms_users_items (submission_id, form_id, user_id, form_item_id, user_answer)
				OUTPUT inserted.form_user_item_id
				VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#val#">)
			</cfquery>

		</cfif>

		<cfif item_type_text EQ "Multiple Choice"><cfset submitItems(form_item_id, val)></cfif>

	</cfif>

</cffunction>

<!--- enters an item answer as temporary saved progress --->
<cffunction name="submitSavedItem">
	<cfargument name="form_item_id" type="numeric" default="0">

	<cfset item_type_text = getItemType(item_type)>

	<cfif isInputType(item_type)>

		<cfset insert = 1>

		<!--- insert checkbox  --->
		<cfif item_type_text EQ "Checkbox">

			<cfif NOT isDefined("check#form_item_id#")>
				<cfset val = 0>
			<cfelse>
				<cfset val = evaluate("check#form_item_id#")>
			</cfif>

		<cfelseif item_type_text EQ "Multiple Choice">
			<cfif NOT isDefined("radio#form_item_id#")>
				<cfset insert = 0>
			<cfelse>
				<cfset val = evaluate("radio#form_item_id#")>
				<cfif not listFindNoCase(radioAnswers, form_item_id)>
					<cfset radioAnswers = listAppend(radioAnswers, form_item_id)>
				</cfif>
				<input type="hidden" name="radio#form_item_id#" value="#val#">
			</cfif>

		<cfelseif item_type_text EQ "Multiple Check">

			<cfset insert = 0>

			<cfif isDefined("multi#form_item_id#")>

				<cfset valList = evaluate("multi#form_item_id#")>

				<cfset cnt = 1>
				<cfquery datasource="#application.applicationDataSource#" name="addMultiAnswers">
					INSERT INTO tbl_forms_saved_users_items (submission_id, form_id, user_id, form_item_id, user_answer)
					VALUES
				        <cfloop list="#valList#" index="i">
				            (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
							<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
							<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
							<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
							<cfqueryparam cfsqltype="cf_sql_integer" value="#i#">)
				            /* ensure a comma gets inserted between each list */
				            <cfif cnt LT listLen(valList)>,</cfif>
				            <cfset cnt = cnt + 1>
				        </cfloop>
				</cfquery>

			</cfif>

		<!--- insert text field --->
		<cfelseif item_type_text EQ "Large Text Field"
				  OR item_type_text EQ "Small Text Field">
			<cfif NOT isDefined("text#form_item_id#")>
				<cfset insert = 0>
			<cfelse>
				<cfset val = evaluate("text#form_item_id#")>
			</cfif>

		<cfelseif item_type_text EQ "Table">

			<!--- get table rows and cols --->
			<cfset getRows = getTableCells(form_item_id, 1, 0)>
			<cfset getCols = getTableCells(form_item_id, 0, 0)>

			<!--- run through the text inputs and ensure the user submitted each one --->
			<cfloop query="getRows">
				<cfset rowi = getRows.form_table_cell_id>
				<cfloop query="getCols">
					<cfset coli = getCols.form_table_cell_id>

					<cfif isDefined("table#form_item_id#c#coli#r#rowi#")>
						<cfset val = evaluate("table#form_item_id#c#coli#r#rowi#")>

						<cfif trim(val) NEQ "">

							<cfset numVal = val(val)>

							<cfquery datasource="#application.applicationDataSource#" name="addCellAnswer">
								INSERT INTO tbl_forms_saved_users_items (submission_id, form_id, user_id, form_item_id, user_answer, row_id, col_id)
								OUTPUT inserted.form_user_item_id
								VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
										<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
										<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
										<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
										<cfqueryparam cfsqltype="cf_sql_integer" value="#numVal#">,
										<cfqueryparam cfsqltype="cf_sql_integer" value="#rowi#">,
										<cfqueryparam cfsqltype="cf_sql_integer" value="#coli#">
										)
							</cfquery>

						</cfif>

					</cfif>

				</cfloop>
			</cfloop>

		</cfif>

		<cfif insert>

			<!--- only insert a temporary answer if the user provided an answer --->
			<cfif val NEQ 0 AND trim(val) NEQ "">

				<!--- now insert the user's answer into the table --->
				<!--- the insert query for text fields is different than other input types --->
				<cfif item_type_text EQ "Large Text Field" OR item_type_text EQ "Small Text Field">
					<cfquery datasource="#application.applicationDataSource#" name="addAnswer">
						INSERT INTO tbl_forms_saved_users_items (submission_id, form_id, user_id, form_item_id, user_text)
						OUTPUT inserted.form_user_item_id
						VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
								<cfqueryparam cfsqltype="cf_sql_varchar" value="#val#">)
					</cfquery>
				<cfelseif item_type_text NEQ "Table" AND item_type_text NEQ "Multiple Check">
					<cfquery datasource="#application.applicationDataSource#" name="addAnswer">
						INSERT INTO tbl_forms_saved_users_items (submission_id, form_id, user_id, form_item_id, user_answer)
						OUTPUT inserted.form_user_item_id
						VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addSubmission.submission_id#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#val#">)
					</cfquery>

					<cfif item_type_text EQ "Multiple Choice"><cfset submitItems(form_item_id, val)></cfif>

				</cfif>

			</cfif>

		</cfif>

	</cfif>

</cffunction>

<cffunction name="drawItems">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="fieldset" type="boolean" default="0">
	<cfargument name="numbered" type="boolean" default="0">
	<cfargument name="header" type="boolean" default="0">
	<cfargument name="first" type="boolean" default="1">
	<cfargument name="recursive" type="boolean" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getAllItems">
		SELECT a.form_item_id, a.item_text, a.item_type, a.item_answer, a.parent_answer
		FROM tbl_forms_items a
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
		      AND a.parent_id = <cfqueryparam cfsqltype="cf_sql_int" value="#parentId#">
		ORDER BY a.sort_order
	</cfquery>

	<cfloop query="getAllItems">

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

		<cfset drawItem(parentId, parent_answer, form_item_id, item_type, item_text, fieldset, numbered, header, first)>

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
	<cfargument name="item_text" type="string" default="">
	<cfargument name="fieldset" type="boolean" default="0">
	<cfargument name="numbered" type="boolean" default="0">
	<cfargument name="header" type="boolean" default="0">
	<cfargument name="first" type="boolean" default="1">

	<cfset item_type_text = getItemType(item_type)>

	<cfoutput>

		<cfset visible = 1>
		<cfif parentId GT 0>

			<cfset visible = 0>

			<cfif isDefined("radio#parentId#")>

				<cfset val = evaluate("radio#parentId#")>
				<cfif val EQ #parentValue#>
					<cfset visible = 1>
				</cfif>

			</cfif>

		</cfif>

		<div class="formItem" formItemId="#form_item_id#"
			 <cfif not visible>style="display:none;"</cfif>
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
						SELECT TOP 1 a.user_answer, b.submission_date, c.username
						FROM tbl_forms_users_items a
						INNER JOIN tbl_forms_submissions b ON b.submission_id = a.submission_id
						INNER JOIN tbl_users c ON c.user_id = b.submitted_by
						WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
							  AND b.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formUserId#">
						ORDER BY b.submission_date DESC
					</cfquery>

					<cfif getCheckInfo.recordCount GT 0>
						<cfparam name="check#form_item_id#" type="integer" default="#getCheckInfo.user_answer#">
					<cfelse>
						<cfparam name="check#form_item_id#" type="integer" default="0">
					</cfif>

				<cfelse>

					<cfparam name="check#form_item_id#" type="integer" default="0">

				</cfif>

				<cfset val = evaluate("check#form_item_id#")>

				<label>
					<input type="checkbox" name="check#form_item_id#" value="1"
						   <cfif val EQ 1>checked="true"</cfif> >
							#item_text# <cfif isTrainingChecklist>
											<cfif getCheckInfo.recordCount GT 0 AND val EQ 1>
												<span class="tinytext">(#getCheckInfo.username# - #dateFormat(getCheckInfo.submission_date, "MMM d, yyyy")# #timeFormat(getCheckInfo.submission_date, "h:mm tt")#)</span>
											</cfif>
										</cfif>
				</label>

				<br/>

			<!--- multiple choice (first task is to fetch the options) --->
			<cfelseif item_type_text EQ "Multiple Choice">

				<cfif not listFindNoCase(radioAnswers, form_item_id)>
					<cfparam name="radio#form_item_id#" type="integer" default="0">
				</cfif>

				<cfquery datasource="#application.applicationDataSource#" name="getOptions">
					SELECT a.form_item_option_id, a.option_text, a.retired
					FROM tbl_forms_items_options a
					WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
					      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
					ORDER BY a.option_order ASC, a.form_item_option_id ASC
				</cfquery>

				<cfset val = evaluate("radio#form_item_id#")>

				#item_text#
				<br/>
				<cfloop query="getOptions">
					<label>
						<input type="radio" name="radio#form_item_id#" value="#form_item_option_id#"
							   class="formItem" formItemId="#form_item_id#"
							   <cfif val EQ form_item_option_id>checked="true"</cfif>>#option_text#
					</label>

					<br/>
				</cfloop>

				<cfif isNumbered><ol></cfif>
					<cfset drawItems(form_item_id, fieldset, numbered, header, 0, 1)>
				<cfif isNumbered></ol></cfif>

			<!--- multiple check (first task is to fetch the options) --->
			<cfelseif item_type_text EQ "Multiple Check">

				<cfif not listFindNoCase(multiAnswers, form_item_id)>
					<cfparam name="multi#form_item_id#" type="string" default="">
				</cfif>

				<cfquery datasource="#application.applicationDataSource#" name="getOptions">
					SELECT a.form_item_option_id, a.option_text, a.retired
					FROM tbl_forms_items_options a
					WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
					      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
					ORDER BY a.option_order ASC, a.form_item_option_id ASC
				</cfquery>

				<cfset val = evaluate("multi#form_item_id#")>

				#item_text#
				<br/>
				<cfloop query="getOptions">
					<label>
						<input type="checkbox" name="multi#form_item_id#" value="#form_item_option_id#"
							   class="formItem" formItemId="#form_item_id#"
							   <cfif listfindNoCase(val, form_item_option_id)>checked="true"</cfif>>#option_text#
					</label>

					<br/>
				</cfloop>

			<!--- text field --->
			<cfelseif item_type_text EQ "Small Text Field">

				<cfif NOT isDefined("text#form_item_id#")>

					<cfparam name="text#form_item_id#" type="string" default="">
				</cfif>

				<cfset val = evaluate("text#form_item_id#")>

				<label for="text#form_item_id#"><cfoutput>#item_text#</cfoutput></label>
				<input id="text#form_item_id#" type="text" name="text#form_item_id#" value="#val#">

			<cfelseif item_type_text EQ "Large Text Field">

				<cfif NOT isDefined("text#form_item_id#")>

					<cfparam name="text#form_item_id#" type="string" default="">
				</cfif>

				<cfset val = evaluate("text#form_item_id#")>

				<label><cfoutput>#item_text#<br/><br/></cfoutput>
					<textarea name="text#form_item_id#"><cfoutput>#htmlEditFormat(val)#</cfoutput></textarea>
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

			<!--- table --->
			<cfelseif item_type_text EQ "Table">

				<cfset getRows = getTableCells(form_item_id, 1, 0)>
				<cfset getCols = getTableCells(form_item_id, 0, 0)>

				<cfoutput>
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
									<cfif NOT isDefined("table#form_item_id#c#coli#r#rowi#")>
										<cfparam name="table#form_item_id#c#coli#r#rowi#" type="string" default="">
									</cfif>
									<cfset val = evaluate("table#form_item_id#c#coli#r#rowi#")>
									<td><label>
											<input type="text" name="table#form_item_id#c#coli#r#rowi#" value="#val#" size="10">
										</label>
									</td>
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