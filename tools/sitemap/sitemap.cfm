<cfmodule template="#application.appPath#/header.cfm" title='Site Map Display' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/sitemap/sitemap_functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmsubmit" type="string" default="">
<cfset myInstance = getInstanceById(session.primary_instance)>
<!---
<cfset maskNames = "">
<cfquery datasource="#application.applicationDataSource#" name="getMasks">
	SELECT a.mask_name
	FROM tbl_header_links_masks b
	INNER JOIN tbl_user_masks a ON a.mask_id = b.mask_id
	WHERE b.link_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkId#">
</cfquery>

<cfloop query="getMasks">
	<cfset maskNames = listAppend(maskNames, mask_name)>
</cfloop>
--->
<!--- check for admin permissions --->
<cfset isAdmin = 0>
<cfif hasMasks("Admin")>
	<cfset isAdmin = 1>
</cfif>

<!--- HEADER / NAVIGATION --->
<cfoutput>
	<h1>#myInstance.instance_mask# Site Map</h1>
	<cfif isAdmin>
		<a href="#application.appPath#/tools/sitemap/category_editor.cfm">Add/Edit Categories</a> |
		<a href="#application.appPath#/tools/sitemap/link_editor.cfm">Add a Link</a> |
		<a href="#application.appPath#/tools/instance/instance_selector.cfm?referrer=#urlEncodedFormat(cgi.script_name)#">Change Instance</a>
	</cfif>
</cfoutput>

<!--- STYLE / CSS --->
<style type="text/css">
	span.retired {
		color: gray;
		font-style: italic;
	}

	p#listStatus {
		display: none;
	}

	<cfif isAdmin><!---normal users should just see a regular list.--->
		/*we want to make the lists slimmer, but the big three pad lists differently, this forces them to be the same.*/
		ul.categories {
			list-style-type: none;
			border-left: solid 2px lightgray;
			/*border-top: solid 2px lightgray;*/
			margin-left: 2em;
			padding-left: 0px;
			margin-top: 0.5em;
		}

		ul.categories li {
			padding-left: 0px;
			margin-left: 0px;
		}

		ul.categories li.item span.pos {
			margin-right: 0.5em;
		}
	</cfif>

</style>

<!--- first find all instance masks the user has that do not correspond to the primary instance --->
<cfquery datasource="#application.applicationDataSource#" name="getNegInstanceMasks">
	SELECT um.mask_id
	FROM tbl_instances i
	INNER JOIN tbl_user_masks um ON um.mask_name = i.instance_mask
	WHERE i.instance_mask != <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
</cfquery>

<cfset negMaskList = "">
<cfloop query="getNegInstanceMasks">
	<cfset negMaskList = listAppend(negMaskList, mask_id)>
</cfloop>

<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
	SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
	FROM tbl_users u
	INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
	INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
	WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
</cfquery>

<!--- fetch the table of masks' parent->child relationships so we can get all the user's inherited masks --->
<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelationships">
	SELECT um.mask_id, um.mask_name,
		CASE
			WHEN mr.mask_id IS NULL THEN 0
			ELSE mr.mask_id
		END AS parent_id
	FROM tbl_user_masks um
	LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
	LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
	ORDER BY um.mask_id
</cfquery>

<!--- get all user masks using the info above --->
<cfset getUserMasks = buildMyMasks(getMyMasks, getAllMaskRelationships)>

<!--- build our final maskList, leaving out any that are in negMaskList --->
<cfset maskList = ""><!---a placeholder so we never have a list of length 0--->
<cfloop query="getUserMasks">
	<cfif NOT listFindNoCase(negMaskList, mask_id)>
		<cfset maskList = listAppend(maskList, mask_id)>
	</cfif>
</cfloop>

<!---start by selecting all the links our user can view.--->
<cfset getUserLinks = getSMLinks(0, maskList)>
<cfset getCategories = getSMCategories(0, maskList)>

<!---handle user input - update sort order.--->
<cfif isAdmin AND frmSubmit eq "Update Order">
	<cfloop query="getUserLinks">
		<cfparam name="frmSortOrder#link_id#" type="integer" default="#sort_order#">

		<!---now insert all the changes to the database--->
		<cfset userVal = evaluate("frmSortOrder#link_id#")>

		<cfif userVal neq sort_order>
			<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
				UPDATE tbl_header_links
				SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#userVal#">
				WHERE link_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#link_id#">
			</cfquery>
		</cfif>
	</cfloop>

	<p class="ok">
		<cfoutput>Sort Order has been updated.  You will need to <a href="#cgi.script_name#">refresh</a> to see changes in the header.</cfoutput>
	</p>

	<!---since we may have changed the order, re-fetch getUserLinks--->
	<cfset getUserLinks = getSMLinks(0, maskList)>

</cfif>

<!---wrap things up in a form to save sort order for admins.--->
<cfif isAdmin>
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
</cfif>

<cfset drawCat(0, isAdmin)>

<!---close off the form and our our little sort message.--->
<cfif isAdmin>
		<p class="alert" id="listStatus">
			The sort order has changed, submit the form to save your changes.
		</p>
		<input type="submit"   name="frmSubmit" value="Update Order">
	</form>
</cfif>

<cfif isAdmin>

	<!---also include links to edit retired links.--->

	<!---fetch all the retired links, and ALL the categories, then we can use the same function to draw this list.--->
	<cfset getUserLinks = getSMLinks(3, maskList)>
	<cfset getCategories = getSMCategories(1, maskList)>

	<span class="trigger">Retired Links</span>
	<div>
		<cfset drawCat(0, isAdmin)>
	</div>

</cfif>


<!--- JQUERY --->
<!--- make our lists into sortable lists. --->
<script type="text/javascript">
	$(document).ready(function(){
		/*prevent clicks on edit links from bubbling up and firing trigger/triggerexpanded items*/
		$("a.editLink").click(function(e){
			e.stopPropagation();
		});

		/*the handlers that'll let us raise and lower items' sort_order.*/
		//make them neat jQuery buttons.
		$("button.up")
			.addClass("glyphicon glyphicon-arrow-up")
			.css("width", "24px")
			.css("height", "24px")
			.css("vertical-align", "middle")
			.on("click", this, function(e){
				e.preventDefault();//don't submit the form.
				/*we're going to find the list item for this button, then find the one above it, highlight them, and swap them.*/
				var myItem = $(this).parent().parent();//thats our li.item
				var prevItem = $(myItem).prev("li.item");
				
				//now that we have both our items switch their sortOrder values.
				var myItemOrder = $("input.sortOrder", myItem).val();
				var prevItemOrder = $("input.sortOrder", prevItem).val();
				
				//if either one is not a numuber, we've reached the top, do nothing.
				if(isNaN(myItemOrder) || isNaN(prevItemOrder)){
					myItem.effect("highlight");//highlight so they know their click registered.
					return;//stop executing before we move stuf around.
				}
				
				//having passed that test swap their sort orders.
				$("input.sortOrder", prevItem).val(myItemOrder);
				$("input.sortOrder", myItem).val(prevItemOrder);

				//now visually swap them for our user.
				myItem.effect("highlight");
				prevItem.effect("highlight");

				//now actually move myItem to before prevItem.
				prevItem.before(myItem);

				//show the warning that the order has changed.
				$("p#listStatus").css("display", "block");

				//disable and re-enable arrows as needed.
				fixArrows()
			});

		$("button.down")
			.addClass("glyphicon glyphicon-arrow-down")
			.css("width", "24px")
			.css("height", "24px")
			.css("vertical-align", "middle")
			.on("click", this, function(e){
				e.preventDefault();//don't submit the form.
				/*we're going to find the list item for this button, then find the one below it, highlight them, and swap them.*/
				var myItem = $(this).parent().parent();//thats our li.item
				var nextItem = $(myItem).next("li.item");

				//now that we have both our items switch their sortOrder values.
				var myItemOrder = $("input.sortOrder", myItem).val();
				var nextItemOrder = $("input.sortOrder", nextItem).val();

				//if either one is not a numuber, we've reached the bottom, do nothing.
				if(isNaN(myItemOrder) || isNaN(nextItemOrder)){
					myItem.effect("highlight");//highlight so they know their click registered.
					return;//stop executing before we move stuf around.
				}

				//having passed that test swap their sort orders.
				$("input.sortOrder", nextItem).val(myItemOrder);
				$("input.sortOrder", myItem).val(nextItemOrder);

				//now visually swap them for our user.
				myItem.effect("highlight");
				nextItem.effect("highlight");

				//now actually move myItem to after nextItem.
				nextItem.after(myItem);

				//show the warning that the order has changed.
				$("p#listStatus").css("display", "block");

				//disable and re-enable arrows as needed.
				fixArrows()
			});

		//now fix the appearance of the up and down arrows.
		fixArrows();
	});

	/*this function fixes arrows.  It disables the "up" arrow on the top item, and disabled the "down" arrow on the bottom item, of each list.*/
	function fixArrows(){
		var u = 0;
		var i = 0;
		//first, for each list we need to know how many items there are.
		$("ul.categories").each(function(u){
			var listLen = $(this).children("li.item").length;

			if(isNaN(listLen)) listLen = 0;//listLen MUST be a number.

			//now find each li's current sortOrder
			$(this).children("li.item").each(function(i){/*we're using .children(), because we only want the first-level childen, and not all the nested li.items under the current ul*/
				var curItem = $(this);
				var curSort = $("input.sortOrder", curItem);
				curSort.val(i+1);//just a little insurance to make sure items never fall out of the order the user sees.
				var curSortValue = curSort.val();

				//now disable the up arrow if we're at the top, enable it everywhere else.
				if(curSortValue == 1) {
					$("span.pos button.up", curItem).prop("disabled", true);
				} else {
					$("span.pos button.up", curItem).prop("disabled", false);
				}


				//now disable the down arrow if we're at the bottom, enable it everywhere else.
				if(curSortValue == listLen){
					$("span.pos button.down", curItem).prop("disabled", true);
				} else {
					$("span.pos button.down", curItem).prop("disabled", false);
				}
			});
		});
	}
</script>

<!---end of sortable list style and javascript--->

<!--- CFFUNCTIONS --->
<cffunction name="drawCat">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="editLink" type="boolean" default="0">

	<cfset var firstPass = 1><!---when we hit our first match we need to draw the containing UL tag.--->

	<!---loop over our categories and draw those belonging to our parentId--->
	<cfloop query="getCategories">
		<cfif parent eq parentId>

			<cfif firstPass>
				<ul>
			</cfif>
			<li>
				<cfoutput>#text#</cfoutput>
				<!---draw this category's child categories--->
				<cfset drawCat(category_id, editLink)>
				<!---now draw this category's child links here--->
				<cfset drawCatLinks(category_id, editLink)>
			</li>

			<cfset firstPass = 0>

		</cfif>
	</cfloop>

	<!---if we opened a UL tag, close it.--->
	<cfif not firstPass>
		</ul>
	</cfif>
</cffunction>

<cffunction name="drawCatLinks">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="editLink" type="boolean" default="0">

	<cfset var firstPass = 1><!---have we drawn the surrounding ul tags yet?--->
	<cfset var myUrl = "">
	
	<cfoutput query="getUserLinks" group="link_id">
		<cfif parent eq parentId>
			<cfif firstPass>
				<ul class="categories">
			</cfif>
				<li class="item">
					<!---if they're an admin the first thing we want are our sorting arrows and the hidden position input.--->
					<cfif isAdmin>
						<span class="pos"><!---where we'll render our up/down arrows--->
							<button class="up" title="Move link Up"></button><button class="down" title="Move link Down"></button>
						</span>
						<input type="hidden" class="sortOrder" name="frmSortOrder#link_id#" value="#sort_order#">
					</cfif>

					<!---if the link is a valid url just use that, otherwise make it relative to application.appPath.--->
					<cfset myUrl = link>
					<cfif not isValid('url', link) AND link neq "##">
						<cfset myUrl = application.appPath & '/' & link>
					</cfif>

					<a href="#myUrl#" <cfif new_window>target="_blank"</cfif>>#text#</a>
					<cfif editLink>
						<!--- this is to add the masks next to the url to show who can change what --->
						<!---
						<cfloop list="#maskNames#" index="maskName">
							<span class="ui-state-default ui-corner-all">#maskName#</span>
						</cfloop>
						--->
						<span class="tinytext">
							&nbsp;&nbsp; [<a href="#application.appPath#/tools/sitemap/link_editor.cfm?frmLinkId=#link_id#">Edit</a>]
						</span>
						&nbsp;
						<cfoutput group="mask_name">
							<span class="btn btn-default btn-xs">#mask_name#</span>
						</cfoutput>
					</cfif>
					</li>

			<cfset firstPass = 0>
		</cfif>
	</cfoutput>

	<!---close our UL if it was opened.--->
	<cfif not firstPass>
		</ul>
	</cfif>
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">