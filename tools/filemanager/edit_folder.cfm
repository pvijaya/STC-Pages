<cfinclude template="file_functions.cfm">

<cfmodule template="#application.appPath#/header.cfm" title='File Manager Edit Folder'>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<h1>File Manager Edit Folder</h1>
<cftry>
	<cfparam name="folderId" type="integer" default="-1">
	<cfparam name="parentFolderId" type="integer" default="-1">
	<cfparam name="folderName" type="string" default="">
	<cfparam name="action" type="string" default="">

	<cfif find("/", folderName)>
		<cfthrow type="custom" message="Folder name" Detail="Folder names cannot include the / character.">
	</cfif>

	<cfif action eq "update">
		<!---verify user input is valid--->
		<cfif folderId lte 0>
			<cfthrow type="custom" message="Folder Id" detail="You must provide a valid Folder Id, you provided #folderId#.">
		</cfif>

		<cfif trim(folderName) eq "">
			<cfthrow type="custom" message="Folder Name" detail="You must provide a name for this folder.">
		</cfif>

		<!---verify parent folder exists--->
		<cfif parentFolderId neq 0>
			<cfquery datasource="#application.applicationDataSource#" name="getParent">
				SELECT *
				FROM tbl_filemanager_folders
				WHERE folder_id = #parentFolderId#
			</cfquery>

			<cfif getParent.recordCount eq 0>
				<cfthrow type="custom" message="Parent Folder" detail="You must provide a Parent Folder for this folder.">
			</cfif>
		</cfif>

		<!---verify a folder does not already exist with folderName in parentFolderId--->
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT *
			FROM tbl_filemanager_folders
			WHERE parent_folder_id = #parentFolderId#
			AND folder_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#folderName#">
		</cfquery>
		<cfif getDupes.recordCount gt 0>
			<cfthrow type="custom" message="Folder Name" detail="A folder named ""#htmlEditFormat(folderName)#"" already exists in Parent Directory.">
		</cfif>

		<!---both attributes check out, make the change.--->
		<cfquery datasource="#application.applicationDataSource#" name="updateFolder">
			UPDATE tbl_filemanager_folders
			SET folder_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#folderName#">,
				parent_folder_id = #parentFolderId#
			WHERE folder_id  = #folderId#
		</cfquery>

	<cfelseif action eq "newsubmit">
		<!---verify and add a new folder--->
		<cfset folderId = addFolder(folderName, parentFolderId)>
		<p style="color: green; font-weight: bold;">Folder Added</p>

	<cfelseif action eq "delete">
		<!---display confirmation screen--->
		<p><span style="font-size: large; font-weight: bold; color: red;">Warning!</span> Deleting this folder will remove it, and all the files/folders it contains, from the server.</p>

		<p>
			Are you sure you wish to continue?
		<cfoutput>
			&nbsp;
			<a href="edit_folder.cfm?action=confirmedDelete&folderId=#folderId#">Yes</a>
			<span style="display: inline-block; width: 1em;">&nbsp;</span>
			<a href="edit_folder.cfm?folderId=#folderId#">No</a>
		</cfoutput>
		</p>
	<cfelseif action eq "confirmeddelete">
		<!---delete folder, and all its contents from the database--->
		<cfset folders = isolateBranch(folderId)>
		<cfloop query="folders">
			<cfset deleteFolder(folder_id)>
			<cfoutput>Deleted #htmlEditFormat(folder_path)#<br/></cfoutput>
		</cfloop>

		<p style="color: green; font-weight: bold;">Complete</p>

		<cfoutput><p>Return to the <a href="manager.cfm">File Manager</a></p></cfoutput>
		<cfinclude template="#application.appPath#/footer.cfm">
		<cfabort><!---with folder removed we should stop rendering--->
	</cfif>

<cfcatch type="any">
	<cfoutput>
		<p><span style="color: red; font-weight: bold;">#cfcatch.Message#</span> - #cfcatch.Detail#</p>
	</cfoutput>
</cfcatch>
</cftry>

<!---our default functionality--->
<cfquery datasource="#application.applicationDataSource#" name="getFolderDetails">
	SELECT parent_folder_id, folder_name
	FROM tbl_filemanager_folders
	WHERE folder_id = #folderId#
</cfquery>

<cfloop query="getFolderDetails">
	<cfif folderId lte 0>
		<p><span style="color: red; font-weight: bold;">Invalid folder</span> - <cfoutput>#folderId# is not a valid Folder Id.</cfoutput></p>
		<cfabort>
	</cfif>

	<cfif trim(folderName) eq "">
		<cfset folderName = folder_name>
	</cfif>

	<cfif parentFolderId lt 0>
		<cfset parentFolderId = parent_folder_id>
	</cfif>
</cfloop>


<!---now our default display code--->

<form action="edit_folder.cfm" method="post">
<input type="hidden" name="folderId" value="<cfoutput>#folderId#</cfoutput>">
<table class="task_table">
	<tr class="titlerow">
		<td colspan="2">
			<cfif folderId lt 0>
				New Folder
				<input type="hidden" name="action" value="newsubmit">
			<cfelse>
				Edit "<cfoutput>#htmlEditFormat(getFolderDetails.folder_name)#</cfoutput>"
				<input type="hidden" name="action" value="update">
			</cfif>
		</td>
	</tr>
	<tr>
		<td align="right">Name:</td>
		<td>
			<input type="text" pattern="[^\/]+" title="Do not include '/' in the names" name="folderName" value="<cfoutput>#htmlEditFormat(folderName)#</cfoutput>">
		</td>
	</tr>
	<tr>
		<td align="right">Parent Folder:</td>
		<cfset folders = removeBranch(folderId)>
		<td>
			<select name="parentFolderId" >
			<cfoutput query="folders">
				<option value="#folder_id#" <cfif folder_id eq parentFolderId>selected</cfif>>#htmlEditFormat(folder_path)#</option>
			</cfoutput>
			</select>
		</td>
	</tr>
	<tr class="titlerow">
		<td></td>
		<td><input type="submit"  value="submit"></td>
	</tr>
</table>
</form>

<cfoutput><p>Return to the <a href="manager.cfm?path=#urlEncodedFormat(folderIdtoPath(parentFolderId))#">File Manager</a></p></cfoutput>

<cfinclude template="#application.appPath#/footer.cfm">

<cffunction name="removeBranch">
	<cfargument name="folderId" type="numeric" required="true"><!---folder to remove, along with its childeren--->

	<cfset var folders = getFolders()>
	<cfset var outputQuery = queryNew("folder_id, folder_path", "integer, varchar")>
	<cfset var found = 0>
	<cfset var path = "">
	<cfset var i = "">

	<!---loop through folders to find folderId's folder_path--->
	<cfloop query="folders">
		<cfif folder_id eq folderId>
			<cfset path = folder_path>
			<cfset found = 1>
			<cfbreak>
		</cfif>
	</cfloop>

	<cfif not found>
		<cfreturn folders>
	<cfelse>
		<!---strip out all folders starting with #path#--->
		<cfloop query="folders">
			<cfset found = 0>

			<cfloop from="1" to="#len(folder_path)#" index="i">
				<cfif left(folder_path, i) eq path AND folder_id neq 0>
					<cfset found = 1>
					<cfbreak>
				</cfif>
			</cfloop>

			<cfif not found>
				<cfset queryAddRow(outputQuery, 1)>
				<cfset querySetCell(outputQuery, "folder_id", folder_id)>
				<cfset querySetCell(outputQuery, "folder_path", folder_path)>
			</cfif>
		</cfloop>
	</cfif>

	<cfreturn outputQuery>
</cffunction>

<!---this isolates a branch of the directory tree beneath folderId--->
<cffunction name="isolateBranch">
	<cfargument name="folderId" type="numeric" required="true">

	<cfset var folders = getFolders()>
	<cfset var excludedFolders = removeBranch(folderId)>
	<cfset var found = 0>
	<cfset var outputQuery = queryNew("folder_id, folder_path", "integer, varchar")>

	<!---loop through folders, where we don't match an item in excludedFolders add that entry to output--->
	<cfloop query="folders">
		<cfset found = 0>
		<cfloop query="excludedFolders">
			<cfif folders.folder_id eq excludedFolders.folder_id>
				<cfset found = 1>
				<cfbreak>
			</cfif>
		</cfloop>

		<cfif not found>
			<cfset queryAddRow(outputQuery, 1)>
			<cfset querySetCell(outputQuery, "folder_id", folder_id)>
			<cfset querySetCell(outputQuery, "folder_path", folder_path)>
		</cfif>
	</cfloop>

	<cfreturn outputQuery>
</cffunction>

<!---delete all versions of all files in this folder--->
<cffunction name="deleteFolder">
	<cfargument name="folderId" type="numeric" required="true">

	<cfset var getFiles = "">
	<cfset var getVersions = "">
	<cfset var remVersions = "">
	<cfset var remFile = "">
	<cfset var remFolder = "">

	<!---get the files for this directory--->
	<cfquery datasource="#application.applicationDataSource#" name="getFiles">
		SELECT file_id
		FROM tbl_filemanager_files
		WHERE folder_id = #folderId#
	</cfquery>

	<cfloop query="getFiles">
		<!---fetch all versions of this file.--->
		<cfquery datasource="#application.applicationDataSource#" name="getVersions">
			SELECT version_file_name
			FROM tbl_filemanager_files_versions
			WHERE file_id = #getFiles.file_id#
		</cfquery>

		<!---remove all those files--->
		<cfloop query="getVersions">
			<cfif fileExists("#fileVault#\#version_file_name#")>
				<cffile action="delete" file="#fileVault#\#version_file_name#">
			</cfif>
		</cfloop>

		<!---with the files gone remove the versions from the database.--->
		<cfquery datasource="#application.applicationDataSource#" name="remVersions">
			DELETE FROM tbl_filemanager_files_versions
			WHERE file_id = #getFiles.file_id#
		</cfquery>

		<!---remove the files from the database--->
		<cfquery datasource="#application.applicationDataSource#" name="remFile">
			DELETE FROM tbl_filemanager_files
			WHERE file_id = #file_id#

			/*audit the change*/
			INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
			VALUES(#file_id#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">, 'File deleted.')
		</cfquery>
	</cfloop>

	<!---with that done we can now remove the folder--->
	<cfquery datasource="#application.applicationDataSource#" name="remFolder">
		DELETE FROM tbl_filemanager_folders
		WHERE folder_id = #folderId#
	</cfquery>
</cffunction>