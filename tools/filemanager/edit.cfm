<cfinclude template="file_functions.cfm">

<cfmodule template="#application.appPath#/header.cfm" title='File Manager Edit File'>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="File Manager">

<h1>File Manager Edit File</h1>

<!---handle user input--->
<cftry>
	<cfparam name="fileId" type="integer" default="0">
	<cfparam name="action" type="string" default="edit">
	<cfparam name="fileName" type="string" default="">

	<!---cfparam name="fileMasks" type="string" default=""--->
	<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="fileMasks" default="[]">
	<cfset fileMasks = arrayToList(fileMasks)><!---the multi-selector always returns an array, but we want a list.--->

	<cfparam name="folderId" type="integer" default="0">
	<cfparam name="path" type="string" default="#folderIdtoPath(folderId)#">
	<cfparam name="fileDescription" type="string" default="">
	<cfparam name="fileVersionId" type="integer" default="0">
	<cfparam name="showHistory" type="boolean" default="0">


	<!---fetch the current file info from the database--->
	<cfset getFileDetails = getFileDetailsById(fileId)>

	<cfif getFileDetails.recordCount eq 0>
		<cfthrow type="custom" message="Bad fileId" detail="Unable to find a file with id #fileId#.">
	</cfif>

	<cfif action eq "update">

		<!---we must have a file name--->
		<cfif trim(fileName) eq "">
			<cfthrow type="custom" message="Missing File Name" detail="You must provide a File Name for this file.">
		</cfif>

		<!---must have a valid maskId's - they should only be integers.--->
		<cfloop list="#fileMasks#" index="n">
			<cfif not isValid("integer", n)>
				<cfthrow type="custom" message="Invalid Masks" detail="You have provided an invalid Permissions Mask, please check Required Masks.">
			</cfif>
		</cfloop>

		<!---check if there is a duplicate in the new destination--->
		<cfif folderId neq getFileDetails.folder_id OR fileName neq getFileDetails.file_name>
			<cfquery datasource="#application.applicationDataSource#" name="findDupes">
				SELECT *
				FROM tbl_filemanager_files
				WHERE folder_id = #folderId#
				AND file_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">
			</cfquery>

			<cfif findDupes.recordCount gt 0>
				<cfthrow type="custom" message="Name Conflict" detail="A file named #htmleditformat(fileName)# already exists in #htmleditformat(folderIdtoPath(folderId))#">
			</cfif>
		</cfif>

		<!---everything checks out, commit our changes to the database--->
		<cfquery datasource="#application.applicationDataSource#" name="updateFile">
			UPDATE tbl_filemanager_files
			SET folder_id = #folderId#,
				file_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">,
				file_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#fileDescription#">
			WHERE file_id = #fileId#
		</cfquery>


		<!---now set the correct version of the file--->
		<cfif fileVersionId gt 0>
			<cfquery datasource="#application.applicationDataSource#" name="setVersion">
				<!---clear current setting---->
				UPDATE tbl_filemanager_files_versions
				SET use_version = 0
				WHERE file_id = #fileId#

				<!---set our new value--->
				UPDATE tbl_filemanager_files_versions
				SET use_version = 1
				WHERE file_version_id = #fileVersionId#
			</cfquery>

			<!---redraw the thumbnail to match the new version.--->
			<cfset generateThumbnail(fileId)>
		</cfif>
		<p style="color: green; font-weight: bold;">File successfully updated.</p>

		<!---audit stuff should go heere.--->
		<cfset auditText = "">
		<cfloop query="getFileDetails">
			<cfif folderId neq folder_id>
				<cfset auditText = auditText & "<b>File Path</b> changed from <i>#htmleditformat(folderIdtoPath(folder_id))#</i> to <i>#htmleditformat(folderIdtoPath(folderId))#</i>.<br/>">
			</cfif>
			<cfif fileName neq file_name>
				<cfset auditText = auditText & "<b>File Name</b> changed from <i>#htmleditformat(file_name)#</i> to <i>#htmleditformat(fileName)#</i>.<br/>">
			</cfif>
			<cfif fileDescription neq file_description>
				<cfset auditText = auditText & "<b>Description</b> changed to: #fileDescription#<br/>">
			</cfif>
			<cfif fileVersionId neq file_version_id>
				<cfset auditText = auditText & "<b>File Version Id</b> changed from #file_version_id# to #fileVersionId#.">
			</cfif>
		</cfloop>

		<!---now fetch the current file masks for audits, then make any needed updates--->
		<cfquery datasource="#application.applicationDataSource#" name="getCurrentMasks">
			SELECT fm.mask_id, um.mask_name
			FROM tbl_filemanager_files_masks fm
			INNER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
			WHERE fm.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		</cfquery>

		<cfset changedMasks = 0>
		<cfset maskNameList = "">
		<!---did we remove one of the existing masks?--->
		<cfloop query="getCurrentMasks">
			<cfset maskNameList = listAppend(masknameList, mask_name)>

			<cfif not listFind(fileMasks, mask_id)>
				<cfset changedMasks = 1>
			</cfif>
		</cfloop>

		<!---did we add any new masks?--->
		<cfloop list="#fileMasks#" index="maskId">
			<cfset foundMask = 0>

			<cfloop query="getCurrentMasks">
				<cfif mask_id eq maskId>
					<cfset foundMask = 1>
					<cfbreak>
				</cfif>
			</cfloop>

			<cfif not foundMask>
				<cfset changedMasks = 1>
				<cfbreak>
			</cfif>
		</cfloop>

		<!---now that we know if we've changed masks, commit them to the DB.--->
		<cfif changedMasks>
			<cfquery datasource="#application.applicationDataSource#" name="removeMasks">
				DELETE FROM tbl_filemanager_files_masks
				WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
			</cfquery>

			<cfloop list="#fileMasks#" index="n">
				<cfquery datasource="#application.applicationDataSource#" name="updateMasks">
					INSERT INTO tbl_filemanager_files_masks (file_id, mask_id)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#n#">
					)
				</cfquery>
			</cfloop>

			<cfset auditText = auditText & "<b>Required Masks</b> changed from ""<i>#htmlEditFormat(maskNameList)#</i>"".<br/>">
		</cfif>


		<!---now we're ready to actually record our audit to the db.--->
		<cfif auditText neq "">
			<cfquery datasource="#application.applicationDataSource#" name="addAudit">
				INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
				VALUES(#fileId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">)
			</cfquery>
		</cfif>

		<!---update our Verity index--->
		<cfset updateSearch(fileId)>

		<!---fetch the new details--->
		<cfset getFileDetails = getFileDetailsById(fileId)>

	<cfelseif action eq "deletefile">
		<!---verify the user wants to nuke the file--->
		<p><span style="font-size: large; font-weight: bold; color: red;">Warning!</span> Deleting this file will remove it, and all previous versions of this file, from the server.</p>

		<p>
			Are you sure you wish to continue?
		<cfoutput>
			&nbsp;
			<a href="edit.cfm?action=confirmedDelete&fileId=#fileId#">Yes</a>
			<span style="display: inline-block; width: 1em;">&nbsp;</span>
			<a href="edit.cfm?action=edit&fileId=#fileId#">No</a>
		</cfoutput>
		</p>
	<cfelseif action eq "confirmedDelete">
		<!---actually nuke the file.--->

		<!---find all physical files tied to this fileId--->
		<cfquery datasource="#application.applicationDataSource#" name="getVersions">
			SELECT file_version_id, version_file_name
			FROM tbl_filemanager_files_versions
			WHERE file_id = #fileId#
		</cfquery>

		<!---loop through delete the files from the filesystem--->
		<cfloop query="getVersions">
			<cfif fileExists("#fileVault#\#version_file_name#")>
				<cffile action="delete" file="#fileVault#\#version_file_name#">
			</cfif>
		</cfloop>

		<!---knock-out the thumbnail, too.--->
		<cfif fileExists("#fileVault#\thumbnails\#fileId#.jpg")>
			<cffile action="delete" file="#fileVault#\thumbnails\#fileId#.jpg">
		</cfif>

		<!---with the files gone, remove them from the database--->
		<cfquery datasource="#application.applicationDataSource#" name="removeVersions">
			DELETE FROM tbl_filemanager_files_versions
			WHERE file_id = #fileId#
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="removeMasks">
			DELETE FROM tbl_filemanager_files_masks
			WHERE file_id = #fileId#
		</cfquery>

		<!---remove the file entry--->
		<cfquery datasource="#application.applicationDataSource#" name="removeFileEntry">
			DELETE FROM tbl_filemanager_files
			WHERE file_id = #fileId#
		</cfquery>

		<!---audit what we've done--->
		<cfquery datasource="#application.applicationDataSource#" name="audit">
			INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
			VALUES(#fileId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">, 'File deleted.')
		</cfquery>

		<p style="color: green; font-weight: bold;">File has been removed.</p>
		Return to the <a href="manager.cfm?path=<cfoutput>#urlEncodedFormat(folderIdtoPath(getFileDetails.folder_id))#</cfoutput>">File Manager</a>

		<!---remove the file from our Verity index--->
		<cfset updateSearch(fileId)>

		<cfabort><!---trying to display from here would break.--->

	<cfelseif action eq "deleteversion">
		<!---nuke this particular version, remove it from the database, and audit its removal.--->
		<cfquery datasource="#application.applicationDataSource#" name="getVersion">
			SELECT file_id, use_version, version_file_name
			FROM tbl_filemanager_files_versions
			WHERE file_version_id = #fileVersionId#
		</cfquery>

		<cfif getVersion.recordCount eq 0>
			<cfthrow type="custom" message="Version Deletion" detail="Unable to find file version id #fileVersionId# in the database.">
		</cfif>

		<cfloop query="getVersion">
			<!---remove file--->
			<cfif fileExists("#fileVault#\#version_file_name#")>
				<cffile action="delete" file="#fileVault#\#version_file_name#">
			</cfif>

			<!---before we remove this version from the database, if it's the use_version for our file, set the next most recent version as use_version--->
			<cfif use_version>
				<cfquery datasource="#application.applicationDataSource#" name="newDefault">
					/*blank all*/
					UPDATE tbl_filemanager_files_versions
					SET use_version = 0
					WHERE file_id = (SELECT TOP 1 file_id FROM tbl_filemanager_files_versions WHERE file_version_id = #fileVersionId#)

					/*set the new value*/
					UPDATE tbl_filemanager_files_versions
					SET use_version = 1
					WHERE file_version_id = (
						SELECT TOP 1 file_version_id
						FROM tbl_filemanager_files_versions
						WHERE file_id = (SELECT TOP 1 file_id FROM tbl_filemanager_files_versions WHERE file_version_id = #fileVersionId#)
						AND file_version_id <> #fileVersionId#
						ORDER BY version_date DESC
					)

					/*return the new value*/
					SELECT TOP 1 file_version_id
					FROM tbl_filemanager_files_versions
					WHERE file_id = (SELECT TOP 1 file_id FROM tbl_filemanager_files_versions WHERE file_version_id = #fileVersionId#)
					AND file_version_id <> #fileVersionId#
					ORDER BY version_date DESC
				</cfquery>
			</cfif>

			<!---remove version from database--->
			<cfquery datasource="#application.applicationDataSource#" name="remVersion">
				DELETE FROM tbl_filemanager_files_versions
				WHERE file_version_id = #fileVersionId#
			</cfquery>

			<!---audit our changes.--->
			<cfset auditText = "<b>File Version Id</b> #fileVersionId# deleted and removed from database.<br/>">
			<cfif isDefined("newDefault")>
				<cfset auditText = auditText & "<b>Fil Version Id</b> changed to #newDefault.file_version_id#.<br/>">
			</cfif>
			<cfquery datasource="#application.applicationDataSource#" name="auditVersionDel">
				INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
				VALUES(#file_id#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">)
			</cfquery>

			<cfoutput>
				<p style="color: green; font-weight: bold;">Version #fileVersionId# deleted and removed.</p>
				<cfif isDefined("newDefault")>
					<p style="color: green; font-weight: bold;">Version changed to #newDefault.file_version_id#.</p>
					<cfset fileVersionId = newDefault.file_version_id>
				</cfif>
			</cfoutput>

			<!---fetch the latest info about the file--->
			<cfset getFileDetails = getFileDetailsById(fileId)>

			<!---update our Verity index--->
			<cfset updateSearch(fileId)>

			<!---now try to update our thumbnail, if we can.--->
			<cfset generateThumbnail(fileId)>
		</cfloop>
	</cfif>

	<!---assign our values from the database--->
	<cfloop query="getFileDetails">

		<!---fetch the users masks--->
		<cfset bulkMasks = bulkGetUserMasks()>
		<!---fetch the masks associated with this file.--->
		<cfset fileMaskLists = "">
		<cfquery datasource="#application.applicationDataSource#" name="getFile">
			SELECT fm.mask_id, um.mask_name
			FROM tbl_filemanager_files_masks fm
			INNER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
			WHERE fm.file_id = #fileId#
		</cfquery>
		<cfloop query="getFile">
			<cfset fileMaskLists = listAppend(fileMaskLists, mask_name)>
		</cfloop>

		<cfif fileMaskLists neq "" AND not bulkHasMasks(bulkMasks, session.cas_username, fileMaskLists)>
			<p><span style="color: red; font-weight: bold;">Access Level Too Low</span> - <cfoutput>#htmleditformat(file_name)# requires a permission mask you do not possess.</cfoutput></p>
			<cfabort>
		</cfif>

		<cfif trim(fileName) eq "">
			<cfset fileName = file_name>
		</cfif>


		<cfif folderId eq 0>
			<cfset folderId = folder_id>
		</cfif>

		<cfset path = folderIdtoPath(folderId)>

		<cfif trim(fileDescription) eq "">
			<cfset fileDescription = file_description>
		</cfif>

		<cfif fileVersionId eq 0 AND isNumeric(file_version_id)>
			<cfset fileVersionId = file_version_id>
		</cfif>
	</cfloop>

<cfcatch type="any">
	<cfoutput>
		<p><span style="color: red; font-weight: bold;">#cfcatch.Message#</span> - #cfcatch.Detail#</p>
	</cfoutput>
</cfcatch>

</cftry>

<!---draw the file's info in a form to update it.--->

<!---handling permission masks can be a trick, we use a lot of jquery to sort them out.--->
<!---fetch all masks, for use with some javasript.--->
<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
	SELECT um.mask_id, um.mask_name, um.mask_name, um.mask_notes,
		CASE
			WHEN mr.mask_id IS NULL THEN 0
			ELSE mr.mask_id
		END AS parent_mask_id,
		CASE
				WHEN fm.file_mask_id IS NULL THEN 0
				ELSE 1
			END AS is_used
	FROM tbl_user_masks um
	LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
	LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
	LEFT OUTER JOIN tbl_filemanager_files_masks fm
		ON fm.mask_id = um.mask_id
		AND fm.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">

	ORDER BY um.mask_name
</cfquery>

<!---create two lists for javascript, one of available masks and another of applied masks--->
<cfset availList = arrayNew(1)>
<cfset usedList = arrayNew(1)>
<cfset allMasks = arrayNew(1)>
<cfloop query="getAllMasks">
	<cfset maskStruct = structNew()>
	<cfset maskStruct["maskId"] = mask_id>
	<cfset maskStruct["name"] = mask_name>

	<cfset arrayAppend(allMasks, maskStruct)>

	<cfif is_used eq 0>
		<cfset arrayAppend(availList, maskStruct)>
	<cfelse>
		<cfset arrayAppend(usedList, maskStruct)>
	</cfif>
</cfloop>


<cfoutput>
<form action="edit.cfm" method="post" class="form-horizontal">
	<input type="hidden" name="fileId" value="#fileId#">
	<input type="hidden" name="action" value="update">

	<h2>Edit "#htmleditformat(fileName)#"</h2>

	<cfset bootstrapCharField("fileName", "File Name", fileName)>

	<!---build the array of folder values to draw a selector.--->
				<cfset folders = getFolders()>
	<cfset foldersArray = arrayNew(1)>
				<cfloop query="folders">
		<cfset arrayAppend(foldersArray, {"name"=folder_path,"value"=folder_id})>
				</cfloop>

	<cfset bootstrapSelectField("folderId", foldersArray, "Folder", folderId, "The category that our current category belongs to.")>

		<!---Fetch the masks used by this file, and feed that to the drawMasksSelector function.--->
		<cfset fileMasks = "">
		<cfloop query="getAllMasks">
		<cfif is_used AND not listFind(fileMasks, mask_id)>
				<cfset fileMasks = listAppend(fileMasks, mask_id)>
			</cfif>
		</cfloop>
	<cfset drawMasksSelector("fileMasks", fileMasks, "Required Masks", "The masks required to view this file.")>

	<cfset bootstrapEditorField("fileDescription", "Description", fileDescription, "", {"toolbar" = "Custom", "toolbar_Custom"=[],"height"="5em"})>

	<div class="form-group">
		<label class="col-sm-3 control-label">Preview</label>
		<div class="col-sm-9" role="alert">
			<img src="get_thumbnail.cfm?fileId=#fileId#" alt="Preview">
		</div>
	</div>

	<!---now make the options for picking the active version of the file.--->
			<!---get all versions--->
			<cfquery datasource="#application.applicationDataSource#" name="getVersions">
				SELECT file_version_id, version_date, use_version
				FROM tbl_filemanager_files_versions
				WHERE file_id = #fileId#
				ORDER BY version_date DESC
			</cfquery>

	<cfset versionArray = arrayNew(1)>
				<cfloop query="getVersions">
		<cfset myOpt = structNew()>
		<cfset myOpt["value"] = file_version_id>
		<cfset myOpt["name"] = "#dateFormat(version_date, "mmm d, yyyy")# #timeFormat(version_date, "long")#">

		<cfset myOpt["name"] = myOpt["name"] & ' <a href="get_file.cfm?fileVersionId=#file_version_id#" target="_blank" class="btn btn-default btn-xs" title="Open Version"><span class="glyphicon glyphicon-share"></span></a>'>
		<cfset myOpt["name"] = myOpt["name"] & ' <a href="edit.cfm?fileVersionId=#file_version_id#&fileId=#fileId#&action=deleteversion" onClick="return confirm(''Are you certain you wish to permanently delete this version?'')" class="btn btn-default btn-xs"  title="Delete this version"><span class="glyphicon glyphicon-trash"></span></a>'>

		<cfset arrayAppend(versionArray, myOpt)>
				</cfloop>

	<cfset bootstrapRadioField("fileVersionId", versionArray, "Version", fileVersionId)>

	<input class="btn btn-primary col-sm-offset-3" type="submit" value="Update">

</form>

<!---offer to upload a new version--->
<p/>
<form action="uploader.cfm" method="post" enctype="multipart/form-data" class="form-horizontal">
	<cfoutput>
		<input type="hidden" name="pathId" value="#folderId#">
		<input type="hidden" name="filename" value="#htmlEditFormat(fileName)#">
		<input type="hidden" name="frmUrl" value="#application.appPath#/tools/filemanager/edit.cfm?fileId=#fileId#&action=edit">
		<input type="hidden" name="action" value="upload">
	</cfoutput>

	<h2>Add New Version</h2>

	<div class="form-group">
		<label class="col-sm-3 control-label" for="newVer">File</label>
		<div class="col-sm-9" role="alert">
			<input type="file"  name="file" id="newVer">
		</div>
	</div>

	<input class="btn btn-primary col-sm-offset-3" type="submit" value="Upload">

<!---table class="stripe">
	<tr class="titlerow">
		<td colspan="2">Add New Version</td>
	</tr>
	<tr>
		<td>File:</td>
		<td>
		<cfoutput>
			<input type="file"  name="file">
		</cfoutput>
		</td>
	</tr>
	<tr class="titlerow">
		<td>&nbsp;</td>
		<td>
			<input type="submit"  value="Upload">
		</td>
	</tr>
</table--->
</form>

<cfif showHistory>
	<!---fetch history of audits--->
	<cfquery datasource="#application.applicationDataSource#" name="getHistory">
		SELECT change_by, change_time, audit_text
		FROM tbl_filemanager_files_audit
		WHERE file_id = #fileId#
		ORDER BY change_time DESC
	</cfquery>
	<p>
		<a href="edit.cfm?action=edit&fileId=#fileId#&showHistory=0">Hide History</a>
	</p>
	<p>
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="2">File History</td>
		</tr>
	<cfset cnt = 0>
	<cfloop query="getHistory">
		<tr class="<cfif cnt mod 2 eq 0>tasktablerow1<cfelse>tasktablerow2</cfif>">
			<td valign="top" align="right">
				#dateFormat(change_time, "mmm d, yyyy")# #timeformat(change_time, "short")#<br/>
				<span style="font-size: smaller; text-decoration: italic;">#change_by#</span>
			</td>
			<td valign="top">
				#audit_text#
			</td>
		</tr>
		<cfset cnt = cnt + 1>
	</cfloop>
	</table>
	</p>
<cfelse>
	<p>
		<a href="edit.cfm?action=edit&fileId=#fileId#&showHistory=1">Show History</a>
	</p>
</cfif>

Return to the <a href="manager.cfm?path=#urlEncodedFormat(folderIdtoPath(folderId))#">File Manager</a>

</cfoutput>


<!---this query is used several times, so let's make it a function.--->
<cffunction name="getFileDetailsById">
	<cfset var getFileDetails = "">

	<cfquery datasource="#application.applicationDataSource#" name="getFileDetails">
		SELECT folder_id, file_name, file_description,
			(SELECT TOP 1 file_version_id FROM tbl_filemanager_files_versions WHERE file_id = #fileId# AND use_version = 1 ORDER BY version_date DESC) as file_version_id
		FROM tbl_filemanager_files
		WHERE file_id = #fileId#
	</cfquery>

	<cfreturn getFileDetails>
</cffunction>

<cfinclude template="#application.appPath#/footer.cfm">