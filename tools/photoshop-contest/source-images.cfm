<cfmodule template="#application.appPath#/header.cfm" title='Photoshop Contest'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<!--- cfparams --->
<cfparam name="frmFile" type="string" default="">
<cfparam name="frmAction" type="string" default="">
<cfparam name="action" type="string" default="">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<cfset folderId = 0>

<!--- get the base info for our photoshop contests --->
<cfset contestPath = "/Photoshop Contest/#myInstance.instance_name#">
<cfset contestFolderId = pathToFolderId(contestPath)>

<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>
<cfif getContest.recordCount GT 0>
	<cfset drawNavigation()>
<cfelse>
	<cfset drawNavigationClosed()>
</cfif>

<!--- the source images should be in a particular folder; grab that id --->
<cfquery datasource="#application.applicationDataSource#" name="getFolder">
	SELECT ff.folder_id
	FROM tbl_filemanager_folders ff
	WHERE ff.parent_folder_id = #contestFolderId#
		  AND ff.folder_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="Source Images">
</cfquery>

<!--- handle user input --->
<cftry>

	<cfif frmAction EQ "submit">

		<cfif not hasMasks('cs')>
			<cfthrow message="Permission" detail="You are not permitted to perform that action.">
		</cfif>

		<cfif trim(frmFile) EQ "">
			<cfthrow message="Missing Input" detail="You must choose a file to upload.">
		</cfif>

		<!--- fetch the actual filename, if we can find it. --->
		<cfset filename = getUploadFileName("frmFile")>
		<!---try to ween the suffix for the file that was uploaded.--->
		<cfset suffix = "">
		<cfif listLen(filename, ".") gt 1>
			<cfloop from="2" to="#listLen(filename, '.')#" index="i">
				<cfset suffix = suffix & "." & listGetAt(filename, i, ".")>
			</cfloop>
		</cfif>
		<!---reset the filename to just the username of the person uploading.--->
		<cfset filename = session.cas_username>

		<!--- if the name is invalid or not unique, assign it a unique name --->
		<cfif trim(filename) eq "" OR checkDuplicateFiles(getFolder.folder_id, filename & suffix)>
			<cfset filename = filename & createUUID() & suffix>
		</cfif>

		<!--- upload the file and retrieve its new file_id --->
		<cfset fileId = uploadFile(getFolder.folder_id, filename & suffix, "frmFile", 9, 1)>

		<p class="ok">File uploaded successfully.</p>

	<cfelseif action EQ "remove">

		<!--- only let cs or above remove source images --->
		<cfif NOT hasMasks('cs')>
			<cfthrow message="Permission" detail="You are not permitted to perform that action.">
		</cfif>

		<!--- if all is well, delete the file --->
		<cfquery datasource="#application.applicationDataSource#" name="deleteFile">
			DELETE FROM tbl_filemanager_files
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
				  AND folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getFolder.folder_id#">
		</cfquery>

		<p class="ok">Image removed successfully.</p>

	</cfif>

<cfcatch>
	<p class="warning">
		<cfoutput><span>Error</span> - #cfcatch.message#. #cfcatch.detail# </cfoutput>
	</p>
</cfcatch>

</cftry>


<!--- draw forms --->
<!--- if the folder exists, draw the gallery for it; if not, throw an error --->
<cfif getFolder.recordCount GT 0>

	<h2>Source Images</h2>

	<cfif hasMasks('cs')>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post" enctype="multipart/form-data">

		<fieldset>
			<legend>Upload New Source Image</legend>
			<input type="file" name="frmFile">
			<input type="submit" name="frmAction" value="Submit">
		</fieldset>

	</form>

	</cfif>

	<cfquery datasource="#application.applicationDataSource#" name="getImages">
		SELECT ff.file_id, ff.file_name
		FROM tbl_filemanager_files ff
		INNER JOIN tbl_filemanager_files_versions ffv ON ffv.file_id = ff.file_id
		WHERE ff.folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getFolder.folder_id#">
			  AND ffv.use_version = 1
		ORDER BY version_date DESC
	</cfquery>

	<cfmodule template="#application.appPath#/tools/photoshop-contest/mod-gallery.cfm"
			  images="#getImages#" psc="1" psc_source="1">

<cfelse>

	<p class="alert">The folder could not be found. Please check the Filemanager or contact the Webmaster.</p>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>