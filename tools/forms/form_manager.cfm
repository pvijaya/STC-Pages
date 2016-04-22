<cfmodule template="#application.appPath#/header.cfm" title='Form Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<!--- cfparams --->
<!---cfparam name="frmMaskEditList" type="string" default=""--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="frmMaskEditList" default="[]">
<cfset frmMaskEditList = arrayToList(frmMaskEditList)><!---the multi-selector always returns an array, but we want a list.--->

<!---cfparam name="frmMaskViewList" type="string" default=""--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="frmMaskViewList" default="[]">
<cfset frmMaskViewList = arrayToList(frmMaskViewList)><!---the multi-selector always returns an array, but we want a list.--->

<cfparam name="frmAction" type="string" default="">
<cfparam name="frmFormId" type="integer" default="0">
<cfparam name="frmFormName" type="string" default="">
<cfparam name="frmFormDescription" type="string" default="">
<cfparam name="frmFormRetired" type="boolean" default="-1">
<cfparam name="frmFormAttributes" type="string" default="">

<!--- Header / Navigation --->
<h1>Form Manager</h1>
<cfoutput>
	<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
		<cfif frmAction EQ "CreateNew" OR frmAction EQ "Go" OR frmAction EQ "Edit">
			<a href="#application.appPath#/tools/forms/form_manager.cfm">Go Back</a> |
		</cfif>
		<a href="#application.appPath#/tools/forms/attribute_manager.cfm">Manage Attributes</a>
		<cfif hasMasks('Admin')>
			| <a href="#application.appPath#/tools/forms/form_submission_report.cfm">Form Submissions</a>
			| <a href="#application.appPath#/tools/forms/form_report.cfm">Form Report</a>
		</cfif>
		<cfif frmAction EQ "Go" OR frmAction EQ "Edit">
			| <a href="<cfoutput>#application.appPath#/tools/forms/form_viewer.cfm?formId=#frmFormId#&referrer=#urlEncodedFormat(cgi.script_name & "?frmFormId=" & frmFormId & "&frmAction=Go")#</cfoutput>">View Form</a>
		</cfif>
	</p>
</cfoutput>

<!--- queries --->
<cfquery datasource="#application.applicationDataSource#" name="getAttributes">
	SELECT a.attribute_id, a.attribute_name, a.attribute_details, a.attribute_text
	FROM tbl_attributes a
	WHERE a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
</cfquery>

<!--- fetch current items, if any --->
<cfset getItems = getFormItems(0)>
<cfset getRetired = getFormItems(1)>

<!--- handle user input --->
<cfif frmAction EQ "Create" OR frmAction EQ "Edit">

	<cftry>
	 
	 	<!--- we want to make the same input checks for both edit and create --->
		<cfif trim(frmFormName) eq "">
			<cfthrow message="Missing Input" detail="Form Name is a required field, and cannot be left blank.">
		</cfif>	
		<cfif trim(frmFormDescription) eq "">
			<cfthrow message="Missing Input" detail="Form Description is a required field, and cannot be left blank.">
		</cfif>	
		
		<!--- verify the mask ids --->
		<cfif listLen(frmMaskViewList) gt 0>
			<cfloop list="#frmMaskViewList#" index="maskId">
				<cfif not isValid("integer", maskId)>
					<cfthrow message="View Masks" detail="The Mask IDs you provide must all be valid integers.">
				</cfif>
			</cfloop>
		</cfif>
		
		<cfif listLen(frmMaskEditList) gt 0>
			<cfloop list="#frmMaskEditList#" index="maskId">
				<cfif not isValid("integer", maskId)>
					<cfthrow message="Edit Masks" detail="The Mask IDs you provide must all be valid integers.">
				</cfif>
			</cfloop>
		</cfif>
		
		<!--- create or edit the form --->
		<cfif frmFormId EQ 0>
		
			<cfquery datasource="#application.applicationDataSource#" name="createForm">
				INSERT INTO tbl_forms (form_name, form_description)
				OUTPUT inserted.form_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFormName#">,
				    <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFormDescription#">
				)			   
			</cfquery>
			
			<cfset frmformId = createForm.form_id>
			<cfset message = "Form created successfully.">
			
		<cfelse>
		
			<cfquery datasource="#application.applicationDataSource#" name="editForm">
				UPDATE tbl_forms
				SET form_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFormName#">,
					form_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFormDescription#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmFormRetired#">
				WHERE form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
			</cfquery>
			
			<!--- update the item order --->
			<cfloop query="getItems">
				<cfparam name="frmSortOrder#form_item_id#" type="integer" default="#sort_order#">
				
				<cfset userVal = evaluate("frmSortOrder#form_item_id#")>
				
				<cfif userVal neq sort_order>
					<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
						UPDATE tbl_forms_items
						SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#userVal#">
						WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
					</cfquery>
				</cfif>
			</cfloop>
			
			<cfset message = "Form updated successfully.">	
			
			<!---since we may have changed the order, re-fetch our form info--->
			<cfset getItems = getFormItems(0)>
			<cfset getRetired = getFormItems(1)>
			
			<cfset frmAction = "Go">
			<!--- stay on the edit page after submitting --->
			<cfoutput>
				<input type="hidden" name="frmFormId" value="#frmFormId#">
			</cfoutput>
			
			
		</cfif>
		
		<!--- clear out existing masks and attributes before inserting, to prevent clutter --->
		<cfquery datasource="#application.applicationDataSource#" name="deleteMasks">
			DELETE FROM tbl_forms_masks
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
		</cfquery>
		
		<cfquery datasource="#application.applicationDataSource#" name="deleteAttributes">
			DELETE FROM tbl_forms_attributes
			WHERE form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
		</cfquery>
		
		<!--- update the mask table --->
		<cfif listLen(frmMaskEditList) + listLen(frmMaskViewList) gt 0>
			<cfset cnt = 1><!---this gets used to put a comma after each set of values, except for the last item in frmMaskList--->
			<cfquery datasource="#application.applicationDataSource#" name="addMasks">
				INSERT INTO tbl_forms_masks (form_id, mask_id, edit)
				VALUES
				<cfloop list="#frmMaskEditList#" index="maskId">
					(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmFormId#">, 
					 <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">,
					 <cfqueryparam cfsqltype="cf_sql_bit" value="1">),
					<cfset cnt = cnt + 1>
				</cfloop>
				<cfloop list="#frmMaskViewList#" index="maskId">
					(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmFormId#">, 
					 <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">,
					 <cfqueryparam cfsqltype="cf_sql_bit" value="0">)
					<cfif cnt lt listLen(frmMaskViewList) + listLen(frmMaskEditList)>,</cfif>
					<cfset cnt = cnt + 1>
				</cfloop>
			</cfquery>
		</cfif>
		
		<!--- update the attribute table --->
		<cfif listLen(frmFormAttributes) GT 0>
			<cfset cnt = 1>
			<cfquery datasource="#application.applicationDataSource#" name="addAttributes">
				INSERT INTO tbl_forms_attributes (form_id, attribute_id)
				VALUES
				<cfloop list="#frmFormAttributes#" index="attributeId">
					(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmFormId#">,
					 <cfqueryparam cfsqltype="cf_sql_integer" value="#attributeId#">)
					<cfif cnt lt listLen(frmFormAttributes)>,</cfif>
					<cfset cnt = cnt + 1>
				</cfloop>
			</cfquery>
		</cfif>
			
		<p class="ok"><cfoutput>#message#</cfoutput></p>
	
	<cfcatch>
		<cfif frmAction EQ "Create">
			<cfset frmAction = "CreateNew">
		<cfelse>
			<cfset frmAction = "Go">
		</cfif>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>	
</cfif>

<!--- draw forms --->
<cfif frmAction EQ "CreateNew" OR frmAction EQ "Go">

	<cftry>

		<cfif frmFormId GT 0>
		
			<!--- fetch the old information to use as default --->
			<cfquery datasource="#application.applicationDataSource#" name="getForm">
				SELECT a.form_name, a.form_description, a.retired
				FROM tbl_forms a
				WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
			</cfquery>
			
			<cfquery datasource="#application.applicationDataSource#" name="getFormAttributes">
				SELECT a.form_attribute_id, a.attribute_id
				FROM tbl_forms_attributes a
				WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
			</cfquery>
			
			<cfquery datasource="#application.applicationDataSource#" name="getEditMasks">
				SELECT a.mask_id
				FROM tbl_forms_masks a
				WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
				      AND a.edit = 1
			</cfquery>
			
			<cfquery datasource="#application.applicationDataSource#" name="getViewMasks">
				SELECT a.mask_id
				FROM tbl_forms_masks a
				WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
				      AND a.edit = 0
			</cfquery>
		
			<!--- to simplify the item_manager, let the user choose what type of item to add here --->
			<cfoutput><h2 style="padding: 0px; margin-top: 0.0em; margin-bottom: 0.0em;">Edit #getForm.form_name#</h2></cfoutput>
			<cfset drawItemTypeLinks(frmFormId, 1)> <!--- draw input types --->
			<cfset drawItemTypeLinks(frmFormId, 0)> <!--- draw non-input types --->
			
			<br/>
			
			<!--- set defaults if the user has not provided new values --->
			<cfif frmMaskEditList EQ "">
				<cfloop query="getEditMasks">
					<cfset frmMaskEditList = listAppend(frmMaskEditList, #mask_id#)>
				</cfloop>
			</cfif>
			<cfif frmMaskViewList EQ "">
				<cfloop query="getViewMasks">
					<cfset frmMaskViewList = listAppend(frmMaskViewList, #mask_id#)>
				</cfloop>
			</cfif>
			<cfif frmFormAttributes EQ "">
				<cfloop query="getFormAttributes">
					<cfset frmFormAttributes = listAppend(frmFormAttributes, #attribute_id#)>
				</cfloop>
			</cfif>
			<cfif frmFormName EQ "">
				<cfset frmFormName = #getForm.form_name#>
			</cfif>
			<cfif frmFormDescription EQ "">
				<cfset frmFormDescription = #getForm.form_description#>
			</cfif>
			<cfif frmFormRetired EQ -1>
				<cfset frmFormRetired = #getForm.retired#>
			</cfif>
		
		<cfelse>
		
			<cfif frmFormName EQ "" AND frmFormDescription EQ "">
				<!--- get the user's masks and default to that list --->
				<cfset tempInstances = getInstanceList()>
				<cfset frmMaskEditList = #tempInstances#>
				<cfset frmMaskViewList = #tempInstances#>
			</cfif>
		
			<h2>New Form</h2>
			
		</cfif>
	
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">	
				
			<label>Name:
				<input name="frmFormName" value="<cfoutput>#htmlEditFormat(frmFormName)#</cfoutput>">
			</label>
			
			<br/> <br/>
			
			<label>Description:
				<textarea name="frmFormDescription"><cfoutput>#htmlEditFormat(frmFormDescription)#</cfoutput></textarea>
			</label>
			
			<!--- replace the default textarea above with a prettier one --->
			<script type="text/javascript">
				//a custom configuration for this ckeditor textarea
				var contactNote = CKEDITOR.replace('frmFormDescription',{
					toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
					toolbar:  'Basic',
					height: '200px',
					width: '500px',
					removePlugins: 'contextmenu,tabletools', /*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
				});	
			</script>				
			
			<br/>
			
			<fieldset>
				<legend>Masks Required to View</legend>
				<cfset drawMasksSelector("frmMaskViewList", frmMaskViewList, "")>
			</fieldset>
			
			<br/>
			
			<fieldset>
				<legend>Masks Required to Submit</legend>
				<cfset drawMasksSelector("frmMaskEditList", frmMaskEditList, "")>
			</fieldset>
			
			<br/>
			
			<fieldset>				
				<legend><cfoutput>Other Attributes <span class="tinytext">[<a href="#application.appPath#/documents/article.cfm?articleId=7346">details</a>]</cfoutput></span></legend>		
			
				<cfloop query="getAttributes">
					<cfoutput>
						<label>
							<input type="checkbox" id="frmFormAttributes" name="frmFormAttributes" value="#attribute_id#"
						   		<cfif listFindNoCase(frmFormAttributes, attribute_id)>checked="true"</cfif> >
								#attribute_text#
						</label><br/>
					</cfoutput>
				</cfloop>	
			</fieldset>
			
			<br/>
			
			<cfif frmFormId eq 0>
			
				<input type="submit"  value="Create" name="frmAction">
				
			<cfelse>
			
				<!--- we can only retire existing articles --->
				<fieldset>
					<legend>Retired?</legend>
					<label>
						Yes
						<input type="radio" name="frmFormRetired" value="1" <cfif frmFormRetired>checked="true"</cfif>>
					</label>
					<label>
						No
						<input type="radio" name="frmFormRetired" value="0" <cfif not frmFormRetired>checked="true"</cfif>>
					</label>
				</fieldset>
			
				<br/>
			
				<!--- draw our form items with the cool order adjuster buttons --->
				<fieldset>
					<legend>Item Order</legend>
					<cfset drawFormItems(0)>
					<span class="trigger">Retired Items</span>
						<div><cfset drawFormItems(1)></div>
				</fieldset>
				
				<br/>
				<input type="submit"  value="Edit" name="frmAction">
				
			</cfif>
			
			<!--- keep track of our form id --->
			<cfoutput>
				<input type="hidden" name="frmFormId" value="#frmFormId#">
			</cfoutput>
		
		</form>
	
	<cfcatch>

		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

<cfelse> <!--- main menu: select a form --->

	<!--- get existing forms --->
	<cfquery datasource="#application.applicationDataSource#" name="getforms">
		SELECT a.form_id, a.form_name, a.form_description, a.retired
		FROM tbl_forms a
		ORDER BY a.retired, a.form_name
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<br/>
		
		<fieldset>
			
			<legend>Choose</legend>
			
			<label>
				Select a Form:
				<select name="frmFormId">
					<cfoutput query="getForms">
						<option value="#form_id#">
							#form_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			
			<input type="submit" value="Go" name="frmAction">
			
			<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
						
			<a href="<cfoutput>#cgi.script_name#?frmAction=createnew</cfoutput>">Create New Form</a>	 
			
		</fieldset>
		
</cfif>


<!--- javascript --->

<!---style and javascript that makes lists sortable.--->
<!---a little style for our links.--->
<style type="text/css">
	span.retired {
		color: gray;
		font-style: italic;
	}
	
	p#listStatus {
		display: none;
	}
		
/*we want to make the lists slimmer, but the big three pad lists differently, this forces them to be the same.*/
ul.forms {
	list-style-type: none;
	border-left: solid 2px lightgray;
	/*border-top: solid 2px lightgray;*/
	margin-left: 2em;
	padding-left: 0px;
	margin-top: 0.5em;
}

ul.forms li {
	padding-left: 0px;
	margin-left: 0px;
}

ul.forms li.item span.pos {
	margin-right: 0.5em;
}

</style>

<!---jquery to make our lists into sortable lists.--->
<script type="text/javascript">
	$(document).ready(function(){
		/*prevent clicks on edit links from bubbling up and firing trigger/triggerexpanded items*/
		$("a.editItem").click(function(e){
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
		$("ul.forms").each(function(u){
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


<!--- Functions --->

<!--- Based on the boolean toggle input, fetches all active or inactive items for this form. --->
<cffunction name="getFormItems">
	<cfargument name="retired" type="boolean" default="0">
	
	<cfquery datasource="#application.applicationDataSource#" name="formItems">
		SELECT a.form_item_id, a.form_id, a.item_text, a.item_type, a.retired, a.sort_order
		FROM tbl_forms_items a
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
			  AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#retired#">
		ORDER BY a.sort_order, a.item_text	
	</cfquery>
	
	<cfreturn formItems>
	
</cffunction>

<!--- Draws all items of a given parent (defaults as items without a parent). --->
<cffunction name="drawFormItems">
	<cfargument name="retired" type="boolean" default="0">
	<cfargument name="parentId" type="numeric" default="0">
	
	<cfset var firstPass = 1> <!--- have we drawn the surrounding ul tags yet? --->
	
	<cfquery datasource="#application.applicationDataSource#" name="items">
		SELECT a.form_item_id, a.form_id, a.item_text, a.item_type, a.retired, a.sort_order
		FROM tbl_forms_items a
		WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmFormId#">
			  AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#retired#">
			  AND a.parent_id = <cfqueryparam cfsqltype="cf_sql_int" value="#parentId#">
		ORDER BY a.sort_order, a.item_text	
	</cfquery>
	
	<cfif items.recordCount GT 0>
		<cfloop query="items">
			<cfif firstPass> <ul class="forms"> <cfset firstPass = 0></cfif>	
			<cfset drawFormItem(item_type, form_item_id, sort_order, item_text, retired)>	
		</cfloop>
	</cfif>
	
	<!---close our UL if it was opened.--->
	<cfif not firstPass>
		</ul>
	</cfif>
	
</cffunction>

<!--- Draws a particular item, given its info. --->
<cffunction name="drawFormItem">
	<cfargument name="item_type" type="numeric" default="0">
	<cfargument name="form_item_id" type="numeric" default="0">
	<cfargument name="sort_order" type="numeric" default="0">
	<cfargument name="item_text" type="string" default="">
	<cfargument name="retired" type="boolean" default="0">
	
		<cfoutput>
			<li class="item">
				<cfset type_text = getItemType(item_type)>
				
				<!--- the first thing we want are our sorting arrows and the hidden position input. --->
				<span class="pos"> <!--- where we'll render our up/down arrows --->
					<button class="up" title="Move Item Up"></button><button class="down" title="Move Item Down"></button>
				</span>
				<input type="hidden" class="sortOrder" name="frmSortOrder#form_item_id#" value="#sort_order#">									
				[#type_text#] #left(stripTags(item_text),140)#
				<span class="tinytext">
					&nbsp;&nbsp; [<a href="#application.appPath#/tools/forms/item_manager.cfm?itemId=#form_item_id#&frmAction=edit">Edit</a>]
				</span>
				<cfset drawFormItems(retired, form_item_id)>					
			</li>
		</cfoutput>	
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>