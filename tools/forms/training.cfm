<cfmodule template="#application.appPath#/header.cfm" title='Training' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmFormId" type="integer" default="0">
<cfparam name="frmFormName" type="string" default="">
<cfparam name="frmFormDescription" type="string" default="">
<cfparam name="frmFormRetired" type="boolean" default="-1">
<cfparam name="frmFormAttributes" type="string" default="">

<cfquery datasource="#application.applicationDataSource#" name="getUser">
	SELECT u.username
	FROM tbl_users u
	WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#Session.cas_uid#">
</cfquery>

<!--- Header / Navigation --->
<cfoutput>
	<h1>Training (#getUser.username#)</h1>
</cfoutput>

<cfquery datasource="#application.applicationDataSource#" name="getUser">
	SELECT u.username
	FROM tbl_users u
	WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#Session.cas_uid#">
</cfquery>

<!--- only show the quizzes / checklists the user has the masks to view --->
<!---fetch all the masks the user explicitly has--->
<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
	SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
	FROM tbl_users u
	INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
	INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
	WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
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
				  AND fm.edit = 0
			 	  AND fm.mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#maskList#" list="true">)
		  )
</cfquery>

<h2>Tests & Surveys</h2>

<cfoutput>
	<table class="stripe" style="padding:0px;">
		<tr class="titlerow" style="padding:5px;">
			<th>Quiz</th>
			<th>Score</th>
			<th>Latest Submission</th>
			<th>Link</th>
		</tr>
		<cfloop query="getForms">
			<cfif attribute_id EQ 5>
				<cfquery datasource="#application.applicationDataSource#" name="getLastSubmission">
					SELECT TOP 1 fs.score, fs.submission_id
					FROM tbl_forms_submissions fs
					WHERE fs.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_id#">
						  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">
					ORDER BY fs.submission_date DESC
				</cfquery>

				<cfif getLastSubmission.recordCount EQ 0>
					<cfset score = -1>
				<cfelse>
					<cfset score = getLastSubmission.score>
				</cfif>
				<cfquery datasource="#application.applicationDataSource#" name="getItems">
					SELECT fi.form_item_id, fit.type_text
					FROM tbl_forms_items fi
					INNER JOIN tbl_forms_items_types fit On fit.type_id = fi.item_type
					WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_id#">
					      AND fi.retired = 0
				</cfquery>
				<tr>
					<td>#form_name#</td>
					<td><cfif score GTE 0>#score# / #maxScoreQuiz(form_id)#<cfelse>N/A</cfif></td>
					<td><a href="#application.appPath#/tools/forms/form_view_submission.cfm?referrer=#urlEncodedFormat(cgi.script_name)#&submissionId=#getLastSubmission.submission_id#">#getLastSubmission.submission_id#</a></td>
					<td><a href="#application.appPath#/tools/forms/form_viewer.cfm?referrer=#urlEncodedFormat(cgi.script_name)#&formUserId=#Session.cas_uid#&formId=#form_id#">Go</a></td>
				</tr>
			</cfif>
		</cfloop>
	</table>
</cfoutput>

<br/>

<cfoutput>
	<table class="stripe" style="padding:0px;">
		<tr class="titlerow" style="padding:5px;">
			<th>Checklist</th>
			<th>Status</th>
			<th>Latest Submission</th>
			<th>Link</th>
		</tr>
		<cfloop query="getForms">
			<cfif attribute_id EQ 4>
				<cfquery datasource="#application.applicationDataSource#" name="getLastSubmission">
					SELECT TOP 1 fs.status, fs.submission_id
					FROM tbl_forms_submissions fs
					WHERE fs.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_id#">
						  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">
					ORDER BY fs.submission_date DESC
				</cfquery>
				<tr>
					<td>#form_name#</td>
					<td><cfif #getLastSubmission.status# EQ 1>complete<cfelseif #getLastSubmission.status# EQ 0>started<cfelse>not started</cfif></span></td>
					<td><a href="#application.appPath#/tools/forms/form_view_submission.cfm?referrer=#urlEncodedFormat(cgi.script_name)#&submissionId=#getLastSubmission.submission_id#">#getLastSubmission.submission_id#</a></td>
					<td><a href="#application.appPath#/tools/forms/form_viewer.cfm?referrer=#urlEncodedFormat(cgi.script_name)#&formUserId=#Session.cas_uid#&formId=#form_id#">Go</a>
				</tr>
			</cfif>
		</cfloop>
	</table>
</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>