<cfmodule template="#application.appPath#/header.cfm" title='Photoshop Contest'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- The Photoshop Contest tools require a particular Filemanager organization --->
<!--- Photoshop Contest (top-level folder)                                                  --->
<!--- TCC IUB                                 || TCC IUPUI                                  --->
<!--- Archives | Source Images                ||  Archives | Sources Images                 --->

<!--- The instance (TCC IUB, etc.) folder will additionally contain the folder of the active contest, if one exists --->
<!--- The Archives folder will contain the folders of all retired Photoshop Contests --->
<!--- The user should not have to create contest folders --->

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmContestId" type="integer" default="0">
<cfparam name="frmName" type="string" default="">
<cfparam name="frmDeadline" type="date" default="#now()#">
<cfparam name="frmSetActive" type="boolean" default="0">
<cfparam name="frmWelcomeText" type="string" default="">
<!--- sanitize the date --->
<cfset frmDeadline = dateFormat(frmDeadline, "mmm d, yyyy ") & "00:00">

<cfset myInstance = getInstanceById(session.primary_instance)>

<cfset folderId = 0>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<!--- now that we have an instance, get the base info for our photoshop contests --->
<cfset contestPath = "/Photoshop Contest/#myInstance.instance_name#">
<cfset archivesPath = "/Photoshop Contest/#myInstance.instance_name#/Archives">
<cfset contestFolderId = pathToFolderId(contestPath)>
<cfset archivesFolderId = pathToFolderId(archivesPath)>

<!--- Header / Navigation --->
<!--- block off the source images and gallery links if there is not an active contest --->
<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>

<cfif getContest.recordCount GT 0>
	<cfset drawNavigation()>
<cfelse>
	<cfset drawNavigationClosed()>
</cfif>

<!--- handle user input --->
<cfif frmAction EQ "Back">
	<cfset frmAction = "">
	<cfset frmContestId = 0>
</cfif>

<cftry>

	<!--- create a new contest --->
	<cfif frmAction EQ "create">
	
		<!--- check user inputs for validity --->
		<cfif trim(frmName) eq "">
			<cfthrow message="Missing Input" detail="Name is a required field, and cannot be left blank.">
		</cfif>
		
		<cfif NOT isDate(frmDeadline)>
			<cfthrow message="Invalid Input" detail="Deadline must be a valid date.">
		</cfif>
		
		<!--- this is a tad more complex, but it helps us make sure our file system has the proper set-up --->
		<!--- the less the user has to fuss about with the Filemanager, the better --->
		<cfquery datasource="#application.applicationDataSource#" name="checkContest">
			SELECT pc.contest_name
			FROM tbl_psc_contests pc
			WHERE pc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
				  AND pc.contest_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmName#">
		</cfquery>
		
		<!--- dont let the user duplicate contest names within an instance --->
		<cfif checkContest.recordCount GT 0>
			<cfthrow message="Error" detail="A contest with this name already exists.">
		</cfif>
		
		<cfquery datasource="#application.applicationDataSource#" name="checkFolders">
			SELECT ff.folder_id, ff.parent_folder_id
			FROM tbl_filemanager_folders ff
			WHERE (ff.parent_folder_id = #contestFolderId#
				   OR ff.parent_folder_id = #archivesFolderId#)
				  AND ff.folder_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmName#">
		</cfquery>
		
		<!--- the folder name should correspond to the contest name, so alert the user if --->
		<!--- we find an existing same-name folder --->
		<cfif checkFolders.recordCount GT 0>
			<cfthrow message="Error" detail="A folder with name #frmName# already exists. Please rename this folder or choose another name for the contest.">
		</cfif>
		
		<!--- if all is well, create the folder for our new photoshop contest --->
		<cfquery datasource="#application.applicationDataSource#" name="createFolder">
			INSERT INTO tbl_filemanager_folders (parent_folder_id, folder_name)
			OUTPUT inserted.folder_id
			VALUES (<cfif frmSetActive>
						<cfqueryparam cfsqltype="cf_sql_integer" value="#contestFolderId#">
					<cfelse>
						<cfqueryparam cfsqltype="cf_sql_integer" value="#archivesFolderId#">
					</cfif>,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmName#">)
		</cfquery>
		<cfset folderId = createFolder.folder_id>
		
		<!--- finally, create the contest --->
		<cfquery datasource="#application.applicationDataSource#" name="createContest">
			INSERT INTO tbl_psc_contests (contest_name, instance_id, deadline, folder_id, open_entry, open_vote, retired)
			OUTPUT inserted.contest_id, inserted.folder_id
			VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmName#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">,
					<cfqueryparam cfsqltype="cf_sql_date" value="#frmDeadline#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#folderId#">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="0">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="0">,
					<cfif frmSetActive>
						<cfqueryparam cfsqltype="cf_sql_bit" value="0">
					<cfelse>
						<cfqueryparam cfsqltype="cf_sql_bit" value="1">
					</cfif>
					)
		</cfquery>
		
		<!--- if the user chose this new contest to be the active one, retire all others --->
		<cfif frmSetActive>
			<cfquery datasource="#application.applicationDataSource#" name="updateFolders">
				UPDATE tbl_filemanager_folders
				SET parent_folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#archivesFolderId#">
				WHERE folder_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#createContest.folder_id#">
					  AND parent_folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contestFolderId#">
					  AND folder_name != 'Archives'
					  AND folder_name != 'Source Images'
			</cfquery>
			<cfquery datasource="#application.applicationDataSource#" name="updateContests">
				UPDATE tbl_psc_contests
				SET retired = 1,
					open_entry = 0,
					open_vote = 0
				WHERE contest_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#createContest.contest_id#">
					  AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
			</cfquery>
			
		</cfif>
		
		<p class="ok">Contest created successfully.</p>

	<!--- edit an existing contest --->	
	<cfelseif frmAction EQ "edit">
	
		<cfif NOT isDate(frmDeadline)>
			<cfthrow message="Invalid Input" detail="Deadline must be a valid date.">
		</cfif>
		<cfoutput>#frmDeadline#</cfoutput>
		<cfquery datasource="#application.applicationDataSource#" name="updateContest">
			UPDATE tbl_psc_contests
			SET deadline = <cfqueryparam cfsqltype="cf_sql_date" value="#frmDeadline#">, 
				welcome_text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmWelcomeText#">
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContestId#">
		</cfquery>
			
		<p class="ok">Contest updated successfully.</p>

	<!--- open or close the contest to entries --->
	<cfelseif frmAction EQ "openForEntries" OR frmAction EQ "closeForEntries">

		<cfquery datasource="#application.applicationDataSource#" name="updateContest">
			UPDATE tbl_psc_contests
			SET open_entry = <cfif frmAction EQ "openForEntries">1<cfelse>0</cfif>
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContestId#">
		</cfquery>

	<!--- open or close the contest to voting --->
	<cfelseif frmAction EQ "openForVotes" OR frmAction EQ "closeForVotes">
	
		<cfquery datasource="#application.applicationDataSource#" name="updateContest">
			UPDATE tbl_psc_contests
			SET open_vote = <cfif frmAction EQ "openForVotes">1<cfelse>0</cfif>
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContestId#">
		</cfquery>

	<!--- retire or activate the contest --->
	<cfelseif frmAction EQ "retire" OR frmAction EQ "makeActive">

		<cfquery datasource="#application.applicationDataSource#" name="getContest">
			SELECT pc.folder_id, pc.contest_id
			FROM tbl_psc_contests pc
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContestId#">
		</cfquery>

		<!--- regardless of which action we want, set the 'open' variables to false for now --->
		<!--- we want to make sure a contest is only open when the user chooses --->
		<cfquery datasource="#application.applicationDataSource#" name="updateContest">
			UPDATE tbl_psc_contests
			SET retired = <cfif frmAction EQ "retire">1<cfelse>0</cfif>,
				open_entry = 0,
				open_vote = 0
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContestId#">
		</cfquery>
		
		<!--- we only want the folder for the active contest in the Photoshop Contest/#instance_name# folder --->
		<!--- retired folders should be moved to the archives --->
		<cfquery datasource="#application.applicationDataSource#" name="updateFolder">
			UPDATE tbl_filemanager_folders
			SET parent_folder_id = <cfif frmAction EQ "retire">
										<cfqueryparam cfsqltype="cf_sql_integer" value="#archivesFolderId#">
									<cfelse>
										<cfqueryparam cfsqltype="cf_sql_integer" value="#contestFolderId#">
									</cfif>
			WHERE folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.folder_id#">
		</cfquery>
		
		<!--- if we are activating a particular contest, retire all the other ones --->
		<!--- this involves moving the folder and setting the contest retired bit --->
		<cfif frmAction EQ "makeActive">
			<cfquery datasource="#application.applicationDataSource#" name="updateFolders">
				UPDATE tbl_filemanager_folders
				SET parent_folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#archivesFolderId#">
				WHERE folder_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.folder_id#">
					  AND parent_folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contestFolderId#">
					  AND folder_name != 'Archives'
					  AND folder_name != 'Source Images'
			</cfquery>
			<cfquery datasource="#application.applicationDataSource#" name="updateContests">
				UPDATE tbl_psc_contests
				SET retired = 1,
					open_entry = 0,
					open_vote = 0
				WHERE contest_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
					  AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
			</cfquery>
		</cfif>

	</cfif>

<cfcatch>
	<cfoutput>
		<p class="warning">
			#cfcatch.Message# - #cfcatch.Detail#
		</p>
	</cfoutput>
</cfcatch>
</cftry>

<!--- draw forms --->
<cfif frmAction EQ "createnew">

	<h2>Create New Photoshop Contest</h2>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<cfoutput>
		
			<input type="hidden" name="frmContestId" value="#frmContestId#">
		
			<table>
				<tr>
					<td><label for="name">Name:</label></td>
					<td><input id="name" name="frmName" placeholder="<cfoutput>#dateFormat(now(), "yyyy")#</cfoutput>" 
					           value="<cfoutput>#htmlEditFormat(frmName)#</cfoutput>"></td>
				</tr>
				<tr>
					<td><label for="deadline">Deadline:</label></td>
					<td><input class="date" name="frmDeadline" value="#dateFormat(frmDeadline,  "MMM d, yyyy")#"></td>
				</tr>	
							
			</table>
			
			<p class="tinytext">
				Note: The Photoshop contest will automatically close at 12:00 AM on the chosen deadline date. <br/>
				So, if you wish to accept submissions until 11:59 PM on April 15th, the deadline here should be set to April 16th.
			</p>
			
			Make this the active contest?
			<label><input type="radio" name="frmSetActive" value="1" <cfif frmSetActive>checked="true"</cfif>>Yes</label>
			<label><input type="radio" name="frmSetActive" value="0" <cfif NOT frmSetActive>checked="true"</cfif>>No</label>
		
			<br/>
			
		</cfoutput>
		
		<br/>
			
		<!--- datepicker javascript - gives us the nice calendar inputs --->
		<script type="text/javascript">
			$(document).ready(function() {
			// make the dates calendars.
			$("input.date").datepicker({dateFormat: 'M d, yy'});
			});
		</script>
			
		<input name="frmAction" type="submit" value="Create">
		<input name="frmAction" type="submit" value="Cancel">
		
	</form>

<cfelseif frmContestId GT 0>

	<h2 style="margin-bottom:0em">Manage Photoshop Contest</h2>

	<!--- fetch the contest's information --->
	<cfquery datasource="#application.applicationDataSource#" name="getContest">
		SELECT pc.deadline, pc.open_entry, pc.open_vote, pc.retired, pc.contest_name, pc.welcome_text
		FROM tbl_psc_contests pc
		WHERE pc.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContestId#">
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" class="form-horizontal" method="post">
	
		<cfoutput>
			
			<!--- write out some informative messages --->
			<!--- tell the user the contest status (retired or active), --->
			<!--- as well as if it is open for entries or voting --->
			<cfif getContest.retired>
				<p class="alert">Viewing an inactive contest.</p>
			<cfelse>
				<p class="ok">Viewing the active contest.</p>
				<cfif getContest.open_entry>
					<p class="ok">This contest is open for entries.</p>
				</cfif>
				<cfif getContest.open_vote>
					<p class="ok">This contest is open for voting.</p>
				</cfif>
			</cfif>
		
			<cfset frmDeadline = getContest.deadline>
			<cfset frmWelcomeText = getContest.welcome_text>
			<cfset retired = getContest.retired>
			<cfset openForEntries = getContest.open_entry>
			<cfset openForVotes = getContest.open_vote>
		
			<input type="hidden" name="frmContestId" value="#frmContestId#">
			
			<cfoutput>#bootstrapTextDisplay("name", "Name", "#getContest.contest_name#", "", "")#</cfoutput>
			<cfoutput>#bootstrapCharField("frmDeadline", "Deadline", "#dateFormat(frmDeadline,  "MMM d, yyyy")#", "", "")#</cfoutput>
			<div class="col-sm-offset-3 col-sm-9">
				<p class="tinytext">
					Note: The Photoshop contest will automatically close at 12:00 AM on the chosen deadline date. <br/>
					So, if you wish to accept submissions until 11:59 PM on April 15th, the deadline here should be set to April 16th.
				</p>	
			</div>
			

			

			<cfset welcomeMessageEditorOptions = {"customConfig" = "#application.appPath#/js/ckeditor/config.cfm"}>
			<cfset welcomeMessageEditorOptions["filebrowserBrowseUrl"] = "#application.appPath#/tools/filemanager/manager.cfm?path=%2Fimages%2Farticles%2F">
			<cfset welcomeMessageEditorOptions["filebrowserUploadUrl"] = "#application.appPath#/tools/photoshop-contest/upload.cfm">
			<cfset welcomeMessageEditorOptions["filebrowserWindowFeatures"] = "resizable=yes,scrollbars=yes">
			<cfoutput>#bootstrapEditorField("frmWelcomeText", "Welcome Message", "#frmWelcomeText#", "", welcomeMessageEditorOptions)#</cfoutput>
            
			<br/>
			<!--- buttons the user can use for easy retiring, activation, opening, or closing of a contest --->
			<div class="col-sm-offset-3 col-sm-9">
				<cfif retired>
					[<a href="#application.appPath#/tools/photoshop-contest/manager.cfm?frmAction=makeActive&frmContestId=#frmContestId#"
						onClick="return confirm('Are you sure you want to make this the active contest?')">Make Active</a>]
			
				<cfelse>
					<cfif not openForEntries>
						[<a href="#application.appPath#/tools/photoshop-contest/manager.cfm?frmAction=openForEntries&frmContestId=#frmContestId#"
							onClick="return confirm('Are you sure you want to open this contest? Users will be able to submit new entries.')">Open</a>]
					<cfelse>
						[<a href="#application.appPath#/tools/photoshop-contest/manager.cfm?frmAction=closeForEntries&frmContestId=#frmContestId#"
							onClick="return confirm('Are you sure you want to close this contest? Users will no longer be able to submit entries.')">Close</a>]
					</cfif>
					
					<cfif not openForVotes>
						[<a href="#application.appPath#/tools/photoshop-contest/manager.cfm?frmAction=openForVotes&frmContestId=#frmContestId#"
							onClick="return confirm('Are you sure you want to allow voting?')">Open Voting</a>]
					<cfelse>
						[<a href="#application.appPath#/tools/photoshop-contest/manager.cfm?frmAction=closeForVotes&frmContestId=#frmContestId#"
							onClick="return confirm('Are you sure you want to close voting? Users will no longer be able to vote.')">Close Voting</a>]
					</cfif>
				
					[<a href="#application.appPath#/tools/photoshop-contest/manager.cfm?frmAction=retire&frmContestId=#frmContestId#"
						onClick="return confirm('Are you sure you want to retire this contest? It will no longer be visible to users.')">Retire</a>]
				</cfif>
			</div>
			<br/>
									
		</cfoutput>
		
		<br/>
		
		<!--- datepicker javascript - gives us the nice calendar inputs ------------------------------------------------------------------------------------------------------------------->
		<script type="text/javascript">
			$(document).ready(function() {
			// make the dates calendars.
			$("input[name=frmDeadline]").datepicker({dateFormat: 'M d, yy'});
			});
		</script>
		<div class="col-sm-offset-3 col-sm-9">
			<input name="frmAction" type="submit" value="Edit">
			<input name="frmAction" type="submit" value="Back">
		</div>
		
	</form>

<cfelse>

	<cfquery datasource="#application.applicationDataSource#" name="getContests">
		SELECT pc.contest_id, pc.contest_name, pc.deadline, pc.open_entry, pc.open_vote, pc.folder_id, pc.retired
		FROM tbl_psc_contests pc
		WHERE pc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
		ORDER BY pc.deadline DESC
	</cfquery>

	<cfquery datasource="#application.applicationDataSource#" name="checkForActive">
		SELECT pc.contest_id
		FROM tbl_psc_contests pc
		WHERE pc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
			  AND pc.retired = 0
		ORDER BY pc.deadline DESC
	</cfquery>

	<!--- write a warning if there is not an active contest --->
	<cfif checkForActive.recordCount EQ 0>
		<p class="alert">
			No active contest selected.
		</p>
	</cfif>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<fieldset style="margin-top:2em;">
		
			<legend>Choose</legend>
			
			<label>
				Select a Photoshop Contest:
				<select name="frmContestId">
					<cfoutput query="getContests">
						<option value="#contest_id#">
							#contest_name# <cfif NOT #retired#>(active)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			
			<input name="frmAction" type="submit" value="Go">
				
			<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
			
			<a href="<cfoutput>#cgi.script_name#?frmAction=createnew</cfoutput>">Create New Photoshop Contest</a>
		
		</fieldset>
		
	</form>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>