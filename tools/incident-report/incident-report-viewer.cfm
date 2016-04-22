<cfmodule template="#application.appPath#/header.cfm" title='Incident Report Viewer'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
	
<!--- CFPARAMS --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="incidentId" type="integer" default="0">
<cfparam name="frmStartDate" default="#DateAdd('d',-30,DateFormat(Now(),'yyyy/mm/dd'))#" type="date">
<cfparam name="frmEndDate" default="#DateFormat(Now(),'yyyy/mm/dd')#" type="date">

<!--- HEADER / NAVIGATION --->
<h1>Incident Report Viewer</h1>
<cfoutput>
	<cfif frmAction EQ "View">
		<a href="#application.appPath#/tools/incident-report/incident-report-viewer.cfm?frmAction=Search&frmStartDate=#frmStartDate#&frmEndDate=#frmEndDate#">Go Back</a> |
	</cfif>
	<a href="#application.appPath#/tools/incident-report/incident-report.cfm">Incident Report Form</a>
	<cfif hasMasks('Admin')>
		| <a href="#application.appPath#/tools/incident-report/incident-situation-manager.cfm">Situations Manager</a>
	</cfif>
</cfoutput>

<br/><br/>

<!--- DRAW FORMS --->
<cfoutput>

	<!--- date range selector --->
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<label for="startDateId">From: </label>
		<input id="startDateId" type="text" style="font-size:110%; width:150px;text-align:center;"  
		       name="frmStartDate" value="#DateFormat(frmStartDate,'mm/dd/yyyy')#">
		       
		<script type="text/javascript">
			$("##startDateId").datepicker({dateFormat: "mm/dd/yy"});
		</script>
		
		<label for="endDateId">To: </label>
		<input id="endDateId" type="text" style="font-size:110%; width:150px;text-align:center;" 
		       name="frmEndDate" value="#DateFormat(frmEndDate,'mm/dd/yyyy')#">
		       
		<script type="text/javascript">
			$("##endDateId").datepicker({dateFormat: "mm/dd/yy"});
		</script>
		
		<input type="submit"  name="frmAction" value="Search">
		<input type="button" onclick="window.location='#application.appPath#/tools/incident-report/incident-report-viewer.cfm'" 
		       name="frmAction" value="Reset">
	
	</form>
	
	<hr/>
	
	<!--- a specific incident report has been selected for viewing --->
	<cfif frmAction EQ "View">
	
		<cfquery datasource="#application.applicationdatasource#" name="getIncident">
			SELECT *
			FROM tbl_incident_reports r
			JOIN tbl_users u ON r.reporter_uid = u.user_id
			WHERE r.incident_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#incidentId#">
		</cfquery>
		
		<cfquery datasource="#application.applicationdatasource#" name="getSituations">
			SELECT s.incident_situation_id, s.situation
			FROM tbl_incident_situation_match sm
			INNER JOIN tbl_incident_situations s ON s.incident_situation_id = sm.incident_situation_id
			WHERE sm.incident_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#incidentId#">
			ORDER BY s.sort_order, s.situation
		</cfquery>
		
		<cfquery datasource="#application.applicationdatasource#" name="peopleInvolved">
			SELECT *
			FROM tbl_incident_people 
			WHERE incident_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#incidentId#">
		</cfquery>
		
		<cfloop query="getIncident">
		
			<fieldset>
				
				<div style="width:30%;float:left;">
					
					<strong>Situation Time:</strong> 
					#DateFormat(situation_time, 'mmm dd, yyyy')# at #TimeFormat(situation_time, 'hh:nn tt')#
					<br/><br/>
					
					<strong>Submission Time:</strong> 
					#DateFormat(submitted_time, 'mmm dd, yyyy')# at #TimeFormat(submitted_time, 'hh:nn tt')#
					<br/><br/>
					
					<cfset labName = getLabsById("i#instance_id#l#lab_id#")>
					<strong>Lab:</strong> <cfoutput>#labName.building_name# (#labName.lab_name#)</cfoutput>
					<br/><br/>
					
					<strong>PR Number:</strong> <cfif pr_number EQ "">N/A<cfelse>#pr_number#</cfif>
					<br/><br/>
					
					<strong>Submitted By:</strong> #first_name# #last_name# (#username#) 
					<br/><br/>
					
					<strong>Situation Conditions:</strong>
					
					<cfif getSituations.recordCount eq 0>
						N/A<br/><br/>
					<cfelse>
						<ul>
						<cfloop query="getSituations">
							<li>#situation#</li>
						</cfloop>
						</ul>
					</cfif>
					
					
					<strong>People Involved or Around:</strong>
					<cfif peopleInvolved.recordCount EQ 0>
						N/A<br/>
					<cfelse>
						<ul>
							<cfloop query="peopleInvolved">
								<li>#name# (#person_position#)</li>
							</cfloop>
						</ul>
					</cfif>
					
				</div>
				
				<div style="width:65%;float:right;">
					<strong>Description:</strong><br/>
					<blockquote><p>#nl2br(description)#</p></blockquote>
				</div>
				
				<div style="clear:both;"></div>
				
			</fieldset>
			
		</cfloop>
		
	<cfelse>
	
		<cfquery datasource="#application.applicationdatasource#" name="recentIncidents">
			SELECT TOP 25 *
			FROM tbl_incident_reports r
			JOIN tbl_users u ON r.reporter_uid = u.user_id
			WHERE r.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
				<cfif frmAction EQ "Search">
				AND r.submitted_time BETWEEN <cfqueryparam cfsqltype="cf_sql_date" value="#frmStartDate#"> 
					  AND <cfqueryparam cfsqltype="cf_sql_date" value="#frmEndDate#">
				</cfif>
			ORDER BY r.submitted_time DESC
		</cfquery>
		
		<cfloop query="recentIncidents">
			
			<cfif frmAction EQ "Search">
				<cfset href = "incident-report-viewer.cfm?frmAction=View&incidentId=#incident_id#&frmStartDate=#frmStartDate#&frmEndDate=#frmEndDate#">
			<cfelse>
				<cfset href = "incident-report-viewer.cfm?frmAction=View&incidentId=#incident_id#">
			</cfif>
			<a style="display:block;" class="block-card hover-box" 
			href="#href#">
				<span style="display:block;width:30%;float:left;">
					Date Submitted: #DateFormat(situation_time, 'mmm dd, yyyy')# at #TimeFormat(situation_time, 'hh:nn tt')#
					<br/>
						<cfset labName = getLabsById("i#instance_id#l#lab_id#")>
						Lab: <cfoutput>#labName.building_name# (#labName.lab_name#)</cfoutput>
					<br/>
					Submitted By: #first_name# #last_name# (#username#) 
					<br/>
				</span>
				<div style="width:65%;float:right;"><p>#left(description,200)#<cfif len(description) GT 200>...</cfif></p></div>
				<div style="clear:both;"></div>
			</a>
			
		</cfloop>
		
	</cfif>

</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>