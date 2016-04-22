<cfmodule template="#application.appPath#/header.cfm" title='File Manager'>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="File Manager">

<cfinclude template="file_functions.cfm">

<cfparam name="path" type="string" default="/">
<cfparam name="folderId" type="integer" default="0">
<cfparam name="CKEditorFuncNum" type="integer" default="0"><!---used by ckeditor to return browsed for files--->
<cfparam name="checkType" type="string" default="/">

<cfset folderId = pathToFolderId(path)><!---get a folder based on the user provided path(makes sure it's valid)--->
<cfset path = folderIdtoPath(folderId)><!---set path to the valid name of our folderId--->

<!---there's one other thing we need.  Since files are limitted to people who have the right masks we have to find all of this user's mask_id's.--->
<cfset userMasks = bulkGetUserMasks(session.cas_username)>
<cfset userMaskIds = "">
<cfloop query="userMasks">
	<cfset userMaskIds = listAppend(userMaskIds, mask_id)>
</cfloop>
<style>
<!--- this is for the submit files button to stay disabled initially --->
.disabled {
  color: grey;
}
<!---keep the span with buttons from collapsing.--->
td.buttons {
	width: 100px;
}
</style>
<h1>File Manager</h1>

<script type="text/javascript">
	$(document).ready(function(){
		<!---if we're being browsed from CKEditor, don't display links return them to ckeditor.--->
		<cfif CKEditorFuncNum neq 0>
			$(".filelink").click(function(e){
				e.preventDefault();//prevent following of link.
				//set the URL to the clicked file.
				var filepath = '<cfoutput>#application.appPath#/tools/filemanager/</cfoutput>' + $(this).attr("href");

				//send the info to ckeditor and close this window.
			<cfif CKEditorFuncNum gt 0>
				window.opener.CKEDITOR.tools.callFunction(<cfoutput>#CKEditorFuncNum#</cfoutput>, filepath);
			<cfelse><!---If it's less than 0 we're doing a fake-out version of the ckeditor object for our File Browser.--->
				window.opener.fileBrowser.tools.callFunction(<cfoutput>#CKEditorFuncNum#</cfoutput>, filepath);
			</cfif>
				window.close();
			})
		</cfif>
		$("input#check_change_mask").change(function(){
			var anyChecked=false;
			$("input#check_change_mask").each(function(){
				if($(this).is(":checked")) {
						anyChecked=true;
						return( 0 );
				}
			});
			if(anyChecked) $("a#submit_button").removeClass("disabled");
			else $("a#submit_button").addClass("disabled");
		});
	});

</script>

<h3>Browsing files for <cfoutput>#path#</cfoutput></h3>

<p>
	<a href="upload.cfm?folderId=<cfoutput>#folderId#</cfoutput>"><span class="btn btn-default"><span class="glyphicon glyphicon-upload"></span> Upload Files</span></a>
	<a href="edit_folder.cfm?parentFolderId=<cfoutput>#folderId#</cfoutput>"><span class="btn btn-default"><span class="glyphicon glyphicon-plus-sign"></span> New Folder</span></a>
	<a href="javascript:{}" onclick="document.getElementById('form-select').submit();" class="submit_button btn btn-default disabled" id="submit_button"><span class="glyphicon glyphicon-ok-sign"></span> Submit Files</a>
</p>

<table class="stripe" style="width: 100%;">
	<tr class="titlerow">
		<th colspan="6">
			<cfoutput>#path#</cfoutput>
		</th>
	</tr>
	<tr class="titlerow2">
		<th></th>
		<th></th>
		<th>Name</th>
		<th>Date</th>
		<th>Level</th>
		<th>Desc.</th>
	</tr>

<!---draw a link to go up one level--->
<cfif folderId gt 0>
	<tr class="tasktablerow2">
		<td></td>
		<td></td>
		<td colspan="4">
			<a href="manager.cfm?path=<cfoutput>#urlEncodedFormat(folderIdtoPath(getParentFolderId(folderId)))#&CKEditorFuncNum=#CKEditorFuncNum#</cfoutput>" class="folder">
				<div class="btn btn-default col-sm-12">
					<span class="glyphicon glyphicon-arrow-up pull-left"></span>
					.. <i>Parent Folder</i>
				</div>
			</a>
		</td>
	</tr>
</cfif>

<!---find all the sub-folders of the current folderId--->
<cfquery datasource="#application.applicationDataSource#" name="getSubFolders">
	SELECT folder_id, folder_name, parent_folder_id
	FROM tbl_filemanager_folders
	WHERE parent_folder_id = #folderId#
	ORDER BY folder_name ASC
</cfquery>

<cfset cnt = 0><!---for striping rows--->
<cfoutput query="getSubFolders">
	<tr class="<cfif cnt mod 2 eq 0>tasktablerow1<cfelse>tasktablerow2</cfif>">
		<td></td>
		<td align="center" class="buttons">
			<div class="btn-group">
				<!---don't display if we're just browsing.--->
				<cfif CKEditorFuncNum eq 0>
					<a href="edit_folder.cfm?action=delete&folderId=#folder_id#" class="btn btn-default" title="Delete Folder"><span class="glyphicon glyphicon-trash"></span></a>
					<a href="edit_folder.cfm?folderId=#folder_id#" class="btn btn-default" title="Edit Folder"><span class="glyphicon glyphicon-pencil"></span></a>
				</cfif>
			</div>
		</td>
		<td colspan="4">
			<a href="manager.cfm?path=#urlEncodedFormat(path & folder_name)#&CKEditorFuncNum=#CKEditorFuncNum#" class="folder">
				<div class="btn btn-default col-sm-12">
					<span class="glyphicon glyphicon-folder-close pull-left"></span> #folder_name#
				</div>
			</a>
		</td>
	</tr>
	<cfset cnt = cnt + 1>
</cfoutput>


<!---find any files in this folder--->
<cfquery datasource="#application.applicationDataSource#" name="getFiles">
	SELECT file_id, file_name, file_description,
		/*now fetch the date of the current file*/
		(SELECT MAX(version_date) FROM tbl_filemanager_files_versions WHERE file_id = ff.file_id) AS version_date
	FROM tbl_filemanager_files ff
	WHERE ff.folder_id = #folderId#
	/*this is ugly as sin, but it does limit us to files that the user has the mask for.*/
	AND 0 = (
		SELECT COUNT(mask_id)
		FROM tbl_filemanager_files_masks
		WHERE file_id = ff.file_id
		AND mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userMaskIds#" list="true">)
	)

	ORDER BY ff.file_name
</cfquery>

<!---fetch all the masks for all the files in this folder, we can then use queries of queries on this data--->
<cfquery datasource="#application.applicationDataSource#" name="getFileMasks">
	SELECT f.file_id, fm.mask_id, um.mask_name
	FROM tbl_filemanager_files f
	INNER JOIN tbl_filemanager_files_masks fm ON fm.file_id = f.file_id
	INNER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
	WHERE f.folder_id = #folderId#
</cfquery>


<cfif getFiles.recordCount eq 0>
	<tr class="<cfif cnt mod 2 eq 0>tasktablerow1<cfelse>tasktablerow2</cfif>">
		<td></td>
		<td colspan="5"><i>No Files in directory.</i></td>
	</tr>
</cfif>
<form name="selectCheck" method="post" action="selection-populate.cfm" id="form-select">
	<input type="hidden" name="path" value="<cfoutput>#htmlEditFormat(path)#</cfoutput>">
<cfoutput query="getFiles">
	<tr class="<cfif cnt mod 2 eq 0>tasktablerow1<cfelse>tasktablerow2</cfif> tinytext">
		<td align="center">
			<label>
				<input type="checkbox" name="checkType" value="#file_id#" id="check_change_mask" title="Select to change mask">
			</label>
		</td>
		<td align="center" class="buttons">
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
		<td>#dateFormat(version_date, "mmm d, yyyy")# #timeFormat(version_date, "short")#</td>

		<!---fetch this files masks.--->
		<cfquery dbtype="query" name="getThisFilesMasks">
			SELECT *
			FROM getFileMasks
			WHERE file_id = #file_id#
		</cfquery>

		<td>
			<cfloop query="getThisFilesMasks">
				<span class="btn btn-default btn-xs">#mask_name#</span>
			</cfloop>
		</td>
		<td>
			<cfset maxLen = 100>
			#left(stripTags(file_description), maxLen)#
			<cfif len(stripTags(file_description)) gt maxLen>...</cfif>
		</td>
	</tr>
	<cfset cnt = cnt + 1>
</cfoutput>

<tr class="titlerow">
	<td colspan="6">
		&nbsp;
	</td>
</tr>
</table>
<p>
	<a href="upload.cfm?folderId=<cfoutput>#folderId#</cfoutput>"><span class="btn btn-default"><span class="glyphicon glyphicon-upload"></span> Upload Files</span></a>
	<a href="edit_folder.cfm?parentFolderId=<cfoutput>#folderId#</cfoutput>"><span class="btn btn-default"><span class="glyphicon glyphicon-plus-sign"></span> New Folder</span></a>
	<cfif getFiles.recordCount GT 0 >
   <a href="javascript:{}" onclick="document.getElementById('form-select').submit();" class="submit_button btn btn-default disabled" id="submit_button"><span class="glyphicon glyphicon-ok-sign"></span> Submit Files</a>
	</cfif>
</p>
</form>
<p class="tinytext">
	Icons are from the <a href="http://materia.infinitiv.it/">Tango Materia Icon Theme</a>, based on the <a href="http://tango.freedesktop.org/">Tango Desktop Project</a>, under a <a href="http://creativecommons.org/licenses/by-sa/2.5/">Creative Commons</a> license.
</p>

<cfinclude template="#application.appPath#/footer.cfm">