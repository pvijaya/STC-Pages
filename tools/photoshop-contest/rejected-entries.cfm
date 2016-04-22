<cfmodule template="#application.appPath#/header.cfm" title='Photoshop Contest'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">

<!--- cfparams --->
<cfparam name="action" type="string" default="">
<cfparam name="fileId" type="integer" default="0">

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
<h2>Rejected Entries</h2>

<!--- handle user input --->
<cftry>
	
	<cfif action EQ "reinstate">
		
		<!--- double check permission to reject - if invalid, bad user, no cookie --->
		<cfif NOT hasMasks('admin')>
			<cfthrow message="Permission" detail="You are not authorized to perform that action.">
		</cfif>
		
		<!--- actually reinstate the image --->
		<cfquery datasource="#application.applicationDataSource#" name="rejectImage">
			UPDATE tbl_psc_entries
			SET rejected = 0
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		</cfquery>
		
		<cfquery datasource="#application.applicationDataSource#" name="getEntryLevel">
			SELECT pe.cs_entry
			FROM tbl_psc_entries pe
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		</cfquery>
		
		<cfif getEntryLevel.cs_entry EQ 1>
			<cfset gallery_url = "cs-gallery.cfm">
		<cfelse>
			<cfset gallery_url = "consultant-gallery.cfm">
		</cfif>
		
		<cfoutput>
			<p class="ok">
				Image reinstated successfully. 
				You may view the image <a href="#application.appPath#/tools/photoshop-contest/#gallery_url#">here</a>.
			</p>
		</cfoutput>
	
	</cfif>
	
	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	
</cftry>

<cfquery datasource="#application.applicationDataSource#" name="getImages">
	SELECT ff.file_id, ff.file_name
	FROM tbl_filemanager_files ff
	INNER JOIN tbl_filemanager_files_versions ffv ON ffv.file_id = ff.file_id
	INNER JOIN tbl_psc_entries pe ON pe.file_id = ff.file_id
	WHERE ff.folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getContest.folder_id#">
		  AND ffv.use_version = 1
		  AND pe.rejected = 1
	ORDER BY version_date DESC
</cfquery>

<!--- we should have a contest folder id now; draw the gallery --->
<cfmodule template="#application.appPath#/tools/photoshop-contest/mod-gallery.cfm" 
		  images="#getImages#" psc="1" psc_rejected="1">

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>