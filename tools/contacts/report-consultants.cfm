<cfmodule template="#application.appPath#/header.cfm" title='Consultant Statistics'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">

<cfinclude template="#application.appPath#/tools/contacts/contact-functions.cfm">

<h1>Consultant Statistics</h1>

<!--- CFPARAMS --->
<cfparam name="frmStartDate" type="date" default="#dateAdd("m", -5, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<cfparam name="frmInstanceId" type="integer" default="#session.primary_instance#">
<cfparam name="frmOrderBy" type="string" default="user">
<cfparam name="frmOrder" type="string" default="asc">


<!---always trim-down/round-up the start and end dates.--->
<cfset frmStartDate = dateFormat(frmStartDate, "yyyy-mm-dd") & " 00:00:00">
<cfset frmEndDate = dateFormat(frmEndDate, "yyyy-mm-dd") & " 23:59:59">


<cfoutput>
	<form method="post" action="#cgi.script_name#">
	
	<fieldset>
		<legend>Report Settings</legend>
		
		<p>
			<label>
				From:
				<input type="text" name="frmStartDate" class="date" value="#dateFormat(frmStartDate, "mmm d, yyyy")#">
			</label>
			
			<label>
				Through:
				<input type="text" name="frmEndDate" class="date" value="#dateFormat(frmEndDate, "mmm d, yyyy")#">
			</label>
		</p>
		
		<!---now draw a selector for which instance to display--->
		<cfquery datasource="#application.applicationDataSource#" name="getInstances">
			SELECT instance_id, instance_name
			FROM tbl_instances
			ORDER BY instance_name
		</cfquery>
		<p>
			<label>
				Instance:
				<select name="frmInstanceId">
				<cfloop query="getInstances">
					<option value="#instance_id#" <cfif instance_id eq frmInstanceId>selected="true"</cfif>>#htmlEditFormat(instance_name)#</option>
				</cfloop>
				</select>
			</label>
		</p>
		
		<!---now let them select the sort order--->
		<fieldset>
			<legend>Sort By</legend>
			<label>
				<input type="radio" name="frmOrderBy" value="user" <cfif frmOrderBy eq "user">checked="true"</cfif>> Consultant
			</label>
			<label>
				<input type="radio" name="frmOrderBy" value="contacts" <cfif frmOrderBy eq "contacts">checked="true"</cfif>> Contacts Opened
			</label>
			<label>
				<input type="radio" name="frmOrderBy" value="hours" <cfif frmOrderBy eq "hours">checked="true"</cfif>> Hours Worked
			</label>
			<label>
				<input type="radio" name="frmOrderBy" value="rate" <cfif frmOrderBy eq "rate">checked="true"</cfif>> Rate
			</label>
		</fieldset>
		
		<fieldset>
			<legend>Order</legend>
			<label>
				<input type="radio" name="frmOrder" value="asc" <cfif frmOrder eq "asc">checked="true"</cfif>> Ascending
			</label>
			<label>
				<input type="radio" name="frmOrder" value="desc" <cfif frmOrder eq "desc">checked="true"</cfif>> Descending
			</label>
		</fieldset>
		
		<p>
			<input type="submit" value="Submit">
		</p>
	</fieldset>
	
	</form>
</cfoutput>

<!---now also make our date fields into jquery-ui datepickers.--->
<script type="text/javascript">
	$(document).ready(function(){
		$("input.date").datepicker({dateFormat: "M d, yy"});
	});
</script>


<!---a query to fetch the contacts for our date range.--->
<cfquery datasource="#application.applicationDataSource#" name="getContacts">
	SELECT c.instance_id, c.user_id, i.instance_name, i.datasource, u.username, COUNT(c.contact_id) AS contacts_opened
	FROM tbl_contacts c
	INNER JOIN tbl_users u ON u.user_id = c.user_id
	INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
	INNER JOIN vi_buildings b
		ON b.instance_id = c.instance_id
		AND b.building_id = c.building_id
	
	WHERE c.created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
	AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#"><!---we made sure we got this with check-instance.cfm--->
	GROUP BY c.instance_id, c.user_id, i.instance_name, i.datasource, u.username
	ORDER BY i.instance_name, u.username
</cfquery>

<!---a place to stash data we'll use to draw a sunburst chart--->
<cfset d3Data = structNew()>
<cfset d3Data['name'] = "Contacts">
<cfset d3Data['children'] = ArrayNew(1)>

<!---this is the div where the sunburst chart will be drawn.--->
<div id="sunburstChart" style="float: right; border: solid 1px gray; margin-top: 5em;"></div>

<!---we've carefully ordered the query so we can use CF's grouping features to split folks up by instance_id--->
<cfloop query="getContacts" group="instance_id">
	<h2><cfoutput>#instance_name#</cfoutput></h2>
	
	<cfset userList = ""><!---a list of users for this instace.--->
	
	<cfloop>
		<!---make a list of users to fetch their hours from PIE--->
		<cfset userList = listAppend(userList, username)>
		
		<!---also build up our d3Data object.--->
		<cfset userObj = structNew()>
		<cfset userObj['name'] = htmlEditFormat(username)>
		<cfset userObj['contacts'] = contacts_opened>
		
		<cfset arrayAppend(d3Data['children'], userObj)>
	</cfloop>
	
	<!---this query recycles from the chat's displayactive nicely.--->
	<cfquery datasource="#getContacts.datasource#" name="getHours">
		SELECT x.username, COUNT(x.username) AS shifts, SUM(DATEDIFF(minute, x.started, x.ended)/60.0) AS hours_worked
		FROM (
			SELECT DISTINCT c.username,
			/*find hours worked*/
			CASE
				WHEN ci.checkin_time >= ci.start_time THEN ci.checkin_time
				ELSE ci.start_time
			END AS started,
			CASE
				WHEN ci.checkout_time <= ci.end_time THEN ci.checkout_time
				ELSE ci.end_time
			END AS ended
			FROM tbl_consultants c 
			LEFT OUTER JOIN tbl_consultant_schedule cs ON c.ssn = cs.ssn
			LEFT OUTER JOIN tbl_checkins ci
				ON ci.checkin_id = cs.checkin_id
				AND ci.end_time BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
			WHERE c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)/*only active users*/
			
		) x
		GROUP BY x.username
	</cfquery>
	
	<!---now that we have both the user's contacts and hours for this instace we can do some math and build up a query with that data.--->
	<cfset statQuery = queryNew("username,rate,total_contacts,total_hours", "varchar,decimal,integer,decimal")>
	
	<!---loop over their contacts, then find their data in getHours and do some math.--->
	<cfloop>
		<cfset userContacts = contacts_opened>
		<cfset userHours = 0>
		<cfset userRate = 0>
		
		<cfloop query="getHours">
			<cfif getContacts.username eq getHours.username>
				<cfset userHours = hours_worked>
				<cfbreak><!---we found what we needed, we're done with the inner loop.--->
			</cfif>
		</cfloop>
		
		<cfif userHours gt 0>
			<cfset userRate = userContacts / userHours>
		</cfif>
		
		<cfset queryAddRow(statQuery)>
		<cfset querySetCell(statQuery, "username", getContacts.username)>
		<cfset querySetCell(statQuery, "rate", userRate)>
		<cfset querySetCell(statQuery, "total_contacts", userContacts)>
		<cfset querySetCell(statQuery, "total_hours", userHours)>
	</cfloop>
	
	<!---having created statQuery, now use frmOrderBy and frmOrder to sort the data--->
	<cfquery dbtype="query" name="statQuery">
		SELECT *
		FROM statQuery
		
		<cfswitch expression="#frmOrderBy#">
			<cfcase value="contacts">
				ORDER BY total_contacts
			</cfcase>
			<cfcase value="hours">
				ORDER BY total_hours
			</cfcase>
			<cfcase value="rate">
				ORDER BY rate
			</cfcase>
			<cfdefaultcase>
				ORDER BY username
			</cfdefaultcase>
		</cfswitch>
		
		<cfif frmOrder eq "asc">
			ASC
		<cfelse>
			DESC
		</cfif>
	</cfquery>
	
	<!---now we can draw a table of the results--->
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="4">Consultant Contact Statistics</td>
		</tr>
		<tr class="titlerow2">
			<th>Consultant</th>
			<th>Contacts Opened</th>
			<th>Hours Worked</th>
			<th title="Contacts per Hour Worked">Rate</th>
		</tr>
	<cfoutput query="statQuery">
		<tr align="center">
			<td>#username#</td>
			<td>#numberFormat(total_contacts, "9,999")#</td>
			<td>#numberFormat(total_hours, "9,999.9")#</td>
			<td>#numberFormat(rate, "9,999.9")#</td>
		</tr>
	</cfoutput>
	</table>
</cfloop>

<!---now create the javascript variable that will drive our sunburst chart.--->
<script type="text/javascript">
	var d3Data = <cfoutput>#serializeJSON(d3Data)#</cfoutput>
	
	//setup our sunburst.
	x = new d3SunBurst();
	x.init("#sunburstChart", 500, 500, d3Data);
	
</script>


<p>
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm">