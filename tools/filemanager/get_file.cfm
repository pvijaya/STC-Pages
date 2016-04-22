<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">

<cfinclude template="file_functions.cfm">

<cfparam name="filePath" type="string" default="">
<cfparam name="fileId" type="integer" default="0">
<cfparam name="fileVersionId" type="integer" default="0">

<cfif fileId gt 0 AND fileVersionId lte 0>
	<!---we were given a file_id, use that to find the current fileVersionId--->
	<cfquery datasource="#application.applicationDataSource#" name="getVersion">
		SELECT TOP 1 file_version_id
		FROM tbl_filemanager_files_versions
		WHERE file_id = #fileId#
		AND use_version = 1
		ORDER BY version_date DESC
	</cfquery>
	<cfloop query="getVersion">
		<cfset fileVersionId = file_version_id>
	</cfloop>
</cfif>

<cfif fileVersionId gt 0><!---fetch a particular version of a file--->
	<!---get details for the file--->
	<cfquery datasource="#application.applicationDataSource#" name="getFileVersion">
		SELECT f.file_id, f.folder_id, f.file_name, v.version_file_name
		FROM tbl_filemanager_files_versions v
		INNER JOIN tbl_filemanager_files f ON f.file_id = v.file_id
		WHERE file_version_id = #fileVersionId#
	</cfquery>
	
	<cfif getFileVersion.recordCount eq 0>
		<cfset draw404("Unable to find File Version Id #fileVersionId#.")>
	</cfif>
	
	<!---fetch file masks--->
	<cfquery datasource="#application.applicationDataSource#" name="getFileMasks">
		SELECT fm.mask_id, um.mask_name
		FROM tbl_filemanager_files_masks fm
		INNER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
		INNER JOIN tbl_filemanager_files f ON f.file_id = fm.file_id
		INNER JOIN tbl_filemanager_files_versions v ON v.file_id = f.file_id
		WHERE v.file_version_id = #fileVersionId#
	</cfquery>
	
	<!---restrict by access level--->
	<cfif getFileMasks.recordCount gt 0 AND NOT isDefined("session.cas_username")>
		<!---send them off to the cas server for authentication.--->
		<cfset casurl = "https://cas.iu.edu/cas/login?cassvc=IU&casurl=https://#cgi.SERVER_NAME##cgi.script_name#?#cgi.QUERY_STRING#">
		<cflocation url="#casurl#" addtoken="no">
	</cfif>
	
	<cfset fileMasks = "">
	<cfloop query="getFileMasks">
		<cfset fileMasks = listAppend(fileMasks, mask_name)>
	</cfloop>
	<cfif fileMasks neq "">
		<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="#fileMasks#">
	</cfif>
	
	<!---we're set, draw the file--->
	<cfset localFilePath = "#fileVault#\#getFileVersion.version_file_name#">

<cfelse><!---normal file fetch by path and name--->
	<!---use pathToFolderId() to find the folder where the file is supposed to be--->
	<cfset pathId = pathToFolderId(filePath)>
	
	<!---verify that file path is actually the path to a file, and not just the path to a folder--->
	<cfset path = folderIdtoPath(pathId)>
	
	<cfset fileId = validFilePath()><!---this function validates that we have a valid path and filename, it then returns the file_id for the file, if it cannot find the file it dies with draw404()--->
	
	<!---now that we have a fileId let's find the private file--->
	<cfquery datasource="#application.applicationDataSource#" name="getFileVersion">
		SELECT TOP 1 fv.version_file_name, f.file_name
		FROM tbl_filemanager_files_versions fv
		INNER JOIN tbl_filemanager_files f ON fv.file_id = f.file_id
		WHERE fv.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		AND use_version = 1
		ORDER BY version_date DESC
	</cfquery>
	
	<cfif getFileVersion.recordCount eq 0>
		<cfset draw404("The file <em>SHOULD</em> exist, but I cannot find the correct version of it.")>
	</cfif>
	
	<!---use fileVault from file_functions.cfm to serve the file--->
	<cfset localFilePath = "#fileVault#\#getFileVersion.version_file_name#">
	<cfset localFilePath = lcase(localFilePath)>
</cfif>

<!---first some mime handling--->
<cfset mimeType = "">
<cfset myMime = getPageContext().getServletContext().getMimeType(localFilePath)>
<cfif isdefined("myMime")>
	<cfset mimeType = myMime>
<cfelse>
	<!---that didn't find a mime type, offer up some options based on file extension.--->
	<cfif right(localFilePath, 4) eq ".m4v">
		<cfset mimeType = "video/x-m4v">
	<cfelseif right(localFilePath, 4) eq ".mp4">
		<cfset mimeType = "video/mp4">
	<cfelseif right(localFilePath, 4) eq ".psd">
		<cfset mimeType = "image/psd">
	<cfelseif right(localFilePath, 5) eq ".docx">
		<cfset mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document">
	<cfelseif right(localFilePath, 5) eq ".xlsx">
		<cfset mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet">
	<cfelseif right(localFilePath, 5) eq ".xlsm">
		<cfset mimeType = "application/vnd.ms-excel.sheet.macroEnabled.12">
	<cfelseif right(localFilePath, 5) eq ".pptx">
		<cfset mimeType = "application/vnd.openxmlformats-officedocument.presentationml.presentation">
	</cfif>
</cfif>
<!---end of mime handling--->

<!---actually serve the file--->
<cftry>	
	<!---give it the right name.--->
	<cfheader name="Content-Disposition" value="filename=""#getFileVersion.file_name#""">
	
	<cfif mimeType neq "">
		<cfcontent file="#localFilePath#" type="#mimeType#">
	<cfelse>
		<!---try to serve it up anyway.--->
		<cfcontent file="#localFilePath#">
	</cfif>
	<cfcatch type="any">
		<cfset draw404("I was unable to retrieve the correct version of this file.")>
	</cfcatch>
</cftry>

<!---functions used to wrangle file paths and verify user input--->
<cffunction name="draw404">
	<cfargument name="errorText" type="string" default="">
	<cfsetting enablecfoutputonly="false">
	<cfset pagetitle="404 File Not Found">
	<cfset homepage = "#application.appPath#/tools/filemanager/manager.cfm">
	<cfmodule template="#application.appPath#/header.cfm">

	The file you requested, <em><cfoutput>#filePath#</cfoutput></em>, was not found.  Please make sure it exists in the <cfoutput><a href="#application.appPath#/tools/filemanager/manager.cfm">File Manager</a></cfoutput>.
	
	<cfif errorText neq "">
		<p><cfoutput>#errorText#</cfoutput></p>
	</cfif>
	<cfinclude template="#application.appPath#/footer.cfm">
	<cfabort>	
</cffunction>


<cffunction name="validFilePath">
	
	<cfset var isValid = 0>
	<cfset var tempPath = "">
	<cfset var fileName = "">
	<cfset var getFile = "">
	<cfset var getFileVersion = "">
	
	<!---temp path will be filePath formatted as though it was a directory, enrobbed in "/"s--->
	<cfset tempPath = filePath>
	<cfif right(tempPath, 1) neq "/">
		<cfset tempPath = tempPath & "/">
	</cfif>
	<cfif left(tempPath, 1) neq "/">
		<cfset tempPath = "/" & tempPath>
	</cfif>
	
	<!---if tempPath and path are identical the user simply entered a directory and no file.--->
	<cfif lcase(tempPath) eq lcase(path)>
		<cfset draw404()>
	</cfif>
	
	<!---find the actual filename, and make sure we have a valid path.--->
	<!---the last item in the filePath will be the file's name--->
	<cfset filePathArray = listToArray(filePath, "/")>
	
	<!---trim off the fileName, and make sure the path matches the path from the database--->
	<cfif arrayLen(filePathArray) gt 1>
		<cfset tempPath = "">
		<cfloop from="1" to="#arrayLen(filePathArray)-1#" index="i">
			<cfset tempPath = tempPath & "/" & filePathArray[i]>
		</cfloop>
		<cfset tempPath = tempPath & "/"><!---finish enrobbing tempPath in "/"s--->
		
		<!---compare tempPath to path from database if they don't match the user entered a folder that doesn't exist--->
		<cfif lcase(tempPath) neq lcase(path)>
			<cfset draw404()>
		</cfif>
	</cfif>
	
	<!---now get our fileName, if filePath isn't an array fail--->
	<cfif arrayLen(filePathArray) gt 0>
		<cfset fileName = filePathArray[arrayLen(filePathArray)]>
	<cfelse>
		<cfset draw404()>
	</cfif>
	
	<!---at this point we know we're looking at a real filePath, and have a fileName to look for.--->
	<cfquery datasource="#application.applicationDataSource#" name="getFile">
		SELECT file_id, file_name, file_description
		FROM tbl_filemanager_files ff
		WHERE ff.folder_id = #pathId#
		AND ff.file_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">
	</cfquery>
	
	<cfif getFile.recordCount eq 0>
		<cfset draw404()>
	</cfif>
	
	<!---we want to restrict access based on the level required to view the file
		 If the required level is 0, don't hassle folks with checkAccess.cfm
	--->
	<cfquery datasource="#application.applicationDataSource#" name="getFileMasks">
		SELECT fm.mask_id, um.mask_name
		FROM tbl_filemanager_files_masks fm
		INNER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
		INNER JOIN tbl_filemanager_files f ON f.file_id = fm.file_id
		WHERE f.folder_id = #pathId#
		AND f.file_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">
	</cfquery>
	
	<cfif getFileMasks.recordCount gt 0 AND NOT isDefined("session.cas_username")>
		<!---send them off to the cas server for authentication.--->
		<cfset casurl = "https://cas.iu.edu/cas/login?cassvc=IU&casurl=https://#cgi.SERVER_NAME##cgi.script_name#?#cgi.QUERY_STRING#">
		<cflocation url="#casurl#" addtoken="no">
	</cfif>
	
	<cfset fileMasks = "">
	<cfloop query="getFileMasks">
		<cfset fileMasks = listAppend(fileMasks, mask_name)>
	</cfloop>
	<cfif fileMasks neq "">
		<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="#fileMasks#">
	</cfif>
	
	<!---we now know where to find the file in our storage area--->
	<cfreturn getFile.file_id>
</cffunction>