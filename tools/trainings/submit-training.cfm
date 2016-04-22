<cfmodule template="#application.appPath#/header.cfm" title='Training Submission' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<h1>Training Submission</h1>
<cfif hasMasks('admin')>
	<a href="training-options-editor.cfm">Options Editor</a> |
</cfif>
<cfif hasMasks('cs')>
	<a href="training-reviews.cfm">Reviews</a>
	<br/><br/>
</cfif>
<cfset todayDate = Now()>

<cfparam name="training" type="integer" default="0">
<cfparam name="rating" type="integer" default="1">
<cfparam name="comment" type="string" default="">
<cfparam name="action" type="string" default="">
<cfparam name="action2" type="string" default="">
<cfparam name="externalUrl" type="string" default="">
<cfparam name="usingURL" type="boolean" default="0">

<cfset instanceList = userHasInstanceList().instanceList>

<cfif action EQ "Back">

	<cfset training = "0">

</cfif>

<cfif action EQ "Submit">

	<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

	<!---Try to fetch the actual filename, if we can find it.--->

	<cftry>

		<cfif comment eq "">

			<cfthrow message="Missing Input" detail="Please complete the 'Comment' field and submit this form again'.">

		</cfif>

		<cfif usingURL eq 0>

			<cfset fileName = getUploadFileName("upload")>

			<cfif trim(fileName) eq "">
				<cfset fileName = createUUID()>
			</cfif>

			<!---does the user's folder already exist in the filemanager?--->
			<cfset myPath = "/Trainings/Users/#session.cas_username#/">
			<cfset myFolderId = pathToFolderId(myPath)>

			<cfif myPath neq folderIdtoPath(myFolderId)>
				<!---create folder, and set myFolderId to that--->
				<cfset myFolderId = addFolder(session.cas_username, #pathToFolderId("/Trainings/Users")#)>
			</cfif>

			<!--- at this point make sure we have a unique filename, if it matches an existing file it'll just upload it as a new version of the existing one, which could break existing articles.--->
			<cfif checkDuplicateFiles(myFolderId, filename)>
				<!---append a unique string to the end of the filename--->
				<cfif find(".", fileName)>
					<cfset fileName = replace(fileName, ".", createUUID() & ".", "one")>
				<cfelse>
					<cfset fileName = fileName & createUUID()>
				</cfif>
			</cfif>
			<!---at this point we sure as shooting have a unique filename.--->

			<!---now process the file the user provided--->
			<!---<cfset result = uploadFile(myFolderId, fileName, "upload", 9, 1)>---><!---provide default mask of "9", consultant, and return the version_id not just the file_id--->
			<cfset result = uploadFile(myFolderId, fileName, "upload", 10, 1)> <!---We cannot have the default mask to be consultant, otherwise it will show up the files in search results of a consultant so it'll have the default mask to be CS instead--->
			<cfif result['code'] eq 302>
				<cfoutput><p>File uploaded, view it <a href="#result['url']#">here</a>.</p></cfoutput>
			<cfelse>
				<cfoutput><p>An error, #result['code']#, occurred - #result['text']#</p>
				<p><a href="#application.appPath#/tools/trainings/submit-training.cfm">Go back</p>
				</cfoutput><cfabort>
			</cfif>

			<cfset ul_url = "#result['url']#">

		<cfelse>

			<cfset ul_url = "#externalUrl#">
			<cfif not isValid("url", externalUrl)>
				<cfthrow message="Missing Input" detail="The External URL you provided is invalid, please correct it and submit this form again.">
			</cfif>

		</cfif>

<!---Put mentor into lists and output list a string in the email--->
		<cfset mentorList = ''>
		<cfloop list="#instanceList#" index='instance'>
			<cfquery name="getPieDatabase" datasource="#application.applicationDatasource#">
				SELECT datasource
				FROM tbl_instances
				WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instance#">
			</cfquery>
			<cfloop query ="getPieDatabase">
				<cfset pieDatabase= getPieDatabase.datasource>
			</cfloop>
		    <cfquery name="getMentor" datasource="#pieDatabase#" >
				SELECT TOP 1  m.username
				FROM tbl_obs_mentors om
				INNER JOIN tbl_consultants c ON c.ssn = om.mentee_id
				INNER JOIN tbl_consultants m ON m.ssn = om.mentor_id
				WHERE c.username = <cfqueryparam value="#session.cas_username#" cfsqltype="cf_sql_varchar">
				AND GETDATE() BETWEEN om.start_date AND om.end_date
				ORDER BY om.start_date DESC
			</cfquery>

			<!---we should only get one mentor, but in the future someone could have more than one at once.  Build a list of their mentor's email addresses.--->
			<cfloop query="getMentor">
				<cfquery name="getMentorEmail" datasource="#application.applicationDataSource#" >
					SELECT email
					FROM tbl_users
					WHERE username = <cfqueryparam value="#getMentor.username#" cfsqltype="cf_sql_varchar">
				</cfquery>
				<cfloop query="getMentorEmail">
					<cfset mentorList = ListAppend(mentorList,email)>
				</cfloop>
			</cfloop>
		</cfloop>

	    <cfquery name="insertTraining" datasource="#application.applicationDataSource#">
			INSERT INTO tbl_training_submissions(user_id, upload_url, training_id, rating, comment)
			VALUES (<cfqueryparam value="#session.cas_uid#" cfsqltype="cf_sql_varchar">,
					<!---><cfqueryparam value="#result['url']#" cfsqltype="cf_sql_varchar">,--->
					<cfqueryparam value="#ul_url#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="#training#" cfsqltype="cf_sql_integer">,
					<cfqueryparam value="#rating#" cfsqltype="cf_sql_integer">,
					<cfqueryparam value="#comment#" cfsqltype="cf_sql_varchar">)
		</cfquery>
		<cfloop list="#mentorList#" index="email">
			<cfmail from="tccwm@iu.edu" to="#email#" subject="New Training Submission!" type="text/html">
				<html>
					<body>
						<center>
							<p>One of your consultants, #session.cas_username#, has completed a training.</p>
						</center>
					</body>
				</html>
			</cfmail>
		</cfloop>

		<p class="ok">
			Thanks, your submission was successful.
		</p>
	    <cfabort>

		<cfcatch>
			<cfoutput>
				<p class="warning">
				<b>Error</b>
				#cfcatch.message# - #cfcatch.Detail#
				</p>
			</cfoutput>
		</cfcatch>

	</cftry>

</cfif>

<cfif training gt 0>

	<cfquery name="trainingOptions" datasource="#application.applicationDatasource#">
		SELECT training_name, external_url
		FROM tbl_trainings
		WHERE training_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#training#">
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" id="trainform" method="post"
	class="form" enctype="multipart/form-data">

	<cfoutput>
		<input type="hidden" name="training" value="#training#">
	</cfoutput>

	<cfoutput query="trainingOptions">
		<fieldset>
			<legend>#training_name# Training</legend>

			<p>Once you have completed a task-based training, please use this form to submit your work to your mentor.
	To help us improve our trainings, please rate them using the star system. Upon clicking "submit", your
	mentor will receive an email notification regarding your training submission. You must complete all fields.</p>

			<cfif NOT trainingOptions.external_url>
				<p><strong>NOTE:</strong>
				If you submit a training file and receive a '404 error' on the next page, your file might be too large.
				In that case, you may submit a smaller version of the file here and provide the original to your mentor
				through Box. For the Photoshop Training, a good way to reduce file size is to flatten the image layers.
				</p>
			</cfif>

				<cfif trainingOptions.external_url>
					<input type="hidden" name="usingURL" value="1" />
					<p>
						<label for="externalUrl">External URL</label><br />
						<input type="text" name="externalUrl" id="externalUrl" size="40"
								value="#htmlEditFormat(externalUrl)#">
					</p>

				<cfelse>
					<input type="hidden" name="usingURL" value="0" />
					<p class="upload">
						<label for="upload">Upload</label><br />
						<input type="file" name="upload" id="upload"
						onChange="$('##fileName').val(this.value)">
					</p>

				</cfif>

				<p>
				<label for="rating">Rate Training</label><br />
	 			<select name="rating" >
	 				<option value="1" <cfif rating eq 1>selected="selected"</cfif>>Very poor</option>
	 				<option value="3" <cfif rating eq 2>selected="selected"</cfif>>Poor</option>
	 				<option value="3" <cfif rating eq 3>selected="selected"</cfif>>Ok</option>
	 				<option value="4" <cfif rating eq 4>selected="selected"</cfif>>Good</option>
	 				<option value="5" <cfif rating eq 5>selected="selected"</cfif>>Very Good</option>
	 			</select>
	 			</p>

	 			<p>The reflection section is designed to give your mentor and CS feedback on your training experience. Here are some sample questions you can address in your reflection:</p>
				<p> <ul>
					<li> Did you learn new skills?</li>
					<li> Did you find it easy/hard?</li>
					<li> What were some specific tasks that gave you troubles?</li>
					<li> Please list any of the Lynda.com or STEPS trainings resources that you used, if any.</li>
					<li> Did you find the Lynda.com materials to be useful?</li>
					<li> What are some suggestions for future tasks that could be added to this project?</li>
				</ul> </p>
				<p>This information is vital for the CS and your mentor to help you learn and grow on the job. Congratulations on completing a training!</p>
				<p class="text">
    				<label for="comment">Comment</label><br />
					<textarea name="comment" id="comment" class="special">#htmlEditFormat(comment)#</textarea>
				</p>

				<p class="submit">
					<input type="submit"  value="Submit" name="action" />
					<input type="submit"  value="Back" name="action" />
				</p>

		</fieldset>
	</cfoutput>

</form>

<cfelse>

	<cfquery name="getTrainings" datasource="#application.applicationDataSource#">
		SELECT training_id, training_name
		FROM tbl_trainings
		WHERE
			<cfif hasMasks('IUB') AND hasMasks('IUPUI')>
				(instance = 1 OR instance =2)
			<cfelseif hasMasks('IUB') >
				instance = 1
			<cfelseif hasMasks('IUPUI')>
				instance = 2
			</cfif>
		AND retired=0
		ORDER BY training_name
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" id="trainform" method="post"
	class="form" enctype="multipart/form-data">

		<fieldset>

		<legend>Select a Training</legend>

		<p class="training">
			<label for="training">Training</label><br />
	    	<select id="training" name="training">
			<cfoutput query="getTrainings">
				<option value="#training_id#">#training_name#</option>
			</cfoutput>
			</select>
	    </p>

		<p class="submit">
			<input type="submit"  value="Submit" name="action2" />
		</p>

		</fieldset>

	</form>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>