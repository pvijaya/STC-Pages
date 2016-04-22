<cfsetting showdebugoutput="false">
<!---this module Displays a form for updating inventory levels in the labs.--->
<div class="panel-heading red-heading">Supply Report</div>
<!---since this is a module we may need to bring in our common functions.--->

<cfif not isDefined("getAllCategoriesQuery")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfif not hasMasks("Consultant")>
	<cfabort>
</cfif>

<!---bring in the inventory functions, too--->
<cfif not isDefined("getItemsBylab")>
	<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">
</cfif>

<!---define our default parameters--->
<cfparam name="attributes.width" type="string" default="100%">
<cfparam name="frmlabId" type="string" default="">
<cfparam name="frmAction" type="string" default="">

<!---since this form can't just be used as a module make sure attributes.width is a legitimate width value--->
<cfset attributes.width = replace(attributes.width, ";", "", "all")>
<cfset goodWidth = reFindNoCase("^\d+[px|em|%]{0,2}$", attributes.width)>
<cfif goodWidth eq 0>
	<cfset attributes.width = "100%">
</cfif>

<!---use the given frmlabId to set instanceId and labId--->
<cfset instanceId = 0>
<cfset labId = 0>
<cfset labName = "Unknown">
<cfset getlabs = getlabsById(frmlabId)>
<cfloop query="getlabs">
	<cfset instanceId = instance_id>
	<cfset labId = lab_id>
	<cfset labName = lab_name>
</cfloop>

<!---if we liked we could add some jQuery here to show when a user has entered a value that would change to a warning or critical level, the attributes are already baked-into the form.--->

<!---set a unique ID to store our output in.--->
<cfif frmAction eq "">
	<cfset invId = "inv"&createUUID()>

	<!---also, we want to use AJAX to highjack the users input and the resultant output.--->
	<cfoutput>
	<script type="text/javascript">
		$(document).ready(function(){
			/*highjack forms in our container*/
			$("div###invId#").on("submit", "form", function(e){
				e.preventDefault();

				var dataObj = new Object();//store all the form's elements in here for use with an ajax call.
				$("input,select", this).each(function(n, item){
					dataObj[$(item).attr("name")] = $(item).val();
				})

				$.ajax({
					type: "Post",
					url: "#application.appPath#/inventory/mod_inventory_form.cfm",
					data: dataObj,
					beforeSend: function(){
						$("div###invId#").html("<div id='invLoading'><center>Please Wait<br/><img src='<cfoutput>#application.appPath#/images/loading.gif</cfoutput>'></center></div>");
						if(!checkVisible("div###invId#")) {
							$('html, body').animate({
						        scrollTop: $("div###invId#").offset().top
						    }, 2000);
						}
					},
					success: function(data){
						$("div###invId#").html(data).fadeIn();
						//if we drew the success message hide it afte a while.
						var n = setTimeout('$("p.ok", "div###invId#").fadeOut()', 8000);
					},
					error: function(){
						$("div###invId#").html("<div class='heading'>Supply Report</div><p>Error submitting form.  Please refresh.</p>");
					}
				});
			});

			/*highjack special links*/
			$("div###invId#").on("click", "a.navlink", function(e){
				e.preventDefault();

				var url = $(this).attr("href");
				$.ajax({
					type: "get",
					url: url,
					success: function(data){
						$("div###invId#").html(data);
						if(!checkVisible("div###invId#")) {
							$('html, body').animate({
						        scrollTop: $("div###invId#").offset().top
						    }, 2000);
						}
						//if we drew the success message hide it after a while.
						var n = setTimeout('$("p.ok", "div###invId#").fadeOut()', 8000);
					},
					error: function(){
						$("div###invId#").html("<div class='heading'>Supply Report</div><p>Error handling link.  Please refresh.</p>");
					}
				});
			});
		});

		function checkVisible(element) {
			var view_height = $(window).height();
			var scroll_top = $(window).scrollTop();
			var y = $(element).offset().top;
			var height = $(element).height;
			return (y > scroll_top) && (y < (view_height + scroll_top)) || (y + height) < (view_height + scroll_top);
		}

	</script>

	<!---apply our style data as well.--->
	<style type="text/css">
		div###invId# {
			width: #attributes.width#;
		}
		##frmlabId {
			width:98%;
		}
	</style>
	</cfoutput>

	<div class="panel-body" id="<cfoutput>#invId#</cfoutput>">
</cfif>


<!---that's got all the odds and ends out of the way, we can do the processing and drawing, now.--->

<!---before we draw any forms, we need to handle any user input.  If we encouter problems they are thrown to the forms below--->
<cfswitch expression="#frmAction#">
	<cfcase value="submit">
		<cftry>
			<!---fetch all active items from the database, loop over them, and if we find one that the user submitted add it to our insert query.--->
			<cfset itemStruct = structNew()>

			<!--- get all the item / type info sorted out  --->
			<cfset allItems = getAllItems(labId)>
			<cfset allItemTypes = getAllItemTypes()>
			<cfset ancestorStruct = createAncestorStruct(allItemTypes)>

			<cfloop query="allItems">

				<cfif not isDefined("frmItem#item_id#")>
					<cfthrow message="Missing Input" detail="You must provide a value for '#item_name#'">
				</cfif>
				<cfset val = evaluate("frmItem#item_id#")>
				<cfif val EQ "">
					<cfthrow message="Missing Input" detail="You must provide a value for '#item_name#'">
				</cfif>
				<cfif not isValid("integer", val)>
					<cfthrow message="Invalid Input" detail="The value for '#item_name#' must be an integer.">
				<cfelse>
					<!---things look good, stash it in itemStruct--->
					<cfset itemStruct[item_id] = val>
				</cfif>

				<!--->
				<!---first, see if the user submitted a value for this item_id. cfparram would make short work of this, but we want to give a more detailed error message.--->
				<cfif isDefined("form.frmItem#item_id#") OR isDefined("url.frmItem#item_id#")>
					<cfset "frmItem#item_id#" = iif(isDefined("form.frmItem#item_id#"), "form.frmItem#item_id#", "url.frmItem#item_id#")>
					<!---at this point we should have the user submitted quantity, move to to make sure it is a valid integer--->
					<cfset quantity = evaluate('frmItem#item_id#')>
					<cfdump var="#quantity#">
					<cfif not isValid("integer", quantity)>
						<cfthrow message="Bad Value" detail="The value for '#item_name#' must be an integer.">
					<cfelse>
						<!---things look good, stash it in itemStruct--->
						<cfset itemStruct[item_id] = quantity>
					</cfif>
				</cfif>
				--->
			</cfloop>

			<!---if we have values in itemStruct, dump `em in the database.--->
			<cfif structCount(itemStruct) gt 0>

				<!---first create a submission, then insert all the items for that submission--->
				<cfquery datasource="#application.applicationDataSource#" name="insertInventory">
					INSERT INTO tbl_inventory_submissions (user_id, instance_id, lab_id)
					OUTPUT inserted.submission_id/*where has this been my entire MS SQL life!????*/
					VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
						    <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">,
						    <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">)
				</cfquery>

				<cfloop query="insertInventory">
					<cfset loopCnt = 1>
					<cfquery datasource="#application.applicationDataSource#" name="insertInventoryItems">
						INSERT INTO tbl_inventory_submission_items (submission_id, item_id, quantity)
						VALUES
						<cfloop list="#structKeyList(itemStruct)#" index="i">
							(<cfqueryparam cfsqltype="cf_sql_integer" value="#submission_id#">,
							 <cfqueryparam cfsqltype="cf_sql_integer" value="#i#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#itemStruct[i]#">)<cfif loopCnt lt structCount(itemStruct)>,</cfif>
							<cfset loopCnt = loopCnt + 1>
						</cfloop>
					</cfquery>
				</cfloop>
			</cfif>

			<p class="ok">
				<b>Success!</b><br/>

				Lab Supply Report updated.

			</p>
			<cfset frmAction = "inventory"><!---deposit them back at the submission form.--->

			<!---at this point we've stored our info in the db, and we can generate any emails we need.--->
			<!---we could add some logic to decide when we should/shouldn't send emails, but for now we'll just spam away.--->

			<!---fetch the details for all emails for this lab, and send any emails that match.--->
			<cfquery datasource="#application.applicationDataSource#" name="getEmails">
				SELECT DISTINCT e.mail_id, e.mail_name, e.recipient_list, e.title
				FROM tbl_inventory_site_items_emails sie
				INNER JOIN tbl_inventory_emails e ON e.mail_id = sie.mail_id
				WHERE e.active = 1
					  AND sie.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
					  AND sie.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
			</cfquery>

			<cfset allItems = getAllItems(labId)>

			<!---loop over the emails and generate the output for them using getEmailItemsList()--->
			<cfloop query="getEmails">

				<!---find the items for this email--->
				<cfset mailItems = getEmailItems(instanceId, labId, mail_id)>

				<!---get the groups for this email--->
				<cfset mailItemList = "">
				<cfset mailTypeList = "">
				<cfloop query="mailItems">
					<cfset mailItemList = listAppend(mailItemList, item_id)>
					<cfset mailTypeList = listAppend(mailTypeList, ancestorStruct["type#item_type_id#"])>
				</cfloop>

				<!---at this point we can draw the actual mail.--->
				<cfset mailTo = recipient_list>
				<cfset mailTo = "#session.cas_username#@indiana.edu"><!---on dev we only want to send mail to ourselves.--->
				<cfset mailTitle = title & " " & labName>

				<cfmail to="#mailTo#" from="tccwm@iu.edu" subject="#mailTitle#" type="html">
					<cfoutput>
						<!---include some CSS templates--->
						<link rel="stylesheet" href="http://<cfoutput>#cgi.http_host##application.appPath#/inventory/inventory.css</cfoutput>">
						<link rel="stylesheet" href="http://<cfoutput>#cgi.http_host##application.appPath#/css/text.css</cfoutput>">
						<h1>#labName#</h1>
						<p>New Inventory information has been submitted for #labName# by #session.cas_username#.</p>

						<cfset drawLabInventory(labId, 0, "", allItems, allItemTypes, false, mailItemList)>
					</cfoutput>
				</cfmail>

				<p class="ok">
					<b><cfoutput>#mail_name#</cfoutput></b><br/>
					Email sent.
				</p>
			</cfloop>

			<!---had to abandon this line of thinking to rewrite some functions, but here's the query that was going on.

			--->
		<cfcatch type="any">
			<cfset frmAction = "inventory"><!---take them back to the form.--->
			<cfoutput>
				<p class="warning">
					<b>Error</b><br/>
					#cfcatch.Message# - #cfcatch.Detail#
				</p>
			</cfoutput>
		</cfcatch>
		</cftry>
	</cfcase>
</cfswitch>

<!---draw our forms.--->
<cfswitch expression="#frmAction#">
	<cfcase value="inventory">

		<!---armed with our labId we can fetch the valid items, types, and current levels for this lab.
		<cfset myItemList = getItemsListBylab(instanceId, labId)>
		<cfset myTypeList = "">

		<cfloop list="#myItemList#" index="n">
			<cfset myTypeList = listAppend(myTypeList, getAncestorTypesByItemId(n))><!---this list may end up with duplicates, but that isn't a problem for the queries it'll be used in.--->
		</cfloop>
		--->
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
			<input type="hidden" name="frmAction" value="submit">
			<input type="hidden" name="frmlabId" value="<cfoutput>i#instanceId#l#labId#</cfoutput>">
			<fieldset>
				<legend><cfoutput>#labName# Supply Report <a title="Open Supply Report form in new window." href="#application.appPath#/inventory/submit.cfm?frmAction=inventory&frmlabId=#frmlabId#" target="_blank"><span class="btn-xs glyphicon glyphicon-new-window"></span></a></cfoutput></legend>

				<cfset allItems = getAllItems(labId)>
				<cfset allItemTypes = getAllItemTypes()>

				<!---at this point we have a list of legit items and types, loop over all types and draw the types and items that apply.--->
				<cfset drawLabInventory(labId, 0, "", allItems, allItemTypes, true, "")>

				<input  type="submit" value="Submit">
			</fieldset>
		</form>

		<p>
			Return to <a class="navlink" href="<cfoutput>#cgi.script_name#?frmAction=labs</cfoutput>">Lab Selection</a>.
		</p>
	</cfcase>

	<cfdefaultcase>
		<!---draw our select a lab form--->
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="get">
		<input type="hidden" name="frmAction" value="inventory">
		<fieldset>
			<legend>Choose a Lab</legend>

			<!---we can't just use drawlabsSelector() here, because we only want sites we have inventory information for.--->
			<cfquery datasource="#application.applicationDataSource#" name="getAllLabs">
				SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name
				FROM vi_labs l
				INNER JOIN vi_buildings b
					ON b.instance_id = l.instance_id
					AND b.building_id = l.building_id
				INNER JOIN tbl_instances i ON i.instance_id = l.instance_id
				INNER JOIN tbl_inventory_site_items si
					ON si.instance_id = l.instance_id
					AND si.lab_id = l.lab_id
				WHERE l.active = 1
					  <cfif session.primary_instance NEQ 0>
					 	 AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
					  </cfif>
					  AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
				ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
			</cfquery>

			<select id="frmlabId"  name="frmlabId" class="siteSelector">
			<cfoutput query="getAllLabs" group="instance_id">
				<optgroup label="#instance_name#">
				<cfoutput group="building_name">
					<optgroup label="&nbsp;&nbsp;&nbsp;&nbsp;#htmlEditFormat(building_name)#">
					<cfoutput>
						<cfset curvalue = "i#instance_id#l#lab_id#">
						<option value="#curvalue#" <cfif listFind(frmlabId, curvalue)>selected</cfif>>&nbsp;&nbsp;&nbsp;&nbsp;#lab_name#</option>
					</cfoutput>
					</optgroup>
				</cfoutput>
				</optgroup>
			</cfoutput>
			</select>

			<!---cfset drawLabsSelector("frmLabId", frmLabId, 0)--->

			<input  type="submit" value="Go">
		</fieldset>
		</form>

		<cfif hasMasks("Admin")>
			<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0em;">
				<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Manage Inventories</a>
			</p>
		<cfelseif hasMasks("Logistics")>
			<p>
				<a href="<cfoutput>#application.appPath#/inventory/report_site_graph.cfm</cfoutput>">Suppllies Levels Graph</a>
			</p>
		</cfif>

	</cfdefaultcase>
</cfswitch>


<!---close off the div tag of our content, we're done processing and drawing.--->
<cfif frmAction eq "">
	</div>
</cfif>

<cffunction name="getEmailItems">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="mailId" type="numeric" required="true">

	<cfset var getEmailItems = "">

	<cfquery datasource="#application.applicationDataSource#" name="getEmailItems">
		SELECT DISTINCT sie.item_id, i.item_type_id
		FROM tbl_inventory_site_items_emails sie
		INNER JOIN tbl_inventory_site_items si /*weed out items that have been removed from a lab*/
			ON sie.item_id = si.item_id
			AND sie.instance_id = si.instance_id
			AND sie.lab_id = si.lab_id
		INNER JOIN tbl_inventory_items i /*weed out items that have been retired*/
			ON i.item_id = si.item_id
			AND i.retired = 0
		WHERE sie.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND sie.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
		AND sie.mail_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#mailId#">
	</cfquery>

	<cfreturn getEmailItems>

</cffunction>