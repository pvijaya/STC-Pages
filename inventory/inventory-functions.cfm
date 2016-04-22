<!--- FUNCTIONS DEFINITELY IN USE --->

<!--- draws a fieldset containing inventory info for a particular lab --->
<cffunction name="drawLabInventory">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="parentTypeId" type="numeric" default="0">
	<cfargument name="parentTypeName" type="string" default="">
	<cfargument name="allItems" type="query" default="#getAllItems()#">
	<cfargument name="allTypes" type="query" default="#getAllItemTypes()#">
	<cfargument name="formMode" type="boolean" default="false">
	<cfargument name="limitItems" type="string" default="">

	<cfset var getEmails = "">

	<cfif formMode>
		<!---fetch all emails for this lab for later use.--->
		<cfquery datasource="#application.applicationDataSource#" name="getEmails">
			SELECT ie.item_id, e.mail_name, recipient_list
			FROM tbl_inventory_site_items_emails ie
			INNER JOIN tbl_inventory_emails e ON e.mail_id = ie.mail_id
			WHERE e.active = 1
			AND ie.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
			AND ie.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
		</cfquery>
	</cfif>

	<ul class="inventory">

		<cfset var ancestorStruct = createAncestorStruct(allTypes)>

		<cfset var typeList = "">
		<cfloop query="allItems">
			<cfif lab_id EQ labId>
				<cfif limitItems EQ "" OR listFindNoCase(limitItems, item_id)>
					<cfset typeList = listAppend(typeList, item_type_id)>
					<cfset typeList = listAppend(typeList, ancestorStruct["type#item_type_id#"])>
				</cfif>
			</cfif>
		</cfloop>

		<cfloop query="allTypes">

			<cfif parentTypeId EQ parent_type_id AND listFindNoCase(typeList, item_type_id)>

				<cfset var typeId = item_type_id>

				<li><cfoutput><b>#item_type_name#</b></cfoutput></li>

				<ul class="inventory">

					<cfloop query="allItems">

						<cfif item_type_id EQ typeId AND lab_id EQ labId>

							<cfif limitItems EQ "" OR listFindNoCase(limitItems, item_id)>

								<cfset itemId = item_id>

								<cfoutput>

									<cfset var cssClass = "normal">
									<cfif quantity lte critical_level>
										<cfset cssClass = "crit">
									<cfelseif quantity lte warn_level>
										<cfset cssClass = "warn">
									</cfif>

									<cfif quantity EQ "">
										<cfset quantityVal = "n/a">
									<cfelse>
										<cfset quantityVal = quantity>
									</cfif>

									<li class="#cssClass#">

										<cfif formMode>
											<cfset mailList = "">
											<cfloop query="getEmails">
												<cfif item_id EQ itemId AND hasMasks("Admin", session.cas_uid)>
													<cfset mailList = mailList & ' <span class="btn btn-default btn-xs" disabled="disabled" title="sends mail to: #htmlEditformat(recipient_list)#"><span class="glyphicon glyphicon-envelope"></span> #mail_name#</span>'>
												</cfif>
											</cfloop>
											<cfif NOT isDefined("frmItem#item_id#")>
												<cfparam name="frmItem#item_id#" type="string" default="#quantityVal#">
											</cfif>
											<cfset val = evaluate("frmItem#item_id#")>
											<label>
												#item_name#
												<input name="frmItem#item_id#" type="text" size="3" value="#val#" class="#cssClass#" warnLevel="#warn_level#" critLevel="#critical_level#">
											</label>
											<br/><span class="tinytext">#username# #dateFormat(submitted_date, 'mmm d, yyyy')# #timeFormat(submitted_date, 'short')#</span>
											#mailList#
										<cfelse>
											#item_name#:
											#quantityVal#
											<span class="tinytext">
												#username#
												#dateFormat(submitted_date, 'mmm d, yyyy')#
												#timeFormat(submitted_date, 'short')#
											</span>
										</cfif>

									</li>

								</cfoutput>

							</cfif>

						</cfif>

					</cfloop>

					<cfset drawLabInventory(labId, item_type_id, item_type_name, allItems, allTypes, formMode, limitItems)>

				</ul>

			</cfif>

		</cfloop>

	</ul>

</cffunction>

<!--- returns a query containing all items, along with the most recent supply report data --->
<cffunction name="getAllItems">
	<cfargument name="labId" type="numeric" default="0">

	<cfset var getItems = "">

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT DISTINCT isi.item_id, isi.lab_id, ii.item_type_id, iit.parent_type_id,
			ii.item_name, isi.sort_order, ci.quantity, isi.critical_level, isi.warn_level,
			ci.submitted_date, u.username, isi.instance_id
		FROM tbl_inventory_items ii
		INNER JOIN tbl_inventory_site_items isi ON isi.item_id = ii.item_id
		INNER JOIN tbl_inventory_item_types iit ON iit.item_type_id = ii.item_type_id
		LEFT OUTER JOIN vi_current_inventory ci
			ON ci.instance_id = isi.instance_id
			AND ci.lab_id = isi.lab_id
			AND ci.item_id = ii.item_id
		LEFT OUTER JOIN tbl_users u ON u.user_id = ci.user_id
		WHERE isi.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			  <cfif labId GT 0>
			  	AND isi.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
			  </cfif>
			  AND ii.retired = 0
		ORDER BY ci.submitted_date DESC, isi.sort_order, ii.item_name
	</cfquery>

	<cfreturn getItems>

</cffunction>

<!--- returns a query containing all item types --->
<cffunction name="getAllItemTypes">

	<cfset var getItemTypes = "">

	<cfquery datasource="#application.applicationDataSource#" name="getItemTypes">
		SELECT parent_type_id, item_type_id, item_type_name
		FROM tbl_inventory_item_types
	</cfquery>

	<cfreturn getItemTypes>

</cffunction>

<!--- returns a list of all ancestor types for a given type --->
<cffunction name="getAncestorsByType">
	<cfargument name="typeId" type="numeric" required="true">
	<cfargument name="allItemTypes" type="query" default="#getAllItemTypes#">
	<cfargument name="parentIdList" type="string" default="">

	<cfset var parentIds = parentIdList>

	<cfloop query="allItemTypes">
		<cfif item_type_id EQ typeId AND NOT listFindNoCase(parentIds, parent_type_id)>
			<cfset parentIds = listAppend(parentIds, parent_type_id)>
			<cfset parentIds = getAncestorsByType(parent_type_id, allItemTypes, parentIds)>
		</cfif>
	</cfloop>

	<cfreturn parentIds>

</cffunction>

<!--- creates a struct containing the ancestors of every item type --->
<cffunction name="createAncestorStruct">
	<cfargument name="allTypes" type="query" default="#getAllItemTypes()#">

	<cfset var ancestorStruct = StructNew()>

	<cfloop query="allTypes">
		<cfif NOT StructKeyExists(ancestorStruct, "type#item_type_id#")>
			<cfset ancestorStruct["type#item_type_id#"] = getAncestorsByType(item_type_id, allTypes, "#item_type_id#")>
		</cfif>
	</cfloop>

	<cfreturn ancestorStruct>

</cffunction>

<!---returns a list of all of this type's descendants--->
<cffunction name="getAllChildTypes">
	<cfargument name="typeId" type="numeric" required="true">

	<cfset var childTypes = getChildTypes(typeId)>
	<cfset var childList = typeId><!---by default we know we must include typeId--->

	<cfloop query="childTypes">
		<cfset childList = listAppend(childList, getAllChildTypes(item_type_id))>
	</cfloop>

	<cfreturn childList>
</cffunction>

<!---draw a select box of all the type_id's.--->
<cffunction name="drawTypeSelectBox">
	<cfargument name="formElementName" default="frmTypeId"><!---name of the HTML select box we're drawing.--->
	<cfargument name="selectedType" type="numeric" default="0"><!---which item is currently selected?--->
	<cfargument name="excludeList" type="string" default=""><!---We don't want something to end-up being its own parent--->
	<cfargument name="inputId" type="string" default="">

	<select name="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>"
		    id="<cfoutput>#inputId#</cfoutput>">
		<cfif not listFind(excludeList, 0)><option value="0"><i>None</i></option></cfif>
		<cfset drawTypeSelectBoxOptions(0, 0, selectedType, excludeList)>
	</select>
</cffunction>

<cffunction name="drawItemSelectBox">
	<cfargument name="formElementName" default="frmItemId">
	<cfargument name="selectedItem" type="numeric" default="0"><!---which item is currently selected?--->
	<cfargument name="excludeList" type="string" default=""><!---we don't want items getting used more than once in a lab.--->
	<cfargument name="inputId" type="string" default="">

	<select name="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>"
	        id="<cfoutput>#inputId#</cfoutput>">
		<cfset drawItemSelectBoxOptions(0,0,selectedItem,excludeList)>
	</select>

</cffunction>

<cffunction name="drawItemSelectBoxOptions">
	<cfargument name="typeId" type="numeric" default="0">
	<cfargument name="level" type="numeric" default="0"><!---the number of levels we are deep, and thus need to indent.--->
	<cfargument name="selectedItem" type="numeric" default="0"><!---which item is currently selected?--->
	<cfargument name="excludeList" type="string" default=""><!---we don't want items getting used more than once in a lab.--->

	<cfset var childTypes = getChildTypes(typeId)>
	<cfset var typeItems = getItemsByType(typeId)>
	<cfset var indent = "&nbsp;&nbsp;"><!---add this for every "level" we are deep in the options.--->
	<cfset var indentString = ""><!---actual string of the indentation so we don't put a cfloop in a weird place.--->
	<cfset var n = ""><!---the index for our loop--->

	<cfloop from="1" to="#level#" index="n">
		<cfset indentString = indentString & indent>
	</cfloop>

	<!---first draw any child types and their items.--->
	<cfoutput query="ChildTypes">
		<optgroup label="#indentString##htmlEditFormat(item_type_name)#">
			<cfset drawItemSelectBoxOptions(item_type_id, level + 1, selectedItem, excludeList)>
		</optgroup>
	</cfoutput>

	<!---then draw the items for this type_id.--->
	<cfoutput query="typeItems">
		<option value="#item_id#" <cfif listFind(selectedItem, item_id)>selected</cfif> <cfif listFind(excludeList, item_id)>disabled</cfif>>
			#indentString##htmlEditFormat(item_name)#<cfif retired>(retired)</cfif>
		</option>
	</cfoutput>
</cffunction>

<!--- FUNCTIONS POSSIBLY IN USE --->
<cffunction name="getTypesByParent">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="allItems" type="query" default="#getAllItems()#">

	<cfset var typeList = "">

	<cfloop query="allItems">
		<cfif parentId EQ parent_type_id>
			<cfset typeList = listAppend(typeList, item_type_id)>
		</cfif>
	</cfloop>

	<cfreturn typeList>

</cffunction>

<!---takes a type_id and returns a query of all types that have type_id for a parent.--->
<cffunction name="getChildTypes">
	<cfargument name="typeId" type="numeric" default="0">

	<cfset var childTypes = "">

	<cfquery datasource="#application.applicationDataSource#" name="childTypes">
		SELECT item_type_id, item_type_name, parent_type_id
		FROM tbl_inventory_item_types
		WHERE parent_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#typeId#">
		ORDER BY item_type_name
	</cfquery>

	<cfreturn childTypes>
</cffunction>

<!---fetch all children and display them.--->
<cffunction name="drawTypesList">
	<cfargument name="typeId" type="numeric" default="0">

	<cfset var childTypes = getChildTypes(typeId)>

	<cfif childTypes.recordCount gt 0><ul></cfif>

	<cfoutput query="childTypes">
		<li>
			#item_type_name#
		</li>
		<cfset drawTypesList(item_type_id)>
	</cfoutput>

	<cfif childTypes.recordCount gt 0></ul></cfif>
</cffunction>

<!---draws the select boxes, with the proper indentation for all types in drawTypeSelectBox--->
<cffunction name="drawTypeSelectBoxOptions">
	<cfargument name="typeId" type="numeric" required="true"><!---the current type_id to draw the children of--->
	<cfargument name="level" type="numeric" required="true"><!---how many levels deep are we in, used for indentation--->
	<cfargument name="selectedType" type="numeric" default="0"><!---which item is currently selected?--->
	<cfargument name="excludeList" type="string" default=""><!---We don't want something to end-up being its own parent--->

	<cfset var childTypes = getChildTypes(typeId)>
	<cfset var n = 0><!---for looping to our indentation "level"--->
	<cfset var padding = "&nbsp;&nbsp;"><!---the characters used for each "level" of indentation.--->


	<cfoutput query="childTypes">
		<option value="#item_type_id#" <cfif item_type_id eq selectedType>selected</cfif> <cfif listFind(excludeList, item_type_id)>disabled</cfif>>
			<!---preface the name of the type with our level of indentation--->
			<cfloop from="1" to="#level#" index="n">
				#padding#
			</cfloop>
			#htmlEditFormat(item_type_name)#
		</option>
		<!---draw any of this type's childen.--->
		<cfset drawTypeSelectBoxOptions(item_type_id, level + 1, selectedType, excludeList)>
	</cfoutput>
</cffunction>

<!---returns true if the given type_id has any "items" or if any of the type_id's descendants contain items.--->
<cffunction name="hasChildItems">
	<cfargument name="typeId" type="numeric" required="true">

	<cfset var hasItems = 0>
	<cfset var childItemsQuery = "">

	<cfquery datasource="#application.applicationDataSource#" name="childItemsQuery">
		SELECT item_id
		FROM tbl_inventory_items
		WHERE retired = 0
		AND item_type_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#getAllChildTypes(typeId)#" list="true">)
	</cfquery>

	<cfif childItemsQuery.recordCount gt 0>
		<cfset hasItems = 1>
	</cfif>

	<cfreturn hasItems>
</cffunction>


<!---returns a query of all items with a given type_id--->
<cffunction name="getItemsByType" output="false">
	<cfargument name="typeId" type="numeric" default="0">

	<cfset var getItems = "">

	<cfquery datasource="#application.applicationDataSource#" name="getItems">
		SELECT item_id, item_name, retired
		FROM tbl_inventory_items
		WHERE item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#typeId#">
		ORDER BY retired ASC, item_name ASC
	</cfquery>

	<cfreturn getItems>
</cffunction>

<!---for every type_id given, return the immediate child types that have items for this lab in themselves or their descendants.--->
<cffunction name="getTypesBylabType">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="typeId" type="numeric" default="0">

	<cfset var childTypes = getChildTypes(typeId)><!---all child types for this typeId--->
	<cfset var labItemsQuery = getItemsBylab(instanceId, labId)><!---the items used by this lab--->
	<cfset var labItemTypes = ""><!---a list of the type_id's in labItemsQuery--->
	<cfset var allChildTypes = ""><!---a list of all the child types of a given type_id--->
	<cfset var validlabType = 0>
	<cfset var labChildTypes = queryNew("item_type_id, item_type_name, parent_type_id", "integer,varchar,integer")><!---this is our output query, we'll restrict it to types that have items in its descendants.--->

	<!---start by populating the labItemTypes list.--->
	<cfloop query="labItemsQuery">
		<cfif not listFind(labItemTypes, item_type_id)>
			<cfset labItemTypes = listAppend(labItemTypes, item_type_id)>
		</cfif>
	</cfloop>

	<!---Now we can loop over the childTypes and only add ones that have items for our lab.--->
	<cfloop query="childTypes">
		<cfset allChildTypes = getAllChildTypes(item_type_id)>
		<cfset validlabType = 0>
		<cfloop list="#allChildTypes#" index="n">
			<cfif listFind(labItemTypes, n)>
				<cfset validlabType = 1>
				<cfbreak><!---we've found a match, we can break out of the loop--->
			</cfif>
		</cfloop>

		<!---if we found a match append this to labChildTypes--->
		<cfif validlabType>
			<cfset queryAddRow(labChildTypes)>
			<cfset querySetCell(labChildTypes, "item_type_id", item_type_id)>
			<cfset querySetCell(labChildTypes, "item_type_name", item_type_name)>
			<cfset querySetCell(labChildTypes, "parent_type_id", parent_type_id)>
		</cfif>
	</cfloop>

	<cfreturn labChildTypes>
</cffunction>


<!---returns a query of all items associated with a lab.--->
<cffunction name="getItemsBylab">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">

	<cfset var getlabItems = "">

	<cfquery datasource="#application.applicationDataSource#" name="getlabItems">
		SELECT si.item_id, i.item_name, si.warn_level, si.critical_level, i.item_type_id, t.item_type_name, u.username, ci.submission_id, ci.quantity, ci.submitted_date
		FROM tbl_inventory_site_items si
		INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
		INNER JOIN tbl_inventory_item_types t ON t.item_type_id = i.item_type_id
		LEFT OUTER JOIN vi_current_inventory ci ON ci.instance_id =si.instance_id AND ci.lab_id = si.lab_id AND ci.item_id = si.item_id
		LEFT OUTER JOIN tbl_users u ON u.user_id = ci.user_id
		WHERE si.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND si.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
		AND i.retired = 0
		ORDER BY si.sort_order, i.item_name
	</cfquery>

	<cfreturn getlabItems>
</cffunction>

<cffunction name="drawlabItemsList">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="typeId" type="numeric" default="0">

	<cfset var childTypes = getTypesBylabType(instanceId, labId, typeId)>
	<cfset var labTypeItems = getItemsBylab(instanceId, labId)>

	<!---draw the child types as their own lists, and then draw the items as list-items--->
	<ul>
	<cfoutput query="childTypes">
		<li>#item_type_name#</li>
		<cfset drawlabItemsList(instanceId, labId, item_type_id)>
	</cfoutput>

	<!---now draw the individulat items--->
	<cfloop query="labTypeItems">
		<cfif item_type_id eq typeId>
			<cfoutput><li>#item_name#</li></cfoutput>
		</cfif>
	</cfloop>
	</ul>
</cffunction>
<!--- take and item id and draw all the item types above it.--->
<cffunction name="getFullItemName">
	<cfargument name="itemId" type="numeric" required="true">

	<cfset var getItemType = "">
	<cfset var fullItemName = "">
	<cfset var tempName = "">

	<!---first find the item's type_id.--->
	<cfquery datasource="#application.applicationDataSource#" name="getItemType">
		SELECT it.item_type_name, i.item_name, it.parent_type_id
		FROM tbl_inventory_items i
		INNER JOIN tbl_inventory_item_types it ON it.item_type_id = i.item_type_id
		WHERE i.item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
	</cfquery>

	<cfloop query="getItemType">
		<cfset fullItemName = "#item_type_name#, #item_name#">
		<cfset tempName = getParentItemName(parent_type_id)>
		<cfif tempName neq "">
			<cfset fullItemName = tempName & ", " & fullItemName>
		</cfif>
	</cfloop>

	<cfreturn fullItemName>
</cffunction>

<!---helper function for getFullItemName--->
<cffunction name="getParentItemName">
	<cfargument name="parentId" type="numeric" required="true">

	<cfset var getParent = "">
	<cfset var fullParentName = "">
	<cfset var tempName = "">

	<cfquery datasource="#application.applicationDataSource#" name="getParent">
		SELECT item_type_name, parent_type_id
		FROM tbl_inventory_item_types
		WHERE item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentId#">
	</cfquery>

	<cfloop query="getParent">
		<cfset fullParentName = item_type_name>
		<cfset tempName = getParentItemName(parent_type_id)>
		<cfif tempName neq "">
			<cfset fullParentName = tempName & ", " & fullParentName>
		</cfif>

	</cfloop>

	<cfreturn fullParentName>
</cffunction>

<!---functions used for submission/display of current inventory levels.--->
<cffunction name="drawListItems">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="itemsList" type="string" required="true">
	<cfargument name="typesList" type="string" required="true">
	<cfargument name="parentTypeId" type="numeric" required="true">
	<cfargument name="readOnly" type="Boolean" default="true">

	<cfset var childTypes = ""><!---a query of all child types for this type_id--->
	<cfset var labItems = ""><!---a query of items for this type in this lab.--->

	<cfset var curVal = ""><!---a holder for any user input for each item we draw.--->
	<cfset var getEmails = ""><!---a query of all emails for this lab, lets us mark which items generate email.--->
	<cfset var getItemEmails = ""><!---a query of queries used to see if a particular lab has email(s) associated with it.--->
	<cfset var mailList = ""><!---the mails that an item will send.--->

	<!---fetch the child types--->
	<cfquery datasource="#application.applicationDataSource#" name="childTypes">
		SELECT item_type_id, item_type_name, parent_type_id
		FROM tbl_inventory_item_types
		WHERE parent_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentTypeId#">
		AND item_type_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#typesList#" list="true">)
		ORDER BY item_type_name
	</cfquery>

	<!---fetch the items, and their current levels, for the current parentTypeId--->
	<cfquery datasource="#application.applicationDataSource#" name="labItems">
		SELECT si.item_id, i.item_name, si.warn_level, si.critical_level, si.sort_order, ci.submission_id, ci.submitted_date,
			CASE
				WHEN u.username IS NULL THEN 'none'
				ELSE u.username
			END AS username,
			CASE
				WHEN ci.quantity IS NULL THEN 0
				ELSE ci.quantity
			END AS quantity
		FROM tbl_inventory_site_items si
		INNER JOIN tbl_inventory_items i ON i.item_id = si.item_id
		LEFT OUTER JOIN vi_current_inventory ci
			ON ci.instance_id = si.instance_id
			AND ci.lab_id = si.lab_id
			AND ci.item_id = i.item_id
		LEFT OUTER JOIN tbl_users u ON u.user_id = ci.user_id
		WHERE si.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND si.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
		AND i.retired = 0
		AND i.item_type_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentTypeId#">
		AND i.item_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#itemsList#" list="true">)/*restrict the items we draw based on itemsList*/
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
	<!---display our types and items for parentTypeId--->
	<ul class="inventory">
	<cfoutput query="childTypes">
		<li><b>#item_type_name#</b></li>
		<!---now use recursion to display child types.--->
		<cfset drawListItems(instanceId, labId, itemsList, typesList, item_type_id, readOnly)>
	</cfoutput>

	<!---now draw the actual items for this type and lab.--->
	<cfoutput query="labItems">
		<!---use user input if it's available instead of the value from the database.--->
		<cfset curVal = quantity>
		<cfset curVal = iif(isDefined("url.frmItem#item_id#"), "url.frmItem#item_id#", curval)>
		<cfset curVal = iif(isDefined("form.frmItem#item_id#"), "form.frmItem#item_id#", curval)>

		<!---make sure we have the correct css class set based upon warn and crit levels.--->
		<cfset cssClass = "normal">
		<cfif curVal lte critical_level>
			<cfset cssClass = "crit">
		<cfelseif curVal lte warn_level>
			<cfset cssClass = "warn">
		</cfif>

		<!---now see if this item generates an email.--->
		<cfset mailList = "">
		<cfquery dbtype="query" name="getItemEmails">
			SELECT item_id, mail_name, recipient_list
			FROM getEmails
			WHERE item_id = #labItems.item_id#
		</cfquery>
		<cfloop query="getItemEmails">
			<cfset mailList = mailList & ' <span class="btn btn-default btn-xs" disabled="disabled" title="sends mail to: #htmlEditformat(recipient_list)#"><span class="glyphicon glyphicon-envelope"></span> #mail_name#</span>'>
		</cfloop>
		<cfif readOnly>
			<li class="#cssClass#">
				#item_name#:
				#curVal#
				<span class="tinytext">#username# #dateFormat(submitted_date, 'mmm d, yyyy')# #timeFormat(submitted_date, 'short')#</span>
			</li>
		<cfelse>
			<li>
				<label>
					#item_name#
					<input name="frmItem#item_id#" type="text" size="3" value="#curval#" class="#cssClass#" warnLevel="#warn_level#" critLevel="#critical_level#">
				</label>
				<br/><span class="tinytext">#username# #dateFormat(submitted_date, 'mmm d, yyyy')# #timeFormat(submitted_date, 'short')#</span>
				#mailList#
			</li>
		</cfif>

	</cfoutput>

	</ul>
</cffunction>

<cffunction name="getItemsListBylab">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="labId" type="numeric" required="true">
	<cfargument name="allItems" type="query" default="#getAllItems()#">

	<cfset var getItems = "">
	<cfset var itemList = "">

	<cfloop query="allItems">
		<cfif lab_id EQ labId AND instance_id EQ instanceId>
			<cfset itemList = listAppend(itemList, item_id)>
		</cfif>
	</cfloop>

	<cfreturn itemList>

</cffunction>

<cffunction name="getAncestorTypesByItemId">
	<cfargument name="itemId" type="numeric" required="true">
	<cfargument name="allItems" type="query" default="#getAllItems()#">
	<cfargument name="allItemTypes" type="query" default="#getAllItemTypes()#">

	<cfset var parentIds = "">

	<cfloop query="allItems">
		<cfif item_id EQ itemId AND NOT listFindNoCase(parentIds, item_type_id)>
			<cfset parentIds = getAncestorsByType(item_type_id, allItemTypes, parentIds)>
		</cfif>
	</cfloop>

	<cfreturn parentIds>

</cffunction>
