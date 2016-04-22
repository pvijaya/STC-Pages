<!---sometimes we fetch the page as an AJAX request, in that case we don't want the header.--->
<cfparam name="drawheader" type="boolean" default="1">
<cfparam name="drawfooter" type="boolean" default="1">
<cfparam name="drawnextShift" type="boolean" default="1">
<cfparam name="drawpreviousShift" type="boolean" default="1">
<cfparam name="drawdialog" type="boolean" default="1">
<cfparam name="drawdialog" type="boolean" default="1">
<cfparam name="drawbackToShift" type="boolean" default="1">
<cfparam name="drawContactModal" type="boolean" default="1">

<cfif drawheader>
	<cfmodule template="#application.appPath#/header.cfm" title='Consultant Shift Report'>
</cfif>

<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/shift-report/mentee-report-functions.cfm">
<cfinclude template="#application.appPath#/tools/contacts/contact-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="currentUserId" type="integer" default="0">

<cfparam name="dayDate" type="date" default="#dateFormat(now(), 'mmm d, yyyy')#">
<cfparam name="nextShift" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">
<cfparam name="previousShift" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">

<cfset myInstance = getInstanceById(session.primary_instance)>

<style type="text/css">

	h2 {
		text-align:center;
	}

	h3 {
		margin: 0px;
		text-align: center;
	}

	div.semester-info {
		float: left;
		width: 20%;
		margin-right: 5px;
		padding:5px;
	}

	div.semester-info-module {
		padding: 5px;
	}

	div.shift-info {
		float:right;
		width:75%;
		vertical-align:top;
	}

	div.shift-info-row {
		width:100%;
		display:inline-block;
		margin:2px;
		padding:3px;
		vertical-align:top;
		text-align:center;
	}

	div#prev-shift {
		width: 25%;
		display: inline-block;
	}

	div#next-shift {
		width: 25%;
		display: inline-block;
		text-align: right;
	}

	div#todays-shifts {
		width: 48%;
		display: inline-block;
		text-align: center;
	}

	span {
	margin-left: 0px; padding-left: 0px;
	}

</style>


<!---now bring in the include, event handler, and div elements we need to display contacts in a bootstrap modal.--->
<cfif drawContactModal>
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
</cfif>

<!--- HEADER / NAVIGATION --->
<h1>Consultant Shift Report</h1>
<cfif drawbackToShift>
	<a href="shift-report.cfm">Back to Shift Report</a>
</cfif>
<br/><br/>

<cfif drawdialog>
<!--- draw consultant / date selector --->
<cfoutput>
	<fieldset class="shadow-border" style="">

		<legend>Select a Consultant</legend>

		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method='get' style="margin-bottom:0px;" class="form-horizontal">

			<cfquery datasource="#application.applicationDataSource#" name="getBlacklist">
				SELECT i.instance_mask
				FROM tbl_instances i
				WHERE i.instance_mask != <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
			</cfquery>

			<cfset blackList = "Admin, Logistics"> <!--- never display admins or logistics members --->
			<cfif not hasMasks("Admin")>
				<cfset blackList= listAppend(blackList, "CS")> <!--- blacklist CS for non-admin users --->
			</cfif>

			<!--- add all non-primary instance masks to the blacklist --->
			<cfloop query="getBlacklist">
				<cfset blackList = ListAppend(blackList,getBlacklist.instance_mask)>
			</cfloop>

			#drawConsultantSelector('consultant', blackList, currentUserId)#

			<!---	<label for="dayDayId">Date:</label>

			<input id="dayDateId" type="text" style="font-size:110%; width:150px;text-align:center;"  name="dayDate" value="#DateFormat

(dayDate,'mm/dd/yyyy')#">
				<!--- replace text field with datepicker --->
			<script type="text/javascript">
				$("##dayDate").datepicker({dateFormat: "mm/dd/yy"});
			</script>--->
		<cfset bootstrapDateField("dayDate", "Date:", dayDate, "Date Field's Help")>

		<!---	<input type='submit' name='action' value='View'/>--->
			<cfset bootstrapSubmitField("action", "View")>

		</form>

	</fieldset>
</cfoutput>
</cfif>

<br/>

<!--- fetch user information based on currently selected consultant --->
<cftry>

	<cfquery datasource="#application.applicationDataSource#" name="getUserInformation">
		SELECT *
		FROM tbl_users u
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#currentUserId#">
	</cfquery>

	<!--- ensure we have a valid consultant id --->
	<cfif getUserInformation.recordCount EQ 0>
		<cfthrow message="Error" detail="Could not find user with id #currentUserId#. Please return to the shift report or select a different consultant.">
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

	<cfset userInfo['datasource'] = getUserInstances.datasource>
	<cfset userInfo['pie_path'] = getUserInstances.pie_path>
	<cfset userInfo['pie_id'] = getUserInstances.pie_id>

	<!--- if the previous query is empty, this user doesn't belong to this instance --->
	<cfif getUserInstances.recordCount eq 0>

		<cfthrow message="Error" detail="Could not find <cfoutput>#userInfo.username#</cfoutput> for a shift in this current instance. Please return to the shift report or select a different consultant.">

	<cfelse>

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

	</cfif>

<cfcatch>
	<cfoutput>
		<p class="warning">
			#cfcatch.message# - #cfcatch.detail#
		</p>
	</cfoutput>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfcatch>

</cftry>

<!---HTML--->
<cfoutput>
<!--- draw left sidebar --->
<!---<div class="shadow-border semester-info">--->
<div class="col-sm-5">
	 <ul class="list-group">
		<!--- consultant photo and basics --->
		<div class="semester-info-module" style="text-align:center;">
		 	<li class="list-group-item">
				<!--- consultant photo --->
				<img class="shadow-border" src="#userinfo.pictureSource#" alt="Picture of #userinfo.username#" style="display:block; width:75%; margin:0px auto;"/>
				<!--- draw name and links --->
				<p>
					<strong>#userinfo.preferredName#</strong>
					<br/>
		 			<ul class="list-group inner">
						<li class="list-group-item">
							<a href="https://#cgi.server_name##userInfo.pie_path#obs/mentor_view.cfm?pie_id=#userInfo.pie_id#">Mentor View</a>
							<br/>
						</li>
						<li class="list-group-item">
							<a href="https://#cgi.server_name##userInfo.pie_path#schedules/schedule.cfm?username=#getUserInformation.username#">Weekly Schedule</a>
							<br/>
						</li>
						<li class="list-group-item">
							<a href="https://#cgi.server_name##application.appPath#/tools/trainings/training-reviews.cfm?currentUserId=#currentUserId#&action=Show%20Consultant%20Reviews">Training Report</a>
						</li>
					</ul>
				</p>
			</li>
		</div>
		<!--- unread articles --->
		<div class="semester-info-module">
			<li class="list-group-item">
				<b>Unread Items</b>
				<cfmodule template="#application.appPath#/documents/mod_individual_readership.cfm" uid="#userInfo.userId#" read="0" catId="3" start="#userInfo.semesterStart#" end="#userInfo.semesterEnd#" header="0" width="100%" indentation="5">
				<cfmodule template="#application.appPath#/documents/mod_individual_readership.cfm" uid="#userInfo.userId#" read="0" catId="7" start="#userInfo.semesterStart#" end="#userInfo.semesterEnd#" header="0" width="100%" indentation="5">
			</li>
		</div>

		<!--- training quizzes and checklists --->

		<li class="list-group-item">
			#drawTrainingForms(userInfo.userId)#
		</li>

		<!--- semester contact, supply report, and lab observation totals --->
		<li class="list-group-item">
			<strong>Semester Contacts</strong>
			#drawUserMonthContacts(userInfo.username, userInfo.semesterStart,userInfo.semesterEnd)#
		</li>
		<li class="list-group-item">
			<strong>Semester Supply Reports</strong>
			<br/>
			<span>#getSupplyReports(userInfo.userId, userInfo.semesterStart, userInfo.semesterEnd, "semester")#</span>
			<br/>
		</li>
		<li class="list-group-item">
			<strong>Semester Lab Observations</strong>
			<br/>
			<span>#getLabObs(userInfo.username, userInfo.semesterStart, userInfo.semesterEnd, "semester")#</span>
			<br/>
		</li>
	</ul>
</div><!--- end left sidebar --->
<!--- draw main shift information box --->
<!---<div class="shift-info" style="text-align:center;" >--->
<div class="col-sm-7" style="text-align:center;">
	<h2>#dateFormat(dayDate, "MMMM d, yyyy")#</h2>

	<!--- previous shift link --->
	<cfif drawpreviousShift>
		<div class="center-block" style="text-align:center;" id="prev-shift">
			<cfif userInfo.previousShift NEQ "">
				<a href="mentee-report.cfm?currentUserId=#userInfo.userId#&dayDate=#userInfo.previousShift#"
				style="font-weight:bold;">Previous Shift</a>
			</cfif>
		</div>
	</cfif>

	<!--- today's shifts --->
	<div class="center-block" style="text-align:center;" id="todays-shifts">
		<cfloop list="#userInfo.dayShifts#" index="shift">
			<cfoutput>#shift#<br/></cfoutput>
		</cfloop>
	</div>

	<!--- next shift link --->
	<cfif drawnextShift>
		<div class="center-block" style="text-align:center;" id="next-shift">
			<cfif userInfo.nextShift NEQ "">
				<a href="mentee-report.cfm?currentUserId=#userInfo.userId#&dayDate=#userInfo.nextShift#" style="font-weight:bold;">Next Shift</a>
			</cfif>
		</div>
	</cfif>

	<br/><hr/>

	<!--- customer contacts logged today --->
	<div class="center-block" style="text-align:center;">
		<h3>Contacts</h3>
		#drawUserContacts(userInfo.username, userInfo.pie_path, dayDate + " 00:00", dayDate +" 23:59:59.999", userInfo.pie_path)#
	</div>

	<hr/>

	<!--- supply reports entered today --->
	<div class="center-block" class="shift-info-row">
		<h3>Supply Reports</h3>
		#getSupplyReports(userInfo.userId, dayDate, dayDate, "day")#
	</div>

	<hr/>

	<!--- lab observations entered today --->
	<div class="center-block" class="shift-info-row">
		<h3>Lab Observations</h3>
		#getLabObs(userInfo.username, dayDate, dayDate, "day")#
	</div>

	<br/><br/><hr/>

	<!--- con observations entered today --->
	<div class="center-block" class="shift-info-row">
		<h3>Consultant Observations</h3>
		#getConObs(userInfo.username, dayDate, dayDate, "day")#
	</div>

	<br/><br/><hr/>

	<!--- con observations entered today --->
	<div class="center-block" class="shift-info-row">
		<h3>Mentor/Lead Comments</h3>
		#getMentorComments(userInfo.username, dayDate, dayDate, "day")#
	</div>
	<br/><br/><hr/>

	<!--- step outs / ins made today --->
	<div class="center-block" class="shift-info-row">
		<h3>Step Outs</h3><br/>
		#drawStepOuts(userInfo.username, dayDate)#
	</div>
	<hr/>

	<!---Deep Cleanings they may have done--->
	<!---first, only draw the cleaning information if there are cleanings associated with the labs the consultant was responsible for today.--->
	<cfquery datasource="#application.applicationDataSource#" name="getRouteCleanings">
		SELECT DISTINCT l.lab_name, cls.section_description, cls.section_image, r.mentor_site_id
		FROM tbl_cleaning_labs_sections cls
		/*Now join the data about the cleaning itself*/
		LEFT OUTER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cls.cleaning_id
		LEFT OUTER JOIN vi_labs l
			ON l.instance_id = cl.instance_id
			AND l.lab_id = cl.lab_id
		/*now bring in the routes data to constrain our results for use on the shift report*/
		LEFT OUTER JOIN vi_labs_sites l2s
			ON l2s.instance_id = cl.instance_id
			AND l2s.lab_id = cl.lab_id
		LEFT OUTER JOIN vi_routes_sites rs
			ON rs.instance_id = l2s.instance_id
			AND rs.site_id = l2s.site_id
		LEFT OUTER JOIN vi_routes r
			ON r.instance_id  = rs.instance_id
			AND r.route_id = rs.route_id

		WHERE cl.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userInfo.instance#">
		AND (
			r.mentor_site_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userInfo.dayShiftsSites#" list="true">)
			OR l2s.site_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userInfo.dayShiftsSites#" list="true">)
		)
	</cfquery>

	<cfif getRouteCleanings.recordCount gt 0>
		<div class="center-block" class="shift-info-row">
			<h3>Deep Cleaning</h3>
			#drawCleanings(userInfo.username, dayDate)#
		</div>
		<hr/>
	</cfif>


	<!--- chat messages from today --->
	<div class="center-block" class="shift-info-row">
		<h3>Chat Messages</h3>
		#getChatMessages(userInfo.username, dayDate)#
	</div>
	</hr>
</div>
<div class="clearfix"></div>
</cfoutput>

















<cfif drawfooter>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
</cfif>