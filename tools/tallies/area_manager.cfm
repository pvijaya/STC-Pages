<cfmodule template="#application.appPath#/header.cfm" title='Area Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">

<h1>Area Manager</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
	[<a href="<cfoutput>#application.appPath#/tools/tallies/submit_tally.cfm</cfoutput>">Submit a Tally</a>]
	[<a href="<cfoutput>#application.appPath#/tools/tallies/tally_report.cfm</cfoutput>">Search Tallies</a>]
	<cfif hasMasks("Admin")>
		[<a href="<cfoutput>#application.appPath#/tools/tallies/task_manager.cfm</cfoutput>">Manage Tasks</a>]
	</cfif>
</p>

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmAreaId" type="numeric" default="0">
<cfparam name="frmAreaName" type="string" default="">
<cfparam name="frmAreaDescription" type="string" default="">
<cfparam name="frmAreaRetired" type="boolean" default="0">

<!--- handle user input --->

<cfif frmAction EQ "Create" OR frmAction EQ "Edit">

	<cftry>		
		
		<!--- ensure we have valid inputs --->
		<cfif trim(frmAreaName) eq "">
			<cfthrow message="Missing Input" detail="Area Name is a required field, and cannot be left blank.">
		</cfif>		
		<cfif trim(frmAreaDescription) eq "">
			<cfthrow message="Missing Input" detail="Description is a required field, and cannot be left blank.">
		</cfif>		
		
		<!--- create or edit a table entry --->
		<cfif frmAction EQ "Create">			
			<!--- try to create our new area --->
			<cfquery datasource="#application.applicationDataSource#" name="addArea">
				INSERT INTO tbl_tallies_areas (area_name, area_description)
				OUTPUT inserted.tally_area_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAreaName#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAreaDescription#">
				)
			</cfquery>			
			<p class="ok"> Area successfully created. </p>		
		<cfelseif frmAction EQ "Edit">		
			<!--- update the table --->
			<cfquery datasource="#application.applicationDataSource#" name="editArea">
				UPDATE tbl_tallies_areas
				SET area_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAreaName#">,
					area_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAreaDescription#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmAreaRetired#">
				WHERE tally_area_id = #frmAreaId#
			</cfquery>			
			<p class="ok"> Area successfully updated. </p>		
		</cfif>	
			
	<cfcatch>
		<cfif frmAction EQ "Create">
			<cfset frmAction = "createnew">
		<cfelseif frmAction EQ "Edit">
			<cfset frmAction = "go">
		</cfif>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	
	</cftry>
	
</cfif>

<!--- draw forms --->

<cfif frmAction EQ "Go" OR frmAction EQ "CreateNew">

	<cfif frmAction EQ "Go">
		<h2>New Area</h2>
	<cfelseif frmAction EQ "CreateNew">
		<h2>Edit Area</h2>
	</cfif>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

		<!--- ensure we keep track of our area id--->
		<cfoutput> <input type="hidden" name="frmAreaId" value="#frmAreaId#"> </cfoutput>
		
		<!--- if we are editing an entry... --->
		<cfif frmAction EQ "Go">
		
			<!--- get the existing entry --->
			<cfquery datasource="#application.applicationDataSource#" name="getArea">
				SELECT tally_area_id, area_name, area_description, retired
				FROM tbl_tallies_areas
				WHERE tally_area_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmAreaId#">
			</cfquery> 
		
			<cfset frmAreaRetired = "#getArea.retired#">
		
			<!--- if the user hasn't entered new info, default to existing values --->
			<cfif frmAreaName EQ "">
				<cfset frmAreaName = "#getArea.area_name#">
			</cfif>
			<cfif frmAreaDescription EQ "">
				<cfset frmAreaDescription = "#getArea.area_description#">
			</cfif>
		</cfif>
		
		<label>Area Name:
			<input name="frmAreaName" value="<cfoutput>#htmlEditFormat(frmAreaName)#</cfoutput>">
		</label>
		
		<br/>
		
		<label>Description:
			<textarea name="frmAreaDescription"><cfoutput>#htmlEditFormat(frmAreaDescription)#</cfoutput></textarea>
		</label>
		
		<!--- replace the default textarea with a prettier one --->
		<script type="text/javascript">
			//a custom configuration for this ckeditor textarea
			var contactNote = CKEDITOR.replace('frmAreaDescription',{
				toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
				toolbar:  'Basic',
				height: '200px',
				width: '500px',
				removePlugins: 'contextmenu,tabletools'/*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
			});	
		</script>
		
		<br/>
		
		<cfif frmAction EQ "Go">
		
			<fieldset>
				<legend>Retired?</legend>
				<label>
					Yes
					<input type="radio" name="frmAreaRetired" value="1" <cfif frmAreaRetired>checked="true"</cfif>>
				</label>
				<label>
					No
					<input type="radio" name="frmAreaRetired" value="0" <cfif not frmAreaRetired>checked="true"</cfif>>
				</label>
			</fieldset>
		
		</cfif>
		
		<br/>	
		
		<cfif frmAction EQ "Go">
			<input type="submit" value="Edit" name="frmAction">
		<cfelseif frmAction EQ "CreateNew">
			<input type="submit" value="Create" name="frmAction">
		</cfif>
	
	</form>
	
	<p> <cfoutput><a href="#cgi.script_name#">Go Back</a></cfoutput> </p>
	
<cfelse>

	<!--- get existing areas --->
	<cfquery datasource="#application.applicationDataSource#" name="getAreas">
		SELECT a.tally_area_id, a.area_name, a.area_description, a.retired
		FROM tbl_tallies_areas a
		ORDER BY retired, area_name
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<br/>
		
		<fieldset>
			
			<legend>Choose</legend>
			
			<label>
				Select an Area:
				<select name="frmAreaId">
					<cfoutput query="getAreas">
						<option value="#tally_area_id#">
							#area_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			<input type="submit" value="Go" name="frmAction">
			
			<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
						
			<a href="<cfoutput>#cgi.script_name#?frmAction=createnew</cfoutput>">Create New Area</a>	 
			
		</fieldset>
		
	</form>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>