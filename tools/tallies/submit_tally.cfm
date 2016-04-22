<cfmodule template="#application.appPath#/header.cfm" title='Submit Tally' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">

<h1>Submit Tally</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
	[<a href="<cfoutput>#application.appPath#/tools/tallies/tally_report.cfm</cfoutput>">Search Tallies</a>]
	<cfif hasMasks("Admin")>
			[<a href="<cfoutput>#application.appPath#/tools/tallies/task_manager.cfm</cfoutput>">Manage Tasks</a>]
			[<a href="<cfoutput>#application.appPath#/tools/tallies/area_manager.cfm</cfoutput>">Manage Areas</a>]
	</cfif>
</p>

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmTaskId" type="numeric" default="0">
<cfparam name="frmTaskDetails" type="string" default="">
<cfparam name="frmAreas" type="string" default="">
<cfparam name="frmComment" type="string" default="">

<!--- set up the cfparams for the submission boxes --->
<cfif frmTaskId gt 0>
	
	<!--- get existing areas --->
	<cfquery datasource="#application.applicationDataSource#" name="getTaskAreas">
		SELECT a.tally_task_id, a.tally_area_id, b.task_name, b.task_details, 
		       c.area_name, c.area_description, c.retired
		FROM tbl_tallies_tasks_areas a
		INNER JOIN tbl_tallies_tasks b ON b.tally_task_id = a.tally_task_id
		INNER JOIN tbl_tallies_areas c ON c.tally_area_id = a.tally_area_id
		WHERE a.tally_task_id = #frmTaskId#
	</cfquery>	

	<!--- ensure correct input --->
	<cfloop query="getTaskAreas">
		<cftry>
			<cfparam name="frmArea#tally_area_id#" type="integer" default="0">
			<cfset frmAreas = listAppend(frmAreas, tally_area_id)>			
		<cfcatch>
			<cfset frmAction = "go">
			<cfset "frmArea#tally_area_id#" = 0>
			<cfoutput>
				<p class="warning">
					#area_name# - #cfcatch.Detail#
				</p>
			</cfoutput>
		</cfcatch>
		</cftry>
	</cfloop>

</cfif>

<!--- handle user input --->
<cfif frmAction EQ "Submit">
	
	<cftry>
		
		<!--- get the new submission into the system and get back our submission_id --->
		<cfquery datasource="#application.applicationDataSource#" name="addTally">
			INSERT INTO tbl_tallies (tally_task_id, user_id, instance_id, comment)
			OUTPUT inserted.tally_id
			VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmTaskId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">,
					<cfqueryparam cfsqltype="cf_sql_varchat" value="#frmComment#">
			)
		</cfquery>
	
		<!--- now we're ready to send our counts to the database --->
		<cfset cnt = 1>
		<cfquery datasource="#application.applicationDataSource#" name="addCounts">
			INSERT INTO tbl_tallies_counts (tally_id, tally_task_id, tally_area_id, area_count)
			OUTPUT inserted.tally_count_id
			VALUES 
			<cfloop query="getTaskAreas">
				<cfset val = evaluate("frmArea#tally_area_id#")>
				(<cfqueryparam cfsqltype="cf_sql_integer" value="#addTally.tally_id#">, 
				 <cfqueryparam cfsqltype="cf_sql_integer" value="#frmTaskId#">,
				 <cfqueryparam cfsqltype="cf_sql_integer" value="#tally_area_id#">,
				 <cfqueryparam cfsqltype="cf_sql_integer" value="#val#">)
				<cfif cnt lt listLen(frmAreas)>,</cfif>
				<cfset cnt = cnt + 1>
			</cfloop>
		</cfquery>
	
		<p class="ok"> Your submission was successful. </p>
	
	<cfcatch>
		<cfset frmAction = "go">
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
	
</cfif>

<!--- draw forms --->

<cfif frmAction EQ "Go">

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

		<!--- get the last submission, if one exists --->
		<cfquery datasource="#application.applicationDataSource#" name="getLastTally">
			SELECT TOP 1 a.tally_id, a.tally_task_id, a.user_id, a.instance_id, a.tally_date, b.username
			FROM tbl_tallies a
			JOIN tbl_users b ON b.user_id = a.user_id
			WHERE a.tally_task_id = #frmTaskId#
			ORDER BY a.tally_date DESC
		</cfquery>
		
		<!--- provide information about the last time this task was submitted --->
		<cfoutput><h3>#getTaskAreas.task_name#</h3>
			<cfif getLastTally.recordCount GT "0"> 
				<p class="tinytext">Last submission by #getLastTally.username# on #dateFormat(getLastTally.tally_date,  "MMM d, yyyy")# #timeFormat(getLastTally.tally_date, "h:mm tt")#.</p>
			</cfif>
		</cfoutput>
		
		<cfoutput><strong>Details:</strong> <blockquote>#getTaskAreas.task_details#</blockquote></cfoutput>
		
		<!--- draw our pretty submission table --->
		<table class="stripe" style="padding:0px;" border="1px">
			<tr class="titlerow" style="padding:5px;">
				<th>Area</th>
				<th>Count</th>
			</tr>
			<cfset cnt = 1>
			<cfloop query="getTaskAreas">
				<cfoutput>
					<tr>
						<cfif NOT retired>
							<td><label for="areaId#tally_area_id#">#area_name#</label></td>
							<td><input type="text"
									   name="frmArea#tally_area_id#"
									   value="#htmlEditFormat(evaluate("frmArea#tally_area_id#"))#"
									   id="areaId#tally_area_id#">
							</td>
						</cfif>
					</tr>
				</cfoutput>
				<cfset cnt = cnt + 1>
			</cfloop>
		</table>
			
		<br/>
		
		<label for="Comment"><h5>Comments (optional):</h5></label>
			<textarea name="frmComment" id="Comment"><cfoutput>#htmlEditFormat(frmComment)#</cfoutput></textarea>
		
		<!--- replace the default textarea above with a prettier one --->
		<script type="text/javascript">
			//a custom configuration for this ckeditor textarea
			var contactNote = CKEDITOR.replace('frmComment',{
				toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
				toolbar:  'Basic',
				height: '200px',
				width: '500px',
				removePlugins: 'contextmenu,tabletools'/*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
			});	
		</script>	
		
		<br/>
		
		<input type="submit" value="Submit" name="frmAction">
		
		<br/>
		
		<p> <cfoutput><a href="#cgi.script_name#">Choose another task.</a></cfoutput> </p>	
	
		<cfoutput> <input type="hidden" name="frmTaskId" value="#frmTaskId#"> </cfoutput>
	
	</form>

<cfelse> <!--- default: select a task to submit --->

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
			
		</fieldset>
		
	</form>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>