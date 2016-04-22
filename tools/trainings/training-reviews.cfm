<cfmodule template="#application.appPath#/header.cfm" title='Training Reviews' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">
<h1>Training Reviews</h1>
<cfif hasMasks('admin')>
	<a href="training-options-editor.cfm">Options Editor</a> |
</cfif>
<a href="submit-training.cfm">Submit Training</a>
<br/><br/>

<cfparam name="action" type="string" default="">
<cfparam name="training" type="integer" default="0">
<cfparam name="currentUserId" type="integer" default=0>

<!---Queries--->
<cfquery name="getTrainings" datasource="#application.applicationDataSource#">
	SELECT training_id, training_name, retired
	FROM tbl_trainings
	WHERE
		<cfif hasMasks('IUB') AND hasMasks('IUPUI')>
			instance = 1 OR instance = 2
		<cfelseif hasMasks('IUB') >
			instance = 1
		<cfelseif hasMasks('IUPUI')>
			instance = 2
		</cfif>
	ORDER BY retired, training_name
</cfquery>

<cfoutput>
<fieldset>
	<legend>Select By Training</legend>
<form action="training-reviews.cfm" id="trainform" method="post" class="form">
	<label for="training">Training: </label>
    <select  id="training" name="training">
	<cfloop query="getTrainings">
		<option value="#training_id#" <cfif training eq training_id>selected="true"</cfif>>#training_name#<cfif retired>(retired)</cfif></option>
	</cfloop>
	</select>
	<input  type="submit" value="Show Training Reviews" name="action" />
</form>
</fieldset>
<fieldset>
	<legend>Select By Consultant</legend>
<form action="training-reviews.cfm" id="trainform" method="post" class="form">
	<label for="training">Consultant: </label>
	<cfquery datasource="#application.applicationDataSource#" name="getBlacklist">
		SELECT instance_mask
		FROM tbl_instances i
		WHERE 0 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
	</cfquery>
	<cfset blackList = "Admin,Logistics"><!---we never want to display admins or Logistics folks here.--->

	<cfif not hasMasks("Admin")>
		<cfset blackList= listAppend(blackList, "CS")>
	</cfif>
	<cfloop query="getBlacklist">
		<cfset blackList = ListAppend(blackList,getBlacklist.instance_mask)>
	</cfloop>
	#drawConsultantSelector('consultant',blackList,currentUserId)#
	<input  type="submit" value="Show Consultant Reviews" name="action" />
</form>
</fieldset>
<br/><br/>
<cfif action EQ "Show Training Reviews" >
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="5">Reviews</td>
		</tr>
		<tr class="titlerow2">
			<td>Username</td>
			<td>Training</td>
			<td>Rating</td>
			<td>Comment</td>
			<td>Date</td>
		</tr>
		<cfquery name="getTrainingReviews" datasource="#application.applicationDataSource#">
			SELECT *
			FROM tbl_training_submissions s
			INNER JOIN tbl_users u ON u.user_id = s.user_id
			INNER JOIN tbl_trainings t ON t.training_id = s.training_id
			WHERE s.training_id = <cfqueryparam value="#training#" cfsqltype="cf_sql_varchar">
			ORDER BY s.submission_date DESC
		</cfquery>
		<cfloop query="getTrainingReviews">
			<tr>
				<td>#username#</td>
				<td><cfif upload_url NEQ "">
						<a href="#upload_url#">#training_name#</a>
					<cfelse>
						#training_name#
					</cfif>
				</td>
				<td>#rating#</td>
				<td>#comment#</td>
				<td>#submission_date#</td>
			</tr>
		</cfloop>
	</table>
<cfelseif action EQ "Show Consultant Reviews">
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="5">Reviews</td>
		</tr>
		<tr class="titlerow2">
			<td>Username</td>
			<td>Training</td>
			<td>Rating</td>
			<td>Comment</td>
			<td>Date</td>
		</tr>
		<cfquery name="getTrainingReviewsByUser" datasource="#application.applicationDataSource#">
			SELECT *
			FROM tbl_training_submissions s
			INNER JOIN tbl_users u ON u.user_id = s.user_id
			INNER JOIN tbl_trainings t ON t.training_id = s.training_id
			WHERE s.user_id = <cfqueryparam value="#currentUserId#" cfsqltype="cf_sql_integer">
			ORDER BY s.submission_date DESC
		</cfquery>
		<cfloop query="getTrainingReviewsByUser">
			<tr>
				<td>#username#</td>
				<td><cfif upload_url NEQ "">
						<a href="#upload_url#">#training_name#</a>
					<cfelse>
						#training_name#
					</cfif>
				<td>#rating#</td>
				<td>#comment#</td>
				<td>#submission_date#</td>
			</tr>
		</cfloop>
	</table>
</cfif>
</cfoutput>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>