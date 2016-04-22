<cfmodule template="#application.appPath#/header.cfm" title='View Tally' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">

<h1>View Tally</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 1em;">
	[<a href="<cfoutput>#application.appPath#/tools/tallies/tally_report.cfm</cfoutput>">New Search</a>]
</p>

<!--- cfparams --->
<cfparam name="tallyId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">

<cfif tallyId GT 0>

	<!--- retrieve information about a tally --->
	<cfquery datasource="#application.applicationDataSource#" name="getTally">
		SELECT a.tally_task_id, a.user_id, a.tally_date, a.comment, b.username, c.task_name
		FROM tbl_tallies a
		INNER JOIN tbl_users b ON b.user_id = a.user_id
		INNER JOIN tbl_tallies_tasks c ON c.tally_task_id = a.tally_task_id
		WHERE a.tally_id = #tallyId#
	</cfquery>
	<cfquery datasource="#application.applicationDataSource#" name="getCounts">
		SELECT a.tally_task_id, a.area_count, b.area_name
		FROM tbl_tallies_counts a
		INNER JOIN tbl_tallies_areas b ON b.tally_area_id = a.tally_area_id
		WHERE a.tally_id = #tallyId#
	</cfquery>

	<cfoutput>
		<h3>#getTally.task_name#</h3>
		<p class="tinytext">Submitted by #getTally.username# on #dateFormat(getTally.tally_date,  "MMM d, yyyy")# #timeFormat(getTally.tally_date, "h:mm tt")#.</p>
		<strong>Comments:</strong> <blockquote>#getTally.comment#</blockquote>
	</cfoutput>

	<h2>Tally Results</h2>
	<table class="stripe" style="padding:0px;">
		<tr class="titlerow" style="padding:5px;">
			<th>Area</th>
			<th>Count</th>
		</tr>
		<cfloop query="getCounts">
			<cfoutput>
				<tr>
					<td>#getCounts.area_name#</td>
					<td>#getCounts.area_count#</td>
				</tr>	
			</cfoutput>	
		</cfloop>
	</table>
		
</cfif>
		
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>