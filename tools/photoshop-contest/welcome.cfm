<cfmodule template="#application.appPath#/header.cfm" title='Photoshop Contest'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<!--- cfparams --->
<cfparam name="frmFile" type="string" default="">
<cfparam name="frmAction" type="string" default="">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<!--- if the deadline has passed and the contest is open, close it --->
<cfif getContest.recordCount GT 0 AND getContest.open_entry EQ 1
	  AND dateCompare(now(), getContest.deadline) GTE 0>

	<cfquery datasource="#application.applicationDataSource#" name="closeContest">
		UPDATE tbl_psc_contests
		SET open_entry = 0
		WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
	</cfquery>

	<cfset getContest = getActiveContest()>

</cfif>

<!--- Header / Navigation --->
<!--- block off the source images and gallery links if there is not an active contest --->
<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>
<cfif getContest.recordCount GT 0>
	<cfset drawNavigation()>
<cfelse>
	<cfset drawNavigationClosed()>
</cfif>

<!--- based on the active contest and its entry status, display a message --->
<cfoutput>
	<cfif getContest.recordCount EQ 0>
		<p class="warning">There is no active Photoshop Contest at this time.</p>
		<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
		<cfabort>
	<cfelseif NOT getContest.open_entry>
		<p class="ok">The Photoshop Contest is currently closed.</p>
	<!---
	<cfelse>
		<p class="ok">The Photoshop Contest is open! Entries are due by #dateTimeFormat(getContest.deadline, 'mmmm dd, yyyy')#.</p>
	--->
	</cfif>
</cfoutput>

<!--- give consultants and CS an extra message if voting is open --->
<cfif hasMasks('consultant') AND getContest.open_vote>

	<cfquery datasource="#application.applicationDataSource#" name="getVotes">
		SELECT pv.entry_id, pe.cs_entry
		FROM tbl_psc_votes pv
		INNER JOIN tbl_psc_entries pe ON pe.entry_id = pv.entry_id
		WHERE pv.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			  AND pv.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
	</cfquery>

	<cfset consultantVotes = 0>
	<cfset csVotes = 0>
	<cfloop query="getVotes">
		<cfif cs_entry EQ 1>
			<cfset csVotes = csVotes + 1>
		<cfelse>
			<cfset consultantVotes = consultantVotes + 1>
		</cfif>
	</cfloop>

	<cfset remCSVotes = max(0, 1 - csVotes)>
	<cfset remConsultantVotes = max(0, 1 - consultantVotes)>

	<cfoutput>
		<p class="ok">You may now vote on entries:
			#remConsultantVotes# Consultant vote<cfif remConsultantVotes NEQ 1>s</cfif> remaining /
			#remCSVotes# CS vote<cfif remCSVotes NEQ 1>s</cfif> remaining.
		</p>
	</cfoutput>

</cfif>

<!--- handle user input --->
<cfif frmAction EQ "Submit" AND getContest.open_entry>

	<cftry>

		<cfif trim(frmFile) EQ "">
			<cfthrow message="Missing Input" detail="You must choose a file to upload.">
		</cfif>

		<!--- fetch the actual filename, if we can find it. --->
		<cfset filename = getUploadFileName("frmFile")>
		<cfset filename = session.cas_username>

		<!--- if the name is invalid or not unique, assign it a unique name --->
		<cfif trim(filename) eq "" OR checkDuplicateFiles(getContest.folder_id, filename)>
			<cfset filename = filename & createUUID()>
		</cfif>

		<!--- upload the file and retrieve its new file_id --->
		<cfset fileId = uploadFile(getContest.folder_id, filename, "frmFile", 9, 1)>

		<!--- finally, add the entry to the database --->
		<cfquery datasource="#application.applicationDataSource#" name="getUploadedId">
			INSERT INTO tbl_psc_entries(user_id, contest_id, file_id, cs_entry)
			VALUES(
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#fileId.id#">,
				<cfqueryparam cfsqltype="cf_sql_bit" value="#hasMasks('CS', session.cas_uid)#">
			)
		</cfquery>

		<p class="ok">File uploaded successfully.</p>

	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.message# - #cfcatch.detail# </cfoutput>
		</p>
	</cfcatch>

	</cftry>

</cfif>

<!--- draw forms --->

<cfquery datasource="#application.applicationDataSource#" name="getWinners">
	SELECT pe.file_id, pw.entry_id, pw.runner_up, u.username, u.first_name, u.last_name, pe.cs_entry
	FROM tbl_psc_winners pw
	INNER JOIN tbl_psc_entries pe ON pe.entry_id = pw.entry_id
	INNER JOIN tbl_users u ON u.user_id = pe.user_id
	WHERE pw.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
	ORDER BY pw.runner_up ASC
</cfquery>

<cfif getWinners.recordCount GT 0>
	<p class="ok">Congratulations to the winners of <cfoutput>#getContest.contest_name# </cfoutput> !</p>
	<div class="winners">
		<h3>Consultant Contest</h3>
		<cfloop query="getWinners">
			<cfif cs_entry EQ 0>
				<cfif not runner_up>
					<div class="block-card" style="float:left;">
						<cfoutput>
							<h4>Winner: #first_name# #last_name#</h4>
							<img src="#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#"/>
						</cfoutput>
					</div>
				<cfelse>
					<div class="block-card" style="float:right;">
						<cfoutput>
							<h4>Runner-up: #first_name# #last_name#</h4>
							<img src="#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#"/>
						</cfoutput>
					</div>
				</cfif>
			</cfif>
		</cfloop>
	</div>
	<div class="winners" style="clear:both;">
		<h3>CS Contest</h3>
		<cfloop query="getWinners">
			<cfif cs_entry EQ 1>
				<cfif not runner_up>
					<div class="block-card" style="float:left;">
						<cfoutput>
							<h4>Winner: #first_name# #last_name#</h4>
							<img src="#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#"/>
						</cfoutput>
					</div>
				<cfelse>
					<div class="block-card" style="float:right;">
						<cfoutput>
							<h4>Runner-up: #first_name# #last_name#</h4>
							<img src="#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#"/>
						</cfoutput>
					</div>
				</cfif>
			</cfif>
		</cfloop>
	</div>
</cfif>

<cfif getContest.open_entry>

	<!--- get the current user's first name --->
	<cfquery datasource="#application.applicationDataSource#" name="getUser">
		SELECT u.first_name
		FROM tbl_users u
		WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	</cfquery>

	<!--- get the number of entries the user has submitted to this contest --->
	<cfquery datasource="#application.applicationDataSource#" name="getEntries">
		SELECT pe.entry_id
		FROM tbl_psc_entries pe
		WHERE pe.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			  AND pe.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
			  AND pe.rejected = 0
	</cfquery>

	<cfoutput>
		<!--- admin-written message goes here (double-check this for font weirdness)--->

		#getContest.welcome_text#

		<p>Hello, #getUser.first_name#!
			You have submitted #getEntries.recordCount# <cfif getEntries.recordCount EQ 1>entry<cfelse>entries</cfif>.
		   	<cfif getEntries.recordCount GT 0>
			   	<cfif hasMasks('cs', session.cas_uid)>
		   			[<a href="#application.appPath#/tools/photoshop-contest/cs-gallery.cfm?userView=1">View</a>]
		   		<cfelse>
		   			[<a href="#application.appPath#/tools/photoshop-contest/consultant-gallery.cfm?userView=1">View</a>]
		   		</cfif>
		   	</cfif>
		</p>
	</cfoutput>

	<h2>Submit an Entry</h2>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post" enctype="multipart/form-data">

		<fieldset>
			<legend>Choose a File to Upload</legend>
			<input type="file" name="frmFile">
			<input type="submit" name="frmAction" value="Submit">
		</fieldset>

	</form>

</cfif>

<style type="text/css">

	h3 {
		margin-top:1%;
		margin-bottom:1%;
	}

	h4 {
		margin-top:0em;
		margin-bottom:0.5em;
	}

	.winners {
		width:100%;
		height: 25%;
		margin-bottom:2%;
	}

	.block-card {
		display:inline-block;
		width: 45%;
		height: 95%;
		margin-left:auto;
		margin-right:auto;
		vertical-align:middle;
		margin: 1%;
		position:relative;
	}

	.block-card img {
		display:inline-block;
		max-height:80%;
		max-width: 95%;
		width:auto;
		height:auto;
		vertical-align:middle;
	}

</style>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>