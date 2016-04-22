<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<!---used with CKeditor to upload files to the TCC filemanager.--->

<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<cftry>
	<cfparam name="CKEditorFuncNum" type="integer" default="0">   
	<cfparam name="fileName" type="string" default="">
	<cfparam name="upload" type="any" default="">
	
	<cfif CKEditorFuncNum eq 0>
		<!---return an error--->
		This page must be used with CKedtior to upload files for the document editor.
		<cfabort>
	</cfif>
	
	<!---fetch the actual filename, if we can find it.--->
	<cfset fileName = getUploadFileName("upload")>
	
	<!---if we didn't provide a unique name.--->
	<cfif trim(filename) eq "">
		<cfset filename = createUUID()>
	</cfif>
	
	<cfset myFolderId = pathToFolderId("/Photoshop Contest/Welcome Images/")>
	
	<!--- at this point make sure we have a unique filename, if it matches an existing file it'll just upload it as a new version of the existing one, which could break existing articles.--->
	<cfif checkDuplicateFiles(myFolderId, filename)>
		<!---append a unique string to the end of the filename--->
		<cfif find(".", fileName)>
			<cfset fileName = replace(fileName, ".", createUUID() & ".", "one")>
		<cfelse>
			<cfset fileName = fileName & createUUID()>
		</cfif>
	</cfif>
	<!---at this point we sure as shooting have a unique filename.--->
	
	<!---now process the file the user provided--->
	<cfset result = uploadFile(myFolderId, fileName, "upload", 9, 1)>
	
	<!---send the result back to ckeditor--->
	<script type="text/javascript">
	<cfif result['code'] eq 302>
		window.parent.CKEDITOR.tools.callFunction(<cfoutput>#CKEditorFuncNum#, '#result["url"]#', ''</cfoutput>);
	<cfelse>
		window.parent.CKEDITOR.tools.callFunction(<cfoutput>#CKEditorFuncNum#, '', '#result["text"]#'</cfoutput>);
	</cfif>
	</script>
<cfcatch type="any">
	<script type="text/javascript">
		window.parent.CKEDITOR.tools.callFunction(<cfoutput>#CKEditorFuncNum#, '', "#cfcatch.message# - #cfcatch.detail#"</cfoutput>);
	</script>
</cfcatch>
</cftry>