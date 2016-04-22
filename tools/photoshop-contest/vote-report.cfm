<cfmodule template="#application.appPath#/header.cfm" title='Photoshop Contest'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<cfparam name="frmAction" type="string" default="">
<cfparam name="frmConRunnerUp" type="integer" default="0">
<cfparam name="frmConWinner" type="integer" default="0">
<cfparam name="frmCSRunnerUp" type="integer" default="0">
<cfparam name="frmCSWinner" type="integer" default="0">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<!--- if there is no active contest, they shouldn't be here. kick 'em back to the welcome page --->
<cfif getContest.recordCount EQ 0>
	<cflocation url="welcome.cfm" addtoken="false">
</cfif>

<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>
<cfset drawNavigation()>

<!--- handle user input --->

<cftry>

	<cfif frmAction EQ "post results">
	
		<!--- check user inputs for validity --->
		<cfif frmConWinner EQ 0>
			<cfthrow message="Missing Input" detail="You must select a consultant contest winner.">
		</cfif>
		
		<cfif frmConRunnerUp EQ 0>
			<cfthrow message="Missing Input" detail="You must select a consultant contest runner-up.">
		</cfif>

		<cfif frmCSWinner EQ 0>
			<cfthrow message="Missing Input" detail="You must select a CS contest winner.">
		</cfif>
		
		<cfif frmConWinner EQ frmConRunnerUp>
			<cfthrow message="Invalid Input" detail="The winner and runner-up must be two different entries.">
		</cfif>
		
		<!--- finally, remove the old winners (if any existed) and insert the updated winners --->
		<cfquery datasource="#application.applicationDataSource#" name="removeOldWinners">
			DELETE FROM tbl_psc_winners
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
		</cfquery>
		
		<cfquery datasource="#application.applicationDataSource#" name="addWinners">
			INSERT INTO tbl_psc_winners (contest_id, entry_id, runner_up)
			VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmConWinner#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="0">),
				   (<cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmConRunnerUp#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="1">),
				   (<cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmCSWinner#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="0">)
		</cfquery>
		
		<!--- just in case, close the contest to entries and voting --->
		<cfquery datasource="#application.applicationDataSource#" name="updateContest">
			UPDATE tbl_psc_contests
			SET open_entry = 0,
				open_vote = 0
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
		</cfquery>
	
	<cfelseif frmAction EQ "clear results">
		
		<!--- this is an easy one - just clear the winner data out --->
		<cfquery datasource="#application.applicationDataSource#" name="removeOldWinners">
			DELETE FROM tbl_psc_winners
			WHERE contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
		</cfquery>
		
		<cfset frmConWinner = 0>
		<cfset frmConRunnerUp = 0>
		<cfset frmCSWinner = 0>
		
		<p class="ok">The contest winner information has been sucessfully cleared.</p>
		
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

<!--- retrieve the existing winner information, if any exists --->
<cfquery datasource="#application.applicationDataSource#" name="getWinners">
	SELECT pw.entry_id, pw.runner_up, pe.cs_entry
	FROM tbl_psc_winners pw
	INNER JOIN tbl_psc_entries pe ON pe.entry_id = pw.entry_id
	WHERE pw.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
</cfquery>

<cfif getWinners.recordCount GT 0>
	<cfloop query="getWinners">
		<cfif cs_entry EQ 0>
			<cfif not runner_up>
				<cfset frmConWinner = entry_id>
			<cfelse>
				<cfset frmConRunnerUp = entry_id>
			</cfif>
		<cfelse>
			<cfif not runner_up>
				<cfset frmCSWinner = entry_id>
			</cfif>
		</cfif>
	</cfloop>
	<p class="ok">The results for this photoshop contest have been posted.</p>
</cfif>

<h2 style="margin-bottom:0.5em;">Vote Report</h2>

<cfquery datasource="#application.applicationDataSource#" name="getVotes">
	SELECT pe.entry_id, pe.file_id, u.username, u.first_name, u.last_name, COUNT(pv.vote_id) AS votes,
		   pe.cs_entry
	FROM tbl_psc_entries pe
	LEFT OUTER JOIN tbl_psc_votes pv ON pv.entry_id = pe.entry_id
	INNER JOIN tbl_users u ON u.user_id = pe.user_id
	WHERE pe.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
		  AND pe.rejected = 0
	GROUP BY pe.entry_id, pe.file_id, u.username, u.first_name, u.last_name, pe.cs_entry
	ORDER BY votes DESC
</cfquery>

<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

	<cfif getVotes.recordCount EQ 0>
	
		No votes have been submitted for this contest.
	
	<cfelse>
	
		<input type="submit" name="frmAction" value="Post Results"
		   onClick="return(confirm('Post the results of this Photoshop Contest? The results will be visible to viewers.'))">
		<!--- if the winners have been posted, allow the option to clear them --->
		<cfif getWinners.recordCount GT 0>
		<input type="submit" name="frmAction" value="Clear Results"
			   onClick="return(confirm('Clear the results of this Photoshop Contest? The results will no longer be visible.'))"> 
		</cfif>
		<br/>

		<h3>Consultant Entries</h3>

		<table class="stripe">
		
			<tr class="titlerow">
				<th>Submitted By</th>
				<th>Username</th>
				<th>Votes</th>
				<th>Image</th>
				<th>Winner</th>
				<th>Runner-Up</th>
			</tr>
			
			<cfloop query="getVotes">
				
				<cfif cs_entry EQ 0>
				
					<cfoutput>
						<tr>
							<td>#first_name# #last_name#</td>
							<td>#username#</td>
							<td>#votes#</td>
							<td><img src="#application.appPath#/tools/filemanager/get_thumbnail.cfm?fileId=#file_id#"></td>
							<td><input type="radio" name="frmConWinner" value="#entry_id#"
								 <cfif frmConWinner EQ entry_id>checked="true"</cfif>>
							</td>
							<td><input type="radio" name="frmConRunnerUp" value="#entry_id#"
								 <cfif frmConRunnerUp EQ entry_id>checked="true"</cfif>>
							</td>
						</tr>
					</cfoutput>
					
				</cfif>
					
			</cfloop>
		
		</table>
		
		<h3>CS Entries</h3>

		<table class="stripe">
		
			<tr class="titlerow">
				<th>Submitted By</th>
				<th>Username</th>
				<th>Votes</th>
				<th>Image</th>
				<th>Winner</th>
			</tr>
			
			<cfloop query="getVotes">
				
				<cfif cs_entry EQ 1>
				
					<cfoutput>
						<tr>
							<td>#first_name# #last_name#</td>
							<td>#username#</td>
							<td>#votes#</td>
							<td><img src="#application.appPath#/tools/filemanager/get_thumbnail.cfm?fileId=#file_id#"></td>
							<td><input type="radio" name="frmCSWinner" value="#entry_id#"
								 <cfif frmCSWinner EQ entry_id>checked="true"</cfif>>
							</td>
						</tr>
					</cfoutput>
					
				</cfif>
					
			</cfloop>
		
		</table>
		
	</cfif>
	
</form>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>