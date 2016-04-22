<cfmodule template="#application.appPath#/header.cfm" title='Training Options Editor'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<h1>Training Options Editor</h1>
<a href="training-options-editor.cfm">Reset</a> |
<a href="training-reviews.cfm">Reviews</a> |
<a href="submit-training.cfm">Submit Training</a>
<br/><br/>
<cfparam name="instanceSelected" type="integer" default="0">
<cfparam name="optionId" type="integer" default="0">
<cfparam name="trainingName" type="string" default="">
<cfparam name="externalUrl" type="boolean" default="0">
<cfparam name="action" type="string" default="">

<!---Resolves instances--->
<cfset instanceList = userHasInstanceList().instanceList>
<cfset instanceNameList = userHasInstanceList().nameList>
<cfif ListLen(instanceList) GTE 2 AND instanceSelected EQ 0>
	<cfoutput>
	<form action='<cfoutput>#cgi.script_name#</cfoutput>' method='post' enctype="multipart/form-data" >
		<cfif ListLen(instanceList) GTE 2>
			<label for="instanceSelected">Campus:</label>
			<select  id="instanceSelected" name="instanceSelected">
			<cfloop list="#instanceList#" index="i">
				<option <cfif instanceSelected EQ i>selected="selected"</cfif> value="#i#">#ListGetAt(instanceNameList,i)#</option>
			</cfloop>
			</select>
		</cfif>
		<input type="submit"  name="action" value="Select"/>
	</form>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
	</cfoutput>
<cfelseif ListLen(instanceList) GTE 2 AND instanceSelected NEQ 0>
	<!---do nothing--->
<cfelse>
	<cfset instanceSelected = instanceList>
</cfif>

<!---Once we have the instance--->
<cfif instanceSelected NEQ 0>
	<cfif action EQ "Create">
		<cftry>

			<!---verify we have a valid trainingName--->
			<cfif trim(trainingName) eq "">
				<cfthrow type="custom" message="Missing Input" detail="You must provide a Training Name to create a new training.">
			</cfif>

			<cfquery name='insertTrainingOption' datasource="#application.applicationdatasource#" >
				INSERT INTO tbl_trainings(training_name, instance, external_url)
				VALUES (<cfqueryparam cfsqltype="cf_sql_string" value="#trainingName#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">,
						<cfqueryparam cfsqltype="cf_sql_bit" value="#externalUrl#">
						)
			</cfquery>
			<p class="ok">
				<b>Success</b>
				Training inserted!
			</p>
			<cfcatch>
				<cfoutput>
				<p class="warning">
				<b>Error</b>
				#cfcatch.message# - #cfcatch.Detail#
				</p>
				</cfoutput>
			</cfcatch>
		</cftry>
	<cfelseif action EQ "Retire">
				<cftry>
			<cfquery name='deleteTrainingOption' datasource="#application.applicationdatasource#" >
				UPDATE tbl_trainings
				SET retired=1
				WHERE training_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#optionId#">
				AND instance = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
			</cfquery>
			<p class="ok">
				<b>Success</b>
				Option retired!
			</p>
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
	<cfquery name='trainingOptions' datasource="#application.applicationdatasource#" >
		SELECT *
		FROM tbl_trainings
		WHERE instance = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
		AND retired=0
	</cfquery>

	<!---HTML--->
	<cfoutput>
	<fieldset style="width:45%;float:left;">
	<legend>Create Training Option</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">
		<p>
			<label>
				Training Name:
				<input type="text"  name="trainingName">
			</label>
		</p>

		<p>
			<fieldset>
				<legend>Uses Box.net?</legend>
				<label>
					Yes
					<input type="radio" name="externalUrl" value="1" <cfif externalUrl>checked="true"</cfif>>
				</label>
				<label>
					No
					<input type="radio" name="externalUrl" value="0" <cfif not externalUrl>checked="true"</cfif>>
				</label>
			</fieldset>
		</p>
		<input type="submit"  name="action" value="Create">
	</form>
	</fieldset>
	<fieldset style="width:45%;float:right;">
	<legend>Retire Training Option</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">

		<select  name="optionId">
		<cfloop query="trainingOptions">
			<option value="#training_id#">#training_name#</option>
		</cfloop>
		</select>
		<input type="submit"  name="action" value="Retire">
	</form>
	</fieldset>
	</cfoutput>

<cfelse>
	<p class="warning">
		<span>Error</span> - You do not belong to any instance.
	</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>