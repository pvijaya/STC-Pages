<cfmodule template="#application.appPath#/header.cfm" title='Inventory Lab Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!---bring in some custom css to tidy things up.--->
<link rel="stylesheet" href="<cfoutput>#application.appPath#/inventory/inventory.css</cfoutput>">

<!--- CFPARAMS --->
<cfparam name="frmLabId" type="string" default="i0l0">
<cfparam name="frmItemId" type="integer" default="0">
<cfparam name="frmSortOrder" type="integer" default="0">
<cfparam name="frmWarnLevel" type="integer" default="1">
<cfparam name="frmCriticalLevel" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">

<cfset getlab = getlabsById(frmlabId)>

<!--- HEADER / NAVIGATION --->
<h1>Inventory Lab Items</h1>
<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Go Back</a>
<cfif frmLabId NEQ "i0l0">
	| <a href="<cfoutput>#cgi.script_name#</cfoutput>">Lab Selection</a>
</cfif>

<!--- CSS / STYLE --->
<style type="text/css">
	ul.labItems li.item span.tinytext {
		color: black;
		font-size: small;
	}
</style>

<!--- HANDLE USER INPUT --->
<cftry>

	<cfif frmAction EQ "addSubmit">

		<cfif getlab.recordCount eq 0>
			<cfthrow message="Missing Lab" detail="You must select a valid lab to add an item.">
		</cfif>

		<cfloop query="getlab">
			<!---add the new item to the database for this lab.--->
			<cfquery datasource="#application.applicationDataSource#" name="addlabItem">
				INSERT INTO tbl_inventory_site_items (instance_id, lab_id, item_id, warn_level, critical_level)
				VALUES (#instance_id#, #lab_id#, #frmItemId#, #frmWarnLevel#, #frmCriticalLevel#)
			</cfquery>
		</cfloop>

		<p class="ok">
			Item added successfully.
		</p>

	<cfelseif frmAction EQ "editOrder">

		<!---first find all the items for this lab, and if we submitted a new order for an item, update it.--->
		<cfloop query="getlab">

			<cfquery datasource="#application.applicationDataSource#" name="getlabItmes">
				SELECT item_id
				FROM tbl_inventory_site_items
				WHERE instance_id = #instance_id#
				AND lab_id = #lab_id#
			</cfquery>

			<cfloop query="getlabItmes">
				<cfif isDefined("form.frmSortOrder#item_id#")>
					<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
						UPDATE tbl_inventory_site_items
						SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#evaluate('form.frmSortOrder' & item_id)#">
						WHERE instance_id = #getlab.instance_id#
						AND lab_id = #getlab.lab_id#
						AND item_id = #item_id#
					</cfquery>
				</cfif>
			</cfloop>

			<p class="ok">
				Sort order updated successfully.
			</p>

		</cfloop>

	<cfelseif frmAction EQ "delItem">

		<!---fetch the item information so we can display the deletion message.--->
		<cfloop query="getlab">
			<cfquery datasource="#application.applicationDataSource#" name="getItem">
				SELECT i.item_name, l.lab_name
				FROM tbl_inventory_site_items si
				INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
				INNER JOIN vi_labs l ON l.instance_id = si.instance_id AND l.lab_id = si.lab_id
				WHERE si.instance_id = #instance_id#
					  AND si.lab_id = #lab_id#
					  AND si.item_id = #frmItemId#
			</cfquery>

			<cfif getItem.recordCount eq 0>
				<cfthrow type="custom" message="Item Not Found" detail="Unable to find the item you selected for the current lab.">
			</cfif>

			<cfquery datasource="#application.applicationDataSource#" name="delItem">
				DELETE FROM tbl_inventory_site_items
				WHERE instance_id = #instance_id#
				AND lab_id = #lab_id#
				AND item_id = #frmItemId#
			</cfquery>

			<!---it worked, display our success message.--->
			<cfoutput query="getItem">
				<p class="ok">
					Item removed successfully.
				</p>
			</cfoutput>

		</cfloop>

	</cfif>

<cfcatch type="any">
	<cfoutput>
		<p class="warning">
			#cfcatch.message# - #cfcatch.Detail#
		</p>
	</cfoutput>
</cfcatch>

</cftry>

<!--- DRAW FORMS --->
<h2>Manage Lab Items</h2>

<cfif frmLabId EQ "i0l0">

	<form accept="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<fieldset>
			<legend>Select Lab</legend>
			<cfset drawlabsSelectorByInstance("frmlabId", frmlabId, 0, 1)>
			<input  type="submit" value="Go">
		</fieldset>
	</form>

<cfelse>

	<!---we're done with their input, draw the form for this lab.--->
	<cfloop query="getlab">

		<!---before we draw our form we need to know which items are already associated with this lab--->
		<cfquery datasource="#application.applicationDataSource#" name="getlabItems">
			SELECT si.item_id, i.item_name, i.item_type_id
			FROM tbl_inventory_site_items si
			INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
			WHERE si.instance_id = #instance_id#
			AND si.lab_id = #lab_id#
			ORDER BY si.sort_order
		</cfquery>

		<cfset itemsList = ""><!---a list of current items so we can sort and avoid duplicates.--->

		<cfloop query="getlabItems">
			<cfset itemsList = listAppend(itemsList, item_id)>
		</cfloop>

		<cfif getlabItems.recordCount gt 0>
			<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
				<input type="hidden" name="frmAction" value="editOrder">
				<input type="hidden" name="frmlabId" value="<cfoutput>i#instance_id#l#lab_id#</cfoutput>">
				<fieldset>
					<legend><cfoutput>#lab_name# Items</cfoutput></legend>

					<!---To draw all items in the type where they belong we will loop over them all, and draw our items where they come up.--->
					<cfset drawlabItems(0, instance_id, lab_id)>

					<!---cfloop query="getlabItems">
						<cfoutput>#getFullItemName(item_id)#</cfoutput><br/>
					</cfloop--->
					<input  type="submit" value="Save Order">
				</fieldset>
			</form>
		</cfif>

		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
			<input type="hidden" name="frmAction" value="addSubmit">
			<input type="hidden" name="frmlabId" value="<cfoutput>i#instance_id#l#lab_id#</cfoutput>">
			<fieldset>
				<legend><cfoutput>#lab_name# Add Item</cfoutput></legend>

				<label>Item: <cfset drawItemSelectBox("frmItemId",frmItemId,itemsList)></label><Br/>
				<label>Warning Level: <input type="text" name="frmWarnLevel" size="3" value="<cfoutput>#frmWarnLevel#</cfoutput>" title="The level that highlights the supply in yellow."></label><br/>
				<label>Critical Level: <input type="text" name="frmCriticalLevel" size="3" value="<cfoutput>#frmCriticalLevel#</cfoutput>" title="The level that highlights the supply in red."></label><br/>
				<input  type="submit" value="Add Item">
			</fieldset>
		</form>
	</cfloop>

</cfif>

<!--- JAVASCRIPT / JQUERY --->
<script type="text/javascript">
	$(document).ready(function(){
		$("ul.labItems").sortable({
			items: "li.item",/*restrict to just moving items, not types*/
			axis: "y",
			placeholder: "ui-state-highlight"
		});


		/*also style up our draggable items to make it clear they are dragable.*/
		$("ul.labItems li.item")
			.addClass("ui-state-default")
			.css({'cursor': 'n-resize','padding': '0.25em'});

		/*when items are dragged update all the sort_orders in that group*/
		$("ul.labItems").bind("sortupdate", function(e, i){
			//fetch the new order of the items, this uses the li's id value.
			//var result = $("ul.labItems").sortable('toArray');

			//loop over the new order and update the form.
			$("ul.labItems").each(function(n){
				$("li.item", this).each(function(i){
					$("input.sortOrder", this).val(i+1);
				});
			});
		});

		//Now some AJAX for changing supply levels.

		/*add handlers for our special levelLink links. Using "on" so it keeps listening when things get redrawn.*/
		$("ul.labItems li.item span.levels").on("click", "a.levelLink",function(e){
			e.preventDefault();//don't actually navigate the link.'
			var mySpan = $(this).parents("span.levels");
			var instanceId = $(this).attr("instanceId");
			var labId = $(this).attr("labId");
			var itemId = $(this).attr("itemId");

			//fetch the current levels, and draw a form.
			mySpan.html('Loading...');
			$.ajax({
				url: "<cfoutput>#application.appPath#/inventory/ajax_site_item_levels.cfm</cfoutput>",
				type: "POST",
				async: true,
				data: {
					"frmAction": "view",
					"frmInstanceId": instanceId,
					"frmlabId": labId,
					"frmItemId": itemId
				},
				success: function(data){
					var levels = $.parseJSON(data);
					//build-up mySpan with a form to submit new values for warning and critical levels.
					mySpan.html('<label>Warning Level: <input type="text" name="warnLevel" size="3" value="' + levels.warnLevel + '"></label>; <label>Critical Level: <input type="text" name="critLevel" size="3" value="' + levels.critLevel + '"></label>')
					/*drop in our email checkboxes*/
					$(levels.emails).each(function(n){
						mySpan.append('<label><input type="checkbox" name="frmMailId" value="' + this.mailId + '" ' + ((this.enrolled == 1)?'checked':'') + '> ' + this.mailName + '</label>');
					});
					mySpan.append(' <input class=" levelButton" type="button" value="Update" class="levelButton" instanceId="' + instanceId + '" labId="' + labId + '" itemId="' + itemId + '"> [<a href="#" class="levelCancel"  instanceId="' + instanceId + '" labId="' + labId + '" itemId="' + itemId + '">Cancel</a>]');
				},
				error: function(){
					mySpan.html('Error loading level values.');
				}
			});
		});

		/*allow folks to cancel out of the form*/
		$("ul.labItems li.item span.levels").on("click", "a.levelCancel", function(e){
			e.preventDefault();//don't actually navigate the link.'
			var mySpan = $(this).parents("span.levels");
			var instanceId = $(this).attr("instanceId");
			var labId = $(this).attr("labId");
			var itemId = $(this).attr("itemId");

			//fetch the current levels, and draw the information.
			$.ajax({
				url: "<cfoutput>#application.appPath#/inventory/ajax_site_item_levels.cfm</cfoutput>",
				type: "POST",
				async: true,
				data: {
					"frmAction": "view",
					"frmInstanceId": instanceId,
					"frmlabId": labId,
					"frmItemId": itemId
				},
				success: function(data){
					try {
						var levels = $.parseJSON(data);

						mySpan.html('Warning Level: ' + levels.warnLevel + '; Critical Level: ' + levels.critLevel + ' [<a href="#" class="levelLink" instanceId="' + instanceId + '" labId="' + labId + '" itemId="' + itemId + '">edit</a>]');
					}
					catch(err){
						mySpan.html("Error: " + data);
					}
				},
				error: function(){
					mySpan.html("Error reloading level values.");
				}
			});
		});

		/*add handlers for submitting new warn and critical levels*/
		$("ul.labItems li.item span.levels").on("click", "input.levelButton", function(e){
			e.preventDefault();

			var mySpan = $(this).parents("span.levels");
			var instanceId = $(this).attr("instanceId");
			var labId = $(this).attr("labId");
			var itemId = $(this).attr("itemId");
			var warnLevel = $("input[name='warnLevel']", mySpan).val();
			var critLevel = $("input[name='critLevel']", mySpan).val();
			var mailIds = new Array();

			//populate mailIds with the values of each frmMailId in our span
			$("input[name='frmMailId']", mySpan).each(function(n){
				if($(this).is(":checked")) mailIds.push($(this).val());
			});

			//now turn mailId's into a useful string for submission.
			mailIds = mailIds.toString();


			if(isNaN(parseInt(warnLevel))) {
				alert("Warning Level must be an integer.");
				return(0);
			}
			if(isNaN(parseInt(critLevel))) {
				alert("Critical Level must be an integer.")
				return(0);
			}

			//submit the values
			mySpan.html('Updating...');
			$.ajax({
				url: "<cfoutput>#application.appPath#/inventory/ajax_site_item_levels.cfm</cfoutput>",
				type: "POST",
				async: true,
				data: {
					"frmAction": "update",
					"frmInstanceId": instanceId,
					"frmlabId": labId,
					"frmItemId": itemId,
					"frmWarnLevel": warnLevel,
					"frmCritLevel": critLevel,
					"frmMailIds": mailIds
				},
				success: function(data){
					try {
						var levels = $.parseJSON(data);

						mySpan.html('Warning Level: ' + levels.warnLevel + '; Critical Level: ' + levels.critLevel + ' [<a href="#" class="levelLink" instanceId="' + instanceId + '" labId="' + labId + '" itemId="' + itemId + '">edit</a>]');
					}
					catch(err){
						mySpan.html("Error: " + data)
					}
				},
				error: function(){
					mySpan.html("Error updating level values.");
				}
			});
		});

	});
</script>

<!--- CFFUNCTIONS --->

<!---To draw all items in the type where they belong we weill loop over them all, and draw our items where they come up.--->
<cffunction name="drawlabItems">
	<cfargument name="typeId" type="numeric" default="0">
	<cfargument name="instanceId" type="numeric" default="0">
	<cfargument name="labId" type="numeric" default="0">

	<cfset var getChildTypes = getChildTypes(typeId)>
	<cfset var getItems = ""><!---a query grabbing the items for this lab based on typeId--->
	<cfset var hasChildren = 0>
	<cfset var childTypesList = "">
	<cfset var getAllChildItems = ""><!---used to generate hasChildren's value--->
	<cfset var getEmails = ""><!---a query to fetch all emails that apply to this lab--->
	<cfset var getItemEmails = ""><!---a query of queries to fetch any emails for each item--->
	<cfset var mailList = ""><!---html to display for each email that applies to an item--->

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT si.item_id, i.item_name, si.warn_level, si.critical_level, si.sort_order
		FROM tbl_inventory_site_items si
		INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
		WHERE si.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND si.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
		AND i.retired = 0
		AND i.item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#typeId#">
		ORDER BY si.sort_order, i.item_name
	</cfquery>

	<!---fetch all emails for this lab for later use.--->
	<cfquery datasource="#application.applicationDataSource#" name="getEmails">
		SELECT ie.item_id, e.mail_name, recipient_list
		FROM tbl_inventory_site_items_emails ie
		INNER JOIN tbl_inventory_emails e ON e.mail_id = ie.mail_id
		WHERE e.active = 1
		AND ie.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND ie.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
	</cfquery>

	<!---loop over each type drawing its children--->
	<cfoutput>
		<ul class="labItems">
		<cfloop query="getChildTypes">
			<cfset hasChildren = 0>
			 <!---fetch a list of all a type's descendants.--->
			 <cfset childTypesList = getAllChildTypes(item_type_id)>
			 <!---see if getChildTypes.item_type_id has any child items.  if it does we want to draw it, otherwise, leave it out.--->
			<cfquery datasource="#application.applicationDataSource#" name="getAllChildItems">
				SELECT site_item_id
				FROM tbl_inventory_site_items si
				INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
				WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
				AND lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
				AND i.item_type_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#childTypesList#" list="true">)
			</cfquery>
			<cfif getAllChildItems.recordCount gt 0>
				<cfset hasCHildren = 1>
			</cfif>

			<!---if they have children we actually want to draw this type, otherwise skip it.--->
			<cfif hasChildren>
				<li><b>#item_type_name#</b></li>
				<cfset drawlabItems(item_type_id, instanceId, labId)>
			</cfif>
		</cfloop>

		<cfloop query="getItems">
			<!---now see if this item generates an email.--->
			<cfset mailList = "">
			<cfquery dbtype="query" name="getItemEmails">
				SELECT item_id, mail_name, recipient_list
				FROM getEmails
				WHERE item_id = #getItems.item_id#
			</cfquery>
			<cfloop query="getItemEmails">
				<cfset mailList = mailList & ' <span class="btn btn-default btn-xs" disabled="disabled" title="sends mail to: #htmlEditformat(recipient_list)#"><span class="glyphicon glyphicon-envelope"></span> #mail_name#</span>'>
			</cfloop>

			<li class="item" id="item#item_id#">
				<input type="hidden" name="frmSortOrder#item_id#" value="#sort_order#" class="sortOrder"><!---this gets changed when we drag the list using jquery's .sortable() feature.--->
				#item_name# - <span class="levels tinytext">Warning Level: #warn_level#; Critical Level: #critical_level# [<a href="##" class="levelLink" instanceId="#instanceId#" labId="#labId#" itemId="#item_id#">edit</a>] #mailList#</span>
				<!---span class="tinytext">
					[Remove</a>]
				</span--->
				<a href="#cgi.script_name#?frmAction=delItem&frmlabId=i#instanceId#l#labId#&frmItemId=#item_id#" onClick="return(confirm('Remove #htmlEditFormat(item_name)# from this lab?'))" title="Remove Item" class="pull-right"><span class="glyphicon glyphicon-remove"></span></a>
			</li>
		</cfloop>
		</ul>
	</cfoutput>
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>