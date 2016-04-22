<!---do we need the common functions from stcpages?--->
<cfif not isDefined("stripTags")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<!--- absolute path to protected content--->
<cfset fileVault = "\\bl-uits-slwc1\pie$\Development\uploads">

<!---functions for handling folder recursion--->
<cffunction name="pathToFolderId" output="false">
	<cfargument name="path" type="string" required="true">
	
	<cfset var folderId = 0><!---the folderId to be returned, 0 is root.--->
	<cfset var getFolderId = "">
	<cfset var pathArray = listToArray(path, "/")>
	
	<!---loop over pathArray, and find the deepest folder matching--->
	<cfloop array="#pathArray#" index="i">
		<cfquery datasource="#application.applicationDataSource#" name="getFolderId">
			SELECT folder_id
			FROM tbl_filemanager_folders
			WHERE parent_folder_id = #folderId#
			AND folder_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#i#">
		</cfquery>
		
		<!---if we didn't have a match, return the last found folder--->
		<cfif getFolderId.recordCount eq 0>
			<cfreturn folderId>
		<cfelse>
			<cfset folderId = getFolderId.folder_id>
		</cfif>
	</cfloop>
	
	<cfreturn folderId>	
</cffunction>

<cffunction name="folderIdtoPath" output="false">
	<cfargument name="folderId" type="numeric" required="true">
	<cfargument name="allFolders" type="query" default="#getAllFolders()#"><!---pass one query around so we don't clobber the database doing our recursion.--->
	
	<cfset var path = "/">
	<cfset var parentId = "">
	<cfset var getFolder = "">
	
	<cfloop query="allFolders">
		<cfif folder_id eq folderId>
			<!---add folder to our path--->
			<cfset path = folderIdtoPath(parent_folder_id, allFolders) & folder_name & path>
			<!---we've reached our folder, we can break out of the loop.--->
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn path>
</cffunction>

<cffunction name="getParentFolderId" output="false">
	<cfargument name="folderId" type="numeric" required="true">
	
	<cfset var folderDetails = "">
	<cfset var parentId = 0>
	
	<cfquery datasource="#application.applicationDataSource#" name="folderDetails">
		SELECT parent_folder_id
		FROM tbl_filemanager_folders
		WHERE folder_id = #folderId#
	</cfquery>
	
	<cfif folderDetails.recordCount gt 0>
		<cfset parentId = folderDetails.parent_folder_id>
	</cfif>
	
	<cfreturn parentId>
</cffunction>

<!---a function to fetch all folders, so we can reduce the number of calls when doing recursion.--->
<cffunction name="getAllFolders">
	<cfset var allFolders = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="allFolders">
		SELECT folder_id, parent_folder_id, folder_name
		FROM tbl_filemanager_folders
		ORDER BY folder_name
	</cfquery>
	
	<cfreturn allFolders>
</cffunction>


<!---we need a function to compile all the folders in order--->
<cffunction name="getFolders">
	<cfargument name="folderId" type="numeric" default="0"><!---the parent folder we are grabbing sub-folders for--->
	<cfargument name="allFolders" type="query" default="#getAllFolders()#"><!---pass one query around so we don't clobber the database doing our recursion.--->
	
	<cfset var outputQuery = queryNew("folder_id, folder_path", "integer, varchar")>
	<cfset var childQuery = "">
	<cfset var folderQuery = "">
	
	<!---if we're at root append that value--->
	<cfif folderId eq 0>
		<cfset queryAddRow(outputQuery, 1)>
		<cfset querySetCell(outputQuery, "folder_id", 0)>
		<cfset querySetCell(outputQuery, "folder_path", "/")>
	</cfif>
	
	<cfloop query="allFolders">
		<cfif parent_folder_id eq folderId>
			<cfset queryAddRow(outputQuery, 1)>
			<cfset querySetCell(outputQuery, "folder_id", folder_id)>
			<cfset querySetCell(outputQuery, "folder_path", folderIdtoPath(folder_id, allFolders))>
			
			<!---get and append any child folders--->
			<cfset childQuery = getFolders(folder_id, allFolders)>
			<cfloop query="childQuery">
				<cfset queryAddRow(outputQuery, 1)>
				<cfset querySetCell(outputQuery, "folder_id", folder_id)>
				<cfset querySetCell(outputQuery, "folder_path", folderIdtoPath(folder_id, allFolders))>
			</cfloop>
		</cfif>
	</cfloop>
	
	<cfreturn outputQuery>
</cffunction>

<cffunction name="addFolder">
	<cfargument name="folderName" type="string" required="true">
	<cfargument name="parentFolderId" type="numeric" required="true">
	
	<cfset var getParent = "">
	<cfset var getDupes = "">
	<cfset var addFolderQuery = "">
	<cfset var folderId = 0>
	
	<!---verify and add a new folder--->
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
	
	<!---insert the values into the database, And set the folderId when done.--->
	<cfquery datasource="#application.applicationDataSource#" name="addFolderQuery">
		INSERT INTO tbl_filemanager_folders (parent_folder_id, folder_name)
		VALUES (#parentFolderId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#folderName#">)
		
		SELECT MAX(folder_id) AS folder_id
		FROM tbl_filemanager_folders
	</cfquery>
	
	<cfset folderId = addFolderQuery.folder_id>
	
	<cfreturn folderId>
</cffunction>

<!---you can find the file name of a file uploaded using coldFusion, but you have to delve into the underlying java to do it.--->
<cffunction name="getUploadFileName">
	<cfargument name="fieldName" type="string" required="true">
	
	<cfset var partsArray = Form.getPartsArray()><!---blow-up the form to some primitive Java objects.--->
	<cfset var part = "">
	<cfset var output = "">
	
	<!---loop over the form items until we hit our file.--->
	<cfloop array="#partsArray#" index="part">
		<cfif part.getName() eq fieldName>
			<!---we've found our file's field, try to return the file name.--->
			<cfset output = part.getFileName()>
			
			<!---if java's tools return 'undefined' it clobbers our variable, and we've got to re-initialize it.--->
			<cfif not isDefined("output")>
				<cfset var output = "">
			</cfif>
		</cfif>
	</cfloop>
	
	<cfreturn output>
</cffunction>

<cffunction name="checkDuplicateFiles">
	<cfargument name="folderId" type="numeric" required="true">
	<cfargument name="fileName" type="string" required="true">
	
	<cfset var getFiles = "">
	<cfset var found = 0>
	
	<cfquery datasource="#application.applicationDataSource#" name="getFiles">
		SELECT file_id
		FROM tbl_filemanager_files
		WHERE folder_id = #folderId#
		AND LOWER(file_name) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">)
	</cfquery>
	
	<cfloop query="getFiles">
		<cfset found = file_id>
	</cfloop>
	
	<cfreturn found>
</cffunction>

<cffunction name="uploadFile">
	<cfargument name="pathId" type="numeric" default="-1">
	<cfargument name="fileName" type="string" default="">
	<cfargument name="file" type="string" default=""><!---the name of the form object to upload--->
	<cfargument name="maskList" type="string" default="9"><!---by default restrict uploads to consultant level.--->
	<cfargument name="versionFile" type="boolean" default="true"><!---true means return fileId, version means return versionId--->
	
	<cfset var hasDupes = "">
	<cfset var bulkMasks = bulkGetUserMasks()>
	<cfset var fileMaskLists = "">
	<cfset var getFile = "">
	<cfset var fileResult = "">
	<cfset var fileId = 0>
	<cfset var addFile = "">
	<cfset var auditVersion = "">
	<cfset var addVersion = "">
	<cfset var resultStruct = structNew()>
	<cfset resultStruct['code'] = 400>
	<cfset resultStruct['text'] = "">
	<cfset resultStruct['url'] = "">
	<cfset resultStruct['id'] = "">
	
	<cftry>
		<!---check for dupes and restrict by access level--->
		<cfset hasDupes = checkDuplicateFiles(pathId, fileName)>
		<cfif hasDupes>
			<!---fetch the masks associated with this file.--->
			<cfquery datasource="#application.applicationDataSource#" name="getFile">
				SELECT fm.mask_id
				FROM tbl_filemanager_files_masks fm
				INNER JOIN tbl_filemanager_files f ON f.file_id = fm.file_id
				WHERE f.folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#pathId#">
				AND LOWER(file_name) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">)
			</cfquery>
			<cfloop query="getFile">
				<cfset fileMaskLists = listAppend(fileMaskLists, mask_id)>
			</cfloop>
			
			<cfif not bulkHasMasks(bulkMasks, session.cas_username, fileMaskLists)>
				<cfset resultStruct['code'] = 403>
				<cfset resultStruct['text'] = "Access Level too low">
				<cfreturn resultStruct>
			</cfif>
		</cfif>
		
		<!---place file in storage space--->
		<cffile action="upload" fileField="#file#" destination="#fileVault#" nameconflict="makeunique" result="fileResult">
		<!---cfdump var="#fileResult#"--->
		
		<!---if it is a duplicate find its file_id, if not get it one.--->
		<cfset fileId = checkDuplicateFiles(pathId, fileName)>
		
		<cfif not fileId>
			<!---it's a new file, add it to the database--->
			<cfquery datasource="#application.applicationDataSource#" name="addFile">
				INSERT INTO tbl_filemanager_files (folder_id, file_name)
				OUTPUT inserted.file_id
				VALUES (#pathId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#fileName#">)
			</cfquery>
			
			<cfset fileId = addFile.file_id>
			
			<!---add the permissions to the db.--->
			<cfloop list="#maskList#" index="mask">
				<cfquery datasource="#application.applicationDataSource#" name="addPermissions">
					INSERT INTO tbl_filemanager_files_masks (file_id, mask_id)
					VALUES (
						#addFile.file_id#,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#mask#">
					)
				</cfquery>
			</cfloop>
			
			
			<!---audit this addition--->
			<cfquery datasource="#application.applicationDataSource#" name="auditVersion">
				INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
				VALUES (#fileId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="<b>File Name</b> set to #htmlEditFormat(fileName)#">)
			</cfquery>
		</cfif>
		
		<!---armed with our fileId we can now add the file to tbl_filemanager_files_versions, and set it to be used--->
		<cfquery datasource="#application.applicationDataSource#" name="addVersion">
			UPDATE tbl_filemanager_files_versions
			SET use_version = 0
			WHERE file_id = #fileId#
			
			INSERT INTO tbl_filemanager_files_versions (file_id, version_date, use_version, version_file_name)
			OUTPUT inserted.file_version_id
			VALUES(
				#fileId#,
				GETDATE(),
				1,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#fileResult.serverfile#">
			)
		</cfquery>
		
		<!---audit the addition of this file_version_id--->
		<cfquery datasource="#application.applicationDataSource#" name="auditVersion">
			INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
			VALUES (#fileId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">, '<b>File Version Id</b> #addVersion.file_version_id# added.')
		</cfquery>
		
		<!---index this file for our Verity search collection.--->
		<cfset updateSearch(fileId)>
		
		<!---we've succeeded, and are done.--->
		<cfoutput>
			<cfset resultStruct['code'] = 302>
			<cfset resultStruct['text'] = "Return to file">
			<cfset resultStruct['id'] = fileId>
			<cfif versionFile>
				<cfset resultSTruct['url'] = "#application.appPath#/tools/filemanager/get_file.cfm?fileId=#fileId#">
			<cfelse>
				<cfset resultStruct['url'] = "#application.appPath#/tools/filemanager/get_file.cfm?fileVersionId=#addVersion.file_version_id#">
			</cfif>
			
			<!---now try to generate a thumbnail, if we can.--->
			<cfset generateThumbnail(fileId)>
			
			<cfreturn resultStruct>
		</cfoutput>
		<cfabort>
	<cfcatch type="any">
		<cfset resultStruct['code'] = 400>
		<cfset resultStruct['text'] = "#cfcatch.Message# - #cfcatch.detail#">
		<cfreturn resultStruct>
	</cfcatch>
	</cftry>
	
	<cfset resultStruct['code'] = 400>
	<cfset resultStruct['text'] = "Unhandled error.">
	<cfreturn resultStruct>
</cffunction>

<!---handle trying to generate a thumbnail for a given file--->
<cffunction name="generateThumbnail">
	<cfargument name="fileId" type="Any" default="0">
	
	<cfset var getCurVer = ""><!---query to find latest version--->
	<cfset var myFile = ""><!---holds the full path to the file--->
	<cfset var myImage = ""><!---the image as ColdFusion reads it in.--->
	<cfset var myThumb = fileVault & "/thumbnails/" & fileId & ".jpg"><!---the path where the generated thumbnail should be saved.--->
	
	<cfset var fileDetails = "">
	
	<cftry>
		<cfquery datasource="#application.applicationDataSource#" name="getCurVer">
			SELECT fv.version_file_name
			FROM tbl_filemanager_files f
			INNER JOIN tbl_filemanager_files_versions fv 
				ON fv.file_id = f.file_id
				AND fv.use_version = 1
			WHERE f.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
			ORDER BY version_date ASC
		</cfquery>
		
		<cfloop query="getCurVer">
			<cfset myFile = fileVault & "/" & version_file_name>
			
			<cfif isImageFile(myFile)><!---is the new file version an image CF can process?--->
				<!---it was, so read it, generate a thumbnail, and save it to the thumbnails folder.--->
				<cfset myImage = imageRead(myFile)>
				<cfset imageScaleToFit(myImage, 150, 150)>
				<cfset imageWrite(myImage, myThumb)>
			</cfif>
		</cfloop>
		<!---that's it, we're done.--->
	<cfcatch>
		<!---nothing happens here, we want to fail silently if something blows up.--->
	</cfcatch>
	</cftry>
</cffunction>

<!---handle adding/removing our new/revised/deleted file from our Verity search collection--->
<cffunction name="updateSearch">
	<cfargument name="fileId" type="numeric" default="0">
	
	<cfset var getFile = "">
	<cfset var fileQuery = queryNew("id,article_title,article_body,required_masks,article_date,article_url,category", "varchar,varchar,varchar,varchar,date,varchar,varchar")><!---our output query, where we collapse masks to a single list, and tidy it all up.--->
	<cfset var maskList = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getFile">
		SELECT f.file_id, f.file_name, f.file_description, fv.version_date, fv.version_file_name, um.mask_name
		FROM tbl_filemanager_files f
		INNER JOIN tbl_filemanager_files_versions fv
			ON f.file_id = fv.file_id
			AND fv.use_version = 1
		LEFT OUTER JOIN tbl_filemanager_files_masks fm ON fm.file_id = f.file_id
		LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
		<cfif fileId gt 0>
			WHERE f.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#fileId#">
		<cfelse><!---if fileId is 0 it's a new file so find the most recently created file.--->
			WHERE f.file_id = (
				SELECT TOP 1 file_id
				FROM tbl_filemanager_files
				ORDER BY file_id DESC
			)
		</cfif>
	</cfquery>
	
	<cfoutput query="getFile" group="file_id">
		<cfset maskList = "">
		<cfoutput>
			<cfset maskList = listAppend(maskList, mask_name)>
		</cfoutput>
		
		<cfset queryAddRow(fileQuery)>
		<cfset querySetCell(fileQuery, "id", file_id)>
		<cfset querySetCell(fileQuery, "article_title", reReplace(file_name, "<[^>]*>", "", "all"))><!---trim out html tags and store the title--->
		<cfset querySetCell(fileQuery, "article_body", reReplace(file_description & " " & file_name, "<[^>]*>", "", "all"))>
		<cfset querySetCell(fileQuery, "required_masks", maskList)>
		<cfset querySetCell(fileQuery, "article_date", version_date)>
		<cfset querySetCell(fileQuery, "article_url", "#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#")>
		<cfset querySetCell(fileQuery, "category", "Files")>
	</cfoutput>
	
	
	<cfset indexSearchQuery(fileQuery)>
	
	<!---if the article is gone, delete it from the search collection.--->
	<cfif getFile.recordCount eq 0>
		<cfindex collection="v4-search" action="delete" type="custom" key="f#fileId#">
	</cfif>
</cffunction>

