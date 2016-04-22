<cfmodule template="#application.appPath#/header.cfm" title='Item Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- item type values: refer to tbl_forms_items_types --->

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<h1>Form Item Editor</h1>

<!--- cfparams --->
<!--- non-form parameters --->
<cfparam name="itemId" type="integer" default="0">
<cfparam name="formId" type="integer" default="0">
<cfparam name="itemType" type="integer" default="0">
<cfparam name="itemTypeText" type="string" default="">
<cfparam name="message" type="string" default="">
<!--- basic item parameters --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmItemText" type="string" default="">
<cfparam name="frmItemAnswer" type="string" default="">
<cfparam name="frmItemRetired" type="boolean" default="0">
<!--- option parameters --->
<cfparam name="frmItemOptionIds" type="string" default="">
<!--- parent parameters --->
<cfparam name="frmParentId" type="integer" default="0">
<cfparam name="frmParentOptionId" type="integer" default="0">
<!--- table parameters --->
<cfparam name="frmActiveRows" type="string" default="">
<cfparam name="frmRetiredRows" type="string" default="">
<cfparam name="frmActiveCols" type="string" default="">
<cfparam name="frmRetiredCols" type="string" default="">

<cfset itemTypeText = getItemType(itemType)>

<!--- In the case of edits, we need to fetch some data before drawing the form --->
<!--- We only do this the first time the user accesses the form; revert to entered information from this point on. --->
<cfif itemId gt 0>

	<!--- retrieve item information if it is unknown --->
	<cfset getFormItem = getItem(itemId)>
	<cfif getFormItem.recordCount GT 0 AND structIsEmpty(form)>
	
		<!--- basic information --->
		<cfif formId EQ 0><cfset formId = "#getFormItem.form_id#"></cfif>
		<cfset itemType = getFormItem.item_type>
		<cfset itemTypeText = getItemType(itemType)>
		<cfset frmItemText = getFormItem.item_text>
		<cfset frmItemRetired = getFormItem.retired>
		
		<!--- answers - single for multiple choice, multiple for multiple check --->
		<cfif itemTypeText EQ "Multiple Choice">
			<cfset frmItemAnswer = getFormItem.item_answer>
		<cfelseif itemTypeText EQ "Multiple Check">
			<cfquery datasource="#application.applicationDataSource#" name="getItemAnswers">
				SELECT fia.item_answer
				FROM tbl_forms_items_answers fia
				WHERE fia.form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
			</cfquery>
			<cfloop query="getItemAnswers">
				<cfset frmItemAnswer = listAppend(frmItemAnswer, item_answer)>
			</cfloop>
		</cfif>
		
		<!--- retrieve the parent information --->
		<cfif frmParentID EQ 0>
			<cfset frmParentId = getFormItem.parent_id>
			<cfset frmParentOptionId = getFormItem.parent_answer>
		</cfif>
		
	</cfif>
	
	<!--- for a multiple choice question, fetch the associated options. --->
	<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">

		<cfset getActive = getOptions(0)>
		<cfset getRetired = getOptions(1)>
		
	</cfif>

	<!--- If we can't find the actual item, we have a problem. --->
	<cfif getFormItem.recordCount eq 0>
		<p class="warning">
			No item with ID <cfoutput>#itemId#</cfoutput> was found. 
		</p>
		<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
		<cfabort>
	</cfif>
	
</cfif>

<!--- retrieve form items for parent selector --->
<cfquery datasource="#application.applicationDataSource#" name="getFormItems">
	SELECT a.form_item_id, a.item_text, b.form_item_option_id, b.option_text, a.retired AS item_retired, b.retired AS option_retired
	FROM tbl_forms_items a
	INNER JOIN tbl_forms_items_options b on b.form_item_id = a.form_item_id
	WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		  AND NOT a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
		  AND a.item_type = <cfqueryparam cfsqltype="cf_sql_int" value="2">
	ORDER BY a.sort_order, a.form_item_id, b.form_item_option_id
</cfquery>

<!--- navigation / header --->
<!--- 'Go Back' uses referrer if possible; otherwise defaults to the form manager --->
<cfif formId GT 0>
	<a href="<cfoutput>#application.appPath#/tools/forms/form_manager.cfm?frmAction=Go&frmFormId=#formId#</cfoutput>">Go Back</a>
<cfelse>
	<a href="<cfoutput>#application.appPath#/tools/forms/form_manager.cfm</cfoutput>">Go Back</a>
</cfif>

<!--- this allows us to present a message at this page through url arguments --->
<!--- be particular about the message to avoid weird user-passed arguments --->
<cfif message EQ "Item Updated." OR message EQ "Item Added.">
	<p class="ok"><cfoutput>#message#</cfoutput></p>	
</cfif>

<!---handle user input--->
<cfif frmAction eq "addItem" OR frmAction eq "editItem">

	<!---both adds and edits require the same verification.--->
	<cftry>
		
		<!--- no blank fields --->
		<cfif trim(frmItemText) eq "">
			<cfthrow message="Missing Input" detail="<b>Text</b> field cannot be left blank.">
		</cfif>
		
		<cfif itemType eq 0>
			<cfthrow message="Missing Input" detail="You must choose a type.">
		</cfif>
		
		<!--- multiple choice / check --->
		<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">
			
			<!--- ensure at least one option supplied --->
			<cfif listLen(frmItemOptionIds) EQ 0>
				<cfthrow message="Missing Input" detail="You must supply at least one option field.">
			</cfif>
			
			<!--- ensure valid option_ids and valid option inputs --->
			<cfloop list="#frmItemOptionIds#" index="option_id">
				
				<!--- check all of our option_ids to ensure they are valid --->
				<!--- valid = either an integer or i followed by an integer --->
				<cfif NOT REFind("^i?\d+$", option_id)>
					<cfthrow message="Invalid Input" detail="Invalid option ID.">
				</cfif>
				
				<cfset option = evaluate("frmItemOption#option_id#")>
				
				<cfif trim(option) EQ "">
					<cfthrow message="Missing Input" detail="You cannot supply a blank option.">
				</cfif>
				
			</cfloop>
			
			<!--- check our answer to ensure it is valid --->
			<!--- valid = either an integer or i followed by an integer --->
			<cfif NOT REFind("^i?\d+$", frmItemAnswer) AND itemTypeText EQ "Multiple Choice">
				<cfthrow message="Invalid Input" detail="Invalid item answer.">
			</cfif>
			
		</cfif>
		
		<!--- at least one valid row and one valid column (table) --->
		<cfif itemTypeText EQ "Table" AND listLen(frmActiveRows) + listLen(frmActiveRows) EQ 0>
			<cfthrow message="Missing Input" detail="You must supply at least one row field.">
		</cfif>
		
		<cfif itemTypeText EQ "Table" AND listLen(frmActiveCols) + listLen(frmActiveCols) EQ 0>
			<cfthrow message="Missing Input" detail="You must supply at least one column field.">
		</cfif>  
		
		<!--- update or add the items --->		
		<cfif itemId gt 0>
			
			<!--- update the existing item --->
			<cfquery datasource="#application.applicationDataSource#" name="updateItem">
				UPDATE tbl_forms_items
				SET	item_text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmItemText#">,
					item_type = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemType#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmItemRetired#">,
					parent_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentId#">,
					parent_answer = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentOptionId#">
				WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
			</cfquery>
			
			<cfset message = "Item updated.">
			
		<cfelse>
		    
		    <cfset sort_order = 0>
		    
		    <cfquery datasource="#application.applicationDataSource#" name="getLastSort">
				SELECT MAX(sort_order) AS max_sort
				FROM tbl_forms_items
				WHERE form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
			</cfquery>
		    
		    <cfif getLastSort.recordCount GT 0 AND getLastSort.max_sort NEQ "">
				<cfset sort_order = getLastSort.max_sort + 1>    
			</cfif>
		    
			<!--- add a new item --->
			<cfquery datasource="#application.applicationDataSource#" name="addItem">
				INSERT INTO tbl_forms_items (form_id, item_text, item_type, retired, parent_id, parent_answer, sort_order)
				OUTPUT inserted.form_item_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmItemText#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#itemType#">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="#frmItemRetired#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentOptionId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#sort_order#">
				)
			</cfquery>
			
			<cfset itemId = addItem.form_item_id>
			<cfset message = "Item Added.">
								
		</cfif>
		
		<!--- update item information --->
		<cfset getFormItem = getItem()>
		
		<!--- manage options if we're dealing with a multiple choice input --->
		<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">
			
			<!--- set all options to retired so we can selectively choose the active ones --->
			<cfquery datasource="#application.applicationDataSource#" name="retireOptions">
				UPDATE tbl_forms_items_options
				SET retired = 1
				WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
			</cfquery>
			
			<cfset ans_id = 0>
			<cfset ans_list = "">
			
			<!--- we have a list of option ids (either valid form option ids or i#n#) --->
			<!--- loop through the list and reinstate or create options as necessary --->
			<cfloop list="#frmItemOptionIds#" index="option_id">
				
				<!--- our option_ids have all been checked for validity above --->
				<cfset option = evaluate("frmItemOption#option_id#")>
			
				<!--- at this point frmItemAnswer is either a form_item_option_id, or a string --->
				<!--- of the form i#n#. we need to figure out which option it corresponds to and set --->
				<!--- this questions' answer while we are looping. --->	
				
				<!--- look for an existing option that matches our current one --->
				<cfquery datasource="#application.applicationDataSource#" name="getOption">
					SELECT fio.form_item_option_id
					FROM tbl_forms_items_options fio
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
						  AND option_text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#option#">
				</cfquery>
				
				<!--- if it exists, reinstate it; otherwise create a new one --->
				<cfif getOption.recordCount GT 0>
					
					<cfquery datasource="#application.applicationDataSource#" name="updateOption">
						UPDATE tbl_forms_items_options
						SET retired = 0
						OUTPUT inserted.form_item_option_id
						WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
							  AND form_item_option_id = <cfqueryparam cfsqltype="cf_sql_integer" 
							  				                          value="#getOption.form_item_option_id#">
					</cfquery>
									
					<cfif option_id EQ frmItemAnswer AND ans_id EQ 0>					
						<cfset ans_id = updateOption.form_item_option_id>					
					</cfif>
					
					<cfif listFindNoCase(frmItemAnswer, option_id)>
						<cfset ans_list = listAppend(ans_list, updateOption.form_item_option_id)>
					</cfif>
					
				<cfelse>
				
					<cfquery datasource="#application.applicationDataSource#" name="addOption">
						INSERT INTO tbl_forms_items_options (form_item_id, option_text)
						OUTPUT inserted.form_item_option_id
						VALUES 
							(<cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">, 
							 <cfqueryparam cfsqltype="cf_sql_varchar" value="#option#">)
					</cfquery>
					
					<cfif option_id EQ frmItemAnswer AND ans_id EQ 0>					
						<cfset ans_id = addOption.form_item_option_id>					
					</cfif>
					
					<cfif listFindNoCase(frmItemAnswer, option_id)>
						<cfset ans_list = listAppend(ans_list, addOption.form_item_option_id)>
					</cfif>
				
				</cfif>
			
			</cfloop>
			
			<cfif itemTypeText EQ "Multiple Choice">
			
				<!--- set our new answer based on the ans_id determined above --->
				<cfquery datasource="#application.applicationDataSource#" name="updateAnswer">
					UPDATE tbl_forms_items
					SET item_answer = <cfqueryparam cfsqltype="cf_sql_integer" value="#ans_id#">
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
				</cfquery>
		
				<!--- update frmItemAnswer to ensure it is a valid option_id --->
				<cfset frmItemAnswer = ans_id>
			
			<cfelseif itemTypeText EQ "Multiple Check">
				
				<!--- clear out any existing answers --->
				<cfquery datasource="#application.applicationDataSource#" name="updateAnswer">
					DELETE FROM tbl_forms_items_answers
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
				</cfquery>
				
				<!--- insert new answers based on ans_list --->
				<cfset cnt = 1>
				<cfif len(ans_list) GT 0>
					<cfquery datasource="#application.applicationDataSource#" name="updateAnswer">
						INSERT INTO tbl_forms_items_answers (form_item_id, item_answer)
						VALUES
					        <cfloop list="#ans_list#" index="i">       
					            (<cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">,
					             <cfqueryparam cfsqltype="cf_sql_integer" value="#i#">)
					            /* ensure a comma gets inserted between each list */
					            <cfif cnt LT listLen(ans_list)>,</cfif>
					            <cfset cnt = cnt + 1>
					        </cfloop>
					</cfquery>
				</cfif>
		
				<!--- update frmItemAnswer to ensure it is a valid option_id --->
				<cfset frmItemAnswer = ans_list>
				
			</cfif>
			
			<!--- fetch the items again to make sure we are up to date --->
			<cfset getActive = getOptions(0)>
			<cfset getRetired = getOptions(1)>
		
		<!--- manage cells if we're dealing with a table --->
		<cfelseif itemType EQ 7>
		
			<cfquery datasource="#application.applicationDataSource#" name="checkSubmissions">
				SELECT fui.user_answer
				FROM tbl_forms_users_items fui
				WHERE fui.form_item_id = <cfqueryparam cfsqltype="integer" value="#itemId#">
			</cfquery>
		
			<cfset getRows = getTableCells(itemId, 1, 0)>
			<cfset getCols = getTableCells(itemId, 0, 0)>
			
			<cfset getOldRetiredRows = getTableCells(itemId, 1, 1)>
			<cfset getOldRetiredCols = getTableCells(itemId, 0, 1)>
		
			<!--- create lists containing old (retired and active) cells --->
			<!--- we want to avoid making any duplicates of existing cells --->
			<cfset oldRows = "">
			<cfset oldCols = "">
			<cfloop query="getRows">
				<cfset oldRows = listAppend(oldRows, cell_text)>
			</cfloop>
			<cfloop query="getCols">
				<cfset oldCols = listAppend(oldCols, cell_text)>
			</cfloop>
			<cfloop query="getOldRetiredRows">
				<cfset oldRows = listAppend(oldRows, cell_text)>
			</cfloop>
			<cfloop query="getOldRetiredCols">
				<cfset oldCols = listAppend(oldCols, cell_text)>
			</cfloop>
			
			<cfset newRows = "">
			<cfset newCols = "">
			<cfloop list="#frmActiveRows#" index="row">
				<cfif NOT listFindNoCase(oldRows, row)>
					<cfset newRows = listAppend(newRows, row)>
				</cfif>
			</cfloop>
			<cfloop list="#frmActiveCols#" index="col">
				<cfif NOT listFindNoCase(oldCols, col)>
					<cfset newCols = listAppend(newCols, col)>
				</cfif>
			</cfloop>
				
			<!--- at this point frmActiveRows-Cols contains all existing active cells --->
			<!--- frmRetiredRows-Cols contains all existing retired cells --->
			<!--- and newRows-Cols contains all new cells --->
			<!--- and oldRows-Cols contains all cells that currently exist in the database --->
				
			<!--- go through and add the new cell records --->		
			<cfset rowCnt = listLen(newRows)>
			<cfset colCnt = listLen(newCols)>
			<cfset newListSum = rowCnt + colCnt>
			<cfset cnt = 1>
			<cfif newListSum GT 0>			
				<cfquery datasource="#application.applicationDataSource#" name="addCells">
					INSERT INTO tbl_forms_items_tables_cells (form_item_id, cell_text, row, retired, cell_order)
					OUTPUT inserted.form_table_cell_id
					VALUES 
					<cfloop list="#newRows#" index="row">
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">, 
						 <cfqueryparam cfsqltype="cf_sql_varchar" value="#row#">,
						 1, 
						 0,
						 <cfqueryparam cfsqltype="cf_sql_integer" value="#rowCnt#">)
						 <cfif cnt LT newListSum>,</cfif>
						 <cfset cnt = cnt + 1>
						 <cfset rowCnt = rowCnt + 1>
					</cfloop>
					<cfloop list="#newCols#" index="col">	
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">, 
						 <cfqueryparam cfsqltype="cf_sql_varchar" value="#col#">,
						 0, 
						 0,
						 <cfqueryparam cfsqltype="cf_sql_integer" value="#colCnt#">)
						<cfif cnt LT newListSum>,</cfif>
						<cfset cnt = cnt + 1>
						<cfset colCnt = colCnt + 1>
					</cfloop>
				</cfquery>				
			</cfif>
			
			<cfset retiredListSum = listLen(frmRetiredRows) + listLen(frmRetiredCols)>
			<cfset activeListSum = listLen(frmActiveRows) + listLen(frmActiveCols)>
			
			<!--- if the form hasn't been submitted to, throw out deleted cells --->
			<cfif checkSubmissions.recordCount EQ 0>
				<cfquery datasource="#application.applicationDataSource#" name="retireCells">
					DELETE FROM tbl_forms_items_tables_cells
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
						  AND ((cell_text NOT IN (<cfqueryparam value="#frmActiveRows#" cfsqltype="cf_sql_varchar" list="yes">)
						        AND row = 1)
						        OR (cell_text NOT IN (<cfqueryparam value="#frmActiveCols#" cfsqltype="cf_sql_varchar" list="yes">)
						           AND row = 0))
				</cfquery>
			</cfif>
			
			<!--- retire existing cells --->
			<cfif retiredListSum GT 0>
				<cfquery datasource="#application.applicationDataSource#" name="retireCells">
					UPDATE tbl_forms_items_tables_cells
					SET retired = 1
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
						  AND ((cell_text IN (<cfqueryparam value="#frmRetiredRows#" cfsqltype="cf_sql_varchar" list="yes">)
						        AND row = 1)
						        OR (cell_text IN (<cfqueryparam value="#frmRetiredCols#" cfsqltype="cf_sql_varchar" list="yes">)
						           AND row = 0))
				</cfquery>
			</cfif>
			<!--- activate existing cells --->
			<cfif activeListSum GT 0>
				<cfquery datasource="#application.applicationDataSource#" name="reinstateCells">
					UPDATE tbl_forms_items_tables_cells
					SET retired = 0
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
					  	  AND ((cell_text IN (<cfqueryparam value="#frmActiveRows#" cfsqltype="cf_sql_varchar" list="yes">)
					        	AND row = 1)
					       		OR (cell_text IN (<cfqueryparam value="#frmActiveCols#" cfsqltype="cf_sql_varchar" list="yes">)
					           	   AND row = 0))
				</cfquery>
			</cfif>
			
			<!--- update cell orders based on their indexes in the frmActive lists --->
			<cfset cnt = 1>
			<cfloop list="#frmActiveRows#" index="row">
				<cfquery datasource="#application.applicationDataSource#" name="updateRowOrder">
					UPDATE tbl_forms_items_tables_cells
					SET cell_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#cnt#">
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
						  AND cell_text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#row#">
						  AND row = 1
				</cfquery>
				<cfset cnt = cnt + 1>
			</cfloop>			
			<cfset cnt = 1>
			<cfloop list="#frmActiveCols#" index="col">
				<cfquery datasource="#application.applicationDataSource#" name="updateColOrder">
					UPDATE tbl_forms_items_tables_cells
					SET cell_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#cnt#">
					WHERE form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
						  AND cell_text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#col#">
						  AND row = 0
				</cfquery>
				<cfset cnt = cnt + 1>
			</cfloop>
					
		</cfif> <!--- end of type-specific stuff --->
		
		<cfif frmAction EQ "additem">
			<!--- it looks nicer if the comment box empties, so the user can add several items in a row --->
			<cflocation url="item_manager.cfm?formId=#formId#&itemType=#itemType#&message=#message#" addtoken="false">
		</cfif>
		
		<p class="ok">
			<cfoutput>#message#</cfoutput>
		</p>
			
	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</p>
	</cfcatch>
	</cftry>
	
</cfif>

<!--- It does us no good to create items if we get disconnected from the form or type somehow. --->
<!--- If that happens, send the user back to the form manager --->
<cfif formId EQ 0 OR itemType EQ 0>
	<cflocation url="form_manager.cfm" addtoken="false">
</cfif>

<!--- display secondary header --->
<cfoutput>
	<cfif itemId gt 0>	
		<h2>Edit #itemTypeText#</h2>	
	<cfelse>	
		<h2>Add #itemTypeText#</h2>	
	</cfif>
</cfoutput>

<!--- draw forms --->
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	
	<!--- keep track of our non-form values --->	
	
		<!--- keep track of our non-form inputs --->
		<cfoutput>
			<input type="hidden" name="formId" value="#formId#"> 
			<input type="hidden" name="itemId" value="#itemId#">
			<input type="hidden" name="itemType" value="#itemType#">
			<input type="hidden" name="itemTypeText" value="#itemTypeText#">
			<cfif itemId gt 0>
				<input type="hidden" name="frmAction" value="editItem">
			<cfelse>
				<input type="hidden" name="frmAction" value="addItem">
			</cfif>	
		</cfoutput>
		
		<cfquery datasource="#application.applicationDataSource#" name="checkSubmissions">
			SELECT fui.user_answer
			FROM tbl_forms_users_items fui
			WHERE fui.form_item_id = <cfqueryparam cfsqltype="integer" value="#itemId#">
		</cfquery>
		
		<cfif itemTypeText EQ "Paragraph">
		
			<label>
				<textarea name="frmItemText"><cfoutput>#htmlEditFormat(frmItemText)#</cfoutput></textarea>
			</label>
			
			<!--- replace the default textarea above with a prettier one --->
			<script type="text/javascript">
				//a custom configuration for this ckeditor textarea
				var contactNote = CKEDITOR.replace('frmItemText',{
					toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
					toolbar:  'Basic',
					height: '200px',
					width: '500px',
					removePlugins: 'contextmenu,tabletools'/*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
				});	
			</script>	
			
			<br/>
			
		<cfelseif itemTypeText EQ "Table">
		
			<!--- retrive and populate current table information --->
			<cfset getRows = getTableCells(itemId, 1, 0)>
			<cfset getCols = getTableCells(itemId, 0, 0)>
			<cfset getRetiredRows = getTableCells(itemId, 1, 1)>
			<cfset getRetiredCols = getTableCells(itemId, 0, 1)>
		
			<label>Table Name:
				<cfoutput> 
					<input type="text" name="frmItemText" value="#frmItemText#" size="30">
				</cfoutput>
			</label>
			
			<br/><br/><br/>
			
			<cfoutput>
				<table id="tableRows" class="stripe" style="padding:0px;" border="1px">
					<tr id="tableCols" class="titlerow" style="padding:5px; font-weight:normal; line-height:100%; font-size:100%;">
						<td></td>
						<!--- if no rows or columns exist, populate with frmActiveCols values (if any) ---> 
						<cfif getRows.recordCount EQ 0 AND getCols.recordCount EQ 0>
							<cfif listLen(frmActiveCols) GT 0>
								<cfset i = 1>
								<cfloop list="#frmActiveCols#" index="c">
									<td class="removable">
										<label><input type="text" name="frmActiveCols" size="10" value="#c#"></label> 
										<cfif i EQ 1>
											<span style="color:gray;">[x]</span>
										<cfelse>
											<a id="removeCol" href="##" onclick="return false;" style="color:white;">[x]</a>
										</cfif>
										<cfset i = i + 1>
									</td>
								</cfloop>
							<!--- otherwise draw the corner cell and one text-field column cell --->
							<cfelse>
								<td>
									<label><input type="text" name="frmActiveCols" size="10"></label> 
									<span style="color:gray;">[x]</span>
								</td>
							</cfif>
						<!--- draw the old columns first; do not allow text to be changed for submitted cells --->
						<cfelse>
							<cfloop query="getCols">
								<cfif checkSubmissions.recordCount GT 0>
									<td>
										<span class="text"><cfoutput>#cell_text#</cfoutput></span> 
										<a id="retireCol" href="##" onclick="return false;" style="color:white;">[x]</a>
										<input type="hidden" name="frmActiveCols" value="#cell_text#">
									</td>
								<cfelse>
									<td class="removable">
										<label><input type="text" name="frmActiveCols" size="10" value="#cell_text#"></label>
										<a id="removeCol" href="##" onclick="return false;" style="color:white;">[x]</a>
									</td>
								</cfif>
							</cfloop>
						</cfif>
					</tr>
					<!--- If no cells exist, populate with frmActiveRows values (if any) --->
					<cfif getRows.recordCount EQ 0 AND getCols.recordCount EQ 0>					
						<cfif listLen(frmActiveRows) GT 0>
							<cfset i = 1>
							<cfloop list="#frmActiveRows#" index="r">
								<tr>
									<td class="removable">
										<label><input type="text" name="frmActiveRows" size="10" value="#r#"></label> 
										<cfif i EQ 1>
											<span style="color:gray;">[x]</span>
										<cfelse>
											<a id="removeRow" href="##" onclick="return false;" style="color:white;">[x]</a>
										</cfif>
										<cfset i = i + 1>
									</td>
								</tr>
							</cfloop>
						<!--- otherwise draw one row with a blank text-field --->
						<cfelse>
							<tr>
								<td>
									<label><input type="text" name="frmActiveRows" size="10"></label>
							 		<span style="color:gray;">[x]</span>
								</td>
							</tr>
						</cfif>
					<!--- populate with existing rows; do not allow text for submitted cells to be updated --->
					<cfelse>
						<cfloop query="getRows">
							<cfif checkSubmissions.recordCount GT 0>
								<tr><td>
									<span class="text"><cfoutput>#cell_text#</cfoutput></span> 
									<a id="retireRow" href="##" onclick="return false;">[x]</a>
									<input type="hidden" name="frmActiveRows" value="#cell_text#">
								</td></tr>
							<cfelse>
								<tr class="removable"><td>
									<label><input type="text" name="frmActiveRows" size="10" value="#cell_text#"></label>
									<a id="removeRow" href="##" onclick="return false;">[x]</a>
								</td></tr>
							</cfif>
						</cfloop>
					</cfif>
				</table>
			</cfoutput>
			
			<br/>
			
			[<a id="addRow" href="##" onclick="return false;">Add Row</a>]
			[<a id="addCol" href="##" onclick="return false;">Add Column</a>]
			
			<br/><br/>

			<span class="triggerexpanded">Retired Rows</span>		
				<div>	
					<table id="retiredRows" class="stripe">			
						<cfloop query="getRetiredRows">
							<tr class="retired">
								<td class="retired"> 											
									<span class="text"><cfoutput>#cell_text#</cfoutput></span> 
									<a id="reinstateRow" href="##" onclick="return false;">[x]</a>
									<cfoutput><input type="hidden" name="frmRetiredRows" value="#cell_text#"></cfoutput>									
								</td>
							</tr>
						</cfloop>
					</table>
				</div>
			
			<br/>
					
			<span class="triggerexpanded">Retired Cols</span>		
				<div>	
					<table id="retiredCols" class="stripe">			
						<cfloop query="getRetiredCols">
							<tr class="retired">
								<td class="retired"> 											
									<span class="text"><cfoutput>#cell_text#</cfoutput></span> 
									<a id="reinstateCol" href="##" onclick="return false;">[x]</a>
									<cfoutput><input type="hidden" name="frmRetiredCols" value="#cell_text#"></cfoutput>								
								</td>
							</tr>
						</cfloop>
					</table>
				</div>
				
			<br/>
		
		<cfelse>
			
			<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">
				<cfset getActive = getOptions(0)>
				<cfset getRetired = getOptions(1)>
				<cfif itemTypeText EQ "Multiple Choice">
					<cfset inputType = "radio">
					<cfset retire = "retireOption">
				<cfelse>
					<cfset inputType = "checkbox">
					<cfset retire = "retireOptionCheck">
				</cfif>	
			</cfif>
		
			<!--- draw our pretty submission table --->
			<table id="itemOptions" class="stripe" style="padding:0px;" border="1px">
				<tr class="titlerow" style="padding:5px;">
					<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">
						<th>Label</th>
						<th>Text</th>
						<th>Answer?</th>
					</cfif>
				</tr>
				<tr>
					<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">
						<td><label for="frmItemText">Text</label></td>
					</cfif>
					
					<!--- don't allow the text of an item to be changed for input types that have already been submitted to --->
					<cfif frmItemText NEQ "" AND isInputType(itemType) AND checkSubmissions.recordCount GT 0>
						<td>
							<cfoutput>#htmlEditFormat(frmItemText)#
								<input type="hidden" name="frmItemText" value="#frmItemText#">
							</cfoutput>
						</td>
					<cfelse>
						<td><textarea name="frmItemText"><cfoutput>#htmlEditFormat(frmItemText)#</cfoutput></textarea></td>
						<!--- replace the default textarea above with a prettier one --->
						<script type="text/javascript">
							//a custom configuration for this ckeditor textarea
							var contactNote = CKEDITOR.replace('frmItemText',{
								toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar'],['Source']], /* source is included so we can use triggers in form items */
								toolbar:  'Basic',
								height: '200px',
								width: '500px',
								removePlugins: 'contextmenu,tabletools', /*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
								enterMode: CKEDITOR.ENTER_BR, /* removes p tags from input text to maintain the form formatting */
								extraAllowedContent: 'div;span(trigger)' /* allows certain html tags to make 'mores' possible in forms */
							});	
						</script>
					</cfif>
					
					<cfif itemTypeText EQ "Multiple Choice">
						<td>
							<input type="radio" name="frmItemAnswer" value="0"
						   	<cfif frmItemAnswer EQ "" OR frmItemAnswer EQ "0">checked="true"</cfif>>None
						</td>
					<cfelseif itemTypeText EQ "Multiple Check">
						<td></td>
					</cfif>
				</tr>
				
				<cfif itemTypeText EQ "Multiple Choice" OR itemTypeText EQ "Multiple Check">
				
					<!--- If we are making a new form, default to two rows (text and minimum one entry) --->
					<cfif getActive.recordCount EQ 0>
						<cfoutput>
							<tr>
								<td><label for="itemOption1">Option</label></td>
								<td><textarea id="itemOption1" name="frmItemOptioni1"></textarea>
									<input type="hidden" name="frmItemOptionIds" value="i1"></td>
								<td><input type="#inputType#" name="frmItemAnswer" value="i1"></td>
							</tr>
						</cfoutput>
					<!--- If we have options, start off with enough rows to hold them. --->
					<cfelse>
						<cfset cnt = 1>
						<cfloop query="getActive">
							<tr>
								<td> 
									<span class="tinytext">
										<cfoutput>
											<a id="#retire#" href="##" onclick="return false;">(retire)</a>
										</cfoutput>
									</span>
								</td>
								
								<cfoutput>
								
									<td class="textCell">
										<cfif checkSubmissions.recordCount GT 0>
											#option_text#
											<input type="hidden" name="frmItemOption#form_item_option_id#" value="#option_text#">
										<cfelse>
											<textarea name="frmItemOption#form_item_option_id#">#option_text#</textarea>
										</cfif>
										<input type="hidden" name="frmItemOptionIds" value="#form_item_option_id#">
									</td>
									<td><input type="#inputType#" name="frmItemAnswer" value="#form_item_option_id#"
										<cfif itemTypeText EQ "Multiple Choice">
							   				<cfif frmItemAnswer EQ form_item_option_id>checked="true"</cfif>
							   			<cfelseif itemTypeText EQ "Multiple Check">
							   				<cfif listFindNoCase(frmItemAnswer, form_item_option_id)>checked="true"></cfif>
										</cfif>
									</td>
								</cfoutput>
							</tr>
							<cfset cnt = cnt + 1>
						</cfloop>
					</cfif>
					
				</cfif>
				
			</table>
				
			<br/>	
		
			<cfif itemTypeText EQ "Multiple Choice">
			
				<!--- A button that adds a new row to the table. --->
				<a id="addOption" href="##" onclick="return false;">Add Option</a>
				<br/><br/>
				
				<span class="trigger">Retired Options</span>		
					<div>	
						<table id="retiredOptions" class="stripe">			
							<cfloop query="getRetired">
								<tr>
									<td> 
										<span class="tinytext">
											<a id="reinstateOption" href="##" onclick="return false;">(reinstate)</a></span></td>
									<td class="textCell"><cfoutput>#option_text#</cfoutput></td>
								</tr>
							</cfloop>
						</table>
					</div>
					
					<br/><br/>
			
			<cfelseif itemTypeText EQ "Multiple Check">
				
				<!--- A button that adds a new row to the table. --->
				<a id="addOptionCheck" href="##" onclick="return false;">Add Option</a>
				<br/><br/>
				
				<span class="trigger">Retired Options</span>		
					<div>	
						<table id="retiredOptions" class="stripe">			
							<cfloop query="getRetired">
								<tr>
									<td> 
										<span class="tinytext">
											<a id="reinstateOptionCheck" href="##" onclick="return false;">(reinstate)</a></span></td>
									<td class="textCell"><cfoutput>#option_text#</cfoutput></td>
								</tr>
							</cfloop>
						</table>
					</div>
					
					<br/><br/>
				
			</cfif>
			
			<br/>
		
		</cfif>
		
		<fieldset id="parentFieldset">
			<legend>Parent</legend>
			<div>
			</div>
		</fieldset>
		
		<br/>
		
		<!--- only show the retired radio buttons if we are editing --->
		<cfif itemId gt 0>
			<cfset drawRadioSelector("frmItemRetired", #frmItemRetired#, "0,1", "Yes,No", "Active?")>
		</cfif>
		
		<br/>
		
		<cfif itemId eq 0>
			<input type="submit"  value="Add Item">
		<cfelse>
			<input type="submit"  value="Edit Item">
		</cfif>
	
</form>

<!--- javascript - dynamic tables --->
<cfoutput>
	
	<script type="text/javascript">
		
		$(document).ready(function() {
			
			var optionCount = 1;
			
			$('##addOption').click(function() {
				optionCount++;
				addOption("radio", optionCount);		
			});
			$('##addOptionCheck').click(function() {
				optionCount++;
				addOption("checkbox", optionCount);
			});
			$(document).on("click", '##removeOption', (function (e) {
				var tr = $(this).closest('tr');	
				tr.fadeOut('slow', function() { tr.remove(); 
				});
			}));
			$(document).on("click", '##retireOption', (function (e) {
				var tr = $(this).closest('tr');
				retireOption(tr, "reinstateOption");
				$(this).fadeOut('slow', function() { $(this).hide(); });		
			}));
			$(document).on("click", '##retireOptionCheck', (function (e) {
				var tr = $(this).closest('tr');
				retireOption(tr, "reinstateOptionCheck");	
				$(this).fadeOut('slow', function() { $(this).hide(); });	
			}));
			$(document).on("click", '##reinstateOption', (function (e) {
				var tr = $(this).closest('tr');
				optionCount++;
				reinstateOption(tr, "radio", "retireOption", optionCount);
			}));
			$(document).on("click", '##reinstateOptionCheck', (function (e) {
				var tr = $(this).closest('tr');
				optionCount++;
				reinstateOption(tr, "checkbox", "retireOptionCheck", optionCount);
			}));
			$(document).on('click', '##addRow', (function (e) {
				var newRow = '<tr class="removable" style="font-weight:normal; line-height:100%; font-size:100%;"><td>';
				newRow += '<input type="text" name="frmActiveRows" size="10">';
				newRow += ' <a id="removeRow" href="##" onclick="return false;">[x]</a>';
				newRow += '</td></tr>';
				$(newRow).appendTo('##tableRows').hide().fadeIn('slow');
			}));
			$(document).on('click', '##removeRow', (function (e) {
				var tr = $(this).closest('tr.removable');
				tr.fadeOut('slow', function() { tr.remove();
				});
			}));
			$(document).on('click', '##addCol', (function (e) {
				var newCol = '<td class="removable"><input type="text" name="frmActiveCols" size="10">';
				newCol += ' <a id="removeCol" href="##" onclick="return false;" style="color:white;">[x]</a>';
				newCol += '</td>';
				$(newCol).appendTo('##tableCols').hide().fadeIn('slow');
			}));
			$(document).on('click', '##removeCol', (function (e) {
				var td = $(this).closest('td.removable');
				td.fadeOut('slow', function() { td.remove();
				});
			}));
			
			$(document).on('click', '##retireCol', (function (e) {
				var td = $(this).closest('td');
				var text = td.find('.text').html();
				var col = '<tr><td>';
				col += '<span class="text"><cfoutput>' + text + '</cfoutput></span>';
				col += ' <a id="reinstateCol" href="##" onclick="return false;">[x]</a>';
				col += '<input type="hidden" name="frmRetiredCols" value="' + text + '">';
				col += '</td></tr>';
				$(col).appendTo('##retiredCols').hide().fadeIn('slow');
				td.fadeOut('slow', function() { td.remove ();
				});
			}));
			$(document).on('click', '##reinstateCol', (function (e) {
				var td = $(this).closest('td');
				var tr = $(this).closest('tr');
				var text = td.find('.text').html();
				var col = '<td>';
				col += '<span class="text"><cfoutput>' + text + '</cfoutput></span>';
				col += ' <a id="retireCol" href="##" onclick="return false;" style="color:white;">[x]</a>';
				col += '<input type="hidden" name="frmActiveCols" value="' + text + '">';
				col += '</td>';
				$(col).appendTo('##tableCols').hide().fadeIn('slow');
				tr.fadeOut('slow', function() { tr.remove();
				});
			}));
			
			$(document).on('click', '##retireRow', (function (e) {
				var td = $(this).closest('td');
				var tr = $(this).closest('tr');
				var text = td.find('.text').html();
				var row = '<tr><td>';
				row += '<span class="text"><cfoutput>' + text + '</cfoutput></span>';
				row += ' <a id="reinstateRow" href="##" onclick="return false;">[x]</a>';
				row += '<input type="hidden" name="frmRetiredRows" value="' + text + '">';
				row += '</td></tr>';
				$(row).appendTo('##retiredRows').hide().fadeIn('slow');
				tr.fadeOut('slow', function() { tr.remove ();
				});
			}));
			$(document).on('click', '##reinstateRow', (function (e) {
				var td = $(this).closest('td');
				var tr = $(this).closest('tr');
				var text = td.find('.text').html();
				var row = '<tr><td>';
				row += '<span class="text"><cfoutput>' + text + '</cfoutput></span>';
				row += ' <a id="retireRow" href="##" onclick="return false;">[x]</a>';
				row += '<input type="hidden" name="frmActiveRows" value="' + text + '">';
				row += '</td></tr>';
				$(row).appendTo('##tableRows').hide().fadeIn('slow');
				tr.fadeOut('slow', function() { tr.remove();
				});
			}));
			
		});
		
		function addOption(inputType, optionCount) {
			var newOption = '<tr id="option'+optionCount+'">';
			newOption += '<td><label for="itemOption'+optionCount+'"><br/><span class="tinytext"><a id="removeOption" href="##" onclick="return false;">(remove)</a></span></label></td>';
			newOption += '<td><textarea id="itemOption'+optionCount+'" name="frmItemOptioni'+optionCount+'"></textarea>';
			newOption += '<input type="hidden" name="frmItemOptionIds" value="i'+optionCount+'"></td>';
			newOption += '<td><input type="' + inputType + '" name="frmItemAnswer" value="i'+optionCount+'"></td>';
			newOption += '</tr>';
			$(newOption).appendTo('##itemOptions').hide().fadeIn('slow');
		}
		
		function retireOption(tr, reinstate) {
			var text = $(tr).find(".textCell").text();	
			tr.fadeOut('slow', function() { tr.remove(); });
			var newOption = '<tr>';
			newOption += '<td> <span class="tinytext"><a id="' + reinstate + '" href="##" onclick="return false;">(reinstate)</a></span></td>';
			newOption += '<td class="textCell"><cfoutput>' + text + '</cfoutput></td>';
			newOption += '</tr>';
			$(newOption).appendTo('##retiredOptions').hide().fadeIn('slow');
		}
		
		function reinstateOption(tr, inputType, retire, optionCount) {
			var text = $(tr).find(".textCell").html().trim();
			tr.fadeOut('slow', function() { tr.remove(); });
			var newOption = '<tr>';
			newOption += '<td> <span class="tinytext"><a id="' + retire + '" href="##" onclick="return false;">(retire)</a></span></td>';
			newOption += '<td class="textCell"><cfoutput>' + text + '<input type="hidden" name="frmItemOptioni'+optionCount+'" value=\"' + text + '\">';
			newOption += '<input type="hidden" name="frmItemOptionIds" value="i'+optionCount+'"></cfoutput></td>';
			newOption += '<td><input type="' + inputType + '" name="frmItemAnswer" value="i'+optionCount+'"></td>';
			newOption += '</tr>';
			$(newOption).appendTo('##itemOptions').hide().fadeIn('slow');
		}
		
	</script>
	
</cfoutput>

<!--- javascript - parent / option selectors --->
<script type="text/javascript">
	$(document).ready(function(){
		var parentQuestions = new Array();
		var tempItem;
		<cfoutput query="getFormItems" group="form_item_id">
			tempItem = {
				"parentId": #form_item_id#,
				"parentText": "#jsonSanitize(item_text)#",
				"options": new Array(),
				"retired" : #item_retired#
			}
			
			<!---now fill-in options with the possible answers--->
			<cfoutput>
				tempItem.options.push(
					{
						"formItemOptionId": #form_item_option_id#,
						"optionText": "#jsonSanitize(option_text)#",
						"retired" : #option_retired#
					}
				);
			</cfoutput>
			parentQuestions.push(tempItem);		
		</cfoutput>
		//console.log(parentQuestions);
		
		//now that we've built-up our possible parent questions, use it to create a select form field
		var parentDiv = $("fieldset#parentFieldset div");
		
		//Draw the possible parent questions.
		parentDiv.html("<label>Parent Question: <select name=\"frmParentId\"><option value=\"0\">None</option></select></label><p/>");
		$(parentQuestions).each(function(n){
			var curVal = <cfoutput>#frmParentId#</cfoutput>;//this allows us to have our default value selected when the form is first drawn
			var curOption = <cfoutput>#frmParentOptionId#</cfoutput>;//this allows us to draw the parent options form with the default value selected.
			$("select[name='frmParentId']", parentDiv).append("<option value=\"" + this.parentId + "\" " + ((curVal == this.parentId) ? "selected='true'":"") + " >" + this.parentText + ((this.retired == 1) ? " (retired)":"") + "</option>");
			
			if(curVal == this.parentId)
				drawFrmParentOptions(curVal, curOption, parentQuestions, parentDiv);
		})
		
		//when the user changes the value of the form provide the options for the question.
		$(parentDiv).on("change", "select[name='frmParentId']", function(evt){
			var myVal = $(this).val();
			drawFrmParentOptions(myVal, 0, parentQuestions, parentDiv);
		})
	});
	
	function drawFrmParentOptions(curItem, curOption, parentQuestions, selector){
		//remove any existing frmParentOptionId, along with its label(which is its immediate parent)
		$("select[name='frmParentOptionId']", selector).parent().remove()
		$("select[name='frmParentOptionId']", selector).remove();
		
		//if the user has selected no parent draw a new frmParentOptionId
		if(curItem != 0)
			$(selector).append("<label>Parent Answer: <select name=\"frmParentOptionId\"></select></label>");
		
		//now, loop over the possible answers for our given question
		$(parentQuestions).each(function(n){
			if (curItem == this.parentId){
				$(this.options).each(function(i){
					console.log(this);
					$("select[name='frmParentOptionId']", selector).append("<option value=" + this.formItemOptionId + " " + ((curOption == this.formItemOptionId) ? "selected='true'":"") + " >" + this.optionText + ((this.retired == 1) ? " (retired)":"") + "</option>");
				})
			}
		})
	}
</script>

<cffunction name="getOptions">
	<cfargument name="retired" type="numeric" default="0">
	
	<cfquery datasource="#application.applicationDataSource#" name="options">
		SELECT fio.option_text, fio.form_item_option_id
		FROM tbl_forms_items_options fio
		WHERE fio.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
			  AND fio.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#retired#">
		ORDER BY fio.form_item_option_id
	</cfquery>
	
	<cfreturn options>	
	
</cffunction>

<cffunction name="getItem">
	<cfargument name="itemId" type="numeric" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getFormItem">
		SELECT a.form_id, a.item_text, a.item_type, a.item_answer, a.retired, a.parent_id, a.parent_answer
		FROM tbl_forms_items a
		WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#itemId#">
	</cfquery>	
	
	<cfreturn getFormItem>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
