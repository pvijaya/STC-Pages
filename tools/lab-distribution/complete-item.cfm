<cfmodule template="#application.appPath#/header.cfm" title='Lab Distribution Ticket Viewer' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="ticketId" type="integer" default=0>
<cfparam name="itemId" type="integer" default=0>
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmLabs" type="string" default="">
<cfparam name="submitted" type="boolean" default="0">

<cfset myInstance = getInstanceById(session.primary_instance)>

<!--- HEADER / NAVIGATION --->
<h1>Lab Distribution Ticket Viewer</h1>
<a href='lab-distribution.cfm'>Go Back</a> |
<a href='item-list-editor.cfm'>Item Manager</a> |
<a href='ticket-editor.cfm'>Ticket Editor</a> |
<a href='history.cfm'>History</a>
<br/>

<!--- if no valid ticket id is provided, show a polite message instead of an error --->
<cfif ticketId EQ 0>

	<p>No ticket selected.</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>

</cfif>

<!--- retrieve the ticket info --->
<cfquery datasource="#application.applicationDataSource#" name="getTicketInfo">
	SELECT t.comment, i.item_id, i.item_name
	FROM tbl_lab_dist_ticket t
	INNER JOIN tbl_lab_dist_item_list i ON t.item_id = i.item_id
	WHERE t.ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ticketId#">
</cfquery>
<cfset itemName = getTicketInfo.item_name>
<cfset ticketText = getTicketInfo.comment>
<cfset itemId = getTicketInfo.item_id>

<cfset getLabs = getLabsByTicket(ticketId)>

<!--- allLabs = all active labs listed for thist ticket --->
<!--- frmLabs = all selected (complete) labs --->
<cfset allLabs = "">
<cfloop query="getLabs">

	<cfif (NOT submitted) AND is_complete>
		<cfset frmLabs = listAppend(frmLabs, "i#instance_id#l#lab_id#")>
	</cfif>
	<cfset allLabs = listAppend(allLabs, "i#instance_id#l#lab_id#")>

</cfloop>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction EQ 'Update Ticket'>

		<cfloop list="#allLabs#" index="n">

			<cfset labObj = parseLabName(n)> <!--- parse string into struct --->

			<!--- fetch last entry for audit purposes --->
			<cfquery datasource="#application.applicationDataSource#" name="getLastEntry">
				SELECT dte.entry_id, dte.is_complete
				FROM vi_lab_dist_ticket_entries	dte
				WHERE dte.ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ticketId#">
					  AND dte.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.instance#">
					  AND dte.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.lab#">
			</cfquery>

			<cfset lastEntryId = 0>
			<cfset isComplete = 0>
			<cfif getLastEntry.recordCount GT 0>
				<cfset lastEntryId = getLastEntry.entry_id>
				<cfset isComplete = getLastEntry.is_complete>
			</cfif>

			<!--- if the lab is in frmLabs, it may need to be marked complete --->
			<cfif listFindNoCase(frmLabs, n)>

				<cfif isComplete EQ 0> <!--- avoid redundant updates --->
					<cfquery datasource="#application.applicationDataSource#" name="markComplete">
						INSERT INTO tbl_lab_dist_ticket_entries_update(user_id, entry_id, changed_to)
						VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#lastEntryId#">,
								1)
					</cfquery>
				</cfif>

			<!--- if the lab is not in frmLabs, it may need to be marked incomplete --->
			<cfelseif NOT listFindNoCase(frmLabs, n)>

				<cfif isComplete EQ 1> <!--- avoid redundant updates --->
					<cfquery datasource="#application.applicationDataSource#" name="markIncomplete">
						INSERT INTO tbl_lab_dist_ticket_entries_update(user_id, entry_id, changed_to)
						VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#lastEntryId#">,
								0)
					</cfquery>
				</cfif>

			</cfif>
		</cfloop>

		<p class="ok">
			Ticket updated successfully.
		</p>

		<cfset submitted = 0>
		<cfset getLabs = getLabsByTicket(ticketId)> <!--- refresh the query data --->

</cfif>

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>

</cftry>

<!--- DRAW FORMS --->
<cfoutput>

	<!--- handy instructions --->
	<ul>
		<li>This tools is used to record successful item delivery.</li>
		<li>Hover over a lab name to see who marked / unmarked that lab last.</li>
		<li>To add/remove labs from the list,
			<!--- this link makes more sense here, since it's keyed to this particular ticket --->
			<a href="ticket-editor.cfm?editTicketId=#ticketId#&frmAction=Go&referrer=#cgi.script_name#">Edit This Ticket</a>.
		</li>
	</ul>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">

			<h2 style="margin-top:0em;">#itemName#</h2>

			<input type="hidden" name="ticketId" value="#ticketId#">
			<input type="hidden" name="submitted" value="1">

			<blockquote><p>#getTicketInfo.comment#</p></blockquote>

			#drawLabCheckboxes(ticketId, getLabs)#<br/><br/>

		<input type='submit'  name='frmAction' value='Update Ticket'/>

	</form>

</cfoutput>

<!--- FUNCTIONS --->
<!--- retrieves the labs associated with a ticket --->
<cffunction name="getLabsByTicket">
	<cfargument name="ticket_id" type="numeric" default="#ticketId#">

	<cfquery datasource="#application.applicationDataSource#" name="selectLabs">
		SELECT vte.submitted_ts, vte.instance_id, vte.lab_id, vte.active, vte.is_complete,
		       l.lab_name, b.building_name, u.username, vte.time_modified, vte.modified_by
		FROM vi_lab_dist_ticket_entries vte
		INNER JOIN vi_labs l
			ON l.lab_id = vte.lab_id
			AND l.instance_id = vte.instance_id
		LEFT OUTER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		LEFT JOIN tbl_users u ON u.user_id = vte.user_id
		WHERE vte.ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ticket_id#">
		      AND vte.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		      AND vte.active = 1
		ORDER BY vte.instance_id, l.lab_name
	</cfquery>

	<cfreturn selectLabs>

</cffunction>

<!--- draws the check boxes for labs corresponding to this ticket --->
<cffunction name="drawLabCheckboxes">
	<cfargument name="ticket_id" type="numeric" default="#ticketId#">
	<cfargument name="getLabs" type="query" default="#getLabsByTicket(ticketId)#">

	<h4 style="margin-bottom:0.5em;">Labs</h4>

	<cfloop query="getLabs">

		<cfoutput>

			<!---Checks if lab is active and if it is make is unchecked--->
			<cfset hoverText = "Not edited.">
			<cfif time_modified NEQ "" AND username NEQ "">
				<cfset hoverText = "Last edited by: #username# at #time_modified#.">
			</cfif>

			<div style='width:150px;float:left;'
			     title="<cfoutput>#hoverText#</cfoutput>">

				<div style='width:50px; display:inline;'>
					<label>
						<input type="checkbox" name="frmLabs" value="i#instance_id#l#lab_id#"
						       title='#building_name#' <cfif is_complete>checked</cfif>  >
						#lab_name#
					</label>
				</div>
				<br/>

			</div>

		</cfoutput>

	</cfloop>


</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>