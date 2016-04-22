<cfmodule template="#application.appPath#/header.cfm" title='Form Submissions' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<h1>Form Submissions</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 1em;">
	<cfif hasMasks("Admin")>
		<a href="<cfoutput>#application.appPath#/tools/forms/attribute_manager.cfm</cfoutput>">Manage Attributes</a> |
		<a href="<cfoutput>#application.appPath#/tools/forms/form_manager.cfm</cfoutput>">Manage Forms</a> |
		<a href="<cfoutput>#application.appPath#/tools/forms/form_report.cfm"</cfoutput>>Form Report</a> |
	</cfif>
</p>	

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmFormId" type="integer" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d",-1,now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<cfparam name="frmUserFor" type="integer" default="0">
<cfparam name="frmUserBy" type="integer" default="0">
<cfparam name="frmLabId" type="string" default="i0l0">
<cfparam name="frmAttributes" type="string" default="">

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
	
		<!--- get existing forms --->
		<cfquery datasource="#application.applicationDataSource#" name="getForms">
			SELECT a.form_id, a.form_name, a.form_description, a.retired
			FROM tbl_forms a
			ORDER BY a.retired, a.form_name
		</cfquery>
		
		<!--- get existing attributes --->
		<cfquery datasource="#application.applicationDataSource#" name="getAttributes">
			SELECT a.attribute_id, a.attribute_name, a.attribute_details, a.attribute_text, a.retired
			FROM tbl_attributes a
			ORDER BY a.retired, a.attribute_name
		</cfquery>
		
		<!--- get users who have recent forms --->	
		<cfquery datasource="#application.applicationDataSource#" name="getUsers">
			SELECT DISTINCT t.user_id, u.username, u.last_name, u.first_name
			FROM tbl_forms_submissions t
			INNER JOIN tbl_users u ON u.user_id = t.user_id
			ORDER BY u.last_name, u.first_name, u.username
		</cfquery>	
		<cfquery datasource="#application.applicationDataSource#" name="getSubmitters">
			SELECT DISTINCT t.submitted_by, u.username, u.last_name, u.first_name
			FROM tbl_forms_submissions t
			INNER JOIN tbl_users u ON u.user_id = t.submitted_by
			ORDER BY u.last_name, u.first_name, u.username
		</cfquery>
		
		<fieldset>
			
			<legend>Choose Search Parameters</legend>
			
			<label for="frmFormId">Form:</label>
				<select name="frmFormId">
					<option value = "0">
					<cfoutput query="getForms">
						<option value="#form_id#"
								<cfif frmFormId EQ form_id>selected="selected"</cfif>>
							#form_name# <cfif retired>(retired)</cfif>
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
			
			<label for="frmUserFor">Form Submitted For User:</label>
				<select name="frmUserFor">
					<option value = "0">
					<cfoutput query="getUsers">
						<option value="#user_id#"
								<cfif frmUserFor EQ user_id>selected="selected"</cfif>>
							#last_name#, #first_name# (#username#)
						</option>
					</cfoutput>
				</select>
			</label>	
				   
			<br/><br/>
			
			<label for="frmUserBy">Form Submitted By User:</label>
				<select name="frmUserBy">
					<option value = "0">
					<cfoutput query="getSubmitters">
						<option value="#submitted_by#"
								<cfif frmUserBy EQ submitted_by>selected="selected"</cfif>>
							#last_name#, #first_name# (#username#)
						</option>
					</cfoutput>
				</select>
			</label>	
				   
			<br/><br/>
			
			<label for="frmLabId">Form Submitted for Lab:</label>
			<cfset drawLabsSelector("frmLabId", frmLabId, 0, 1)>
			
			<br/><br/>
			
			<fieldset>
				<legend>Attributes</legend>
				<cfoutput>
					<cfloop query="getAttributes">
						<cfif NOT retired>
							<label>
								<input type="checkbox" name="frmAttributes" value="#attribute_id#"
										<cfif listFindNoCase(frmAttributes, attribute_id)>checked="true"</cfif>>
									#attribute_name#<br>	
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

	<cfset lab = parseLabName(frmLabId)>
	<cfset labId = lab['lab']>
	<cfset instanceId = lab['instance']>

	<cfquery datasource="#application.applicationDataSource#" name="getSearchResults">
		SELECT DISTINCT TOP 100 f.form_id, f.form_name, 
		                        fs.submission_id, fs.submission_date, fs.user_id, fs.submitted_by, fs.score,
		                        fs.lab_id, fs.instance_id, w.workstation_name
		FROM tbl_forms f
		INNER JOIN tbl_forms_submissions fs ON fs.form_id = f.form_id
		LEFT OUTER JOIN vi_workstations w ON w.workstation_id = fs.workstation_id
		LEFT OUTER JOIN tbl_forms_attributes fa ON fa.form_id = f.form_id
		WHERE fs.submission_date BETWEEN <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmStartDate#"> AND
								        <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmEndDate#">
		<cfif labId GT 0>AND fs.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#"></cfif>
		<cfif instanceId GT 0>AND fs.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		<cfelse>AND fs.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		</cfif>
		<cfif frmFormId GT 0> AND f.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmFormId#"></cfif>
		<cfif frmUserBy GT 0> AND fs.submitted_by = <cfqueryparam cfsqltype="cf_sql_int" value="#frmUserBy#"></cfif>
		<cfif frmUserFor GT 0> AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserFor#"></cfif>
		<cfif frmAttributes NEQ "">AND fa.attribute_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmAttributes#" list="true">)</cfif>
		ORDER BY fs.submission_date DESC
	</cfquery>
	
	<h1>Search Results</h1>
	
	<cfif getSearchResults.recordCount EQ 0>
		
		No results found.
			
	<cfelse>
	
		<table class="stripe" style="padding:0px;">
			
			<tr class="titlerow" style="padding:5px;">
				<th>Link</th>
				<th>Form</th>
				<th>Submitted For</th>
				<th>Submitted By</th>
				<th>Lab</th>
				<th>Date</th>
				<th>Score</th>
				<th>Workstation</th>
			</tr>
			
				<cfloop query="getSearchResults">
					
					<cfquery datasource="#application.applicationDataSource#" name="getUserFor">
						SELECT u.username
						FROM tbl_users u
						WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#user_id#">
					</cfquery>
					
					<cfquery datasource="#application.applicationDataSource#" name="getUserBy">
						SELECT u.username
						FROM tbl_users u
						WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#submitted_by#">
					</cfquery>
					
					<cfquery datasource="#application.applicationDataSource#" name="getItems">
						SELECT fi.form_item_id, fit.type_text
						FROM tbl_forms_items fi
						INNER JOIN tbl_forms_items_types fit ON fit.type_id = fi.item_type
						WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_id#">
						      AND fi.retired = 0
					</cfquery>
					
					<cfset getLab = getLabsById("i#instance_id#l#lab_id#")>
					
					<cfoutput>
						<tr>
							<td><a href="#application.appPath#/tools/forms/form_view_submission.cfm?submissionId=#submission_id#&referrer=#urlEncodedFormat(cgi.script_name)#">#submission_id#</a></td>
							<td>#form_name#</td>
							<td><cfif getUserFor.recordCount GT 0>#getUserFor.username#<cfelse>N/A</cfif></td>
							<td><cfif getUserBy.recordCount GT 0>#getUserBy.username#<cfelse>N/A</cfif></td>
							<td><cfif getLab.recordCount GT 0>#getLab.lab_name#<cfelse>N/A</cfif></td>
							<td class="tinytext">#dateFormat(submission_date, "MMM d, yyyy")# 
								                 #timeFormat(submission_date, "h:mm tt")#</td>
							<td><cfif score GTE 0>#score# / #maxScoreQuiz(form_id)#<cfelse>N/A</cfif></td>
							<td>#shortWorkstationName(workstation_name)#</td>
						</tr>	
					</cfoutput>	
				</cfloop>
				
		</table>
	
	</cfif>
	
	<!--- preserve user input --->
	<cfoutput> <input type="hidden" name="frmFormId" value="#frmFormId#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmUserFor" value="#frmUserFor#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmUserBy" value="#frmUserBy#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmStartDate" value="#frmStartDate#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmEndDate" value="#frmEndDate#"> </cfoutput>
	<cfoutput> <input type="hidden" name="frmAttributes" value="#frmAttributes#"> </cfoutput>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>