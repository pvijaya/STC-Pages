<cfmodule template="#application.appPath#/header.cfm" title='Tally Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">

<h1>Tally Report</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 1em;">
	[<a href="<cfoutput>#application.appPath#/tools/tallies/submit_tally.cfm</cfoutput>">Submit a Tally</a>]
	<cfif hasMasks("Admin")>
		[<a href="<cfoutput>#application.appPath#/tools/tallies/task_manager.cfm</cfoutput>">Manage Tasks</a>]
		[<a href="<cfoutput>#application.appPath#/tools/tallies/area_manager.cfm</cfoutput>">Manage Areas</a>]
	</cfif>
</p>	

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmTaskId" type="integer" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d",-1,now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<cfparam name="frmUser" type="integer" default="0">
<cfparam name="frmAreas" type="string" default="">

<!--- sanitize our dates for searching --->
<cfset frmStartDate = dateFormat(frmStartDate, "mmm d, yyyy ") & "00:00">
<cfset frmEndDate = dateFormat(frmEndDate, "mmm d, yyyy ") & "23:59:59.9">

<cfif frmAction EQ "Clear">
	<cfset frmTaskId = "0">
	<cfset frmUser = "0">
	<cfset frmStartDate = "#dateAdd("d", -1, now())#">
	<cfset frmEndDate = "#now()#">
	<cfset frmAreas = "">
	<cfset frmAction = "">
</cfif>

<!--- draw forms --->

<!--- when showing search results, collapse our form --->
<cfif frmAction EQ "Search">
	<span class="trigger">Search Parameters</span>
<cfelse>
	<span class="triggerexpanded">Search Parameters</span>
</cfif>

<div>
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	
		<!--- get existing tasks --->
		<cfquery datasource="#application.applicationDataSource#" name="getTasks">
			SELECT a.tally_task_id, a.task_name, a.task_details, a.retired
			FROM tbl_tallies_tasks a
			ORDER BY retired, task_name
		</cfquery>
		
		<!--- get existing areas --->
		<cfquery datasource="#application.applicationDataSource#" name="getAreas">
			SELECT a.tally_area_id, a.area_name, a.area_description, a.retired
			FROM tbl_tallies_areas a
			ORDER BY retired, area_name
		</cfquery>
		
		<!--- get recent tally users --->	
		<cfquery datasource="#application.applicationDataSource#" name="getUsers">
			SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
			FROM tbl_tallies t
			INNER JOIN tbl_users u ON u.user_id = t.user_id
			ORDER BY u.last_name, u.first_name, u.username
		</cfquery>	
		
		<fieldset>
			
			<legend>Choose Search Parameters</legend>
			
			<label for="frmTaskId">Task:</label>
				<select name="frmTaskId">
					<option value = "0">
					<cfoutput query="getTasks">
						<option value="#tally_task_id#"
								<cfif frmTaskId EQ tally_task_id>selected="selected"</cfif>>
							#task_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>	
			
			<br/><br/>
					
			<cfoutput>
				<label>From: <input class="date" name="frmStartDate" value="#dateFormat(frmStartDate,  "MMM d, yyyy")#"></label>
				<label>To: <input class="date" name="frmEndDate" value="#dateFormat(frmEndDate,  "MMM d, yyyy")#"></label>
			</cfoutput>
			
			<script type="text/javascript">
				$(document).ready(function() {
				// make the dates calendars.
				$("input.date").datepicker({dateFormat: 'M d, yy'});
				});
			</script>
			
			<br/><br/>
			
			<label for="frmUser">User:</label>
				<select name="frmUser">
					<option value = "0">
					<cfoutput query="getUsers">
						<option value="#user_id#"
								<cfif frmUser EQ user_id>selected="selected"</cfif>>
							#last_name#, #first_name# (#username#)
						</option>
					</cfoutput>
				</select>
			</label>	
				   
			<br/><br/>
			
			<fieldset>
				<legend>Areas</legend>
				<br/>
				<cfoutput>
					<cfloop query="getAreas">
						<cfif NOT retired>
							<label>
								<input type="checkbox" name="frmAreas" value="#tally_area_id#"
										<cfif listFindNoCase(frmAreas, tally_area_id)>checked="true"</cfif>>
									#area_name#<br>	
							</label>
						</cfif>
					</cfloop>
				</cfoutput>
			</fieldset>
			
		</fieldset>
		
		<p class="submit">
			<input type="submit" value="Search" name="frmAction">
			<input type="submit" value="Clear" name="frmAction">
		</p>	
			
	</form>
</div>

<!--- search --->

<cfif frmAction EQ "Search">

	<cfquery datasource="#application.applicationDataSource#" name="getSearchResults">
		SELECT DISTINCT TOP 100 a.tally_id, b.task_name, c.username, a.tally_date, a.comment
		FROM tbl_tallies a
		INNER JOIN tbl_tallies_tasks b ON b.tally_task_id = a.tally_task_id
		INNER JOIN tbl_users c ON c.user_id = a.user_id
		INNER JOIN tbl_tallies_counts d ON d.tally_id = a.tally_id
		WHERE a.tally_date BETWEEN <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmStartDate#"> AND
								   <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmEndDate#">
		<cfif frmTaskId GT 0> AND a.tally_task_id = #frmTaskID#</cfif>
		<cfif frmUser GT 0> AND a.user_id = #frmUser#</cfif>
		<cfif frmAreas NEQ "">AND d.tally_area_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmAreas#" list="true">)</cfif>
		ORDER BY a.tally_date DESC
	</cfquery>

	<h1>Search Results</h1>
	<table class="stripe" style="padding:0px;">
		<tr class="titlerow" style="padding:5px;">
			<th>Link</th>
			<th>Comments</th>
			<th>Task</th>
			<th>Submitted By</th>
			<th>Date</th>
		</tr>
		<cfloop query="getSearchResults">
			<cfoutput>
				<tr>
					<td><a href="#application.appPath#/tools/tallies/view_tally.cfm?tallyId=#tally_id#">Link</a></td>
					<td>#left(stripTags(comment),95)#</td>
					<td>#task_name#</td>
					<td>#username#</td>
					<td class="tinytext">#dateFormat(tally_date,  "MMM d, yyyy")# 
						#timeFormat(tally_date, "h:mm tt")#</td>
				</tr>	
			</cfoutput>	
		</cfloop>
	</table>
	
	<!--- preserve user input --->
	<cfoutput> <input type="hidden" name="frmTaskId" value="#frmTaskId#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmUser" value="#frmUser#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmStartDate" value="#frmStartDate#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmEndDate" value="#frmEndDate#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmAreas" value="#frmAreas#"> </cfoutput>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>