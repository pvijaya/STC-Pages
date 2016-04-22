<cfmodule template="#application.appPath#/header.cfm">
<h1>Staffed Lab Hours</h1>

<!---set these values so we can use scheduling functions from PIE--->
<cflock scope="session" timeout="30" type="exclusive">
	<cfset session.accessLevel = 0>
	<cfset application.sitechk = 'tcciub'>
</cflock>

<!---
	This page presents an anonymized version of the staffing schedule.
	First it generates a list of labs for the instance, and matches them to sites(using tbl_labs_sites).
	Once the user picks a staffed lab it aggregates all the staffing hours for each lab's sites and prints the hours it is staffed.
--->

<cfparam name="frmLabId" type="integer" default="0">
<cfparam name="frmDate" type="date" default="#now()#">
<cfparam name="frmSubmit" default="">

<!---users from the public may not have a default instance, handle that gracefuly--->
<cfif isDefined("Session.primary_instance")>
	<cfparam name="instanceSelected" type="integer" default="#iif(Session.primary_instance gt 0, Session.primary_instance, 1)#">
<cfelse>
	<cfparam name="instanceSelected" type="integer" default="1">
</cfif>


<!---we've got all our default values, draw the form for user provided information.--->

<cfquery name="getPieDatabase" datasource="#application.applicationDatasource#">
	SELECT instance_name, datasource
	FROM tbl_instances
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
</cfquery>
<cfloop query ="getPieDatabase">
	<cfset pieDatabase= getPieDatabase.datasource>
</cfloop>

<!---fetch instances to draw a selector for the user--->
<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT instance_id, instance_name
	FROM tbl_instances
	ORDER BY instance_name
</cfquery>

<!---let's get under way, find staffed labs.--->
<cfquery datasource="#pieDatabase#" name="getStaffedLabs">
	SELECT DISTINCT l.lab_id, b.building_name, l.lab_name
	FROM tbl_labs l
	INNER JOIN tbl_buildings b ON b.building_id = l.building_id
	WHERE l.active = 1
	AND l.staffed = 1
	ORDER BY b.building_name, l.lab_name
</cfquery>

<form method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
<fieldset>
	<legend>Select a Date</legend>
	
	<label>
		Date: <input type="text" name="frmDate" style="width: 7em;" value="<cfoutput>#dateFormat(frmDate, 'mmm d, yyyy')#</cfoutput>">
	</label>
	<p/>
	<label>
		Campus: 
		<select name="instanceSelected">
		<cfoutput query="getInstances">
			<option value="#instance_id#" <cfif instance_id eq instanceSelected>selected</cfif>>#htmlEditFormat(instance_name)#</option>
		</cfoutput>
		</select>
	</label>
	<input type="submit" name="frmSubmit" value="Go">
</fieldset>
</form>
<script type="text/javascript">
	$(document).ready(function(){
		$('input[name="frmDate"]').datepicker({dateFormat: "M d, yy"});
	});
</script>
<p/>
<!---
	if we've got a labId we can get to work drawing the schedule for that day.
	Match the lab to it's sites and build a shiftsArray[day][hour]->shiftDetails to be used by our normal schedule drawing functions.
--->
<p>X = Staffed</p>
<table class="stripe">
	<tr class="titlerow" style="border-bottom:none;">
		<td colspan="25" style="text-align:center;font-size:150%;line-height:150%;"><cfoutput>#getPieDatabase.instance_name#</cfoutput> Lab Schedules</td>
	</tr>
	<tr class="titlerow">
		<td colspan="25">
		<div style="width:33%;float:left;">
			<cfoutput><a href="#cgi.script_name#?instanceSelected=#instanceSelected#&frmDate=#dateAdd("d", -1, frmDate)#" style="color:##fff;">&lt;#dateFormat(frmDate-1, "dddd")#</a></cfoutput>
		</div>
		<div style="width:34%;float:left;text-align:center;">
			<cfoutput>#dateFormat(frmDate, "dddd mmmm d, yyyy")#</cfoutput>
		</div>
		<div style="width:33%;float:right;text-align:right;">
			<cfoutput><a href="#cgi.script_name#?instanceSelected=#instanceSelected#&frmDate=#dateAdd("d", 1, frmDate)#" style="color:##fff;">#dateFormat(frmDate+1, "dddd")#&gt;</a></cfoutput>
		</div>
		</td>
	</tr>
	<tr class="titlerow2">
		<td></td>
	<cfloop from="1" to="24" index="hour">
		<td style="text-align:center;"><cfoutput>#timeFormat("#hour-1#:00","h tt")#</cfoutput></td>
	</cfloop>
	</tr>
<cfset staffLabStruct = structNew()>
<cfloop query="getStaffedLabs">
	<!---when does the week start and end?--->
	<cfset frmDate = dateFormat(frmDate, "mmm d, yyyy")>
	<cfset startDate = dateFormat(frmDate, "yyyy-mm-d")>
	<cfset endDate = dateAdd("d", 0, frmDate)>
	<cfset labName = "#htmlEditformat(building_name)#(#htmlEditFormat(lab_name)#)">
	<!---fetch the sites for this lab--->
	<cfquery datasource="#pieDatabase#" name="getSites">
		SELECT site_id
		FROM tbl_labs_sites
		WHERE lab_id = #lab_id#
	</cfquery>
	
	<!---fetch the staffing for each site and update shiftsArray accordingly.---->
	<cfset labSiteList = "">
	<cfloop query="getSites">
		<cfset labSiteList = listAppend(labSiteList, site_id)>
	</cfloop>
	
	<!---there are a few special SSN's that indicate the shift is not actually staffed--->
	<cfset unstaffedOwners = "0,999999999,999999998">
	
	<tr>
		<th><cfoutput>#labName#</cfoutput></th>
	
	<!---if we found sites for this lab fetch their staffing details, and update shiftDetails.--->
	<cfif len(LabSiteList) gt 0>
		<cfquery datasource="#pieDatabase#" name="getSiteSchedule">
			SELECT c.username, cs.day_id, cs.time_id, cs.ssn, cs.shift_date, cs.shift_time
			FROM shift_blocks cs 
			INNER JOIN tbl_consultants c ON c.ssn = cs.ssn 
			WHERE cs.site_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#LabSiteList#" list="true">)
			AND cs.shift_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
			AND cs.ssn NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#unstaffedOwners#" list="true">)
			ORDER BY cs.shift_time ASC
		</cfquery>
		
		<!---now we can loop over each hour, check it against getSiteSchedule, and draw the row in the HTML table for our lab.--->
		<cfloop from="1" to="24" index="h">
			<cfset isStaffed = 0>
			<cfloop query="getSiteSchedule">
				<cfif time_id eq h>
					<cfset isStaffed = 1>
					<cfbreak><!---we found a site for our lab that is staffed during the current hour, we can break out of this loop.--->
				</cfif>
			</cfloop>
			
			<td style="text-align:center; vertical-align:middle;"><cfif isStaffed>X</cfif></td>
		</cfloop>
		
	<cfelse>
		<!---there are no sites tied to this lab so it is never staffed, just write out blank hours--->
		<cfloop from="1" to="24" index="h">
			<td style="text-align:center;  vertical-align:middle;"></td>
		</cfloop>
	</cfif>
	
	</tr>
</cfloop>
</table>
<br/>

<p class="tinytext">
	<cfoutput>
		Generated at #timeFormat(now(), "short")#, #dateFormat(now(), "mmm d, yyyy")# from <br/>
		https://#cgi.server_name##cgi.script_name#?instanceSelected=#instanceSelected#&frmDate=#urlEncodedFormat(frmDate)#
	</cfoutput>
</p>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>