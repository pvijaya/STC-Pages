<cfmodule template="#application.appPath#/header.cfm" title='Manage Rehire Deadlines'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- fetch user's email address --->
<cfquery datasource="#application.applicationDataSource#" name="getEmail">
	SELECT email
	FROM tbl_users
	WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">
</cfquery>

<!--- CFPARAMS --->
<cfparam name="frmAction" default="" type='string'>
<cfparam name="frmSemester" default="i0s0" type='string'><!---this will be in the form "i#instance_id#s#semester_id#"--->
<cfparam name="frmSemesterId" default="0" type="integer"><!---the semester_id parsed out from frmSemester--->
<cfparam name="frmMask" type="string" default="consultant"><!---the mask the deadline applies to.  Eg. consultants or CS--->
<cfparam name="frmDeadline" default="#now()#" type='string'>
<cfparam name="frmDeadlineId" type="integer" default="0">
<cfparam name="frmEmail" default="#getEmail.email#" type="string"><!---who will be emailed if a user misses the deadline.--->
<cfparam name="submitted" default="0" type="boolean">

<!--- HEADER / NAVIGATION --->
<h1>Manage Rehire Deadlines</h1>
<cfif frmAction NEQ "">
	<a href="<cfoutput>#cgi.script_name#</cfoutput>">Go Back</a> |
</cfif>
<a href="rehire-options-editor.cfm">Edit Reasons</a> |
<a href="rehire-report.cfm">Report</a> |
<a href="rehire-request.cfm">Request</a>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction EQ "Create" OR frmAction EQ "Edit">
	
		<!--- for both actions, check inputs for validity --->
		<cfif trim(frmEmail) EQ "">
			<cfthrow message="Missing Input" detail="You must provide an email.">
		</cfif>
		
		<cfif trim(frmMask) EQ "">
			<cfthrow message="Missing Input" detail="You must choose an employee type for this deadline.">
		</cfif>
		
		<cfif trim(frmDeadline) EQ "" OR NOT isDate(frmDeadline)>
			<cfset frmDeadline = ""> <!--- leaving a non-date will cause an error in the form --->
			<cfthrow message="Missing Input" detail="You must provide a valid date.">
		</cfif>
		
		<cfif frmSemesterId EQ 0>
			<cfthrow message="Error" detail="No semester selected.">
		</cfif>
		
		<cfif frmAction EQ "Create">
		
			<cfquery datasource="#application.applicationDataSource#" name="getDeadline">
				SELECT rd.deadline_id
				FROM tbl_rehire_deadlines rd 
				INNER JOIN vi_semesters s
					ON s.instance_id = rd.instance_id
					AND s.semester_id = rd.semester_id
				INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
				WHERE s.semester_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmSemesterId#">
					  AND s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
					  AND rd.mask_list = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMask#">
			</cfquery>
			
			<!--- make sure only one deadline gets created per semester / group --->
			<cfif getDeadline.recordCount GT 0>
				<cfthrow message="Error" detail="A #frmMask# deadline already exists for the chosen semester.">
			</cfif>
			
			<cfquery datasource="#application.applicationDataSource#" name="addDeadline">
				INSERT INTO tbl_rehire_deadlines (instance_id, semester_id, deadline_date, email_contact, mask_list)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmSemesterId#">,
					<cfqueryparam cfsqltype="cf_sql_datetime" value="#frmDeadline#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmEmail#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMask#">
				)
			</cfquery>
			
			<p class="ok">Deadline created successfully.</p>
			<cfset frmAction EQ ""> <!--- go back to the base Manage Rehire Deadlines --->
			
		<cfelseif frmAction EQ "Edit">
		
			<!--- make sure we still have a deadline id --->
			<cfif frmDeadlineId EQ 0>
				<cfthrow message="Error" detail="No deadline selected.">
			</cfif>
		
			<cfquery datasource="#application.applicationDataSource#" name="updateDeadline">
				UPDATE tbl_rehire_deadlines
				SET deadline_date = <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmDeadline#">,
					email_contact = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmEmail#">,
					mask_list = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMask#">
				WHERE deadline_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmDeadlineId#">
			</cfquery>
			
			<p class="ok">Deadline updated successfully.</p>
			<cfset frmAction EQ "EditForm"> <!--- go back to edit form --->
		
		</cfif>
	
	</cfif>
	
	<cfcatch>
	    <cfoutput>
			
	        <p class="warning">
	            #cfcatch.Message# - #cfcatch.Detail#
	        </p>
			
			<!--- make sure we get back to the right form screen if it errors out --->
			<cfif frmAction EQ "Create">
				<cfset frmAction = "Go">
			<cfelseif frmAction EQ "Edit">
				<cfset frmAction = "EditForm">
			</cfif>
			
	    </cfoutput>
	</cfcatch>

</cftry>

<!--- DRAW FORMS --->
<cfif frmAction EQ "Go" OR frmAction EQ "EditForm">

	<cfif frmAction EQ "Go">
		<h2>Create New Deadline</h2>
	<cfelse>
		<h2>Edit Existing Deadline</h2>
	</cfif>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<!--- if we're at the deadline form, we got here from one of two ways --->
		<!--- a) create, frmAction="create" and provided frmSemester --->
		<!--- b) edit, frmAction="edit" and provided frmDeadlineId --->
		<!--- either way, we need to make sure we get the semester's info from a query called getSemester --->
		
		<cfif frmAction EQ "Go">
		
			<!--- parse frmSemester (string) into an object with two fields, instance and semester --->
			<cfset semStruct = parseSemesterString(frmSemester)>
		
			<!--- use that info for getSemester --->
			<cfquery datasource="#application.applicationDataSource#" name="getSemester">
				SELECT s.start_date, s.end_date, i.instance_name, s.semester_name, s.semester_id
				FROM vi_semesters s
				INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
				WHERE s.semester_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#semStruct['semester']#">
					  AND s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#semStruct['instance']#">
			</cfquery>
		
		<cfelseif frmAction EQ "EditForm">
		
			<!--- look up the existing information for frmDeadlineId --->
			<cfquery datasource="#application.applicationDataSource#" name="getDeadline">
				SELECT rd.deadline_date, rd.email_contact, rd.mask_list
				FROM tbl_rehire_deadlines rd 
				INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
				WHERE rd.deadline_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmDeadlineId#">
			</cfquery>
		
			<!--- use the deadline id for getSemester --->
			<cfquery datasource="#application.applicationDataSource#" name="getSemester">
				SELECT s.start_date, s.end_date, i.instance_name, s.semester_name, s.semester_id
				FROM tbl_rehire_deadlines rd 
				INNER JOIN vi_semesters s ON s.semester_id = rd.semester_id
				INNER JOIN tbl_instances i ON i.instance_id = rd.instance_id
				WHERE rd.deadline_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmDeadlineId#">
			</cfquery>
			
			<!--- if the form hasn't been submitted, default to what's in the database --->
			<cfif getDeadline.recordCount GT 0 AND submitted EQ 0>
				<cfset frmDeadline = getDeadline.deadline_date>
				<cfset frmEmail = getDeadline.email_contact>
				<cfset frmMask = getDeadline.mask_list>
			</cfif>
			
		</cfif>	
		
		<cfoutput>
			
			<fieldset>
			
				<!--- semester info - this is why we need getSemester above --->
				<legend>
					#getSemester.instance_name# #getSemester.semester_name# #dateFormat(getSemester.start_date, "yyyy")# 
					(#dateFormat(getSemester.start_date, "mmm d, yyyy")# to #dateFormat(getSemester.end_date, "mmm d, yyyy")#)
				</legend>
				
				<!--- hidden inputs --->
				<input type="hidden" name="frmSemester" value="#frmSemester#">
				<input type="hidden" name="frmSemesterId" value="#getSemester.semester_id#">
				<input type="hidden" name="submitted" value="1">
				<input type="hidden" name="frmDeadlineId" value="#frmDeadlineId#">
				
				<p>
					Note: When selecting a date, please keep in mind the way that PIE handles deadlines.
					If March 31st is selected, a rehire request will be considered 'late' after 11:59 PM on March 30th. 
					In order to accept requests through 11:59 PM on March 31st, the deadline must be set to April 1st. 
					To avoid confusion, the consultant rehire request page will display a date one day previous to the deadline date
					(i.e. if the deadline is set to April 1st, consultants will see March 31st).
				</p>
				
				<table>
					<tr>
						<td><label for="deadline">Deadline:</label></td>
						<td>
							<input type="text" id="deadline" name="frmDeadline" 
							       value="#dateFormat(frmDeadline, 'mmm dd, yyyy')#">
						</td>
					</tr>
									
					<tr>
						<td><label for="email">Email *:</label></td>
						<td>
							<input type="text" id="email" name="frmEmail" value="#frmEmail#">
						</td>
					</tr>				
				</table>
				
				<span class="tinytext">
					* This address will be sent a message when someone submits a rehire request after the deadline.
				</span>
				
				<br/><br/>
				
				<fieldset>
					<legend>For (choose one)</legend>
				
					<label>
						<input type="radio" name="frmMask" value="Consultant" 
						       <cfif frmMask EQ 'consultant'>checked="yes"</cfif>>
						Consultants
					</label><br/>
					<label>
					<input type="radio" name="frmMask" value="CS" 
						   <cfif frmMask EQ 'cs'>checked="yes"</cfif>>
						Consultant Supervisors
					</label><br/>
				
				</fieldset>
				
				<br/>
				
				<cfif frmAction EQ "Go">
					<input type="submit" name="frmAction" value="Create">
				<cfelse>
					<input type="submit" name="frmAction" value="Edit">
				</cfif>
			
			</fieldset>
			
		</cfoutput>
		
		<!--- make our deadline a datepicker --->
		<script type="text/javascript">
			$(document).ready(function(){
				$("input[name='frmDeadline']").datepicker({dateFormat: 'M d, yy'});
			});
		</script>
	
	</form>

<cfelse>
	
	<!--- fetch existing deadlines for the user's instance --->
	<!--- only future and current semesters will appear here --->
	<cfquery datasource="#application.applicationDataSource#" name="getPresentDeadlines">
		SELECT rd.deadline_id, rd.instance_id, rd.semester_id, i.instance_name, s.semester_name, s.start_date, s.end_date, rd.deadline_date, rd.email_contact, rd.mask_list
		FROM tbl_rehire_deadlines rd
		INNER JOIN vi_semesters s ON s.instance_id = rd.instance_id AND s.semester_id = rd.semester_id
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE s.start_date >= GETDATE()
			  AND rd.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY i.instance_name, rd.mask_list, s.start_date
	</cfquery>
	
	<!--- only show the existing deadlines table if there are deadlines to populate it --->
	<cfif getPresentDeadlines.recordCount GT 0>
	
		<fieldset style="margin-top:2em;">
			<legend>Edit Existing Deadlines</legend>
		
			<table class="stripe">
			
				<!---draw our column headers--->
				<tr class="titlerow">
					<th>Semester</th>
					<th>For</th>
					<th>Deadline</th>
					<th>Email</th>
					<th>Link</th>
					<th>Report</th>
				</tr>
		
				<cfloop query="getPresentDeadlines">
					
					<cfoutput>
								
							<tr>
								<td>
									#semester_name# #dateFormat(start_date, "yyyy")# 
									(#dateFormat(start_date, "mm/dd")# to #dateFormat(end_date, "mm/dd")#)
								</td>
								<td>#mask_list#</td>
								<td>
									#dateFormat(deadline_date, "mmm d, yyyy")#
								</td>
								<td>
									#email_contact#
								</td>
								<td>
									<!--- link to edit form --->
									<a href="#cgi.script_name#?frmAction=editForm&frmDeadlineId=#deadline_id#">Edit</a>
								</td>
								<td>
									<!--- link to report --->
									<a href="rehire-report.cfm?frmDeadlineId=#deadline_id#">Report</a>
								</td>
							</tr>
						
					</cfoutput>
					
				</cfloop>
			
			</table>
			
		</fieldset>
	
	</cfif>
	
	<!--- now draw a select box of the semesters for new deadlines. --->
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<fieldset style="margin-top:2em;">
			
			<legend>Add a New Deadline</legend>
			<cfset drawSemesterSelector('future')> <!--- show only current / future semesters --->
			<input type="submit" name="frmAction" value="Go">
			
		</fieldset>
		
	</form>
	
</cfif>

<!--- CFFUNCTIONS --->
<!--- provided a semester / instance string of the form i0s0, parses it into a struct --->
<cffunction name="parseSemesterString">
	<cfargument name="semester" type="string" default="">
	
	<cfloop list="#frmSemester#" index="n">
		
		<!--- find the instance id --->
		<cfset instanceId = mid(n, find("i", n)+1, (find("s", n) - 1 - find("i", n)))>
		
		<!--- find the semester id, depending where it is in the list --->
		<cfset semesterId = right(n, len(n) - find("s", n))>
		
		<cfset semesterStruct = StructNew()>
		<cfif isNumeric(instanceId) AND isNumeric(semesterId)>
			<cfset semesterStruct['instance'] = instanceId>
			<cfset semesterStruct['semester'] = semesterId>
		<cfelse>
			<cfset semesterStruct['instance'] = 0>
			<cfset semesterStruct['semester'] = 0>
		</cfif>
		
	</cfloop>
	
	<cfreturn semesterStruct>
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>