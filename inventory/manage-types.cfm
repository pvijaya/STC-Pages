<cfmodule template="#application.appPath#/header.cfm" title='Inventory Type Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmAction" type="string" default="list">
<cfparam name="frmTypeId" type="integer" default="0">
<cfparam name="frmTypeName" type="string" default="">
<cfparam name="frmParentId" type="integer" default="0">

<!--- HEADER / NAVIGATION --->
<h1>Inventory Type Manager</h1>
<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Go Back</a> |
<a href="<cfoutput>#cgi.script_name#</cfoutput>">Edit Existing Types</a> |
<a href="<cfoutput>#cgi.script_name#?frmAction=add</cfoutput>">Add New Types</a>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction eq "addSubmit">
		<cfif trim(frmTypeName) eq "">
			<cfthrow type="custom" message="Bad Input" detail="Name may not be blank.">
		</cfif>
		
		<!---that's our one real requirement.  Try to add it to the database, now.--->		
		<cfquery datasource="#application.applicationDataSource#" name="addType">
			INSERT INTO tbl_inventory_item_types (item_type_name, parent_type_id)
			VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTypeName#">, #frmParentId#)
		</cfquery>
		
		<cfset frmAction = "list">
		<p class="ok">
			New type <cfoutput>#htmlEditFormat(frmTypename)#</cfoutput> successfully added.
		</p>

	<cfelseif frmAction eq "editSubmit">

		<cfif trim(frmTypeName) eq "">
			<cfthrow type="custom" message="Bad Input" detail="Name may not be blank.">
		</cfif>
		<cfif frmParentId eq frmTypeId>
			<cfthrow type="custom" message="Bad Input" detail="Item cannot be its own Parent Type.">
		</cfif>
		
		<!---our input checks out, we can now commit the changes to the database.--->
		<cfquery datasource="#application.applicationDataSource#" name="updateItemType">
			UPDATE tbl_inventory_item_types
			SET	item_type_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTypeName#">,
				parent_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentId#">
			WHERE item_type_id = #frmTypeId#
		</cfquery>
		
		<cfset frmAction = "edit">
		<p class="ok">
			Type updated successfully.
		</p>

	</cfif>

	<cfcatch type="any">
		 <!--- throw them back to the form. --->
		<cfif frmAction EQ "addSubmit">
			<cfset frmAction = "add">
		<cfelseif frmAction EQ "editSubmit">
			<cfset frmAction = "edit"> 
		</cfif>
		<cfoutput>
			<p class="warning">
				#cfcatch.message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
</cftry>

<!--- DRAW FORMS --->

<cfif frmAction eq "add">

	<h2 style="margin-bottom:0em;">Add New Types</h2>
	
	<em>
		<p>Note: When creating new inventory types, remember that types should be general and items should be specific. <br/> 
		   For example, "Paper" is a type with two sub-types "Plain" and "Plotter." The "Plain" type
		   contains the items "Letter(8.5" x 11")" and "Legal(8.5" x 14")".
		</p>
	</em>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<input type="hidden" name="frmAction" value="addSubmit">
		
		<fieldset style="margin-top:2em;">
			<legend>New Type</legend>
			<cfoutput>
				<table>
					<tr>
						<td><label for="typeName">Name:</label></td>
						<td><input type="text" name="frmTypeName" value="#htmlEditFormat(frmTypeName)#"></td>
					</tr>
					<tr>
						<td><label for="typeParent">Parent Type:</label>
						<td><cfset drawTypeSelectBox("frmParentId", 0, "", "typeParent")></td>
					</tr>
				</table>
			</cfoutput>
			<input  type="submit" value="Add">
		</fieldset>
	</form>

<cfelseif frmAction eq "edit">

	<cfquery datasource="#application.applicationDataSource#" name="getType">
		SELECT item_type_id, item_type_name, parent_type_id
		FROM tbl_inventory_item_types
		WHERE item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmTypeId#">
	</cfquery>
	
	<cfif getType.recordCount eq 0>
		<p class="warning">
			<b>No Item Type Found</b>
			Please go back and select another Item Type.
		</p>
	</cfif>
	
	<cfoutput><h2>Edit #getType.item_type_name#</h2></cfoutput>
	
	<cfoutput query="getType">
		<form action="#cgi.script_name#" method="post">
			<input type="hidden" name="frmAction" value="editSubmit">
			<input type="hidden" name="frmTypeId" value="#item_type_id#">
			<fieldset>
				<legend>Update Existing Values</legend>
				<table>
					<tr>
						<td><label for="typeName">Name:</label></td>
						<td><input id="typeName" type="text" name="frmTypeName" 
						     value="#htmlEditFormat(iif(trim(frmTypeName) eq "", "item_type_name", "frmTypeName"))#">
						</td>
					</tr>
					<tr>
						<td><label for="typeParent">Parent Type: </label></td>
						<td><cfset drawTypeSelectBox("frmParentId", parent_type_id, getAllChildTypes(frmTypeId), "typeParent")></td>
					</tr>
				</table>
				<input  type="submit" value="Update">
			</fieldset>
		</form>
	</cfoutput>
	
<cfelse>

	<h2>Edit Existing Types</h2>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<input type="hidden" name="frmAction" value="edit">
	
		<fieldset>
			<legend>Choose</legend>
			<label>Type: <cfset drawTypeSelectBox("frmTypeId", 0, 0)></label>
			<input  type="submit" value="Edit">
		</fieldset>
		
	</form>
	
</cfif>

<cfmodule template="#application.appPath#/footer.cfm">