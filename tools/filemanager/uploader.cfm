<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfinclude template="file_functions.cfm">

<!---handle unauthorized users--->
<cfif not hasMasks("File Manager")>
	<cfheader statuscode="403" statustext="Access Level too low">
	<cfabort>
</cfif>

<cfparam name="pathId" type="integer" default="-1">
<cfparam name="fileName" type="string" default=""><!---the name of the file to be uploaded, this may be different from the name of the file being uploaded. --->

<!---cfparam name="maskIdList" type="string" default="9"---><!---by default assume files will be restricted to consultants.--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="maskIdList" default="[9]">
<cfset maskIdList = arrayToList(maskIdList)><!---the multi-selector always returns an array, but we want a list.--->

<cfparam name="frmUrl" type="string" default=""><!---let the user provide a location to go to upon successful upload.--->
<cfparam name="action" type="string" default="check">

<!---just to make sure the frmUrl provided by a user isn't too mallicious, strip out characters that would whisk us off to another site.--->
<cfset frmUrl = replace(frmUrl, "://", "", "all")>

<!---verify user's input is useful--->
<cfif pathId lt 0>
	<cfheader statuscode="400" statustext="No path provided">
	<cfabort>
</cfif>

<cfif fileName eq "">
	<cfheader statuscode="400" statustext="No file provided">
	<cfabort>
</cfif>


<cfif action eq "check"><!---check for duplicate files, return an error if such a file already exists in this directory.--->
	<cfset hasDupes = checkDuplicateFiles(pathId, fileName)>
	
	<cfif hasDupes>
		<!---fetch the user's masks--->
		<cfset bulkMasks = bulkGetUserMasks()>
		<cfset fileMaskLists = "">
		<!---fetch the file''s required masks, with a level too low they cannot write--->
		<cfquery datasource="#application.applicationDataSource#" name="getFile">
			SELECT fm.mask_id, m.mask_name
			FROM tbl_filemanager_files_masks fm
			INNER JOIN tbl_user_masks m ON m.mask_id = fm.mask_id
			WHERE file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#hasDupes#">
		</cfquery>
		<cfloop query="getFile">
			<cfset fileMaskLists = listAppend(fileMaskLists, mask_name)>
		</cfloop>
		
		<cfif not bulkHasMasks(bulkMasks, session.cas_username, fileMaskLists)>
			<cfheader statuscode="403" statustext="Access Level too low">
			<cfabort>
		</cfif>
		
		<!---otherwise just return that there is a duplicate--->
		<cfheader statuscode="409" statustext="Conflict">
		<cfheader name="Message" value="File already exists in path">
		<cfabort>
	</cfif>
	
	<cfheader statuscode="200" statustext="OK">
	<cfabort>

<cfelseif action eq "upload"><!---handle actually uploading files--->
	
	<cfset result = uploadFile(pathId, fileName, "file", maskIdList)>
	
	<cfif result['code'] eq 302>
		<!---success--->
		<cfheader statuscode="302" statustext="Return to file">
		<cfif frmUrl eq "">
			<cfset frmUrl = result['url']>
		</cfif>
		<cfheader name="Location" value="#frmUrl#">
	<cfelse>
		<!---failure--->
		<cfheader statuscode="#result['code']#" statustext="Error">
		<cfheader name="Message" value="#result['text']#">
	</cfif>
	<cfabort>

</cfif>

