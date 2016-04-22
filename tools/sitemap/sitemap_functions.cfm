<cffunction name="getSMCategories">
	<cfargument name="includeRetired" type="boolean" default="1">

	<cfset var getCategories = "">
	<cfquery datasource="#application.applicationDataSource#" name="getCategories">
		SELECT category_id, text, link, parent, sort_order, retired
		FROM tbl_header_categories
		WHERE 1 = 1
		<cfif not includeRetired>
			AND retired = 0
		</cfif>
		ORDER BY sort_order, text
	</cfquery>

	<cfreturn getCategories>
</cffunction>

<cffunction name="getSMcategoriesArray">
	<cfargument name="allCats" type="query" default="#getSMCategories(0)#">
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
		<cfif parent eq parentId>
			<cfset myObj = structNew()>
			<cfset myObj["name"] = text>
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
			<cfset childArray = getSMcategoriesArray(allCats, category_id, indentLevel + 1)>
			<cfloop from="1" to="#arrayLen(childArray)#" index="i">
				<cfset ArrayAppend(myArray, childArray[i])>
			</cfloop>

		</cfif>
	</cfloop>

	<cfreturn myArray>
</cffunction>

<cffunction name="getSMLinks">
	<cfargument name="includeRetired" type="numeric" default="0"> <!---0 no retired folks, 1, include retired folks, 3 ONLY retired folks--->
	<cfargument name="maskList" type="string" default="">

	<cfset var getLinks = "">

	<cfquery datasource="#application.applicationDataSource#" name="getLinks">
		SELECT hl.link_id, hl.text, hl.link, hl.parent, hl.new_window, hl.sort_order, hlmo.mask_name
		FROM tbl_header_links hl
		LEFT OUTER JOIN tbl_header_links_masks hlm ON hlm.link_id = hl.link_id
		LEFT OUTER JOIN tbl_user_masks hlmo ON hlmo.mask_id = hlm.mask_id
		WHERE NOT EXISTS (
			SELECT mask_id
			FROM tbl_header_links_masks hlm
			WHERE link_id = hl.link_id
			 	  AND mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#maskList#" list="true">)
		  )
		<cfif includeRetired eq 0>
			AND hl.retired = 0
		<cfelseif includeRetired gt 1>
			AND hl.retired = 1
		</cfif>
		ORDER BY hl.sort_order, hl.parent, hl.text, hl.link_id
	</cfquery>

	<cfreturn getLinks>
</cffunction>

<cffunction name="drawSMCategorySelect">
	<cfargument name="fieldName" type="string" required="true">
	<cfargument name="curVal" type="numeric" default="0">
	<cfargument name="disabledValue" type="numeric" default="-1">
	<cfargument name="getCategories" type="query" default="#getSMCategories(0)#">

	<cfoutput>
		<select name="#htmlEditFormat(fieldName)#" >
			<option value="0" style="font-style: italic;" <cfif disabledValue eq 0>disabled="true"</cfif>>No Parent</option>
			<cfset drawSMCategoryOptions(0, curVal, disabledValue, 0, getCategories)>
		</select>
	</cfoutput>
</cffunction>

<cffunction name="drawSMCategoryOptions">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="curVal" type="numeric" default="0">
	<cfargument name="disabledValue" type="numeric" default="-1">
	<cfargument name="indentLevel" type="numeric" default="0">
	<cfargument name="getCategories" type="query" default="#getSMCategories(0)#">

	<cfset var indentString = "">
	<cfset var i = "">
	<cfloop from="1" to="#indentLevel#" index="i">
		<cfset indentString = indentString & "&nbsp;&nbsp;">
	</cfloop>

	<!---draw the current value, indented the correct ammount, then draw its children.--->
	<cfloop query="getCategories"><!---defined at the top of this page--->
		<cfif parent eq parentId>
			<cfoutput>
				<option value="#category_id#" <cfif category_id eq curVal>selected="true"</cfif> <cfif category_id eq disabledValue OR (disabledValue gt 0 AND parent eq disabledValue)>disabled="true"</cfif>>
					#indentString#
					#text#
				</option>
			</cfoutput>
			<!---now we need to draw any of this categories children, but if this value was disabled, so must all of its children.  It prevents items from becoming their own parents.--->
			<cfif category_id eq disabledValue>
				<cfset drawSMCategoryOptions(category_id, curVal, category_id, indentLevel + 1, getCategories)>
			<cfelse>
				<cfset drawSMCategoryOptions(category_id, curVal, disabledValue, indentLevel + 1, getCategories)>
			</cfif>
		</cfif>
	</cfloop>
</cffunction>

<cffunction name="recordCategoryUpdate">
	<cfargument name="catId" type="numeric">
	<cfargument name="auditText" type="string">
	<cfquery datasource="#application.applicationDataSource#" name="insertCategoryUpdate">
	INSERT INTO tbl_header_categories_audit(user_id, category_id, audit_text)
	VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
		<cfqueryparam cfsqltype="cf_sql_integer" value="#catId#">,
		<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
		)
	</cfquery>
</cffunction>

<cffunction name="recordLinkUpdate">
	<cfargument name="linkId" type="numeric">
	<cfargument name="auditText" type="string">
	<cfquery datasource="#application.applicationDataSource#" name="insertCategoryUpdate">
	INSERT INTO tbl_header_links_audit(user_id, link_id, audit_text)
	VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
		<cfqueryparam cfsqltype="cf_sql_integer" value="#linkId#">,
		<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
		)
	</cfquery>
</cffunction>