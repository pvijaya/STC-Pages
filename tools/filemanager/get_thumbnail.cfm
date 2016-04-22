<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">

<cfinclude template="file_functions.cfm">

<cfparam name="fileId" type="integer" default="0">

<!---this is just a viewer, if they haven't authenticated send a 403 error.--->
<cfif not isDefined("session.cas_uid")>
	<cfheader statuscode="403" statustext="Not logged in.">
	<cfabort>
</cfif>

<!---find the file's information, the current version and masks the user must have to see them.--->
<cfquery datasource="#application.applicationDataSource#" name="getFileDetails">
	SELECT f.file_id, f.file_name, fv.version_file_name, um.mask_name
	FROM tbl_filemanager_files f
	INNER JOIN tbl_filemanager_files_versions fv 
		ON fv.file_id = f.file_id
		AND fv.use_version = 1
	INNER JOIN tbl_filemanager_files_masks fm ON fm.file_id = f.file_id
	INNER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
	WHERE f.file_id = #fileId#
</cfquery>

<!---build-up a list of masks required to view this file.--->
<cfset maskList = "">
<cfset myFile = "">
<cfset myThumb = "#fileVault#/thumbnails/#fileId#.jpg">
<cfloop query="getFileDetails">
	<cfset maskList = listAppend(maskList, mask_name)>
	<cfset myFile = "#fileVault#/#version_file_name#">
</cfloop>

<cfif not hasMasks(maskList)>
	<cfheader statuscode="403" statustext="Missing permission masks.">
	<cfabort>
</cfif>

<!---we've had some odd requests where the wrong thumbnail image is being sent back.  Let's see if locking it takes care of that.--->
<cflock timeout="20" name="thumbnailLock">
	
	<!---at this point we're in the clear.  If the thumbnail exists, draw it.--->
	<cfif fileExists(myThumb)>
		<cfcontent file="#myThumb#" type="image/jpeg">
	<cfelse>
		<!---didn't find a thumbnail, try to serve-up an apropriate icon.--->
		<!---we're going to start like we do in the regular get file, by mime type.--->
		<cfset mimeType = "unknown">
		<cfset myMime = getPageContext().getServletContext().getMimeType(myFile)>
		<cfif isdefined("myMime")>
			<cfset mimeType = myMime>
		<cfelse>
			<!---that didn't find a mime type, offer up some options based on file extension.--->
			<cfif right(myFile, 4) eq ".m4v">
				<cfset mimeType = "video/x-m4v">
			<cfelseif right(myFile, 4) eq ".mp4">
				<cfset mimeType = "video/mp4">
			<cfelseif right(myFile, 4) eq ".psd">
				<cfset mimeType = "image/psd">
			<cfelseif right(myFile, 5) eq ".docx">
				<cfset mimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document">
			<cfelseif right(myFile, 5) eq ".xlsx">
				<cfset mimeType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet">
			<cfelseif right(myFile, 5) eq ".xlsm">
				<cfset mimeType = "application/vnd.ms-excel.sheet.macroEnabled.12">
			<cfelseif right(myFile, 5) eq ".pptx">
				<cfset mimeType = "application/vnd.openxmlformats-officedocument.presentationml.presentation">
			</cfif>
		</cfif>
		
		<!---now, based on the mime type we hit select an icon to draw.--->
		<cfswitch expression="#mimeType#">
			<!---Images we couldn't thumbnail. eg photoshop, pdfs, et al.--->
			<cfcase value="image/x-photoshop">
				<cfcontent file="#fileVault#/thumbnails/image-x-generic.png">
			</cfcase>
			<cfcase value="application/pdf">
				<cfcontent file="#fileVault#/thumbnails/x-office-document.png">
			</cfcase>
			
			<!---archives--->
			<cfcase value="application/zip">
				<cfcontent file="#fileVault#/thumbnails/package-x-generic.png">
			</cfcase>
			
			<!---spreadsheets--->
			<cfcase value="application/vnd.ms-excel">
				<cfcontent file="#fileVault#/thumbnails/x-office-spreadsheet.png">
			</cfcase>
			<cfcase value="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet">
				<cfcontent file="#fileVault#/thumbnails/x-office-spreadsheet.png">
			</cfcase>
			<cfcase value="application/vnd.ms-excel.sheet.macroEnabled.12">
				<cfcontent file="#fileVault#/thumbnails/x-office-spreadsheet.png">
			</cfcase>
			
			<!---Documents--->
			<cfcase value="text/html">
				<cfcontent file="#fileVault#/thumbnails/text-html.png">
			</cfcase>
			<cfcase value="text/css">
				<cfcontent file="#fileVault#/thumbnails/text-css.png">
			</cfcase>
			<cfcase value="text/plain">
				<cfcontent file="#fileVault#/thumbnails/text-x-generic.png">
			</cfcase>
			<cfcase value="application/vnd.openxmlformats-officedocument.wordprocessingml.document">
				<cfcontent file="#fileVault#/thumbnails/x-office-document.png">
			</cfcase>
			<cfcase value="application/msword">
				<cfcontent file="#fileVault#/thumbnails/x-office-document.png">
			</cfcase>
			
			<!---presentations--->
			<cfcase value="application/vnd.openxmlformats-officedocument.presentationml.presentation">
				<cfcontent file="#fileVault#/thumbnails/x-office-presentation.png">
			</cfcase>
			<cfcase value="application/vnd.ms-powerpoint">
				<cfcontent file="#fileVault#/thumbnails/x-office-presentation.png">
			</cfcase>
			
			<!---video--->
			<cfcase value="video/mp4">
				<cfcontent file="#fileVault#/thumbnails/video-x-generic.png">
			</cfcase>
			<cfcase value="application/x-shockwave-flash">
				<cfcontent file="#fileVault#/thumbnails/video-x-generic.png">
			</cfcase>
			<cfcase value="video/quicktime">
				<cfcontent file="#fileVault#/thumbnails/video-x-generic.png">
			</cfcase>
			<cfcase value="video/x-m4v">
				<cfcontent file="#fileVault#/thumbnails/video-x-generic.png">
			</cfcase>
			
			<!---audio--->
			<cfcase value="audio/x-mpeg">
				<cfcontent file="#fileVault#/thumbnails/audio-x-generic.png">
			</cfcase>
			
			<!---scripts--->
			<cfcase value="text/javascript">
				<cfcontent file="#fileVault#/thumbnails/text-x-script.png">
			</cfcase>
			<cfcase value="application/postscript">
				<cfcontent file="#fileVault#/thumbnails/text-x-script.png">
			</cfcase>
			
			<cfdefaultcase>
				<cfcontent file="#fileVault#/thumbnails/emblem-system.png">
			</cfdefaultcase>
		</cfswitch>
	</cfif>
</cflock>