<cfmodule template="#application.appPath#/header.cfm" title='Lab Distribution Item Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="frmItemText" type="string" default="">
<cfparam name="itemId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">

<!--- HEADER / NAVIGATION --->
<h1>Lab Distribution Item Manager</h1>
<a href='lab-distribution.cfm'>Lab Distribution</a> |
<a href='ticket-editor.cfm'>Ticket Editor</a> |
<a href='history.cfm'>History</a>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction EQ 'Create'>

		<!--- check for blank submissions --->
		<cfif trim(frmItemText) EQ "">
			<cfthrow message="Missing Input" detail="Item name is a required field.">
		</cfif>

		<!--- check for duplicates --->
		<cfquery datasource="#application.applicationdatasource#" name='checkDuplicates'>
			SELECT ldil.item_id, ldil.item_name, ldil.active
			FROM tbl_lab_dist_item_list ldil
			WHERE ldil.item_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmItemText#">
		</cfquery>

		<!--- if there is an existing entry with this name... --->
		<cfif checkDuplicates.recordCount GT 0>

			<cfif checkDuplicates.active EQ 1>
				<!--- an active existing entry throws an error --->
				<cfthrow message="Invalid Input" detail="An item with name #frmItemText# already exists.">
			<cfelse>

				<!--- if the matching entry is retired, reinstate it instead of making a new one --->
				<cfquery datasource="#application.applicationdatasource#" name='updateItem'>
					UPDATE tbl_lab_dist_item_list
					SET active = 1
					WHERE item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#checkDuplicates.item_id#">
				</cfquery>

			</cfif>

		<cfelse>

			<!--- if there isn't a matching entry, insert the item normally --->
			<cfquery datasource="#application.applicationdatasource#" name='insertItem'>
				INSERT INTO tbl_lab_dist_item_list (item_name)
				VALUES(<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmItemText#">)
			</cfquery>

		</cfif>

		<p class="ok">Item created successfully.</p>

		<cfset frmItemText = "">

	<cfelseif frmAction EQ 'Delete'>

		<cfquery datasource="#application.applicationdatasource#" name='insertHeaderCat'>
			UPDATE tbl_lab_dist_item_list
			SET active = 0
			WHERE item_id =  <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
		</cfquery>

		<p class="ok">Item removed successfully.</p>

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

	<h2>Choose an Action</h2>

	<fieldset style="width:40%;">
		<legend>Create</legend>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
			<label>Item Name:
				<input type='text' id='itemText1' name="frmItemText" value='#frmItemText#' style="width:240px;">
			</label>
			<input type="submit" name="frmAction" value="Create" style="float:right;">
		</form>
	</fieldset>

	<br/>

	<fieldset style="width:40%;">
		<legend>Delete</legend>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
			#drawItemSelect()#
			<input type="submit" name="frmAction" value="Delete" style="float:right;">
		</form>
	</fieldset>

</cfoutput>

<!--- FUNCTIONS --->
<cffunction name="drawItemSelect">

	<cfquery datasource="#application.applicationdatasource#" name='selectItems'>
		SELECT *
		FROM tbl_lab_dist_item_list
		WHERE active = 1
		ORDER BY item_name
	</cfquery>
	<label for='itemId1'>Select Item: </label>
		<select  name="itemId" id='itemId1'>
			<cfloop query="selectItems">
				<cfoutput>
					<cfif itemId EQ  item_id>
						<option value="#item_id#" SELECTED>#item_name#</option>
						<cfset frmItemText = item_name>
					<cfelse>
						<option value="#item_id#">#item_name#</option>
					</cfif>
				</cfoutput>
			</cfloop>
		</select>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>