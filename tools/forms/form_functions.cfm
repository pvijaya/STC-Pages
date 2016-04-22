<!--- Given an item type, returns the associated text description. --->
<cffunction name="getItemType">

	<cfargument name="itemType" type="numeric" default="0">
	
	<cfquery datasource="#application.applicationDataSource#" name="getType">
		SELECT t.type_text
		FROM tbl_forms_items_types t
		WHERE t.type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemType#">
	</cfquery>
	
	<cfreturn getType.type_text>

</cffunction>

<!--- Given an item type, returns whether the type is an input. --->
<cffunction name="isInputType">
	<cfargument name="itemType" type="numeric" default="0">
	
	<cfquery datasource="#application.applicationDataSource#" name="getType">
		SELECT fit.is_input
		FROM tbl_forms_items_types fit
		WHERE fit.type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemType#">
	</cfquery>
	
	<cfreturn getType.is_input>
	
</cffunction>

<!--- Used to draw radio selectors. --->
<cffunction name="drawRadioSelector">

	<cfargument name="varName" type="string" default="frmRadio">
	<cfargument name="varValue" type="numeric" default="0">
	<cfargument name="valList" type="string" default="">
	<cfargument name="textList" type="string" default="">
	<cfargument name="legend" type="string" default="Choose One">
	
	<cftry>
		
		<cfset len1 = listLen(valList)>
		<cfset len2 = listLen(textList)>
		
		<cfif len1 NEQ len2>
			<cfthrow message="Invalid Input" detail="List arguments must match in length.">
		</cfif>
	
		<fieldset>
			<legend><cfoutput>#legend#</cfoutput></legend>
			<cfloop from="1" to="#len1#" index="i">
				<cfset val = listGetAt(valList, i)>
				<cfset text = listGetAt(textList, i)>
				<label>
					<cfoutput>
						<input type="radio" name="#varName#" value="#val#" 
							   <cfif varValue EQ val>checked="true"</cfif>> 
							#text#
					</cfoutput>
				</label>
				<br/>
			</cfloop>
		</fieldset>
		
		<cfcatch>
			<p class="warning">
				<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
			</p>
		</cfcatch>
	
	</cftry>

</cffunction>

<!--- Draw 'Add New X' links for the form_manager corresponding to database types. --->
<cffunction name="drawItemTypeLinks">
	<cfargument name="frmFormId" type="numeric" default="0">
	<cfargument name="getInputTypes" type="boolean" default="1">
	
	<cfquery datasource="#application.applicationDataSource#" name="getTypes">
		SELECT fit.type_id, fit.type_text
		FROM tbl_forms_items_types fit
		WHERE fit.is_input = <cfqueryparam cfsqltype="cf_sql_bit" value="#getInputTypes#">
	</cfquery>
	
	<p style="padding: 0px;margin-top:0em; margin-bottom:0.5em;">
		<cfoutput>
			<cfloop query="getTypes">
				[<a href="#application.appPath#/tools/forms/item_manager.cfm?formId=#frmFormId#&itemType=#type_id#">Add New #type_text#</a>]
			</cfloop>
		</cfoutput>
	</p>
	
</cffunction>

<!--- A quicker way of checking form attributes. --->
<!--- Given an attribute name and a list of attribute IDs, --->
<!--- returns whether the attribute is present in the list. --->
<cffunction name="hasAttribute">
	<cfargument name="attributeName" type="string" default="">
	<cfargument name="attributeList" type="string" default="">
	
	<cfset var getAttribute = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getAttribute">
		SELECT a.attribute_name
		FROM tbl_attributes a
		WHERE a.attribute_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#attributeName#">
			  AND a.attribute_id IN (<cfqueryparam value="#attributeList#" cfsqltype="cf_sql_varchar" list="yes">)
	</cfquery>
	
	<cfif getAttribute.recordCount GT 0>
		<cfreturn 1>
	<cfelse>
		<cfreturn 0>
	</cfif>
	
</cffunction>

<!--- Returns the user's primary instance list --->
<cffunction name="getInstanceList">

	<cfset tempInstances = userHasInstanceList().idList><!--- returns default masks --->
	
	<!--- if the user has both IUB and IUPUI masks, use only the one corresponding the current Tetra instance --->
	<!--- this is to prevent articles from defaulting to 'IUB, IUPUI, consultant' --->
	<!--- To do this, remove all instance_ids from tempInstance that do not match the primary instance. --->
	<cfquery datasource="#application.applicationDataSource#" name="getInstanceMask">
		SELECT b.mask_id
		FROM tbl_instances a
		INNER JOIN tbl_user_masks b ON b.mask_name = a.instance_mask
		WHERE instance_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
	</cfquery>
	
	<cfloop query="getInstanceMask">
		<cfset i = listFindNoCase(tempInstances, mask_id)>
		<cfif i gt 0>
			<cfset tempInstances = listDeleteAt(tempInstances, i)>
		</cfif>
	</cfloop>
	
	<cfreturn tempInstances>

</cffunction>


<!--- given a form Id and a bit indicating rows or cols, --->
<!--- returns a query fetching the appropriate cells --->
<cffunction name="getTableCells">

	<cfargument name="form_item_id" type="numeric" default="0">
	<cfargument name="row" type="numeric" default="0">
	<cfargument name="retired" type="numeric" default="0">
	
	<cfquery datasource="#application.applicationDataSource#" name="getCells">
		SELECT fitc.form_table_cell_id, fitc.cell_text
		FROM tbl_forms_items_tables_cells fitc
		WHERE fitc.form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#form_item_id#">
			  AND fitc.retired = <cfqueryparam cfsqltype="cf_sql_integer" value="#retired#">
			  AND row = <cfqueryparam cfsqltype="cf_sql_integer" value="#row#">
	</cfquery>
		
	<cfreturn getCells>	
		
</cffunction>

<cffunction name="maxScoreQuiz">
	<cfargument name="formId" type="numeric" default="0">

	<cfif formId EQ 0>
		<cfreturn 0>
	</cfif>

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT fi.form_item_id
		FROM tbl_forms_items fi
		INNER JOIN tbl_forms_items_types fit ON fit.type_id = fi.item_type
		WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
			  AND (fit.type_text = 'Multiple Check' OR fit.type_text = 'Multiple Choice')
			  AND fi.retired = 0
	</cfquery>
	
	<cfreturn getItems.recordCount>

</cffunction>

<!--- grades a quiz --->
<cffunction name="scoreQuiz">
	<cfargument name="submissionId" type="numeric" default="0">
	<cfargument name="formId" type="numeric" default="0">
	<cfargument name="userId" type="numeric" default="0">

	<cfset score = 0>
	
	<!--- score multiple choice items --->
	<cfquery datasource="#application.applicationDataSource#" name="getCorrectItems">
		SELECT fui.user_answer
		FROM tbl_forms_users_items fui
		INNER JOIN tbl_forms_items fi ON fi.form_item_id = fui.form_item_id
		WHERE fui.user_answer = fi.item_answer
			  AND fui.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
			  AND fui.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formUserId#">
			  AND fui.submission_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#submissionId#">
			  AND fi.retired = 0 
	</cfquery>
	
	<cfset score = score + getCorrectItems.recordCount>
	
	<cfquery datasource="#application.applicationDataSource#" name="getCheckItems">
		SELECT fi.form_item_id
		FROM tbl_forms_items fi
		INNER JOIN tbl_forms_submissions fs ON fs.form_id = fi.form_id
		INNER JOIN tbl_forms_items_types fit ON fit.type_id = fi.item_type
		WHERE fi.form_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#formId#">
			  AND fs.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
			  AND fs.submission_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#submissionId#"> 
			  AND fit.type_text = 'Multiple Check'
			  AND fi.retired = 0
	</cfquery>
	
	<cfloop query="getCheckItems">
	
		<cfset correct = 1>
	
		<!--- score multiple check items --->
		<cfquery datasource="#application.applicationDataSource#" name="getAnswers">
			SELECT fia.item_answer
			FROM tbl_forms_items_answers fia
			WHERE fia.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
		</cfquery>	
		
		<cfquery datasource="#application.applicationDataSource#" name="getUserAnswers">
			SELECT fui.user_answer
			FROM tbl_forms_users_items fui
			WHERE fui.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
				  AND fui.submission_id = <cfqueryparam cfsqltype="cf_sql_int" value="#submissionId#">
		</cfquery>
		
		<cfset answers = "">
		<cfloop query="getAnswers">
			<!--- scoped to query, not variable --->
			<cfset answers = listAppend(answers, getAnswers.item_answer)>
		</cfloop>		
		
		<cfset userAnswers = "">
		<cfloop query="getUserAnswers">
			<cfset userAnswers = listAppend(userAnswers, user_answer)>
		</cfloop>
		
		<cfloop list="#answers#" index="i">
			<cfif NOT listFindNoCase(userAnswers, i)>
				<cfset correct = 0>
			</cfif>
		</cfloop>
		
		<cfloop list="#userAnswers#" index="i">
			<cfif NOT listFindNoCase(answers, i)>
				<cfset correct = 0>
			</cfif>
		</cfloop>
		
		<cfif correct EQ 1>
			<cfset score = score + 1>
		</cfif>
		
	</cfloop>
	
	<cfreturn score>

</cffunction>