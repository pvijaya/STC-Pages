<cfmodule template="#application.appPath#/header.cfm" title='Lab Cleaning Form'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="frmCleaningId" type="integer" default="0">
<cfparam name="frmLabId" type="integer" default="0">
<cfparam name="frmUsername" type="string" default="#session.cas_username#">
<cfparam name="frmUserId" type="integer" default="#session.cas_uid#">
<cfparam name="frmSectionId" type="integer" default="0">
<cfparam name="frmComments" type="string" default="">
<cfparam name="frmAction" type="string" default="">
<cfparam name="lastCleaned" type="integer" default="0">
<!--- Heading / Navigation --->
<h1>Lab Cleaning Form</h1>
<cfif frmCleaningId GT 0>
	[<cfoutput><a href="#application.appPath#/tools/cleaning/lab_cleaning.cfm">Go Back</a></cfoutput>]
</cfif>
<cfif hasMasks('admin')>
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_manager.cfm</cfoutput>">Manage Labs</a>]
</cfif>
<cfif hasMasks('cs')>
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/cleaning_report.cfm</cfoutput>">Cleaning Submissions</a>]
</cfif>

<br/>

<cfif frmAction EQ "Submit">
	<cftry>

		<cfquery datasource="#application.applicationDataSource#" name="createSubmission">
			INSERT INTO tbl_cleaning_submissions (cleaning_id, section_id, user_id, comments, date_cleaned)
			OUTPUT inserted.submission_id
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmSectionId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmComments#">,
				getDate()
			)
		</cfquery>

		<p class="ok">Cleaning submitted successfully.</p>

		<cfset frmAction = "">

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

</cfif>

<cfif frmCleaningId GT 0>

	<cfquery datasource="#application.applicationDataSource#" name="getLab">
		SELECT l.lab_name, cl.lab_id, cl.instance_id
		FROM tbl_cleaning_labs cl
		INNER JOIN vi_labs l ON l.lab_id = cl.lab_id AND l.instance_id = cl.instance_id
		WHERE cl.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
	</cfquery>

	<cfset frmLabId = getLab.lab_id>

	<cfquery datasource="#application.applicationDataSource#" name="needsCleaning">
		SELECT TOP 1 cls.section_id, cls.section_image, cls.section_description, cs.date_cleaned,
					 l.lab_name
		FROM tbl_cleaning_labs_sections cls
		LEFT OUTER JOIN
			(SELECT section_id, MAX(date_cleaned) AS date_cleaned
			 FROM tbl_cleaning_submissions
			 GROUP BY section_id) cs ON cs.section_id = cls.section_id
		INNER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cls.cleaning_id
		INNER JOIN vi_labs l ON l.lab_id = cls.lab_id AND l.instance_id = cl.instance_id
		WHERE cls.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
			  AND cls.retired = 0
		ORDER BY cs.date_cleaned ASC, cls.sort_order ASC, cls.section_id ASC
	</cfquery>

	<cfoutput query="needsCleaning">
		<h3><cfoutput>#getLab.lab_name#</cfoutput></h3>
		<table>
			<tr>
				<td><b>Needs Cleaning: #lab_name# <cfif section_description NEQ "">- #section_description#</cfif></b><br/>
					<cfif #date_cleaned# NEQ "">
						Last cleaned #dateFormat(date_cleaned, "mmm d, yyyy")# #timeFormat(date_cleaned, "short")# (<em>#dateDiff("d", date_cleaned, now())# days ago</em>)
			        <cfelse>
						This section has not yet been cleaned.
					</cfif>
				</td>
			</tr>
			<tr>
				<td><cfif section_image NEQ "">
						<img src="#section_image#" align="#htmlEditFormat(lab_name)#"
				 			style="width:500px;">
			 		</cfif>
				</td>
			 </tr>
		</table>
		<cfset frmSectionId = #section_id#>
	</cfoutput>

	<h3>Cleaning Form</h3>
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

		<cfoutput>
			<input type="hidden" name="frmLabId" value="#frmLabId#">
			<input type="hidden" name="frmCleaningId" value="#frmCleaningId#">
		</cfoutput>

		<table>
			<cfoutput>
				<tr>
					<td><label for="dateFieldId">Date: </label></td>
					<td>#dateFormat(now(), 'MMM d, yyyy')# #timeFormat(now(), 'short')#</td>
				</tr>
			</cfoutput>
			<cfoutput>
				<tr>
					<td><label for="usernameTextId">Username: </label></td>
					<td>#htmlEditFormat(frmUsername)#
						<cfoutput><input type="hidden" name="frmUserId" value="#frmUserId#"></cfoutput></td>
				</tr>
			</cfoutput>
			<cfquery datasource="#application.applicationDatasource#" name="getSections">
				SELECT cls.section_id, cls.lab_id, l.lab_name, cls.section_description
				FROM tbl_cleaning_labs_sections cls
				INNER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cls.cleaning_id
				INNER JOIN vi_labs l ON l.lab_id = cls.lab_id AND l.instance_id = cl.instance_id
				WHERE cls.retired = 0
					  AND cls.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
				ORDER BY cls.sort_order ASC
			</cfquery>
			<tr>
				<td><label for="selectFieldId">Section: </label></td>
				<td><select id="selectFieldId"  name="frmSectionId">
						<cfoutput query="getSections">
							<option value="#section_id#" <cfif section_id eq frmSectionId>selected</cfif>>#htmlEditFormat(lab_name)# - #htmlEditFormat(section_description)#</option>
						</cfoutput>
					</select>
				</td>
			</tr>
			<tr>
				<td><label for="commentFieldId">Comments: </label></td>
				<td><textarea id="commentFieldId" class="special" style="width:100%;height:50px;"name="frmComments"><cfoutput>#htmlEditFormat(frmComments)#</cfoutput></textarea></td>
			</tr>
			<tr>
				<td colspan="2"><input type="submit" name="frmAction" value="Submit"></td>
			</tr>
		<table>
	</form>
	<br/>

	<!--- by user request, show the current day's cleaning submissions --->
	<h3>Recent Cleanings:</h3>
	<cfquery datasource="#application.applicationDataSource#" name="getCleanings">
		SELECT TOP 16 cs.section_id, u.username, cs.comments, cs.date_cleaned, l.lab_name,
				     cls.section_description
		FROM tbl_cleaning_submissions cs
		INNER JOIN tbl_users u ON u.user_id = cs.user_id
		INNER JOIN tbl_cleaning_labs_sections cls ON cls.section_id = cs.section_id
		INNER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cls.cleaning_id
		INNER JOIN vi_labs l ON l.lab_id = cls.lab_id AND l.instance_id = cl.instance_id
		WHERE cs.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
		ORDER BY cs.date_cleaned DESC
	</cfquery>

	<cfif getCleanings.recordCount EQ 0>
		<cfoutput>
			<blockquote>This lab has not yet been cleaned.</blockquote>
			<br/>
		</cfoutput>
	<cfelse>

		<table class="stripe" style="width: 100%;">

			<tr class="titlerow">
				<th>Date</th>
				<th>Cleaned By</th>
				<th>Section</th>
				<th>Comments</th>
			</tr>
			<cfoutput query="getCleanings">
				<tr>
					<td>
						 #dateFormat(date_cleaned, "MMM d, yyyy")# #timeFormat(date_cleaned, "short")#
					</td>
					<td>#htmlEditFormat(username)#</td>
					<td>#htmlEditFormat(lab_name)#
						<cfif section_description NEQ "">
							- #section_description#
						</cfif>
					</td>
					<td>
					<cfif len(comments) eq 0><em>none</em></cfif>
						<!---#htmlEditFormat(left(comments, 80))#<cfif len(comments) gt 80>...</cfif>--->
						#htmlEditFormat(left(comments, 80))#
						<cfif len(comments) gt 80>
							<span class="trigger">(more)</span>
							<div>
								#mid(comments, 81, len(comments) - 81)#
							</div>
						</cfif>
					</td>
				</tr>
			</cfoutput>
		</table>


	</cfif>

<!--- Select a lab. --->
<cfelse>

	<!--- Fetch existing labs with cleaning forms. --->
	<cfquery datasource="#application.applicationDataSource#" name="getLabs">
		SELECT a.cleaning_id, a.lab_id, a.retired, b.lab_name
		FROM tbl_cleaning_labs a
		INNER JOIN vi_labs b ON b.lab_id = a.lab_id AND b.instance_id = a.instance_id
		INNER JOIN tbl_instances c ON c.instance_id = a.instance_id
		WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, c.instance_mask)
				  AND retired = 0
		ORDER BY a.retired, a.lab_id
	</cfquery>

	<br/>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

		<fieldset>

			<legend>Choose</legend>

			<label>
				Select a Lab:
				<select name="frmCleaningId">
					<cfoutput query="getLabs">
						<option value="#cleaning_id#">
							#lab_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			<input type="submit" value="Go" name="frmAction">

		</fieldset>

	</form>

</cfif>

<cfinclude template="#application.appPath#/footer.cfm">