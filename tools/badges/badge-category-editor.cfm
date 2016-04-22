<cfmodule template="#application.appPath#/header.cfm" title='Badge Category Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Badge Editor">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="instanceId" type="integer" default="#Session.primary_instance#">
<cfparam name="categoryId" type="integer" default="#Session.primary_instance#">
<cfparam name="categoryName" type="string" default="0">
<cfparam name="categoryDescription" type="string" default="0">
<cfparam name="action" type="string" default="-1">
<cfparam name="getInfo" type="string" default="">

<!---now find the details of the current instance based on instanceId--->
<cfset myInstance = getInstanceById(instanceId)>

<!--- Header / Navigation --->
<cfoutput>
	<h1>Assign Achievement Badges (#myInstance.instance_name#)</h1>
	<cfinclude template="#application.appPath#/tools/badges/secondary-navigation.cfm">
</cfoutput>

<!--- Queries --->
<cffunction name="getBadgeCategoriesFunction">
	<cfquery datasource="#application.applicationDataSource#" name="badgeCategories">
		SELECT c.category_id, c.name 
		FROM tbl_badges_categories c
		WHERE c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND c.active = 1
	</cfquery>
	<cfreturn badgeCategories>
</cffunction>


<cffunction name="getCategoryDetails">
	<cfargument name="categoryId" type="numeric">
	<cfquery datasource="#application.applicationDataSource#" name="getBadgeCategoryDetails">
		SELECT c.category_id, c.name, c.description
		FROM tbl_badges_categories c
		WHERE c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND c.category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#categoryId#">
		AND c.active = 1
	</cfquery>
	<cfreturn getBadgeCategoryDetails>
</cffunction>

<cfif action EQ "Create">
	<cfif categoryName NEQ "" AND categoryDescription NEQ "">
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="insertBadgeCategory">
				INSERT INTO tbl_badges_categories(name, description, instance_id)
				VALUES(<cfqueryparam cfsqltype="cf_sql_varchar" value="#categoryName#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#categoryDescription#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">)
			</cfquery>
				<p class="ok">
					<b>Success</b>
					Category inserted!
				</p>
			<cfcatch>
				<cfoutput>
				<p class="warning">
					<b>Error</b>
					#cfcatch.message# - #cfcatch.Detail#
				</p>
				</cfoutput>
			</cfcatch>
		</cftry>
	<cfelse>
		<p class="warning">
			<b>Error</b>
			Please be sure to enter a name and description for the category.
		</p>
	</cfif>
<cfelseif action EQ "Edit">
	<cfif categoryId NEQ 0 AND categoryName NEQ "" AND categoryDescription NEQ "" >
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="insertBadgeCategory">
				UPDATE tbl_badges_categories
				SET name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#categoryName#">, 
				description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#categoryDescription#">, 
				instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
				WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#categoryId#">
			</cfquery>
				<p class="ok">
					<b>Success</b>
					Category edited!
				</p>
			<cfcatch>
				<cfoutput>
				<p class="warning">
					<b>Error</b>
					#cfcatch.message# - #cfcatch.Detail#
				</p>
				</cfoutput>
			</cfcatch>
		</cftry>
	<cfelse>
		<p class="warning">
			<b>Error</b>
			Please be sure to enter a name and description for the category.
		</p>
	</cfif>
<cfelseif action EQ "Delete">
	<cfif categoryId NEQ 0>
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="insertBadgeCategory">
				UPDATE  tbl_badges_categories
				SET active = 0
				WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#categoryId#">
			</cfquery>
			<p class="ok">
				<b>Success</b>
				Category deleted!
			</p>
			
			<cfcatch>
				<cfoutput>
				<p class="warning">
					<b>Error</b>
					#cfcatch.message# - #cfcatch.Detail#
				</p>
				</cfoutput>
			</cfcatch>
		</cftry>	
	</cfif>
</cfif>

<cfset getBadgeCategories = getBadgeCategoriesFunction()>
<!---In the selectbox, if they change the value, we retrieve the info for it--->
<cfif getInfo EQ "Edit">
	<cfset categoryInfo = getCategoryDetails(categoryId)>
	<cfloop query="categoryInfo">
		<cfset categoryId = categoryInfo.category_id>
		<cfset categoryName = categoryInfo.name>
		<cfset categoryDescription = categoryInfo.description>
	</cfloop>
</cfif>

<cfoutput>
	<fieldset style="width:29%;display:inline-block;vertical-align:top;">			
		<legend>Create Category</legend>
		<form action="#cgi.script_name#" method="POST">
			<input type="hidden" name="instanceId" value="#instanceId#">
			<label for="categoryName">Name:</label>
			<input type="text" id="categoryName" name="categoryName" value="<cfif action EQ "Create"><cfoutput>#categoryName#</cfoutput></cfif>">
			<br/><br/>
			<label for="categoryDescription">Description:</label>
			<textarea id="categoryDescription" name="categoryDescription"><cfif action EQ "Create"><cfoutput>#categoryDescription#</cfoutput></cfif></textarea>
			<br/><br/>
			<input type="submit"  name="action" value="Create">
		</form>
	</fieldset>
	<fieldset style="width:29%;display:inline-block;vertical-align:top;">			
		<legend>Edit Category</legend>
		<form action="#cgi.script_name#" method="POST">
			<input type="hidden" name="getInfo" value="Edit">
			<input type="hidden" name="instanceSelected" value="#instanceId#">
				
			<label for="categoryId">Select Category:</label>
			<select id="categoryId"  name="categoryId" onchange="this.form.submit();">
				<option value="0">Select Category</option>
				<cfloop query="getBadgeCategories">
					<option <cfif getInfo EQ "Edit" && categoryId EQ getBadgeCategories.category_id>selected="selected"</cfif> value="#getBadgeCategories.category_id#">#getBadgeCategories.name#</option>
				</cfloop>
			</select>
			<br/><br/>
			<input type="hidden" name="instanceId" value="#instanceId#">
			<label for="categoryName">Name:</label>
			
			<input type="text" id="categoryName" name="categoryName" value="<cfif getInfo EQ 'Edit'><cfoutput>#categoryName#</cfoutput></cfif>">
			<br/><br/>
			<label for="categoryDescription">Description:</label>
			<textarea id="categoryDescription" name="categoryDescription"><cfif getInfo EQ "Edit"><cfoutput>#categoryDescription#</cfoutput></cfif></textarea>
			<br/><br/>
			<input type="submit"  name="action" value="Edit">
		</form>
	</fieldset>
	<fieldset style="width:29%;display:inline-block;vertical-align:top;">			
		<legend>Delete Category</legend>
		<form action="#cgi.script_name#" method="POST">
			<select id="categoryId"  name="categoryId" >
				<option value="0">Select Category</option>
				<cfloop query="getBadgeCategories">
					<option value="#getBadgeCategories.category_id#">#getBadgeCategories.name#</option>
				</cfloop>
			</select>
			<br/><br/>
			<input type="submit"  name="action" value="Delete">
		</form>
	</fieldset>
</cfoutput>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>