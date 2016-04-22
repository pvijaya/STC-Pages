<cfmodule template="#application.appPath#/header.cfm" title="Category Editor">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">

<h2>Category Editor</h2>

<cfparam name="frmCatId" type="integer" default="0">
<cfparam name="frmParentId" type="integer" default="0">
<cfparam name="frmNewCatName" type="string" default="">

<!---cfparam name="frmOwnerMasks" type="string" default=""--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="frmOwnerMasks" default="[]">
<cfset frmOwnerMasks = arrayToList(frmOwnerMasks)><!---the multi-selector always returns an array, but we want a list.--->

<cfparam name="frmRetired" type="boolean" default="0">
<cfparam name="frmAction" type="string" default="">
<cfparam name="jsonSortArray" type="string" default="">
<cfset sortArray = arrayNew(1)>

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
				var myItemOrder = $("span.category", myItem).attr('sortOrder');
				var prevItemOrder = $("span.category", prevItem).attr('sortOrder');


				//if either one is not a numuber, we've reached the top, do nothing.
				if(isNaN(myItemOrder) || isNaN(prevItemOrder)){
					myItem.effect("highlight");//highlight so they know their click registered.
					return;//stop executing before we move stuf around.
				}

				//having passed that test swap their sort orders.
				$("span.category", prevItem).attr('sortOrder', myItemOrder)
				$("span.category", myItem).attr('sortOrder', prevItemOrder);

				//now visually swap them for our user.
				myItem.effect("highlight");
				prevItem.effect("highlight");

				//now actually move myItem to before prevItem.
				prevItem.before(myItem);

				//disable and re-enable arrows as needed.
				fixArrows();
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
				var myItemOrder = $("span.category", myItem).attr('sortOrder');
				var nextItemOrder = $("span.category", nextItem).attr('sortOrder');

				//if either one is not a numuber, we've reached the bottom, do nothing.
				if(isNaN(myItemOrder) || isNaN(nextItemOrder)){
					myItem.effect("highlight");//highlight so they know their click registered.
					return;//stop executing before we move stuf around.
				}

				//having passed that test swap their sort orders.
				$("span.category", nextItem).attr('sortOrder', myItemOrder);
				$("span.category", myItem).attr('sortOrder', nextItemOrder);

				//now visually swap them for our user.
				myItem.effect("highlight");
				nextItem.effect("highlight");

				//now actually move myItem to after nextItem.
				nextItem.after(myItem);

				//disable and re-enable arrows as needed.
				fixArrows();
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
		var sortArray = new Array();//We also want to store the new sort order for every category.
		var catObj = "";

		//first, for each list we need to know how many items there are.
		$("ul.categories").each(function(u){
			var listLen = $(this).children("li.item").length;

			if(isNaN(listLen)) listLen = 0;//listLen MUST be a number.

			//now find each li's current sortOrder
			$(this).children("li.item").each(function(i){/*we're using .children(), because we only want the first-level childen, and not all the nested li.items under the current ul*/
				var curItem = $(this);
				var curSort = $("span.category", curItem);

				curSort.attr('sortOrder', i+1);//just a little insurance to make sure items never fall out of the order the user sees.
				var curSortValue = curSort.attr('sortOrder');

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

				//update our array with the sort order for this category.
				catObj = {"cat_id": curSort.attr('catId'), "sort_order": curSortValue}
				sortArray.push(catObj);
			});
		});

		//console.log(sortArray);

		//Now that we have a useful sortArray we want to convert it to JSON, and stash it in jsonSortArray
		$("form input[name='jsonSortArray']").val(JSON.stringify(sortArray));
	}
</script>


<!---a query to fetch all categories--->
<cfset getAllCats = getAllCategoriesQuery()>

<!---handle user input.--->

<cfswitch expression="#frmAction#">
	<cfcase value="addCat">
		<cftry>
			<!---make sure the user's input is safe to use.--->
			<cfif trim(frmNewCatName) eq "">
				<cfthrow type="custom" message="Category Name" detail="Category Name cannot be left blank.">
			</cfif>
			<!---is there already a category with this name in its parent category?--->
			<cfquery dbtype="query" name="getDupes">
				SELECT *
				FROM getAllCats
				WHERE parent_cat_id = #frmParentId#
				AND LOWER(category_name) = LOWER('#frmNewCatName#')
			</cfquery>
			<cfif getDupes.recordCount gt 0>
				<cfthrow type="custom" message="Category Name" detail="Category Name <em>#frmNewCatName#</em> is already in use in this parent category.">
			</cfif>

			<!---the input looks sound, add the category.--->
			<cfquery datasource="#application.applicationDataSource#" name="addCategory">
				INSERT INTO tbl_articles_categories (parent_cat_id, category_name)
				OUTPUT inserted.category_id
				VALUES (#frmParentId#, <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNewCatName#">)
			</cfquery>

			<!---Now set the masks for the owner of--->
			<!---validate that the user provided valid masks for the owner--->
			<cfloop list="#frmOwnerMasks#" index="maskId">
				<cfif not isValid("integer", maskId)>
					<cfthrow message="Invalid Owner Mask" detail="The Mask IDs you provide must all be valid integers.">
				</cfif>
			</cfloop>

			<!---the masks are good, remove the existing owner masks, and provide the new ones.--->
			<cfquery datasource="#application.applicationDataSource#" name="remOwnerMasks">
				DELETE FROM tbl_articles_categories_owner
				WHERE category_id = #addCategory.category_id#
			</cfquery>

			<cfloop list="#frmOwnerMasks#" index="maskId">
				<cfquery datasource="#application.applicationDataSource#" name="addOwnerMasks">
					INSERT INTO tbl_articles_categories_owner (category_id, mask_id)
					VALUES (
						#addCategory.category_id#,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">
					)
				</cfquery>
			</cfloop>

			<p class="ok">
				New category created.
			</p>

			<!---reset our user's input--->
			<cfset frmNewCatName = "">
			<cfset frmAction = "">
			<cfset frmParentId = 0>

			<!---re-fetch getAllCats since the DB was updated--->
			<cfset getAllCats = getAllCategoriesQuery()>

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
			<!---is there already a category with this name in its parent category?--->
			<cfquery dbtype="query" name="getDupes">
				SELECT *
				FROM getAllCats
				WHERE parent_cat_id = #frmParentId#
				AND LOWER(category_name) = LOWER('#frmNewCatName#')
				AND category_id <> #frmCatId#
			</cfquery>
			<cfif getDupes.recordCount gt 0>
				<cfthrow type="custom" message="Category Name" detail="Category Name <em>#frmNewCatName#</em> is already in use in this parent category.">
			</cfif>

			<!---If we've got this far the category checks out, audit the changes, and update the database.--->
			<cfset oldCat = getCatStruct(frmCatId)><!---current values for audit--->

			<cfquery datasource="#application.applicationDataSource#" name="updateCat">
				UPDATE tbl_articles_categories
				SET	category_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNewCatName#">,
					parent_cat_id = #frmParentId#,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
				WHERE category_id = #frmCatId#
			</cfquery>


			<!---Now set the masks for the owner of--->
			<!---validate that the user provided valid masks for the owner--->
			<cfloop list="#frmOwnerMasks#" index="maskId">
				<cfif not isValid("integer", maskId)>
					<cfthrow message="Invalid Owern Mask" detail="The Mask IDs you provide must all be valid integers.">
				</cfif>
			</cfloop>

			<!---the masks are good, remove the existing owner masks, and provide the new ones.--->
			<cfquery datasource="#application.applicationDataSource#" name="remOwnerMasks">
				DELETE FROM tbl_articles_categories_owner
				WHERE category_id = #frmCatId#
			</cfquery>

			<cfloop list="#frmOwnerMasks#" index="maskId">
				<cfquery datasource="#application.applicationDataSource#" name="addOwnerMasks">
					INSERT INTO tbl_articles_categories_owner (category_id, mask_id)
					VALUES (
						#frmCatId#,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">
					)
				</cfquery>
			</cfloop>


			<p class="ok">
				<cfoutput>Category #oldCat.category_name# has been updated.</cfoutput>
			</p>

			<cfset newCat = getCatStruct(frmCatId)><!---new values for audit.--->

			<cfset auditText = "">
			<cfset auditList = structKeyList(oldCat)>

			<cfloop list="#auditList#" index="i">
				<cfif oldCat[i] neq newCat[i] AND i neq "owner_mask_list"><!---print any changes, but don't spit out technical stuff like mask_id's--->
					<cfset auditText = auditText & "<p><b>#i#</b> changed from <em>#oldCat[i]#</em></p>">
				</cfif>
			</cfloop>

			<!---if there have been changes record them in the audit table.--->
			<cfif auditText neq "">
				<cfquery datasource="#application.applicationDataSource#" name="addAudit">
					INSERT INTO tbl_articles_categories_audit (category_id, user_id, audit_text)
					VALUES (#frmCatId#, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">)
				</cfquery>

				<p class="ok">
					Changes have successfully been audited.
				</p>
			</cfif>

			<!---things are all set, throw them back to the form--->
			<!---re-fetch getAllCats since the DB was updated--->
			<cfset getAllCats = getAllCategoriesQuery()>
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
			<cfif not isJSON(jsonSortArray)>
				<cfthrow message="Bad Input" detail="There was an error processing the order you prvoided.  It does not appear to be valid JSON.">
			</cfif>
			<cfset sortArray = DeserializeJSON(jsonSortArray)>

			<!---we need to snag all the categories to set defaults for each item's sort order.--->
			<cfset allCatsOrder = getAllCategoriesQuery()>

			<cfloop query="allCatsOrder">
				<!---now loop through sortArray to find the matching cat_id--->
				<cfloop from="1" to="#arrayLen(sortArray)#" index="i">
					<cfif allCatsOrder.category_id eq sortArray[i].cat_id>
						<!---we've hit our match, see if the values changed.--->
						<cfif allCatsOrder.sort_order neq sortArray[i].sort_order>
							<!---we have a new value, store it in the DB.--->
							<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
								UPDATE tbl_articles_categories
								SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#sortArray[i].sort_order#">
								WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#sortArray[i].cat_id#">
							</cfquery>
						</cfif>

						<!---we're done, break out of the array's loop.--->
						<cfbreak>
					</cfif>
				</cfloop>
			</cfloop>

			<!---with that all done we need to update getAllCats, so it is ordered correctly.--->
			<cfset getAllCats = getAllCategoriesQuery()>

			<p class="ok">
				Order has been updated in the database.
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



<!---now determine which form to draw--->
<cfswitch expression="#frmAction#">
	<cfcase value="addCatForm">
		<h3>Add a New Category</h3>
		<cfoutput>
			<form action="#cgi.script_name#" method="post">
			<input type="hidden" name="frmAction" value="addCat">

			<fieldset>
				<legend>New Category</legend>

				#bootstrapSelectField("frmParentId", getCategoriesArray(getAllCats), "Parent Category", frmParentId, "The category that our current category belongs to.")#

				#bootstrapCharField("frmNewCatName", "Category Name", frmNewCatname)#

				<!---draw the mask selector for the category owner.--->
					<cfset drawMasksSelector("frmOwnerMasks", frmOwnerMasks, "Owner", "Optional.  The owner of a category is inherited by all child categories, and the owner must approve revisions to articles made in those categories.")>

				<p>
					<input class="btn btn-primary col-sm-offset-3" type="submit" value="Add Category">
				</p>
			</fieldset>
			</form>

			<p>
				<a href="#cgi.script_name#">Select Another Category</a>
			</p>
		</cfoutput>
	</cfcase>

	<cfcase value="editCatForm">
		<!---fetch the name of the category---->
		<cfset curCat = getCatStruct(frmCatId)>
		<!--use curCat to populate default values if they haven't been submitted.--->
		<cfif not isDefined("form.frmParentId")>
			<cfset frmParentId = curCat.parent_cat_id>
		</cfif>
		<cfif not isDefined("form.frmNewCatName")>
			<cfset frmNewCatName = curCat.category_name>
		</cfif>
		<cfif not isDefined("form.frmOwnerMasks")>
			<cfset frmOwnerMasks = curCat.owner_mask_list>
		</cfif>
		<cfif not isDefined("form.frmRetired")>
			<cfset frmRetired = curCat.retired>
		</cfif>


		<cfoutput>
			<h3>Edit Category: <cfoutput>#curCat.category_name#</cfoutput></h3>

			<cfif curCat.category_name neq "">
				<form action="#cgi.script_name#" method="post" name="editForm" class="form-horizontal">
					<input type="hidden" name="frmAction" value="editCat">
					<input type="hidden" name="frmCatId" value="#frmCatId#">

					<!---we want to prvent categories from having a loop of parent/child relations.  Never let a group have a parent that is currently its child.--->
					<cfset childOptions = listToArray(getCategoryChildrenList(frmCatId))>
					#bootstrapSelectField("frmParentId", getCategoriesArray(getAllCats), "Parent Category", frmParentId, "The category that our current category belongs to.", childOptions)#

					#bootstrapCharField("frmNewCatName", "Category Name", frmNewCatname)#

					<!---draw the mask selector for the category owner.--->
					<cfset drawMasksSelector("frmOwnerMasks", frmOwnerMasks, "Owner", "Optional.  The owner of a category is inherited by all child categories, and the owner must approve revisions to articles made in those categories.")>

					<!---find if this category already inherits any owners.--->
					<cfset inheritedOwner = getInheritedOwnerMasks(frmCatId, getAllCats)>

					<cfif listLen(inheritedOwner) gt 0>
							<div class="alert alert-info col-sm-offset-3" role="alert">
								The following masks are aleady inherited from parent categories: <i><cfoutput>#replace(inheritedOwner, ",", ", ", "all")#</cfoutput></i>
							</div>
					</cfif>

					#bootstrapRadioField("frmRetired", [{"name"="Yes ", "value"="0"},{"name"="No ", "value"="1"}], "Active", frmRetired)#

					<p>
						<input class="btn btn-primary col-sm-offset-3" type="submit" name="submit"  value="Update">
					</p>
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

		<!---now fetch and display the history of the category--->
		<cfquery datasource="#application.applicationDataSource#" name="getCatAudit">
			SELECT u.username, a.audit_text, a.audit_date
			FROM tbl_articles_categories_audit a
			INNER JOIN tbl_users u ON u.user_id = a.user_id
			WHERE a.category_id = #frmCatId#
			ORDER BY a.audit_date DESC
		</cfquery>

		<cfif getCatAudit.recordCount gt 0>
			<h3>Category History</h3>

			<table class="stripe">
				<tr class="titlerow">
					<td colspan="2">Category History</td>
				</tr>
				<tr class="titlerow2">
					<th>Date</th>
					<th>Details</th>
				</tr>

				<cfoutput query="getCatAudit">
					<tr>
						<td class="tinytext" align="right">
							#username#<br/>
							#dateFormat(audit_date, "mmm d, yyyy")#
							#timeFormat(audit_date, "short")#
						</td>
						<td>
							#audit_text#
						</td>
					</tr>
				</cfoutput>

			</table>
		</cfif>

		<cfoutput>
			<p>
				<a href="#cgi.script_name#">Select Another Category</a>
			</p>
		</cfoutput>
	</cfcase>

	<cfdefaultcase>
		<h3>Select a Category</h3>

		<p class="tinytext">
			Gray, italicized links are categories that have been retired.
		</p>

		<!---draw categories to select here as a nested list of links--->
		<form accept="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
			<input type="hidden" name="frmAction" value="updateOrder">
			<input type="hidden" name="jsonSortArray" value="">

			<fieldset>
				<legend>Category List</legend>
				<cfset drawCategoryList(0, getAllCats)>
			</fieldset>

			<input type="submit"  value="Update Order">
		</form>

		<p>
			<cfoutput><a href="#cgi.script_name#?frmAction=addCatForm">Add a New Category</a></cfoutput>
		</p>
	</cfdefaultcase>
</cfswitch>


<cfmodule template="#application.appPath#/footer.cfm">





<cffunction name="drawCategoryList">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var getChildren = getChildCategoriesByParent(parentId, allCategories)><!---call getChildren with the global getAllCats query to save DB calls--->
	<cfset var pos = 1><!---the positional value of each item in the list.--->
	<cfset var hasGrandChildren = "">

	<cfif getChildren.recordCount gt 0>
		<ul class="categories">
		<cfoutput query="getChildren">

			<!---if the item has children wrap them in a trigger expand tag so the list is easier to look at.--->
			<cfset hasGrandChildren = getChildCategoriesByParent(category_id, allCategories)>

			<li class="item">
				<span class="pos"><!---where we'll render our up/down arrows--->
					<button class="up" title="Move Article Up"></button><button class="down" title="Move Article Down"></button>
				</span>
				<cfif hasGrandChildren.recordCount gt 0><span class="trigger"></cfif>
					<span class="category<cfif retired> retired</cfif>" catId="#category_id#" sortOrder="#pos#"> #category_name#</span> <span class="tinytext" style="font-weight: normal;">[<a class="editLink" href="#cgi.script_name#?frmAction=editCatForm&frmCatId=#category_id#">Edit</a>] [<a class="editLink" href="#cgi.script_name#?frmAction=addCatForm&frmParentId=#category_id#">Add Category</a>]</span>
				<cfif hasGrandChildren.recordCount gt 0></span></cfif>
				<!---check for any child items--->
				<cfset drawCategoryList(category_id, allCategories)>
			</li>


			<!---increment pos for our next pass--->
			<cfset pos = pos + 1>
		</cfoutput>
		</ul>
	</cfif>
</cffunction>


<!---fetch a struct with the details of a category for a given category_id--->
<cffunction name="getCatStruct" output="false">
	<cfargument name="catId" type="numeric" required="true">

	<cfset var getCat = "">
	<cfset var catStruct = structNew()>
	<cfset var getOwnerMasks = "">

	<!---set our default values to return--->
	<cfset catStruct.category_id = catId>
	<cfset catStruct.category_name = "">
	<cfset catStruct.parent_cat_id = 0>
	<cfset catStruct.retired = 0>
	<cfset catStruct.owner_mask_list = "">
	<cfset catStruct.owner_mask_names = "">

	<cfquery datasource="#application.applicationDataSource#" name="getCat">
		SELECT *
		FROM tbl_articles_categories
		WHERE category_id = #catId#
	</cfquery>

	<cfloop query="getCat">
		<cfset catStruct.category_name = category_name>
		<cfset catStruct.parent_cat_id = parent_cat_id>
		<cfset catStruct.retired = retired>
	</cfloop>

	<cfquery datasource="#application.applicationDataSource#" name="getOwnerMasks">
		SELECT m.mask_id, mask_name
		FROM tbl_articles_categories_owner co
		INNER JOIN tbl_user_masks m ON m.mask_id = co.mask_id
		WHERE co.category_id = #catId#
		ORDER BY m.mask_id ASC
	</cfquery>

	<cfloop query="getOwnerMasks">
		<cfset catStruct.owner_mask_list = listAppend(catStruct.owner_mask_list, mask_id)>
		<cfset catStruct.owner_mask_names = listAppend(catStruct.owner_mask_names, mask_name)>
	</cfloop>

	<cfreturn catStruct>
</cffunction>

<cffunction name="getCategoriesArray">
	<cfargument name="allCats" type="query" default="#getAllCategoriesQuery()#">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="indentLevel" type="numeric" default="0">

	<cfset var padding = "&nbsp; &nbsp; ">
	<cfset var myArray = arrayNew(1)>
	<cfset var myObj = structNew()>
	<cfset var childArray = arrayNew(1)>

	<cfif parentId eq 0>
		<cfset arrayAppend(myArray, {"name"="No Parent", "value"="0"})>
	</cfif>

	<cfloop query="allCats">
		<cfif parent_cat_id eq parentId>
			<cfset myObj = structNew()>
			<cfset myObj["name"] = category_name>
			<cfset myObj["value"] = category_id>

			<cfif retired>
				<cfset myObj["name"] = myObj["name"] & " (retired)">
			</cfif>

			<!---now add our padding to the category name.--->
			<cfloop from="1" to="#indentLevel#" index="i">
				<cfset myObj["name"] = padding & myObj["name"]>
			</cfloop>
			<cfset ArrayAppend(myArray, myObj)>


			<!---now fetch any children, and draw them, too--->
			<cfset childArray = getCategoriesArray(allCats, category_id, indentLevel + 1)>
			<cfloop from="1" to="#arrayLen(childArray)#" index="i">
				<cfset ArrayAppend(myArray, childArray[i])>
			</cfloop>

		</cfif>
	</cfloop>

	<cfreturn myArray>
</cffunction>

