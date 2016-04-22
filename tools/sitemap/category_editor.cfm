<cfmodule template="#application.appPath#/header.cfm" title='Site Map Categoriy Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/sitemap/sitemap_functions.cfm">

<!--- HEADER NAVIGATION --->
<h1>Site Map Category Editor</h1>
<a href="<cfoutput>#application.appPath#/tools/sitemap/sitemap.cfm</cfoutput>">Go Back</a>

<!--- CFPARAMS --->
<cfparam name="frmCatId" type="integer" default="0">
<cfparam name="frmParentId" type="integer" default="0">
<cfparam name="frmNewCatName" type="string" default="">
<cfparam name="frmLink" type="string" default="">
<cfparam name="frmRetired" type="boolean" default="0">
<cfparam name="frmAction" type="string" default="">

<cfset myInstance = getInstanceById(session.primary_instance)>

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

<!---fetch all categories for display--->
<!---fetch all the categories, so we can draw the ones that are populated for our users.--->
<cfset getCategories = getSMCategories(3, maskList)>

<!---a little style for our links.--->
<style type="text/css">
	span.retired {
		color: gray;
		font-style: italic;
	}

	/*we want to make the lists slimmer, but the big three padd lists differently, this forces them to be the same.*/
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
</style>

<!---jquery to make our lists into sortable lists.--->
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

				//disable and re-enable arrows as needed.
				fixArrows()
			});

		//now fix the appearance of the up and down arrows.
		fixArrows();
		
		//Activate any popovers on our page for tooltips.
		activatePopovers();
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


<!---handle user input.--->
<cfswitch expression="#frmAction#">

	<cfcase value="addCat">
		<cftry>
			<!---make sure the user's input is safe to use.--->
			<cfif trim(frmNewCatName) eq "">
				<cfthrow type="custom" message="Category Name" detail="Category Name cannot be left blank.">
			</cfif>

			<!---fix the link they provide, if they left it blank just make it go to a blank anchor.--->
			<cfif trim(frmLink) eq "">
				<cfset frmLink = "##">
			</cfif>

			<!---the input looks sound, add the category.--->
			<cfquery datasource="#application.applicationDataSource#" name="addCategory">
				INSERT INTO tbl_header_categories (parent, text, link)
				OUTPUT inserted.category_id
				VALUES (#frmParentId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNewCatName#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmLink#">)
			</cfquery>

			<p class="ok">
				New category created.  You will need to <a href="<cfoutput>#cgi.script_name#</cfoutput>">refresh</a> to see changes in the header.
			</p>
			<cfset message = "Category Added.,Parent:#frmParentId#, text:#frmNewCatName#,link:#frmLink#">
			<cfset recordCategoryUpdate(frmCatId,message)>
			<!---reset our user's input--->
			<cfset frmNewCatName = "">
			<cfset frmAction = "">
			<cfset frmParentId = 0>

			<!---re-fetch getCategories since the DB was updated--->
			<cfset getCategories = getSMCategories()>
			<cfset frmAction = ""><!---throw ourselves back to the main form.--->

		<cfcatch type="any">
			<cfset frmAction = "addCatForm">
			<cfoutput>
				<p class="warning">
					<span>Error</span> - #cfcatch.message#. #cfcatch.detail#
				</p>
			</cfoutput>
		</cfcatch>
		</cftry>
	</cfcase>

	<cfcase value="editCat">
		<cftry>
			<!---make sure the user's input is safe to use.--->
			<cfif frmCatId eq 0>
				<cfthrow type="custom" message="Category ID" detail="0 is not a valid Category ID.">
			</cfif>
			<!---a category cannot be its own parent.--->
			<cfif frmParentId eq frmCatId>
				<cfthrow type="custom" message="Parent Category" detail="A category cannot be its own parent, nor a category already under it, please select another Parent Category.">
			</cfif>
			<cfif trim(frmNewCatName) eq "">
				<cfthrow type="custom" message="Category Name" detail="Category Name cannot be left blank.">
			</cfif>

			<!---fix the link they provide, if they left it blank just make it go to a blank anchor.--->
			<cfif trim(frmLink) eq "">
				<cfset frmLink = "##">
			</cfif>


			<cfquery datasource="#application.applicationDataSource#" name="updateCat">
				UPDATE tbl_header_categories
				SET	text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNewCatName#">,
					parent = #frmParentId#,
					link = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmLink#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
				WHERE category_id = #frmCatId#
			</cfquery>


			<p class="ok">
				<cfoutput>Category #frmNewCatName# has been updated.  You will need to <a href="#cgi.script_name#">refresh</a> to see changes in the header.</cfoutput>
			</p>
			<cfset message = "Category Updated.,Parent:#frmParentId#, text:#frmNewCatName#,link:#frmLink#">
			<cfset recordCategoryUpdate(frmCatId,message)>
			<!---things are all set, throw them back to the form--->
			<!---re-fetch getAllCats since the DB was updated--->
			<cfset getCategories = getSMCategories()>
			<cfset frmAction = "editCatForm">

		<cfcatch type="any">
			<cfset frmAction = "editCatForm">
			<cfoutput>
				<p class="warning">
					<span>Error</span> - #cfcatch.message#. #cfcatch.detail#
				</p>
			</cfoutput>
		</cfcatch>
		</cftry>
	</cfcase>

	<cfcase value="updateOrder">
		<cftry>
			<!---loop over all our categories, to set their default values, where they do not match with user submitted values, update them.--->
			<cfloop query="getCategories">
				<!---set the param to the default value--->
				<cfparam name="frmSortOrder#category_id#" type="integer" default="#sort_order#">

				<!---now insert all the changes to the database--->
				<cfset userVal = evaluate("frmSortOrder#category_id#")>

				<cfif userVal neq sort_order>
					<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
						UPDATE tbl_header_categories
						SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#userVal#">
						WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#category_id#">
					</cfquery>
				</cfif>
			</cfloop>

			<!---with that all done we need to update getAllCats, so it is ordered correctly.--->
			<cfset getCategories = getSMCategories()>

			<p class="ok">
				Order has been updated in the database. You will need to <a href="<cfoutput>#cgi.script_name#</cfoutput>">refresh</a> to see changes in the header.
			</p>

		<cfcatch type="any">
			<cfset frmAction = "">
			<cfoutput>
				<p class="warning">
					<span>Error</span> - #cfcatch.message#. #cfcatch.detail#
				</p>
			</cfoutput>
		</cfcatch>
		</cftry>
	</cfcase>
</cfswitch>


<!---determine which form to draw--->
<cfswitch expression="#frmAction#">

	<cfcase value="addCatForm">
		<h2>Add a New Category</h2>
		<cfoutput>
			<form action="#cgi.script_name#" method="post">
			<input type="hidden" name="frmAction" value="addCat">

			<fieldset>
				<legend>New Category</legend>
				<p>
				<label>
					Parent Category:
					<cfset drawSMCategorySelect("frmParentId", frmParentId, -1, getCategories)>
				</label>
				<span class="btn btn-default glyphicon glyphicon-question-sign" title="" data-placement="top" data-toggle="popover" data-content="Categories with no Parent Category go into the header displayed on each page, but its own child categories will only be displayed on the full Site Map."></span>
				</p>

				<p>
				<label>
					Category Name:
					<input type="text"  name="frmNewCatName" value="#htmlEditFormat(frmNewCatName)#">
				</label>
				</p>

				<p>
				<label>
					Link:
					<input type="text"  name="frmLink" size="90" value="#htmlEditFormat(frmLink)#">
				</label>
				</p>

				<p>
					<input type="submit"  value="Add Category">
				</p>
			</fieldset>
			</form>

			<p>
				<a href="#cgi.script_name#">Select Another Category</a>
			</p>
		</cfoutput>
	</cfcase>

	<cfcase value="editCatForm">
		<!---fetch the details of the category---->
		<cfset curCat = structNew()>
		<cfloop query="getCategories">
			<cfif category_id eq frmCatid>
				<cfset curCat.category_id = category_id>
				<cfset curCat.category_name = text>
				<cfset curCat.link = link>
				<cfset curCat.parent_cat_id = parent>
				<cfset curCat.retired = retired>
				<cfbreak>
			</cfif>
		</cfloop>

		<!--use curCat to populate default values if they haven't been submitted.--->
		<cfif not isDefined("form.frmParentId")>
			<cfset frmParentId = curCat.parent_cat_id>
		</cfif>
		<cfif not isDefined("form.frmNewCatName")>
			<cfset frmNewCatName = curCat.category_name>
		</cfif>
		<cfif not isDefined("form.frmLink")>
			<cfif not isValid('url', curCat.link) AND curCat.link neq "##">
				<cfset frmLink = "#application.appPath#/#curCat.link#">
			<cfelse>
				<cfset frmLink = curCat.link>
			</cfif>

		</cfif>
		<cfif not isDefined("form.frmRetired")>
			<cfset frmRetired = curCat.retired>
		</cfif>


		<cfoutput>
			<h2>Edit Category: <cfoutput>#curCat.category_name#</cfoutput></h2>

			<cfif curCat.category_name neq "">
				<form action="#cgi.script_name#" method="post" name="editForm">
					<input type="hidden" name="frmAction" value="editCat">
					<input type="hidden" name="frmCatId" value="#frmCatId#">

					<fieldset>
						<legend>#curCat.category_name#</legend>

						<p>
							<label>
								Parent Category:
								<cfset drawSMCategorySelect("frmParentId", frmParentId, frmCatId, getCategories)>
							</label>
							<span class="btn btn-default glyphicon glyphicon-question-sign" title="" data-placement="top" data-toggle="popover" data-content="Categories with no Parent Category go into the header displayed on each page, but its own child categories will only be displayed on the full Site Map."></span>
						</p>

						<p>
							<label>
								Category Name:
								<input type="text"  name="frmNewCatName" value="#htmlEditFormat(frmNewCatName)#">
							</label>
						</p>

						<p>
							<label>
								Link:
								<input type="text"  name="frmLink" size="90" value="#htmlEditFormat(frmLink)#">
							</label>
						</p>

						<fieldset>
							<legend>Active:</legend>
							<label>
								<input type="radio" name="frmRetired" value="0" <cfif not frmRetired>checked</cfif>> Yes
							</label>
							<label>
								<input type="radio" name="frmRetired" value="1" <cfif frmRetired>checked</cfif>> No
							</label>
						</fieldset>


						<p>
							<input type="submit"   value="Update">
						</p>
					</fieldset>
				</form>

				<!---add a little javascript so folks know what they're getting into when they retire a category, but we only need it if we went in without the item being retired..--->
				<cfif curCat.retired eq 0>
					<script type="text/javascript">
						$(document).ready(function(){
							$("form[name='editForm']").submit(function(e){
								//If the retired boxk is checked, display the message.
								if($("input[name='frmRetired']:checked").val() == 1) return confirm("If you retire this category all child categories, and articles in those categories, will become unavailable to users.");

							});
						});
					</script>
				</cfif>

			<cfelse>
				<p>
					<em>No category found with an ID of #frmCatId#.</em>
				</p>
			</cfif>
		</cfoutput>


		<cfoutput>
			<p>
				<a href="#cgi.script_name#">Select Another Category</a>
			</p>
		</cfoutput>
	</cfcase>


	<cfdefaultcase>
		<h2 style="margin-bottom:0em; margin-top:0.5em;">Select a Category</h2>

		<p class="tinytext" style="margin-bottom:0em;">
			Gray, italicized links are categories that have been retired.
		</p>

		<br/>

		<!---draw categories to select here as a nested list of links--->
		<form accept="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
			<input type="hidden" name="frmAction" value="updateOrder">

			<fieldset>
				<legend>Category List</legend>
				<cfset drawCategoryList(0)>
			</fieldset>

			<input type="submit"   value="Update Order">
		</form>

		<p>
			<cfoutput><a href="#cgi.script_name#?frmAction=addCatForm">Add a New Category</a></cfoutput>
		</p>
	</cfdefaultcase>
</cfswitch>

<cfmodule template="#application.appPath#/footer.cfm">


<cffunction name="drawCategoryList">
	<cfargument name="parentId" type="numeric" default="0">

	<cfset var firstPass = 1><!---determines if we've drawn an opening UL or not.--->

	<cfloop query="getCategories">
		<cfif parentId eq parent>
			<cfif firstPass>
				<ul class="categories">
			</cfif>

			<!---draw this category.--->
			<li class="item">
				<span class="pos"><!---where we'll render our up/down arrows--->
					<button class="up" title="Move Article Up"></button><button class="down" title="Move Article Down"></button>
				</span>
				<cfoutput>
					<span <cfif retired>class="retired"</cfif>>
						#text#
					</span>
					<span class="tinytext" style="font-weight: normal;">[<a class="editLink" href="#cgi.script_name#?frmAction=editCatForm&frmCatId=#category_id#">Edit</a>] [<a class="editLink" href="#cgi.script_name#?frmAction=addCatForm&frmParentId=#category_id#">Add Category</a>]</span>
					<input type="hidden" class="sortOrder" name="frmSortOrder#category_id#" value="#sort_order#">
				</cfoutput>
				<!---now draw this category's children.--->
				<cfset drawCategoryList(category_id)>
			</li>

			<cfset firstPass = 0>
		</cfif>
	</cfloop>

	<cfif not firstPass>
		</ul>
	</cfif>

</cffunction>