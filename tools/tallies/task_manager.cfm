<cfmodule template="#application.appPath#/header.cfm" title='Task Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">

<h1>Task Manager</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
	[<a href="<cfoutput>#application.appPath#/tools/tallies/submit_tally.cfm</cfoutput>">Submit a Tally</a>]
	[<a href="<cfoutput>#application.appPath#/tools/tallies/tally_report.cfm</cfoutput>">Search Tallies</a>]
	<cfif hasMasks("Admin")>
		[<a href="<cfoutput>#application.appPath#/tools/tallies/area_manager.cfm</cfoutput>">Manage Areas</a>]
	</cfif>
</p>

<!--- cfparams --->
<cfparam name="areaList" type="string" default="">
<cfparam name="frmAreas" type="string" default="">
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmTaskId" type="numeric" default="0">
<cfparam name="frmTaskName" type="string" default="">
<cfparam name="frmTaskDetails" type="string" default="">
<cfparam name="frmTaskRetired" type="boolean" default="0">

<!--- handle user input --->

<cfif frmAction EQ "Create" OR frmAction EQ "Edit">

	<cftry>		
		
		<!--- ensure we have valid inputs --->
		<cfif trim(frmTaskName) eq "">
			<cfthrow message="Missing Input" detail="Task Name is a required field, and cannot be left blank.">
		</cfif>		
		<cfif trim(frmTaskDetails) eq "">
			<cfthrow message="Missing Input" detail="Task Details is a required field, and cannot be left blank.">
		</cfif>		
		
		<!--- create or edit a table entry --->
		<cfif frmAction EQ "Create">			
			<!--- try to create our new area --->
			<cfquery datasource="#application.applicationDataSource#" name="addTask">
				INSERT INTO tbl_tallies_tasks (task_name, task_details)
				OUTPUT inserted.tally_task_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTaskName#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTaskDetails#">
				)
			</cfquery>
			<cfset frmTaskId = addTask.tally_task_id>			
			<p class="ok"> Task successfully created. </p>		
		<cfelseif frmAction EQ "Edit">		
			<!--- update the table --->
			<cfquery datasource="#application.applicationDataSource#" name="editTask">
				UPDATE tbl_tallies_tasks
				SET task_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTaskName#">,
					task_details = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTaskDetails#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmTaskRetired#">
				WHERE tally_task_id = #frmTaskId#
			</cfquery>			
			<p class="ok"> Task successfully updated. </p>		
		</cfif>
		
		<!--- handle the new task areas --->
		<!--- delete all existing entries for task areas --->
		<cfquery datasource="#application.applicationDataSource#" name="deleteTaskAreas">
			DELETE FROM tbl_tallies_tasks_areas
			WHERE tally_task_id = #frmTaskId#
		</cfquery>
		
		<!--- add new entries for task areas --->
		<cfif listLen(frmAreas) gt 0>
			<cfset cnt = 1><!---this gets used to put a comma after each set of values, except for the last item in frmMaskList--->
			<cfquery datasource="#application.applicationDataSource#" name="addTaskAreas">
				INSERT INTO tbl_tallies_tasks_areas (tally_task_id, tally_area_id)
				OUTPUT inserted.tally_task_area_id
				VALUES 
				<cfloop list="#frmAreas#" index="areaId">
					(<cfqueryparam cfsqltype="cf_sql_integer" 
								   value="#frmTaskId#">, 
					<cfqueryparam cfsqltype="cf_sql_integer" 
								  value="#areaId#">)
					<cfif cnt lt listLen(frmAreas)>,</cfif>
					<cfset cnt = cnt + 1>
				</cfloop>
			</cfquery>
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
		<h2>Edit Task</h2>
	<cfelseif frmAction EQ "CreateNew">
		<h2>New Task</h2>
	</cfif>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<!--- ensure we keep track of our task id--->
		<cfoutput> <input type="hidden" name="frmTaskId" value="#frmTaskId#"> </cfoutput>
		
		<!--- if we are editing an entry... --->
		<cfif frmAction EQ "Go">
		
			<!--- get the existing entry --->
			<cfquery datasource="#application.applicationDataSource#" name="getTask">
				SELECT a.tally_task_id, a.task_name, a.task_details, a.retired
				FROM tbl_tallies_tasks a 
				WHERE tally_task_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmTaskId#">
			</cfquery> 
			
			<cfquery datasource="#application.applicationDataSource#" name="getTaskAreas">
				SELECT a.tally_task_area_id, a.tally_task_id, a.tally_area_id
				FROM tbl_tallies_tasks_areas a 
				WHERE tally_task_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmTaskId#">
			</cfquery>
		
			<cfloop query="getTaskAreas">
				<cfset areaList = listAppend(areaList, #tally_area_id#)>
			</cfloop>
			
			<!--- ensure we keep track of the area list --->
			<cfoutput> <input type="hidden" name="AreaList" value="#AreaList#"> </cfoutput>
			
			<cfset frmTaskRetired = "#getTask.retired#">
		
			<!--- if the user hasn't entered new info, default to existing values --->
			<cfif frmTaskName EQ "">
				<cfset frmTaskName = "#getTask.task_name#">
			</cfif>
			<cfif frmTaskDetails EQ "">
				<cfset frmTaskDetails = "#getTask.task_details#">
			</cfif>
		</cfif>
		
		<label>Task Name:
			<input name="frmTaskName" value="<cfoutput>#htmlEditFormat(frmTaskName)#</cfoutput>">
		</label>
		
		<br/>
		
		<label>Description:
			<textarea name="frmTaskDetails"><cfoutput>#htmlEditFormat(frmTaskDetails)#</cfoutput></textarea>
		</label>
		
		<!--- replace the default textarea above with a prettier one --->
		<script type="text/javascript">
			//a custom configuration for this ckeditor textarea
			var contactNote = CKEDITOR.replace('frmTaskDetails',{
				toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
				toolbar:  'Basic',
				height: '200px',
				width: '500px',
				removePlugins: 'contextmenu,tabletools'/*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
			});	
		</script>	
		
		<br/>
		
		<!--- get existing areas --->
		<cfquery datasource="#application.applicationDataSource#" name="getAreas">
			SELECT a.tally_area_id, a.area_name, a.area_description, a.retired
			FROM tbl_tallies_areas a
			ORDER BY retired, area_name
		</cfquery>
		
		<fieldset>
			<legend>Select Areas</legend>

				<cfoutput>
					<cfloop query="getAreas">
						<cfif NOT retired>
							<label>
								<input type="checkbox" name="frmAreas" value="#tally_area_id#"
									   <cfif listFindNoCase(areaList, tally_area_id)>checked="true"</cfif>>
									#area_name#<br>	
							</label>
						</cfif>
					</cfloop>
				</cfoutput>

		</fieldset>
		
		<br/>
		
		<cfif frmAction EQ "Go">
		
			<fieldset>
				<legend>Retired?</legend>
				<label>
					Yes
					<input type="radio" name="frmTaskRetired" value="1" <cfif frmTaskRetired>checked="true"</cfif>>
				</label>
				<label>
					No
					<input type="radio" name="frmTaskRetired" value="0" <cfif not frmTaskRetired>checked="true"</cfif>>
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

	<!--- get existing tasks --->
	<cfquery datasource="#application.applicationDataSource#" name="getTasks">
		SELECT a.tally_task_id, a.task_name, a.task_details, a.retired
		FROM tbl_tallies_tasks a
		ORDER BY retired, task_name
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<br/>
		
		<fieldset>
			
			<legend>Choose</legend>
			
			<label>
				Select a Task:
				<select name="frmTaskId">
					<cfoutput query="getTasks">
						<option value="#tally_task_id#">
							#task_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			<input type="submit" value="Go" name="frmAction">
			
			<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
						
			<a href="<cfoutput>#cgi.script_name#?frmAction=createnew</cfoutput>">Create New Task</a>	 
			
		</fieldset>		
		
	</form>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>