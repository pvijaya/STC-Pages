<cfmodule template="#application.appPath#/header.cfm" title='Inventory Item Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmAction" type="string" default="list">
<cfparam name="frmItemId" type="integer" default="0">
<cfparam name="frmItemName" type="string" default="">
<cfparam name="frmTypeId" type="integer" default="0">
<cfparam name="frmRetired" type="boolean" default="0">

<!--- HEADER / NAVIGATION --->
<h1>Inventory Item Manager</h1>
<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Go Back</a> |
<a href="<cfoutput>#cgi.script_name#</cfoutput>">Edit Existing Items</a> |
<a href="<cfoutput>#cgi.script_name#?frmAction=add</cfoutput>">Add New Items</a>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction EQ "addSubmit">
	
		<!---first make sure we aren't missing any input, and that the input is legit.--->
		<cfif frmTypeId lte 0>
			<cfthrow type="custom" message="Missing Input" detail="You must select a value for Item Type.">
		</cfif>
		<cfif trim(frmItemName) eq "">
			<cfthrow type="custom" message="Missing Input" detail="You must select a value for Item Name.">
		</cfif>
		
		<!---everything checks out, insert it to the database--->
		<cfquery datasource="#application.applicationDataSource#" name="addItem">
			INSERT INTO tbl_inventory_items (item_name, item_type_id)
			VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmItemName#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#frmTypeId#">)
		</cfquery>
		
		<p class="ok">
			<b>Success</b>
			<cfoutput>#htmlEditFormat(frmItemName)#</cfoutput> added to the database.
		</p>
		
	
	<cfelseif frmAction EQ "editSubmit">
		<!---first make sure we aren't missing any input, and that the input is legit.--->
		<cfif frmTypeId lte 0>
			<cfthrow type="custom" message="Missing Input" detail="You must select a value for Item Type.">
		</cfif>
		
		<cfif trim(frmItemName) eq "">
			<cfthrow type="custom" message="Missing Input" detail="You must select a value for Item Name.">
		</cfif>
	
		<!---things look good commit the changes to the database--->
		<cfquery datasource="#application.applicationDataSource#" name="updateItem">
			UPDATE tbl_inventory_items
			SET	item_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmItemname#">,
				item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmTypeId#">,
				retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
			WHERE item_id = #frmItemId#
		</cfquery>
		
		<p class="ok">
			<b>Success</b>
			<cfoutput>#htmlEditFormat(frmItemName)#</cfoutput> has been updated.
		</p>
		
	</cfif>

<cfcatch type="any">
	<cfset frmAction = "add"><!---throw them back to the form.--->
	<cfoutput>
		<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.Detail#
		</p>
	</cfoutput>
</cfcatch>
</cftry>

<!--- DRAW FORMS --->
<cfif frmAction EQ "add">
	<h2>New Inventory Item</h2>
		
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<input type="hidden" name="frmAction" value="addSubmit">
		<fieldset>
			<legend>New Item</legend>
			<table>
				<tr>
					<td><label for="itemName">Item Name:</label></td> 
					<td><input type="text" name="frmItemName" id="itemName" 
						       value="<cfoutput>#htmlEditFormat(frmItemName)#</cfoutput>">
					</td>
				</tr>
				<tr>
					<td><label for="itemType">Item Type:</label></td>
					<td><cfset drawTypeSelectBox("frmTypeId", frmTypeId, "", "itemType")></td>
				</tr>
			</table>
			<input  type="submit" value="Add Item">
		</fieldset>
	</form>
	
	<cfelseif frmAction EQ "edit">
		<h2>Edit Inventory Item</h2>
		
		<!---fetch the details of the provided item--->
		<cfquery datasource="#application.applicationDataSource#" name="getItem">
			SELECT item_id, item_name, item_type_id, retired
			FROM tbl_inventory_items
			WHERE item_id = #frmItemId#
		</cfquery>
		
		<cfset frmItemName = getItem.item_name>
		<cfset frmItemId = getItem.item_id>
		<cfset frmTypeId = getItem.item_type_id>
		<cfset frmRetired = getItem.retired>
		
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
			<input type="hidden" name="frmAction" value="editSubmit">
			<input type="hidden" name="frmItemId" value="<cfoutput>#frmItemId#</cfoutput>">
			
			<fieldset>
				<cfoutput><legend>#frmItemName#</legend></cfoutput>
				
				<table>
					<tr>
						<td><label for="itemName">Item Name:</label></td> 
						<td><input type="text" name="frmItemName" id="itemName" 
							       value="<cfoutput>#htmlEditFormat(frmItemName)#</cfoutput>">
						</td>
					</tr>
					<tr>
						<td><label for="itemType">Item Type:</label></td>
						<td><cfset drawTypeSelectBox("frmTypeId", frmTypeId, "", "itemType")></td>
					</tr>
				</table>
				
				<fieldset>
					<legend>Retired:</legend>
					<label>
						<input type="radio" name="frmRetired" value="1" 
					           <cfif frmRetired>checked="true"</cfif>>Yes
					</label> 
					<label>
						<input type="radio" name="frmRetired" value="0" 
						       <cfif not frmRetired>checked="true"</cfif>>No</label>
				</fieldset>
				
				<input  type="submit" value="Update">
				
			</fieldset>
		</form>
		
	
	<!---our landing page, choose an item to edit or create a new one.--->
	<cfelse>
		<h2>Manage Inventory Items</h2>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="get">
			<input type="hidden" name="frmAction" value="edit">
			<fieldset>
				<legend>Choose</legend>
				<label>Item:<cfset drawItemSelectBox()></label>
				<input  type="submit" value="Edit">
			</fieldset>
		</form>
</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>