<cfmodule template="#application.appPath#/header.cfm" title='Cleaning Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmLab" type="string" default="">
<cfparam name="frmLabId" type="integer" default="0">
<cfparam name="instanceId" type="integer" default="0">
<cfparam name="cleaningId" type="integer" default="0">
<cfparam name="sectionId" type="integer" default="0">
<cfparam name="frmImage" type="string" default="">
<cfparam name="frmDescription" type="string" default="">
<cfparam name="frmRetired" type="boolean" default="0">
<cfparam name="submitted" type="boolean" default="0">

<!--- Header / Navigation --->
<h1>Cleaning Manager</h1>
<cfif cleaningId GT 0>
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_manager.cfm?frmCleaningId=#cleaningId#</cfoutput>">Go Back</a>]
</cfif>
[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_cleaning.cfm</cfoutput>">Submit Cleaning</a>]
<cfif hasMasks('cs')>
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/cleaning_report.cfm</cfoutput>">Cleaning Submissions</a>]
</cfif>

<!--- Handle user input. --->
<cfif frmAction EQ "Submit">
	
	<cftry>
		
		<cfif trim(frmDescription) EQ "">
			<cfthrow message="Missing Input" detail="You must supply a description.">
		</cfif>
		
		<cfset labStruct = parseLabName(frmLab)>
		<cfset frmLabId = labStruct.lab>
		<cfset frmInstanceId= labStruct.instance>
			
		<cfif sectionId EQ 0>	
					
			<!--- Create new section record. --->
			<cfquery datasource="#application.applicationDataSource#" name="addSection">
				INSERT INTO tbl_cleaning_labs_sections (cleaning_id, lab_id, section_image, section_description)
				OUTPUT inserted.section_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#cleaningId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmLabId#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmImage#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmDescription#">
				)
			</cfquery>	
					
			<p class="ok"> Section successfully created. </p>	
			
			<!--- Clear the form fields for adding multiple sections cleanly. --->
			<cfset frmDescription = "">
			<cfset frmImage = "">
			<cfset frmLab = "">
				
		<cfelseif sectionId GT 0>
				
			<!--- From now on, preserve user input. --->
			<cfset submitted = 1>	
				
			<!--- Update existing section record. --->
			<cfquery datasource="#application.applicationDataSource#" name="editSection">
				UPDATE tbl_cleaning_labs_sections
				SET lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLabId#">,
					section_image = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmImage#">,
					section_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmDescription#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
				WHERE section_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#sectionId#">
			</cfquery>
						
			<p class="ok"> Section successfully updated. </p>	
				
		</cfif>
		
	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

</cfif>

<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

	<!--- Track our non-form parameters. --->
	<cfoutput>
		<input type="hidden" name="cleaningId" value="#cleaningId#">
		<input type="hidden" name="instanceId" value="#instanceId#">
		<input type="hidden" name="sectionId" value="#sectionId#">
		<input type="hidden" name="submitted" value="#submitted#">
	</cfoutput>

	<cfif sectionId EQ 0>
	
		<cfif frmLab EQ "">
			<cfquery datasource="#application.applicationDataSource#" name="getLab">
				SELECT cl.lab_id, cl.instance_id
				FROM tbl_cleaning_labs cl
				WHERE cl.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#cleaningId#">
			</cfquery>
			
			<cfset frmLabId = getLab.lab_id>
			<cfset instanceId = getLab.instance_id>
			<cfset frmLab = "i#instanceId#l#frmLabId#">
		</cfif>
		
		<h2>Create Section</h2>
	
	<cfelseif sectionId GT 0>
		
		<!--- If the user hasn't provided any values, default to the existing ones. --->
		<cfif submitted EQ 0>
			
			<cfquery datasource="#application.applicationDataSource#" name="getLabSection">
				SELECT cls.section_image, cls.section_description, cls.retired, cls.lab_id, cl.instance_id
				FROM tbl_cleaning_labs_sections cls
				INNER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cls.cleaning_id
				INNER JOIN vi_labs l ON l.lab_id = cls.lab_id 
						   AND l.instance_id = cl.instance_id
				WHERE cls.section_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#sectionId#">
				      AND cls.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#cleaningId#">
			</cfquery>
			
			<cfset frmLab = "i#getLabSection.instance_id#l#getLabSection.lab_id#">
			<cfset frmImage = "#getLabSection.section_image#">
			<cfset frmDescription = "#getLabSection.section_description#">
			<cfset frmRetired = "#getLabSection.retired#">
			
		</cfif>
		
		<h2>Edit Section</h2>
		
	</cfif>
	
	<table>
		<tr>
			<td><label for="frmLab">Lab:</label></td>
			<td><cfset drawLabsSelector("frmLab", "#frmLab#")></td>
		</tr>
		<tr>
			<td>Image URL (optional):</td>
			<td>
				<input type="text" name="frmImage" size="80" value="<cfoutput>#htmlEditFormat(frmImage)#</cfoutput>">
				<a href="#" class="browseLink">Browse</a>
			</td>
		</tr>
		<tr>
			<td>Description:</td>
			<td><input type="text" name="frmDescription" size="80" value="<cfoutput>#htmlEditFormat(frmDescription)#</cfoutput>"></td>
		</tr>
		<cfif sectionId GT 0>
			<tr>
				<td>Active?</td>
				<td>
					<label><input type="radio" name="frmRetired" value="0" <cfif NOT frmRetired>checked</cfif>>Yes</label>
					<label><input type="radio" name="frmRetired" value="1" <cfif frmRetired>checked</cfif>>No</label>	
				</td>
			</tr>
		</cfif>
	</table>

	<br/>

	<input type="submit" value="Submit" name="frmAction">

</form>

<script type="text/javascript">
	$(document).ready(function(){
		
		//Define a fake-out ckeditor object so we can snag file data from our filebrowser using the same method as the ckeditor.
		fileBrowser = new Object();
		fileBrowser.tools = new Object();
		/*
			Now setup our "instances" these should be the number of the instance(must be negative), the selector where we want to store the file selected from browsing, and the selector(listener) for the object to click on that launches the  file browser.
		*/
		fileBrowser.instances = [
			{
				"num": -1,
				"selector": $("input[name='frmImage']"),
				"listener": $("a.browseLink")
			}
		];
		/*now, what to do when we get a response from the file-browser*/
		fileBrowser.tools.callFunction = function(num, filePath) {
			
			//loop over our instances until we find the one matching num, then set its selector's value to filePath.
			$(fileBrowser.instances).each(function(n){
				if(this.num == num){
					this.selector.val(filePath);
				}
			});
		};
		
		
		//now setup our listeners for each instance we defined.
		$(fileBrowser.instances).each(function(n){
			console.log(this);
			this.listener.on("click", function(e){
				e.preventDefault();//don't whisk us away from this page!
				
				//and open a window to our file-browser
				window.open('<cfoutput>#application.appPath#</cfoutput>/tools/filemanager/manager.cfm?path=%2Fimages%2FCleaning&CKEditorFuncNum=' + fileBrowser.instances[n].num);
			});
		});
		
		/*there's a lot of gnarly objective AND global javascript going on to make this happen; but it works, doesn't break ckeditor, and can be used more than once on a page.*/
	});
</script>


<cfinclude template="#application.appPath#/footer.cfm">