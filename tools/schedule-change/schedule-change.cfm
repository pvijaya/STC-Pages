<cfmodule template="#application.appPath#/header.cfm" title='Schedule Change'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfparam name="requestType" type="string" default="">
<cfparam name="dropDay" type="string" default="">
<cfparam name="dropLab" type="string" default="i0s0">
<cfparam name="dropStart" type="string" default="">
<cfparam name="dropEnd" type="string" default="">
<cfparam name="addDay" type="string" default="">
<cfparam name="addlab" type="string" default="i0s0">
<cfparam name="addStart" type="string" default="">
<cfparam name="addEnd" type="string" default="">
<cfparam name="dropReason" type="string" default="">
<cfparam name="action" type="string" default="">
<cfparam name="duration" type="string" default="">
<cfparam name="lateOK" type="string" default="">
<cfparam name="earlyLeave" type="string" default="">

<!---queries--->

<!---functions--->
<cffunction name="daysSelect">
	<cfoutput>
			<option value="---">---</option>
			<option value="Sunday">Sunday</option>
			<option value="Monday">Monday</option>
			<option value="Tuesday">Tuesday</option>
			<option value="Wednesday">Wednesday</option>
			<option value="Thursday">Thursday</option>
			<option value="Friday">Friday</option>
			<option value="Saturday">Saturday</option>
	</cfoutput>
</cffunction>

<cffunction name="shiftTimes">
	<cfoutput>
		<option value="---">---</option>
		<cfloop from="0" to="24" index="i" step="1">
			<option value="#i#:00">#i#:00</option>
		</cfloop>
	</cfoutput>
</cffunction>


<!---Logic--->
<!---fetch our viewer's email address.--->
<cfset userEmail = session.cas_username & "@indiana.edu"><!---a dumb default to fall back on.--->
<cfquery datasource="#application.applicationDataSource#" name="getUserEmail">
	SELECT email
	FROM tbl_users
	WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
</cfquery>
<cfloop query="getUserEmail">
	<cfset userEmail = email>
</cfloop>

<!---if we got a lab we can set the recipient email and the name of the site.--->
<cfset recipient = "tccwm@iu.edu">
<cfset siteName = "None Selected">
<cfset newSiteName = "None Selected">
<cfset mySite = parseSitename(dropLab)>
<cfset newSite = parseSitename(addlab)>

<!---who to send the mail to?--->
<cfswitch expression="#mySite.instance#">
	<cfcase value="1">
		<cfset recipient = "tcchr@indiana.edu">
		<!---one time requests for IUB should go to Consult instead of the TCCHR--->
		<cfif requestType eq "request" AND duration eq "Temporary">
			<cfset recipient = "consult@indiana.edu">
		</cfif>
	</cfcase>
	<cfcase value="2">
		<cfset recipient = "admintcc@iupui.edu">
	</cfcase>
	<cfdefaultcase>
		<cfset recipient = "tccwm@iu.edu">
	</cfdefaultcase>
</cfswitch>

<!---on dev we only want emails going to tccwm--->
<cfset recipient = "tccwm@iu.edu">

<!---the name of the dropped site.--->
<cfquery datasource="#application.applicationDataSource#" name="getSite">
	SELECT site_name
	FROM vi_sites
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#mySite.instance#">
	AND site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#mySite.site#">
</cfquery>
<cfloop query="getSite">
	<cfset siteName = site_name>
</cfloop>

<!---the name of the new site, if provided.--->
<cfquery datasource="#application.applicationDataSource#" name="getNewSite">
	SELECT site_name
	FROM vi_sites
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newSite.instance#">
	AND site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newSite.site#">
</cfquery>
<cfloop query="getNewSite">
	<cfset newSiteName = site_name>
</cfloop>

<cfif requestType EQ "change">
	<cfif dropReason NEQ "">
		<cftry>
			<cfoutput>
				<cfmail to="#recipient#" from="#userEmail#" bcc="#userEmail#" subject="SCHEDULE CHANGE: #session.cas_username#">
	From: #session.cas_username# 
				
	Request to drop: #siteName# on #dropDay# from #dropStart# to #dropEnd#.
				
	Request to add: #newSiteName# on #addDay# from #addStart# to #addEnd#.
				
	Reason: #dropReason#
				</cfmail>
			</cfoutput>
				<p class="ok">
					Email sent successfully
				</p>
			<cfcatch>
				<p class="warning">
					<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
				</p>
			</cfcatch>
		</cftry>
	<cfelse>
	<p class="warning">
		<cfoutput>Please enter a reason</cfoutput>
	</p>
</cfif>
<cfelseif requestType EQ "request">
	<cfif dropReason NEQ "">
		<cftry>
			<cfoutput>
				<cfmail to="#recipient#" from="#userEmail#" bcc="#userEmail#" subject="SCHEDULE CHANGE: #session.cas_username#">
	From: #session.cas_username# 
				
	Requested #duration# Shift Change : #siteName# on #dropDay# from #dropStart# to #dropEnd#.
				
	Wants: 
		#lateOK#
		#earlyLeave#
								
	Reason: #dropReason#
				</cfmail>
			</cfoutput>
				<p class="ok">
					Email sent successfully
				</p>
			<cfcatch>
				<p class="warning">
					<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
				</p>
			</cfcatch>
		</cftry>
	<cfelse>
	<p class="warning">
		<cfoutput>Please enter a reason</cfoutput>
	</p>
</cfif>
</cfif>






<!---HTML--->
<cfoutput>
<h1>Schedule Change Request Forms</h1>
<form action="#cgi.script_name#" method="post">
	<input type="hidden" name="requestType" value="change">
<table class="stripe">
	<tr class="titlerow"><td colspan="2">Permanent Schedule Change</td></tr>
	<tr><td colspan="2">Shift to Drop</td></tr>
	<tr>
		<td>Day: </td>
		<td>
			<select  name="dropDay">
				#daysSelect()#
			</select>
		</td>
	</tr>
	<tr>
		<td>Lab: </td>
		<td>
			#drawSitesSelector('dropLab',dropLab)#
		</td>
	</tr>
	<tr>
		<td>Start Time: </td>
		<td>
			<select  name="dropStart">
				#shiftTimes()#
			</select>
		</td>
	</tr>
	<tr>
		<td>End Time: </td>
		<td>
			<select  name="dropEnd">
				#shiftTimes()#
			</select>
		</td>
	</tr>
	<tr><td colspan="2">Shift to Add</td></tr>
	<tr>
		<td>Day: </td>
		<td>
			<select  name="addDay">
				#daysSelect()#
			</select>
		</td>
	</tr>
	<tr>
		<td>Lab: </td>
		<td>
			#drawSitesSelector('addLab',addLab)#
		</td>
	</tr>
	<tr>
		<td>Start Time: </td>
		<td>
			<select  name="addStart">
				#shiftTimes()#
			</select>
		</td>
	</tr>
	<tr>
		<td>End Time: </td>
		<td>
			<select  name="addEnd">
				#shiftTimes()#
			</select>
		</td>
	</tr>
	<tr><td colspan="2">Other Information</td></tr>
	<tr>
		<td>Username:</td>
		<td>#session.cas_username#</td>
	</tr>
	<tr>
		<td>Reason (required): </td>
		<td><textarea type="text" name="dropReason" class="special"></textarea></td>
	</tr>
	<tr>
		<td colspan="2"><p>You may be required to retain ownership of scheduled shifts for up to a week after the schedule change has been processed.</p></td>
	</tr>
	<tr>
		<td colspan="2"><input  type="submit" name="action" value="Submit" /></td>
	</tr>
</table>
</form>
<h2 class="text-center">OR</h2>


<form action="#cgi.script_name#" method="post">
	<input type="hidden" name="requestType" value="request">
<table class="stripe">
	<tr class="titlerow"><td colspan="2">Request Late OK/Early Leave</td></tr>
	<tr><td colspan="2">Shift to Drop</td></tr>
	<tr>
		<td>Day: </td>
		<td>
			<select  name="dropDay">
				#daysSelect()#
			</select>
		</td>
	</tr>
	<tr>
		<td>Lab: </td>
		<td>
			#drawSitesSelector('dropLab',dropLab)#
		</td>
	</tr>
	<tr>
		<td>Start Time: </td>
		<td>
			<select  name="dropStart">
				#shiftTimes()#
			</select>
		</td>
	</tr>
	<tr>
		<td>End Time: </td>
		<td>
			<select  name="dropEnd">
				#shiftTimes()#
			</select>
		</td>
	</tr>
	<tr>
		<td colspan="2">I would like to request:</td>
	</tr>
	<tr>
		
		<td><input type="checkbox" name="lateOK" value="a late OK" />a late OK</td>
		<td><input type="checkbox" name="earlyLeave" value="an early leave" />an early leave</td>
	</tr>
	<tr>
		<td colspan="2">Duration of Request:</td>
	</tr>
	<tr>
		<td><input type="radio" name="duration" value="Temporary" />one shift</td>
		<td><input type="radio" name="duration" value="Permanent" />all shifts</td>
	</tr>
	<tr>
		<td>Reason (required): </td>
		<td><textarea type="text" name="dropReason" class="special"></textarea></td>
	</tr>
	<tr>
		<td colspan="2"><p>You may be required to retain ownership of scheduled shifts for up to a week after the schedule change has been processed.</p></td>
	</tr>
	<tr>
		<td colspan="2"><input  type="submit" name="action" value="Submit" /></td>
	</tr>
</table>
</form>
</cfoutput>


<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
