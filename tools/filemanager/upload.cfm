<cfsetting showdebugoutput="false">
<cfinclude template="file_functions.cfm">

<cfparam name="folderId" type="integer" default="0">
<cfparam name="minLevel" type="integer" default="10">
<cfparam name="frmFiles" type="any" default="">
<cfparam name="submit" type="string" default="display">

<cfset pagetitle="Upload Files">
<cfset homepage = "#application.appPath#/tools/filemanager/manager.cfm">
<cfmodule template="#application.appPath#/header.cfm" title='File Manager Upload File'>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="File Manager">
<h1>File Manager Upload File</h1>

<script type="text/javascript">
//filesArray is a global used for manage our files.
//in the format of [fileObject, statusCode]
filesArray = new Array();

$(document).ready(function() {
	//handle when files are added to the upload list.
	$('form#displayForm input#files').change(function(){
		$(this.files).each(function(){
			//console.log(this);
			addFile(this);//strip any duplicate filenames.
		});
		
		/*this allows us to use the native javascript array.sort method on filesArray*/		
		File.prototype.toString = function(){
			return(this.fileName.toLowerCase());
		}
		
		//sort it.
		filesArray = filesArray.sort();
		
		drawFileArray();
	});
	
	$('form#displayForm input[name="submit"]').click(function(){
		sendFiles();
		//prevent form submission.
		$('form#displayForm').submit(function(){
			return false;
		});
	});
	
});

//add functions for removing items from fileObject

//add function for uploading items in fileObject, skipping those without status == 200.

//addFile() takes a file object, and if it isn't already in the list of files add it to filesArray.
function addFile(fileObject){
	var matchFound = 0;
	
	$.each(filesArray, function(index){
		if(!matchFound){
			if(filesArray[index][0].name == fileObject.fileName) {
				matchFound = 1
				return(0);//break out of loop.
			}
		}
	});
	
	//if we've made it here add the fileObject to our array.
	if(!matchFound) filesArray.push([fileObject, 0]);
}

//remove position n from filesArray, then redraw the filesList
function removeFile(n){
	if(filesArray.length > 1) filesArray.splice(n, 1);
	else filesArray = new Array();
	drawFileArray();
}

//change status for a file, used to allow over-writing
function changeFileStatus(n, status){
	filesArray[n][1] = status;
	drawFileArray();
}

function drawFileArray(){
	//clear out table#fileList, and add a row for each file
	$('table#fileList').html("<tr><th>Files to be uploaded</th><th>Actions</th></tr>");
	
	
	//now loop through filesArray and fill-up the table.
	$.each(filesArray, function(index){
		$.ajaxSetup({async:false});//doing this to keep our list in alphabetical order.
		
		//only check if we don't already hava an OK status for this file, allows us to force over-writing.
		if(filesArray[index][1] != 200){
			//ask the server if we have a duplicate on the server.
			var jqxhr = $.post("uploader.cfm", {pathId: "<cfoutput>#folderId#</cfoutput>", fileName: filesArray[index][0].name, action: "check"})
			.complete(function(data){
				//display the filename and any input we need from the user based on the status.
				//console.log(data);
				
				//store the status in filesArray
				filesArray[index][1] = data.status
			});
		}
		
		//draw each file based on status.
		//200 ok, 409 file already exists, anything else is an unspecified error.
		if(filesArray[index][1] == 200){
			$('table#fileList').append('<tr><td>' + filesArray[index][0].name + '</td><td align="center"><span class="btn btn-default btn-xs" title="Remove" onclick="removeFile(' + index + ')"><span class="glyphicon glyphicon-remove"></span></span></td></tr>');
		} else if(filesArray[index][1] == 409){
			$('table#fileList').append('<tr><td style="color: red">' + filesArray[index][0].name + '</td><td align="center" style="font-size: small">Overwrite Existing file?<br/><span class="btn btn-default btn-xs"  title="Yes" onclick="changeFileStatus(' + index + ', 200)"><span class="glyphicon glyphicon-ok"></span></span> <span class="btn btn-default btn-xs" title="No" onclick="removeFile(' + index + ')"><span class="glyphicon glyphicon-remove"></span></span></td></tr>');
		} else if(filesArray[index][1] == 403){
			$('table#fileList').append('<tr><td style="color: red">' + filesArray[index][0].name + '</td><td align="center" style="font-size: small">User access level too low,<br/>file will not be uploaded.<br/><span class="btn btn-default btn-xs" title="Remove" onclick="removeFile(' + index + ')"><span class="glyphicon glyphicon-remove"></span></span></td></tr>');
		} else {
			$('table#fileList').append('<tr><td style="color: red">' + filesArray[index][0].name + '</td><td align="center" style="font-size: small">Error checking file,<br/>it will not be uploaded.<br/><span class="btn btn-default btn-xs" title="Remove" onclick="removeFile(' + index + ')"><span class="glyphicon glyphicon-remove"></span></span></td></tr>');
		}
		
	});	
}

//function to send each approved item in filesArray 
function sendFiles(){
	$(filesArray).each(function(index){
		if(this[1] == 200){
			//code to send the file...
			var result = uploadFile(index);
		}
	});
	
	//files that uploaded successfully now have a 200 restul... remove them.
	var tempFilesArray = new Array();
	$(filesArray).each(function(index){
		if(this[1] != 200){
			tempFilesArray[tempFilesArray.length] = this;
		}
	});
	//set our new value for files array.
	filesArray = tempFilesArray;
	
	//having completed our upload cycle redraw the fileList.
	drawFileArray();
}

//sending a file is a heck of a thing to do with jQuery.  It requires making some events happen inside a self-create iFrame.
//file is a filesArray[0] element, a file object.
function uploadFile(index){
	//jquery's ajax functions aren't robust enough to send a file, so we'll write our own httprequest.
	var xhr = new XMLHttpRequest();
	var maskList = $("input[name='maskIdList']").val();
	
	//build up our request's data
	formData = new FormData();
	formData.append("pathId", <cfoutput>#folderId#</cfoutput>);
	formData.append("maskIdList", maskList);
	formData.append("action", "upload");
	formData.append("fileName", filesArray[index][0].name)
	formData.append("file", filesArray[index][0]);
	
	
	//handle xhr results
	xhr.onreadystatechange = function(){
		if(xhr.readyState == 4){
			//upload attempt complete, update the file
			updateStatus(filesArray[index][0], [xhr.status, xhr.statusText])
		}
	}
	//send xhr request.
	xhr.open("POST", "uploader.cfm", false);//make this synchronous.
	xhr.overrideMimeType('text/plain; charset=x-user-defined-binary');
	xhr.send(formData);
}

//updateStatus() re-draws the file's status after an upload attemp.
function updateStatus(file, status){
	var color = "red";
	if(status[0] == 200){
		color = "green";
	} 
	
	//update the file's status in our table.
	$("table#fileList td").each(function(){
		if($(this).html() == file.fileName){
			$(this).next().html("<span style='color: " + color + "'>" + status[1] + "</span>");
		}
	});
	
	//update status code in filesArray
	$(filesArray).each(function(index){
		if(this[0].fileName == file.fileName){
			filesArray[index][1] = status[0];
		}
	});
}

</script>


<!---first attempt to upload files--->
<cfif submit eq "Upload">
<cftry>
	<cfdump var="#form#">
	<!---cffile action="uploadall" destination="#fileVault#" nameconflict="makeunique" result="fileResult">
	<cfdump var="#fileResult#"--->	
	
	<cfcatch type="any">
		<p class="warning">
			An error was encountered with your request.
			<cfoutput>#cfcatch.Message#: #cfcatch.detail#</cfoutput>
		</p>
	</cfcatch>
</cftry>
</cfif>


<!---fetch all masks, for use with some javasript.--->
<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
	SELECT DISTINCT m.mask_id, um.mask_name
	FROM vi_all_masks_users m
	INNER JOIN tbl_user_masks um ON um.mask_id = m.mask_id
	WHERE m.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">/*limit to the user's own masks.*/
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
	
	<cfif mask_name neq "Consultant">
		<cfset arrayAppend(availList, maskStruct)>
	<cfelse>
		<cfset arrayAppend(usedList, maskStruct)>
	</cfif>
</cfloop>


<cfset path = folderIdtoPath(folderId)>
<cfoutput><h3>Uploading to #path#</h3></cfoutput>

<noscript>
	<p style="red">Javascript must be enabled to use this form.</p>
</noscript>
<b>Files:</b>
<!---display form--->
<form id="displayForm" action="uploader.cfm" method="post" enctype="multipart/form-data" class="form-horizontal">
	<input type="hidden" name="pathId" value="<cfoutput>#folderId#</cfoutput>">
	<input type="hidden" name="action" value="upload">
	
	
	<div class="form-group">
		<label class="col-sm-3 control-label" for="newVer">File</label>
		<div class="col-sm-9">
			<input type="file"   multiple="multiple" name="file" id="files">
		</div>
	</div>
	
	
	<cfset drawMasksSelector("maskIdList", "9", "Required Masks", "Masks required to view the uploaded files.")>
	
	
	<div class="form-group">
		<div class="col-sm-3 control-label"></div>
	
		<div class="col-sm-9">
			<table id="fileList" border="1" width="500px">
				<tr>
					<th>Files to be uploaded</th>
					<th>Actions</th>
				</tr>
			</table>
		</div>
	</div>
	<input class="btn btn-primary col-sm-offset-3" type="submit" name="submit" value="Upload">
</form>

<br/>

<p>Return to the <a href="manager.cfm?path=<cfoutput>#urlEncodedFormat(path)#</cfoutput>">File Manager</a></p>

<cfinclude template="#application.appPath#/footer.cfm">