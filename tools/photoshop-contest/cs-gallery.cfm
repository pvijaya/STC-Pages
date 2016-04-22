<cfmodule template="#application.appPath#/header.cfm" title='CS Gallery'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">

<!--- cfparams --->
<cfparam name="userView" type="boolean" default="0"> <!--- view entries the user has submitted --->
<cfparam name="voteView" type="boolean" default="0"> <!--- view entries the user has voted for --->
<cfparam name="action" type="string" default="">
<cfparam name="fileId" type="integer" default="0"> <!--- passed in to reject or vote on an image --->

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<!--- if there is no active contest, they shouldn't be here. kick 'em back to the welcome page --->
<cfif getContest.recordCount EQ 0>
	<cflocation url="welcome.cfm" addtoken="false">
</cfif>

<!--- Header / Navigation --->
<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>
<cfset drawNavigation()>

<!--- handle user input --->
<cftry>
	
	<cfif action EQ "remove">
	
		<!--- make sure there is a valid entry for the given file id --->
		<cfquery datasource="#application.applicationDataSource#" name="getEntry">
			SELECT pe.entry_id, pe.user_id
			FROM tbl_psc_entries pe
			WHERE pe.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
				  AND pe.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		</cfquery>
	
		<cfif getEntry.recordCount EQ 0>
			<cfthrow message="File Not Found" detail="No file with given id found for this contest.">
		</cfif>
	
		<!--- if there is, make sure it belongs to the user --->
		<cfif getEntry.user_id NEQ session.cas_uid>
			<cfthrow message="Permission" detail="You are not permitted to perform that action.">
		</cfif>
		
		<!--- if all is well, delete the entry and the file --->
		<cfquery datasource="#application.applicationDataSource#" name="deleteEntry">
			DELETE FROM tbl_psc_entries
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
				  AND user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
				  AND contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
		</cfquery>
		
		<cfquery datasource="#application.applicationDataSource#" name="deleteFile">
			DELETE FROM tbl_filemanager_files
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
				  AND folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.folder_id#">
		</cfquery>
		
		<p class="ok">Image removed successfully.</p>
	
	<cfelseif action EQ "reject">
		
		<!--- double check permission to reject - if invalid, bad user, no cookie --->
		<cfif NOT hasMasks('admin')>
			<cfthrow message="Permission" detail="You are not authorized to perform that action.">
		</cfif>
		
		<!--- actually reject the image --->
		<cfquery datasource="#application.applicationDataSource#" name="rejectImage">
			UPDATE tbl_psc_entries
			SET rejected = 1,
				rejected_by = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		</cfquery>
		
		<cfoutput>
			<p class="ok">Image rejected successfully. You may view the image <a href="#application.appPath#/tools/photoshop-contest/rejected-entries.cfm">here</a>.</p>
		</cfoutput>
		
	<cfelseif action EQ "vote">
	
		<!--- double check permission to vote - if invalid, bad user, no cookie --->
		<cfif NOT hasMasks('consultant')>
			<cfthrow message="Permission" detail="You are not authorized to perform that action.">
		</cfif>

		<!--- make sure the user hasn't already reached his or her vote limit --->
		<cfquery datasource="#application.applicationDataSource#" name="getVotes">
			SELECT pv.entry_id
			FROM tbl_psc_votes pv
			INNER JOIN tbl_psc_entries pe ON pv.entry_id = pe.entry_id
			WHERE pv.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
				  AND pv.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
				  AND pe.cs_entry = 1
		</cfquery>
		
		<cfif getVotes.recordCount GTE 1>
			<cfthrow message="Error" detail="You have already voted for a CS image.">
		</cfif>
		
		<!--- get the name of the entry that goes with the given file id --->
		<cfquery datasource="#application.applicationDataSource#" name="getEntry">
			SELECT pe.entry_id
			FROM tbl_psc_entries pe
			WHERE pe.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		</cfquery>
		
		<cfif getEntry.recordCount EQ 0>
			<cfthrow message="Error" detail="This image does not correspond to an existing entry.">
		</cfif>
		
		<!--- if all is well, enter the new vote --->
		<cfquery datasource="#application.applicationDataSource#" name="voteForImage">
			INSERT INTO tbl_psc_votes (user_id, contest_id, entry_id)
			VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#getEntry.entry_id#">)
		</cfquery>
		
		<cfoutput>
			<p class="ok">Your vote has been cast!</p>
		</cfoutput>
		
	<cfelseif action EQ "resetVotes">
	
		<!--- double check permission to vote - if invalid, bad user, no cookie --->
		<cfif NOT hasMasks('consultant')>
			<cfthrow message="Permission" detail="You are not authorized to perform that action.">
		</cfif>
		
		<cfquery datasource="#application.applicationDataSource#" name="resetVotes">
			DELETE pv FROM tbl_psc_votes pv
			INNER JOIN tbl_psc_entries pe ON pe.entry_id = pv.entry_id
			WHERE pv.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
				  AND pv.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
				  AND pe.cs_entry = 1
		</cfquery>
		
		<p class="ok">Vote reset successfully.</p>
		
	</cfif>
	
	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	
</cftry>

<!--- draw an extra message if voting is open --->
<cfif hasMasks('consultant') AND getContest.open_vote>
	
	<cfquery datasource="#application.applicationDataSource#" name="getVotes">
		SELECT pv.entry_id
		FROM tbl_psc_votes pv
		INNER JOIN tbl_psc_entries pe ON pe.entry_id = pv.entry_id
		WHERE pv.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			  AND pv.contest_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.contest_id#">
			  AND pe.cs_entry = 1
	</cfquery>
	
	<cfset remVotes = max(0, 1 - getVotes.recordCount)>
	
	<cfoutput>
		<p class="ok">You have #remVotes# CS entry vote<cfif remVotes NEQ 1>s</cfif> remaining.
			<cfif remVotes LT 1>
				[<a href="#application.appPath#/tools/photoshop-contest/cs-gallery.cfm?action=resetVotes"
					onClick="return(confirm('Are you sure you wish to reset your cs entry vote?'))">Reset Votes</a>]		
			</cfif>
		</p>
	</cfoutput>
	
</cfif>

<!--- secondary header --->
<cfif userView>
	<h2>My Entries</h2>
<cfelse>
	<h2>CS Entry Gallery</h2>
</cfif>

<cfquery datasource="#application.applicationDataSource#" name="getImages">
	SELECT ff.file_id, ff.file_name
	FROM tbl_filemanager_files ff
	INNER JOIN tbl_filemanager_files_versions ffv ON ffv.file_id = ff.file_id
	INNER JOIN tbl_psc_entries pe ON pe.file_id = ff.file_id
	<cfif voteView>
		INNER JOIN tbl_psc_votes pv ON pv.entry_id = pe.entry_id
	</cfif>
	WHERE ff.folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.folder_id#">
		  AND ffv.use_version = 1
		  AND pe.rejected = 0
		  AND pe.cs_entry = 1
		  <cfif userView>
		  	AND pe.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		  </cfif>
		  <cfif voteView>
		  	AND pv.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		  </cfif>
	ORDER BY version_date DESC
</cfquery>

<!--- we should have a contest folder id now; draw the gallery --->
<cfmodule template="#application.appPath#/tools/photoshop-contest/mod-gallery.cfm" 
		  images="#getImages#" psc="1" psc_voting="#getContest.open_vote#"
		  psc_userView="#userView#" psc_entries="#getContest.open_entry#"
		  gallery_url="cs-gallery.cfm">

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>