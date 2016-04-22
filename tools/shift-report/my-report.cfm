<cfmodule template="#application.appPath#/header.cfm" title='Personal Shift Report'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/shift-report/mentee-report-functions.cfm">

<!---the parameters the user can provide--->
<cfparam name="dayDate" type="date" default="#dateFormat(now(), 'mmm d, yyyy')#">
<cfparam name="nextShift" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">
<cfparam name="previousShift" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">

<cfset myInstance = getInstanceById(session.primary_instance)>

<!---now bring in the include, event handler, and div elements we need to display contacts in a bootstrap modal.--->
<cfinclude template="#application.appPath#/views/contacts/view-contacts.cfm">
<script type="text/javascript">
	$(document).ready(function(){
		//Add an event handler to open up our bootrap modal with the contact clicked by the user.
		$("a.contactLink").click(function(e){
			//if the user was holding he ctrl or shift keys don't show our pop-in use the browser's behavior
			if(e.ctrlKey || e.shiftKey)
				return (0);

			e.preventDefault();//don't let clicking links whisk them off to another page.

			var cId = $(this).attr("contactId");

			//use the new contact viewer and a bootstrap modal to display the contact.
			contactViewer("#contactModal .modal-body", {"contact_id": cId});
			$('#contactModal').modal('show');
		});
	});
</script>

<div class="modal fade" id="contactModal" role="dialog">
	<div class="modal-dialog">
		<!-- Modal content-->
		<div class="modal-content" id="content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal">&times;</button>
				<h3 class="modal-title">View Contact</h3>
			</div>

			<div class="modal-body"></div>

			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Dismiss</button>
			</div>
		</div>
	</div>
</div>
<!--- end of contacts modal.--->

<!---let the user select a specific date.--->
<form method="get" class="form-horizontal">
	<cfset bootstrapDateField("dayDate", "Date:", dayDate, "Pick the date of the shifts you want to review.")>
	<cfset bootstrapSubmitField("action", "View")>
</form>
<hr>

<!--- fetch user information based on currently selected consultant and date. --->
<cftry>

	<cfquery datasource="#application.applicationDataSource#" name="getUserInformation">
		SELECT *
		FROM tbl_users u
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">
	</cfquery>

	<!--- ensure we have a valid consultant id --->
	<cfif getUserInformation.recordCount EQ 0>
		<cfthrow message="Error" detail="Could not find user with id #Session.cas_uid#.">
	</cfif>

	<cfset userInfo = structNew()>
	<cfset userInfo['userId']=getUserInformation.user_id>
	<cfset userInfo['username']=getUserInformation.username>
	<cfset userInfo['preferredName']=getUserInformation.preferred_name>
	<cfset userInfo['pictureSource']=getUserInformation.picture_source>
	<cfset userInfo['instance']=myInstance.instance_id>
	<cfset userInfo['instanceName']=myInstance.instance_mask>
	<cfset userInfo['dayShifts'] = "">
	<cfset userInfo['dayShiftsSites'] = "">

	<!--- retrieve instance / datasource information --->
	<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
		SELECT i.instance_id, i.instance_name, i.instance_mask, i.datasource, i.pie_path, vpi.pie_id
		FROM tbl_instances i
		INNER JOIN vi_pie_ids vpi ON vpi.instance_id = i.instance_id
		WHERE i.instance_mask = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
			  AND vpi.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userInfo.userId#">
	</cfquery>

	<!--- if the previous query is empty, this user doesn't belong to this instance --->
	<cfif getUserInstances.recordCount eq 0>
		<cfthrow message="Error" detail="Could not find information for <cfoutput>#userInfo.username#</cfoutput> in this current instance. Please switch your instance, and try again.">
	</cfif>

	<cfset userInfo['datasource'] = getUserInstances.datasource>
	<cfset userInfo['pie_path'] = getUserInstances.pie_path>
	<cfset userInfo['pie_id'] = getUserInstances.pie_id>

	<!--- fetch previous / next shift dates --->
	<cfquery name="getPreviousShift" datasource="#userInfo.datasource#">
		SELECT TOP 1 cs.shift_date
		FROM shift_blocks cs
		INNER JOIN tbl_consultants c ON c.ssn = cs.ssn
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#userInfo.username#">
			AND cs.shift_date < <cfqueryparam cfsqltype="cf_sql_date" value="#dayDate#">
		ORDER BY cs.shift_date DESC
	</cfquery>
	<cfset userInfo['previousShift'] = getPreviousShift.shift_date>

	<cfquery name="getNextShift" datasource="#userInfo.datasource#">
		SELECT TOP 1 cs.shift_date
		FROM shift_blocks cs
		INNER JOIN tbl_consultants c ON c.ssn = cs.ssn
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#userInfo.username#">
		AND cs.shift_date > <cfqueryparam cfsqltype="cf_sql_date" value="#dayDate#">
		ORDER BY cs.shift_date ASC
	</cfquery>
	<cfset userInfo['nextShift'] = getNextShift.shift_date>

	<!--- fetch current semester --->
	<cfset semesterObj = getSemesterByDate(userInfo.instance)>
	<cfset userInfo['semesterStart'] = semesterObj.start_date>
	<cfset userInfo['semesterEnd'] = semesterObj.end_date>

	<!--- fetch shifts, and sites for the selected date --->
	<cfset getDayShifts(userInfo.username, dayDate, userInfo.datasource)>

<cfcatch>
	<cfoutput>
		<div class="alert alert-danger" role="alert">
			#cfcatch.message# - #cfcatch.detail#
		</div>
	</cfoutput>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfcatch>

</cftry>


<!--- add the shift details and navigation for prev/next shifts.--->
<div class="col-sm-12 ">
	<div class="panel panel-default">
		<div class="panel-heading red-heading"><cfoutput>#dateFormat(dayDate, "MMMM d, yyyy")#</cfoutput></div>
		<cfif userInfo.previousShift NEQ "">
			<cfoutput>
				<a href="#cgi.script_name#?dayDate=#userInfo.previousShift#" class="btn btn-default pull-left">Previous Shift</a>
			</cfoutput>
		</cfif>

		<cfif userInfo.nextShift NEQ "">
			<cfoutput>
				<a href="#cgi.script_name#?dayDate=#userInfo.nextShift#" class="btn btn-default pull-right">Next Shift</a>
			</cfoutput>
		</cfif>

		<div style="text-align: center;">
		<cfloop list="#userInfo.dayShifts#" index="shift">
			<cfoutput>#shift#<br/></cfoutput>
		</cfloop>
		</div>
	</div>
</div>

<!--- draw left sidebar --->
<div class="col-sm-5">
	<!--- unread articles --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Unread Items</div>

		<strong>Announcements</strong><hr/>
		<cfmodule template="#application.appPath#/documents/mod_individual_readership.cfm" uid="#userInfo.userId#" read="0" catId="3" start="#userInfo.semesterStart#" end="#userInfo.semesterEnd#" header="0" width="100%" indentation="5">

		<strong>Newsletters</strong><hr/>
		<cfmodule template="#application.appPath#/documents/mod_individual_readership.cfm" uid="#userInfo.userId#" read="0" catId="7" start="#userInfo.semesterStart#" end="#userInfo.semesterEnd#" header="0" width="100%" indentation="5">
	</div>

	<!---quizes and training--->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Trainings</div>
		<cfset drawTrainingForms(userInfo.userId)>
	</div>

	<!---Customer Contacts Statistics--->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Semester Customer Contacts</div>
		<cfset drawUserMonthContacts(userInfo.username, userInfo.semesterStart,userInfo.semesterEnd)>
	</div>

	<!---Supply Reports Statistics--->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Semester Supply Reports</div>
		<cfset getSupplyReports(userInfo.userId, userInfo.semesterStart, userInfo.semesterEnd, "semester")>
	</div>

	<!---Lab Obs Statistics--->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Semester Lab Observations</div>
		<cfset getLabObs(userInfo.username, userInfo.semesterStart, userInfo.semesterEnd, "semester")>
	</div>
</div>
<!--- end of left sidebar --->

<!--- right bar, the main view --->
<div class="col-sm-7">
	<!--- today's contacts --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Customer Contacts</div>
		<cfset drawUserContacts(userInfo.username, userInfo.pie_path, dayDate + " 00:00", dayDate +" 23:59:59.999", userInfo.pie_path)>
	</div>

	<!--- today's supply reports --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Supply Reports</div>
		<cfset getSupplyReports(userInfo.userId, dayDate, dayDate, "day")>
	</div>

	<!--- today's Lab Observations --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Lab Observations</div>
		<cfset getLabObs(userInfo.username, dayDate, dayDate, "day")>
	</div>

	<!--- today's Consultant Observations --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Consultant Observations</div>
		<cfset getConObs(userInfo.username, dayDate, dayDate, "day")>
	</div>

	<!--- today's Mentor Comments and Lead Comments --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Mentor/Lead Comments</div>
		<cfset getMentorComments(userInfo.username, dayDate, dayDate, "day")>
	</div>

	<!--- today's Stepouts --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Step Outs</div>
		<cfset drawStepOuts(userInfo.username, dayDate)>
	</div>

	<!--- today's cleanings --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Deep Cleaning</div>
		<cfset drawCleanings(userInfo.username, dayDate)>
	</div>

	<!--- today's chat messages --->
	<div class="panel panel-default">
		<div class="panel-heading red-heading">Chat Messages</div>
		<cfset getChatMessages(userInfo.username, dayDate)>
	</div>

</div>
<!--- end of right bar --->
<cfmodule template="#application.appPath#/footer.cfm">