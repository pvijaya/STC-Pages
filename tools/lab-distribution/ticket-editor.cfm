<cfmodule template="#application.appPath#/header.cfm" title='Lab Distribution Ticket Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="frmTicketText" type="string" default="">
<cfparam name="frmItemId" type="integer" default="0">
<cfparam name="frmLabList" type="string" default="">
<cfparam name="frmAction" type="string" default="">
<cfparam name="editTicketId" type="integer" default="0">
<cfparam name="deleteTicketId" type="integer" default="0">
<cfparam name="submitted" type="integer" default="0">
<cfparam name="referrer" type="string" default="">

<!--- HEADER / NAVIGATION --->
<h1>Lab Distribution Ticket Editor</h1>
<cfif trim(referrer) NEQ "" OR editTicketId GT 0>
	<cfif trim(referrer) EQ "">
		<a href="<cfoutput>#cgi.script_name#</cfoutput>">Go Back</a> |
	<cfelse>
		<a href="<cfoutput>#referrer#?ticketId=#editTicketId#</cfoutput>">Go Back</a> |
	</cfif>
</cfif>
<a href='lab-distribution.cfm'>Lab Distribution</a> |
<a href='item-list-editor.cfm'>Item Manager</a> |
<a href='history.cfm'>History</a>

<!--- fetch existing ticket information, if any. --->
<cfif editTicketId NEQ 0 AND NOT submitted>

	<cfquery datasource="#application.applicationDataSource#" name="getTicketInfo">
		SELECT ldt.comment, ldt.item_id
		FROM tbl_lab_dist_ticket ldt
		WHERE ldt.ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#editTicketId#">
	</cfquery>
	<cfset frmTicketText = getTicketInfo.comment>
	<cfset frmItemId = getTicketInfo.item_id>

	<cfset frmLabList = getTicketLabs(editTicketId)>

</cfif>

<cfset existingLabList = getTicketLabs(editTicketId)>
<cfset existingLabs = "">
<cfloop list="#existingLabList#" index="labString">
	<cfset labStruct = parseLabName(labString)>
	<cfset existingLabs = listAppend(existingLabs, labStruct['lab'])>
</cfloop>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction EQ 'Create Ticket'>

		<!--- check inputs for validity --->
		<cfif trim(frmTicketText) EQ "">
			<cfthrow message="Missing Input" detail="Ticket Description is a required field.">
		</cfif>

		<cfif len(frmTicketText) GT 2000>
			<cfthrow message="Invalid Input" detail="Ticket Description cannot exceed 2000 characters.">
		</cfif>

		<cfquery datasource="#application.applicationDataSource#" name="addTicket">
			INSERT INTO tbl_lab_dist_ticket (item_id, comment, created_by)
			OUTPUT inserted.ticket_id
			VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmItemId#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTicketText#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">)
		</cfquery>

		<!--- loop over frmLabList, and create new ticket entries for each lab selected --->
		<cfloop list="#frmLabList#" index="lab">

			<cfset labStruct = parseLabName(lab)>

			<cfquery datasource="#application.applicationDataSource#" name="addLabToTicket">
				INSERT INTO tbl_lab_dist_ticket_entries (ticket_id, instance_id, lab_id, site_id, modified_by)
				VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#addTicket.ticket_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['lab']#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['lab']#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
						)
			</cfquery>

		</cfloop>

		<p class="ok">Ticket created successfully.</p>
		<cfset frmAction = "">

	<cfelseif frmAction EQ 'Update Ticket'>

		<cfset frmAction = "Go"> <!--- whether we fail or succeed, go back to the edit page --->

		<!--- check inputs for validity --->
		<cfif trim(frmTicketText) EQ "">
			<cfthrow message="Missing Input" detail="Ticket Description is a required field.">
		</cfif>

		<cfif len(frmTicketText) GT 2000>
			<cfthrow message="Invalid Input" detail="Ticket Description cannot exceed 2000 characters.">
		</cfif>

		<!--- parse out the lab ids from frmLabList and put them in labList --->
		<cfset labList = "">
		<cfloop list="#frmLabList#" index="lab">
			<cfset labStruct = parseLabName(lab)>
			<cfset labList = listAppend(labList, labStruct['lab'])>
		</cfloop>

		<!--- update the ticket info --->
		<cfquery datasource="#application.applicationDataSource#" name="editTicket">
			UPDATE tbl_lab_dist_ticket
			SET item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmItemId#">,
			    comment = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTicketText#">
			WHERE ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#editTicketId#">
		</cfquery>

		<!--- retire any labs for this ticket in the database that are not in labList --->
		<cfquery datasource="#application.applicationDataSource#" name="deactivateTicketLab">
			UPDATE tbl_lab_dist_ticket_entries
			SET active = 0,
			    modified_by = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
			    time_modified = <cfqueryparam cfsqltype="cf_sql_date" value="#now()#">
			WHERE ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#editTicketId#">
			      AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			      AND lab_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#labList#" list="yes">)
		</cfquery>

		<!--- reactivate any existing retired entries for labs in labList --->
		<cfquery datasource="#application.applicationDataSource#" name="reactivateTicketLab">
			UPDATE tbl_lab_dist_ticket_entries
			SET active = 1,
				modified_by = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				time_modified = <cfqueryparam cfsqltype="cf_sql_date" value="#now()#">
			WHERE ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#editTicketId#">
			      AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			      AND lab_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#labList#" list="yes">)
		</cfquery>

		<!--- loop through frmLabList, and add records for any new labs --->
		<cfloop list="#frmLabList#" index="lab">

			<cfset labStruct = parseLabName(lab)>
			<cfset labId = labStruct['lab']>
			<cfset instanceId = labStruct['instance']>

			<cfif NOT listFindNoCase(existingLabs, labId)>

				<cfquery datasource="#application.applicationDataSource#" name="addLabToTicket">
					INSERT INTO tbl_lab_dist_ticket_entries (ticket_id, instance_id, lab_id, site_id)
					VALUES
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#editTicketId#">,
						 <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
						 <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">,
						 <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">)
				</cfquery>

			</cfif>

		</cfloop>

		<!--- reset the form --->
		<cfset submitted = 0>

		<p class="ok">Ticket updated successfully.</p>

	<cfelseif frmAction EQ 'Go' AND deleteTicketID GT 0> <!--- this occurs straight from the main page --->

		<cfquery datasource="#application.applicationDataSource#" name="retireTicket">
			UPDATE tbl_lab_dist_ticket
			SET active = 0
			WHERE ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#deleteTicketId#">
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="retireTicketEntries">
			UPDATE tbl_lab_dist_ticket_entries
			SET active = 0,
				modified_by = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				time_modified = getDate()
			WHERE ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#deleteTicketId#">
		</cfquery>

		<p class="ok">Ticket removed Successfully.</p>

	</cfif>

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>

			<!--- go back to the create form if we fail --->
			<cfif frmAction EQ "Create Ticket">
				<cfset frmAction = "Create New Ticket">
			</cfif>

		</cfoutput>
	</cfcatch>
</cftry>


<!---HTML--->
<cfoutput>

	<!--- ensure that the user selected a ticket --->
	<cfif frmAction EQ 'Go' AND editTicketId EQ 0 AND deleteTicketId EQ 0>
		<p class="alert">You must select a ticket.</p>
	</cfif>

	<!--- edit and create have essentially the same form --->
	<cfif frmAction EQ 'Create New Ticket' OR
		  (frmAction EQ 'Go' AND deleteTicketId EQ 0 AND editTicketId GT 0)>

		<h2><cfif editTicketId GT 0>Edit<cfelse>Create a New</cfif> Ticket</h2>

		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">

			#drawItemSelect()#<br/><br/>

			<label for='frmTicketText1'>Ticket Description (2000 characters max):</label><br/>
			<textarea maxLength="2000" class='special' name='frmTicketText' style='width:60%;'>#frmTicketText#</textarea>

			<!--- draw the various lab checkboxes --->
			#drawLabSelect(frmLabList)#<br/><br/>

			<cfoutput>
				<input type="hidden" name="referrer" value="#referrer#">
			</cfoutput>

			<cfif editTicketId GT 0>
				<cfoutput>
					<input type="hidden" name="editTicketId" value="#editTicketId#">
					<input type="hidden" name="submitted" value="1"> <!--- form has been submitted --->
				</cfoutput>
				<input type='submit'  name='frmAction' value='Update Ticket'/>
			<cfelse>
				<input type='submit'  name='frmAction' value='Create Ticket'/>
			</cfif>

		</form>

	<!--- otherwise present the action list --->
	<cfelse>

		<h2>Choose an Action</h2>

			<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
				<input type='submit' name='frmAction' value='Create New Ticket'/>
			</form>
		<br/>
		<fieldset style='width:29%;display:inline-block;vertical-align:top;'>
			<legend>Edit</legend>
			<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="GET">
				#drawTicketSelect("editTicketId", editTicketId)#
				<input style="float:right;" type='submit'  name='frmAction' value='Go'/>
			</form>
		</fieldset>
		<br/>
		<fieldset style="width:29%;display:inline-block;vertical-align:top;">
			<legend>Delete</legend>
			<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
				#drawTicketSelect("deleteTicketId", deleteTicketId)#
				<input style="float:right;" type='submit'  name='frmAction' value='Go'/>
			</form>
		</fieldset>

	</cfif>

</cfoutput>

<!--- FUNCTIONS --->
<!---Gets a selectbox full with active tickets for selecting--->
<cffunction name="drawTicketSelect">
	<cfargument name="fieldName" type="string" default="ticketId">
	<cfargument name="fieldValue" type="numeric" default="#ticketId#">

	<cfquery datasource="#application.applicationdatasource#" name='getActiveTickets'>
		SELECT DISTINCT t.ticket_id , il.item_name, t.time_created
		FROM tbl_lab_dist_ticket t
		INNER JOIN tbl_lab_dist_item_list il ON il.item_id = t.item_id
		INNER JOIN vi_lab_dist_ticket_entries te ON te.ticket_id = t.ticket_id
		WHERE t.active = 1
			  AND te.is_complete = 0
		ORDER BY t.time_created DESC
	</cfquery>

	<label>Select Ticket:<br/>
		<select name="<cfoutput>#fieldName#</cfoutput>">
			<option value="0">---</option>
			<cfloop query="getActiveTickets">
				<cfoutput>
					<option value="#ticket_id#" <cfif ticket_id EQ fieldValue>selected="true"</cfif>>
						#item_name# (Posted #DateFormat(time_created, "mm/dd/yyyy")#)
					</option>
				</cfoutput>
			</cfloop>
		</select>
	</label>

</cffunction>

<!--- draws a select input --->
<cffunction name="drawItemSelect">
	<cfargument name="fieldValue" type="numeric" default="#frmItemId#">

	<cfquery datasource="#application.applicationdatasource#" name='getItems'>
		SELECT item_id, item_name
		FROM tbl_lab_dist_item_list
		WHERE active = 1
		ORDER BY item_name
	</cfquery>

	<label>Select Item:
		<select name="frmItemId">
			<cfloop query="getItems">
				<cfoutput>
					<option value="#item_id#" <cfif item_id EQ fieldvalue>selected="true"</cfif>>
						#item_name#
					</option>
				</cfoutput>
			</cfloop>
		</select>
	</label>

</cffunction>

<!--- draws the various checkboxes used to select a lab --->
<cffunction name="drawLabSelect">
	<cfargument name="checkedLabs" default="">

	<!--- fetch all labs for this instance --->
	<cfquery datasource="#application.applicationdatasource#" name='getLabs'>
		SELECT i.instance_id, i.instance_name, l.building_id, b.building_name, l.lab_id, l.lab_name
		FROM vi_labs l
		INNER JOIN vi_buildings b ON b.instance_id = l.instance_id AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = l.instance_id
		WHERE l.active = 1
			  AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY i.instance_name, b.building_name, l.lab_name
	</cfquery>

	<!--- we want the trigger spans to be expanded when a lab is already selected --->
	<!--- this can get pretty nasty in terms of database pings, so the next section minimizes that work --->

	<!--- go through checkedLabs, peel off the lab id, and save it in a separate list --->
	<cfset labIdList = "">
	<cfloop list="#checkedLabs#" index="lab">
		<cfset labStruct = parseLabName(lab)>
		<cfset labIdList = listAppend(labIdList, labStruct['lab'])>
	</cfloop>

	<!--- now, fetch all building ids associated with those lab ids in a single query --->
	<cfquery datasource="#application.applicationdatasource#" name='getBuildingIds'>
		SELECT l.building_id
		FROM vi_labs l
		WHERE l.lab_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#labIdList#" list="yes">)
			  AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	</cfquery>

	<!--- finally, build a list of those building ids --->
	<cfset buildingList = "">
	<cfloop query="getBuildingIds">
		<cfset buildingList = listAppend(buildingList, building_id)>
	</cfloop>

	<h3>Labs Requiring Item</h3>

	<fieldset>

		<legend>Check All That Apply</legend>
		<cfoutput query="getLabs" group="building_id">

			<!--- if the current building id appears in buildingList, expand the trigger --->
			<span class="trigger<cfif listFindNoCase(buildingList, building_id)>expanded</cfif>">
				#building_name#
			</span>
			<div>
				<fieldset>
					<cfoutput>
						<div style='width:150px;float:left;'>

							<input type="checkbox" name="frmLabList" value="i#instance_id#l#lab_id#"
							<cfif listFindNoCase(checkedLabs, "i#instance_id#l#lab_id#")>checked="yes"</cfif>>

							<div style='width:50px; display:inline;'>
								<label for='i#instance_id#l#lab_id#'>#lab_name#</label>
							</div>
							<br/>

						</div>
					</cfoutput>
				</fieldset>
			</div>
			<br/>

		</cfoutput>

	</fieldset>

</cffunction>

<cffunction name="getTicketLabs">
	<cfargument name="ticket_id" type="numeric" default="#editTicketId#">

	<!--- retrive lab entries for this ticket (there will be one per lab) --->
	<cfquery datasource="#application.applicationDataSource#" name="getTicketLabQuery">
		SELECT ldte.lab_id, ldte.active
		FROM tbl_lab_dist_ticket_entries ldte
		LEFT JOIN tbl_users u ON u.user_id = ldte.modified_by
		WHERE ldte.ticket_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ticket_id#">
			  AND ldte.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	</cfquery>

	<cfset var labList = "">
	<cfloop query="getTicketLabQuery">
		<cfset labList = listAppend(labList, "i#session.primary_instance#l#lab_id#")>
	</cfloop>

	<cfreturn labList>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>