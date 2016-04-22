<cfmodule template="#application.appPath#/header.cfm" title='File Manager Selection Mask Editor'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
<cfinclude template="file_functions.cfm">
<cfparam name="path" type="string" default="/">
<cfparam name="CKEditorFuncNum" type="integer" default="0"><!---used by ckeditor to return browsed for files--->
<cfparam name="checkType" type="string" default="0">
<cfparam name="action" type="string" default="edit">

<cfset folderId = pathToFolderId(path)><!---get a folder based on the user provided path(makes sure it's valid)--->
<!---<cfset path = folderIdtoPath(folderId)><!---set path to the valid name of our folderId---> --->
<!---cfparam name="fileMasks" type="string" default=""--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="fileMasks" default="[]">
<cfset fileMasks = arrayToList(fileMasks)><!---the multi-selector always returns an array, but we want a list.--->

<!---there's one other thing we need.  Since files are limitted to people who have the right masks we have to find all of this user's mask_id's.--->
<cfset userMasks = bulkGetUserMasks(session.cas_username)>
<cfset userMaskIds = "">
<cfloop query="userMasks">
	<cfset userMaskIds = listAppend(userMaskIds, mask_id)>
</cfloop>


<!---whether we're viewing or updating we need to run the getFilesMasks query, which has been made into a funtion for easy reuse.--->
<cfset getFilesMasks = filesAndMasksQuery()>

<!---handle when a user submits the form--->
<cfif action eq "update">
	<cfset filesArray = arrayNew(1)>
	<!---use the specially ordered query, getFilesMasks, to build an array with structs representing the current state of the files.--->
	<!---we only want to manipulate files the user has the masks to work with, so build a filesList instead of using checkType.--->
	<cfset filesList = "">
	<cfloop query="getFilesMasks" group="file_id">
		<cfset fileStruct = structNew()>

		<cfset fileStruct.fileId = file_id>
		<cfset fileStruct.fileName = file_name>
		<cfset fileStruct.masks = "">

		<!---build-up the masks for each file.--->
		<cfloop>
			<cfset fileStruct.masks = listAppend(fileStruct.masks, mask_name)>
		</cfloop>

		<!---now that our struct is complete add it to the array--->
		<cfset arrayAppend(filesArray, fileStruct)>

		<!---also update filesList--->
		<cfset filesList = listAppend(filesList, file_id)>
	</cfloop>


	<!---with the current data safely tucked away in filesArray, make the actual changes to the masks used by each file.--->
	<!---remove the existing masks.--->
	<cfquery datasource="#application.applicationDataSource#" name="removeMasks">
		DELETE FROM tbl_filemanager_files_masks
		WHERE file_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#filesList#" list="true">)
	</cfquery>
	<!---add the new masks to the file(s)--->
	<cfif listLen(fileMasks) gt 0>
		<cfset cnt = 1><!---used to put a comma before all but the last VALUE in the insert query.--->
		<cfset totalCnt = listLen(filesList) * listLen(fileMasks)>

		<cfquery datasource="#application.applicationDataSource#" name="addMasks">
			INSERT INTO tbl_filemanager_files_masks (file_id, mask_id)
			VALUES
			<cfloop list="#filesList#" index="fileId">
				<cfloop list="#fileMasks#" index="maskId">
					(<cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">)<cfif cnt lt totalCnt>,</cfif>

					<!---update cnt for the next pass.--->
					<cfset cnt = cnt + 1>
				</cfloop>
			</cfloop>
		</cfquery>
	</cfif>

	<!---with the new masks in place record the audit data we made earlier.--->
	<cfloop array="#filesArray#" index="file">
		<!---build-up the audit text.--->
		<cfset auditText = "<b>Required Masks</b> changed from ""<i>" & file.masks & "</i>"".">
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#file.fileId#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
	</cfloop>

	<!---since we've updated the masks we need to get a fresh version of getFilesMasks for the display code below.--->
	<cfset getFilesMasks = filesAndMasksQuery()>

	<!---spit out a success message--->
	<p style="color: green; font-weight: bold;">File masks successfully updated and audited.</p>
</cfif>



<table class="stripe" style="width: 100%;">
		<tr class="titlerow">
		<th colspan="5">
			<cfoutput>#path#</cfoutput>
		</th>
	</tr>
	<tr class="titlerow2" style="width: auto">
		<th></th>
		<th>Name</th>
		<th>Date</th>
		<th>Level</th>
		<th>Desc.</th>
	</tr>

	<!---we also want to build-up a list of all the masks used by files in getFilesMasks as we go.--->
	<cfset fileMasks = "">
	<cfoutput query="getFilesMasks" group="file_id">
		<tr>
			<td align="right">
				<div class="btn-group">
					<!---don't display if we're just browsing.--->
					<cfif CKEditorFuncNum eq 0>
						<a href="edit.cfm?fileId=#file_id#&action=deletefile" class="btn btn-default" title="Delete File"><span class="glyphicon glyphicon-trash"></span></a>
						<a href="edit.cfm?fileId=#file_id#&action=edit" class="btn btn-default" title="Edit File"><span class="glyphicon glyphicon-pencil"></span></a>
					</cfif>

				</div>
			</td>
			<td>
				<a href="get_file.cfm?filePath=#urlEncodedFormat(path & file_name)#" target="_blank" class="filelink">
					<img src="get_thumbnail.cfm?fileId=#file_id#" style="max-height: 50px; max-width: 100px; vertical-align: text-top;">
					#file_name#
				</a>
			</td>
			<td>
				#dateFormat(version_date, "mmm d, yyyy")# #timeFormat(version_date, "short")#
			</td>
			<td>
				<!---use our grouping to draw the masks--->
				<cfoutput>
					<span class="btn btn-default btn-xs">#mask_name#</span>
					<!---building up our filemasks list if we've encountered a mask we don't already have.--->
					<cfif not listFind(fileMasks, mask_id)>
						<cfset fileMasks = listAppend(fileMasks, mask_id)>
					</cfif>
				</cfoutput>
			</td>
			<td>
				<cfset maxLen = 100>
				#left(stripTags(file_description), maxLen)#
				<cfif len(stripTags(file_description)) gt maxLen>...</cfif>
			</td>
		</tr>
	</cfoutput>

	<tr class="titlerow">
	<td colspan="5">
		&nbsp;
	</td>
	</tr>
</table>

<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post" class="form-horizontal">
	<cfoutput>
		<input type="hidden" name="checkType" value="#htmlEditFormat(checkType)#">
		<input type="hidden" name="action" value="update">
	</cfoutput>

	<!---draw the masks selector using the fileMasks we built up earlier.--->
	<cfset drawMasksSelector("fileMasks", fileMasks, "Required Masks", "The masks required to view this file.")>
	<input class="btn btn-primary col-sm-offset-3" type="submit" value="Update">
</form>
<p>Return to the <a href="manager.cfm?path=<cfoutput>#urlEncodedFormat(path)#</cfoutput>">File Manager</a></p>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>


<!---we use the getFilesMasks query in multiple places, so make it a function to be reused.--->
<cffunction name="filesAndMasksQuery">
	<cfset var getFilesMasks = "">

	<cfquery datasource="#application.applicationDatasource#" name="getFilesMasks">
		SELECT f.file_id, f.file_name, f.file_description, fv.version_date, m.mask_id, m.mask_name
		FROM tbl_filemanager_files f
		LEFT OUTER JOIN tbl_filemanager_files_versions fv
			ON fv.file_id = f.file_id
			AND fv.use_version = 1
		LEFT OUTER JOIN tbl_filemanager_files_masks fm ON fm.file_id = f.file_id
		LEFT OUTER JOIN tbl_user_masks m On m.mask_id = fm.mask_id
		WHERE f.file_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#checkType#" list="true">)
		/*Limit the files to be edited to files the user has masks for.*/
		AND 0 = (
			SELECT COUNT(mask_id)
			FROM tbl_filemanager_files_masks
			WHERE file_id = f.file_id
			AND mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userMaskIds#" list="true">)
		)
		ORDER BY f.file_id, m.mask_name DESC
	</cfquery>

	<cfreturn getFilesMasks>
</cffunction>
