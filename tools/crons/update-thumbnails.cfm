<!---
	NOTE NOTE NOTE!
	This file runs as a cron-job, and could be run by just about anyone.
	Make sure that the page does not generate any output.

	Currently pages that use UITS badge photos, think of the chat, use the
	fullsize badge image.	This is a problem on mobile devices, so we'd like to
	use the filemanager to manage badge photos.	This way we get to secure the
	images, and use its native thumbnailing feature.

	This file finds users' thumbnails in the PIE, and if it finds a newer version
	of their badge photo there it will will store it in the filemanager.
--->

<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<!---first find our instances of PIE--->
<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT instance_id, instance_name, pie_path
	FROM tbl_instances
	ORDER BY instance_name
</cfquery>

<cfset filesQuery = queryNew("filePath,username,modified", "varchar,varchar,date")>

<cfloop query="getInstances">
	<!---list the contents of the thumbnails directory for this instance of PIE--->
	<cfset pieThumbs = directoryList(expandPath(pie_path) & "\thumbnails", 0, "query")>

	<!---loop over the files we found, and build up a filesQuery with the information we're interested in for each thumbnail--->
	<cfloop query="pieThumbs">
		<cfset myPath = getInstances.pie_path & "thumbnails/" & pieThumbs.name>
		<cfset myUser = listGetAt(pieThumbs.name, 1, ".")>
		<cfset myDate = pieThumbs.dateLastModified>

		<cfset queryAddRow(filesQuery)>
		<cfset querySetCell(filesQuery, "filePath", myPath)>
		<cfset querySetCell(filesQuery, "username", myUser)>
		<cfset querySetCell(filesQuery, "modified", myDate)>
	</cfloop>
</cfloop>

<!---now return filesQuery, but sorted by username, with the most recent thumbnail first.--->
<cfquery dbtype="query" name="sortFiles">
	SELECT *
	FROM filesQuery
	ORDER BY username, modified DESC
</cfquery>


<!---now we're ready to fetch all of our active users, and start pairing them up with their most recent thumbnail--->
<cfquery datasource="#application.applicationDataSource#" name="getActiveUsers">
	SELECT u.username, u.picture_source
	FROM tbl_users u
	WHERE dbo.userHasMasks(u.user_id, 'consultant') = 1
</cfquery>

<!---now see about retreiving the files from the filemanager for the users' badge photos--->
<cfset folderId = pathToFolderId("/images/users/")>

<!---now do a query to find the existing files in the folder.--->
<cfquery datasource="#application.applicationDataSource#" name="getFmFiles">
	SELECT ff.file_id, ff.file_name, MAX(fv.version_date) last_modified
	FROM tbl_filemanager_files ff
	INNER JOIN tbl_filemanager_files_versions fv ON fv.file_id = ff.file_id
	WHERE folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#folderId#">
	GROUP BY ff.file_id, ff.file_name
</cfquery>

<!---now we can loop over every person, see if they:
	0.) Already have an up-to-date picture in the filemanager.
	1.) Already have a filemanager badge picture, but a newer one from PIE
	2.) Need to have a badge picture created in the filemanager.
--->

<cfloop query="getActiveUsers">
    <cfset needsBadge = 2><!---assume they have never updated a badge photo.--->
	<cfset lastModified = '1999-01-01'>
    <cfset myUser = getActiveUsers.username>
    <cfset myFile = "">

	<cfloop query="getFmFiles">
        <cfset myFmUser = listGetAt(file_name, 1, ".")><!---disect the file's name to get the username.--->

        <cfif myUser eq myFmUser>
            <cfset lastModified = last_modified>
            <cfset myFile = expandPath(sortFiles.filePath)>

            <!---do we have a badge picture from one of the PIEs that is more recent than the existing filemanager's version?--->
            <cfloop query="sortFiles">
                <cfif myUser eq username>
                    <cfif dateCompare(lastModified, modified) lt 0>
                        <!---we've found a newer badge pic, upload it.--->
                        <cfset needsBadge = 1>
                        <!---we need to fake out cffile, so we need to tell it where to find the file to "upload."--->
                        <cfset myFile = expandPath(sortFiles.filePath)>

                        <cfbreak>
                    <cfelse>
                        <cfset needsBadge = 0>
                        <cfbreak><!---there doesn't seem to be a newer badge photo.--->
                    </cfif>
                </cfif>
            </cfloop>
        </cfif>

        <!---If we updated a badge we're done for the current user, move on.--->
        <cfif needsBadge eq 0>
            <cfbreak>
        </cfif>
	</cfloop>




    <cfif needsBadge neq 0>
        <!---Now find users who don't yet have badges in the file manager, and try to find a file form them.--->
        <cfif needsBadge eq 2>
            <cfloop query="sortFiles">
                <cfif myUser eq username>
                    <!---this is our user's most recent badge photo, we're done.--->
                    <cfset myFile = expandPath(sortFiles.filePath)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>

        <cfif myFile neq "">
            <cfset myFileId = fauxUpload(folderId, myUser & ".jpg", myFile)>

            <cfquery datasource="#application.applicationDataSource#" name="updatePicture">
                UPDATE tbl_users
                SET picture_source = <cfqueryparam cfsqltype="cf_sql_varchar" value="#application.appPath#/tools/filemanager/get_thumbnail.cfm?fileId=#myFileId#">
                WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myUser#">
            </cfquery>
        </cfif>
    </cfif>

    <!---debugging output
    <cfoutput>
        <p>#myUser# - #dateFormat(lastModified, "mmm d, yyyy")#: #needsBadge#</p>
    </cfoutput>--->

</cfloop>

<!---the filemanager's upload function expects a real upload from a form, so we need to do what it does without an actual form submission.--->
<cffunction name="fauxUpload">
    <cfargument name="pathId" type="numeric" default="-1">
    <cfargument name="fileName" type="string" default="">
    <cfargument name="filePath" type="string" default="">

    <cfset var maskList = "9"><!---in this case we just want the badge photos restricted to the "consultant" mask.--->
    <cfset var fileId = checkDuplicateFiles(pathId, fileName)><!---if it is a duplicate find its file_id, if not we'll make it one later.--->
    <cfset var destFile = fileVault & "\" & fileName><!---where we aim to store our file.--->
    <cfset var addFile = "">
    <cfset var addPermissions = "">
    <cfset var auditVersion = "">

    <!---make sure we have a unique destination filename.--->
    <cfset var uniqueify = 0>
    <cfloop condition="fileExists(destFile)">
        <cfset var destFile = fileVault & "\" & uniqueify & fileName>

        <cfset uniqueify = uniqueify + 1>
    </cfloop>

    <!---read the file from its PIE location, then write it to the filemanager's datasore.--->
    <cffile action="copy" destination="#destFile#" source="#filePath#">

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
            VALUES (#fileId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="tccpie">, <cfqueryparam cfsqltype="cf_sql_varchar" value="<b>File Name</b> set to #htmlEditFormat(fileName)#">)
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
            <cfqueryparam cfsqltype="cf_sql_varchar" value="#listLast(destFile, "\")#">
        )
    </cfquery>

    <!---audit the addition of this file_version_id--->
    <cfquery datasource="#application.applicationDataSource#" name="auditVersion">
        INSERT INTO tbl_filemanager_files_audit (file_id, change_by, audit_text)
        VALUES (#fileId#, 'tccpie', '<b>File Version Id</b> #addVersion.file_version_id# added.')
    </cfquery>

    <!---index this file for our Verity search collection.--->
    <cfset updateSearch(fileId)>
    <!---now try to generate a thumbnail, if we can.--->
    <cfset generateThumbnail(fileId)>

    <cfreturn fileId>
</cffunction>
