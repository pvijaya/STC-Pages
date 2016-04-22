<cfmodule template="#application.appPath#/header.cfm" title='TETRA' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<!---We also need to bring in our file-functions to handle uploading/removing the emoticon from the File Manager.--->
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<style type="text/css">
	span.ok {
		color: green;
		font-weight: bold;
	}
	span.error {
		color: red;
		font-weight: bold;
	}
	
	input.frmCode {
		width: 5em;
	}
	
	img.emoticon {
		max-width: 3em;
		max-height: 3em;
	}
</style>

<h2>Edit Chat Icons</h2>

<!---handle user input--->
<cftry>
	<cfparam name="frmId" type="integer" default="0">
	<cfparam name="frmCode" type="string" default="">
	<cfparam name="frmFile" type="any" default="">
	<cfparam name="frmSubmit" type="string" default="">
	
	<cfif frmSubmit eq "Update">
		<cfif frmId eq 0>
			<cfthrow message="No ID" detail="You must provide an emoticon's ID to update it.">
		</cfif>
		<cfif trim(frmCode) eq "">
			<cfthrow message="Bad Code" detail="Code may not be left blank when updating an emoticon."> 
		</cfif>
		
		<!---things look good update the emoticon in the database--->
		<cfquery datasource="#application.applicationDatasource#" name="updateIcon">
			UPDATE tbl_chat_replace
			SET match = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmCode#">
			WHERE emoticon_id = #frmId#
		</cfquery>
		
		<!---update worked, reset our values--->
		<cfoutput>
			<p><span class="ok">Success</span> emoticon #htmlEditFormat(frmCode)# has been updated.</p>
		</cfoutput>
		<cfset frmId = 0>
		<cfset frmCode = "">
	
	<cfelseif frmSubmit eq "Delete">
		<cfif frmId eq 0>
			<cfthrow message="No ID" detail="You must provide an emoticon's ID to update it.">
		</cfif>
		
		<!---first try to remove the file from the File Manager.--->
		<cfquery datasource="#application.applicationDataSource#" name="getIconDetails">
			SELECT f.file_id
			FROM tbl_chat_replace cr
			INNER JOIN tbl_filemanager_files f 
				ON f.file_id = cr.file_id
				AND f.folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#pathToFolderId('/Emoticons/')#">/*emoticon folder_id*/
			WHERE cr.emoticon_id = #frmId#
		</cfquery>
		
		<!---now make a call to the filemanager's deletion form, so everything is audited correctly.--->
		<cfloop query="getIconDetails">
			<script type="text/javascript">
				$(document).ready(function(){
					$.ajax({
						type: 'POST',
						url: '<cfoutput>#application.appPath#/tools/filemanager/edit.cfm</cfoutput>',
						data: {
						<cfoutput>
							action: "confirmedDelete",
							fileId: #file_id#
						</cfoutput>
						}
					})
				});
			</script>
		</cfloop>
		
		<!---now remove the match from tbl_chat_replace--->
		<cfquery datasource="#application.applicationDatasource#" name="deleteIcon">
			DELETE FROM tbl_chat_replace
			WHERE emoticon_id = #frmId#
		</cfquery>
		
		<!---deletion worked, reseet our values--->
		<cfoutput>
			<p class="ok">Success emoticon #htmlEditFormat(frmCode)# has been deleted.</p>
		</cfoutput>
		<cfset frmId = 0>
		<cfset frmCode = "">
		
	<cfelseif frmSubmit eq "Upload">
		<cfif trim(frmCode) eq "">
			<cfthrow message="Bad Code" detail="Code may not be left blank when uploading an emoticon."> 
		</cfif>
		
		<!---first, to try to upload a file we need to find the path_id to the emoticons folder in the filemanager--->
		<!---does the user's folder already exist in the filemanager?--->
		<cfset myPath = "/Emoticons/">
		<cfset myFolderId = pathToFolderId(myPath)>
		
		<!---if the Emoticons directory doesn't exist, create it.--->
		<cfif myPath neq folderIdtoPath(myFolderId)>
			<!---create folder, and set myFolderId to that--->
			<cfset myFolderId = addFolder("Emoticons", 0)>
		</cfif>
		
		<!---snag the filename we've submitted, too.--->
		<cfset fileName = getUploadFileName("frmFile")>
		
		<!---Now that we have our folderId/pathId and file name we can check if a file of that name already exists.--->
		<cfset hasDupes = checkDuplicateFiles(myFolderId, fileName)>
		
		<cfif hasDupes>
			<cfthrow message="File Already Exists" detail="A file named <em>#fileName#</em> already exists.  Change your file name, or use the <a href=""#application.appPath#/tools/filemanager/edit.cfm?fileId=#hasDupes#&action=edit"">File Manager</a> to upload a new version of the existing file.">
		</cfif>
		
		<!---now commit the file to the filemanager.--->
		<cfset result = uploadFile(myFolderId, fileName, "frmFile", "9")><!---default permissions to just "9", consultant mask.--->
		
		<cfif result['code'] neq 302>
			<cfthrow message="File Upload" detail="#result.code# - #result.text#">
		</cfif>
		
		
		<!---our file is in like Flynn, store the details in tbl_chat_replace--->
		<!---the file uploaded, add the emoticon to the database--->
		<cfquery datasource="#application.applicationDatasource#" name="uploadIcon">
			INSERT INTO tbl_chat_replace (match, replacement, file_id)
			VALUES	(
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmCode#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="<img class=""emoticon"" src=""#result.url#"" />">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#result.id#">
					)
		</cfquery>
		
		<!---insert succeded, clear our values--->
		<cfoutput>
			<p class="ok">Success emoticon #htmlEditFormat(frmCode)# has been created.</p>
		</cfoutput>
		
		<cfset frmCode = "">
		
	</cfif>
<cfcatch type="any">
	<cfoutput>
	<p>
		<span class="error">Error</span> - #cfcatch.message#. #cfcatch.detail# 
	</p>
	</cfoutput>
</cfcatch>
</cftry>



<!---draw content from database, our default action.--->

<cfquery name="getIcons" datasource="#application.applicationDatasource#">
	SELECT emoticon_id, Match, Replacement, file_id
	FROM tbl_chat_replace
	ORDER BY Match
</cfquery>


<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post" enctype="multipart/form-data">
<table>
	<tr>
		<td colspan="2"><strong>Add Emoticon</strong></td>
	</tr>
	<tr>
		<td align="right">Code:</td>
		<td>
			<input type="text" name="frmCode" class="frmCode" value="<cfoutput>#htmlEditFormat(frmCode)#</cfoutput>">
		</td>
	</tr>
	<tr>
		<td align="right">
			Image:
		</td>
		<td>
			<input type="file"  name="frmFile">
		</td>
	</tr>
	<tr>
		<td></td>
		<td>
			<input type="submit" name="frmSubmit" value="Upload">
		</td>
	</tr>
</table>
</form>

<cfset maxCols = 6><!---how many columns should each row of our table have?--->
<table>
	<tr>
		<td colspan="#maxCols#">
			<strong>Existing Emoticons</strong>
		</td>
	</tr>
	
<cfset cnt = 0><!---counter for itterations through the loop--->
<cfoutput query="getIcons">
	<!---begin rows as needed--->
	<cfif cnt mod maxCols eq 0>
		<tr>
	</cfif>
	
	<td valign="bottom">
		<form accept="#cgi.script_name#" method="post">
			<input type="hidden" name="frmId" value="#htmlEditFormat(emoticon_id)#">
			#replacement#<br/>
			Code: <input type="text" name="frmCode" class="frmCode" value="#htmlEditFormat(match)#"><br/>
			<input type="submit" name="frmSubmit" value="Update">
			<input type="submit" name="frmSubmit" value="Delete" onClick="return(confirm('Are you sure you want to delete #htmlEditFormat(match)# and all associated files?'))">
		</form>
	</td>
	
	<cfset cnt = cnt + 1><!---itterate for our next pass--->
	<!---end rows as required.--->
	<cfif (cnt) mod maxCols eq 0 OR cnt eq getIcons.recordCount></tr></cfif>
</cfoutput>

</table>


<p>
	Return to <a href="<cfoutput>#application.appPath#</cfoutput>">Chat</a>
</p>

<cfinclude template= "#application.appPath#/footer.cfm">