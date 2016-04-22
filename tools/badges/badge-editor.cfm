<cfmodule template="#application.appPath#/header.cfm" title='Badge Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Badge Editor">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="instanceSelected" type="integer" default="#Session.primary_instance#">
<cfparam name="badgeId" type="integer" default="0">
<cfparam name="badgeName" type="string" default="">
<cfparam name="badgeCategory" type="integer" default="0">
<cfparam name="badgeDescription" type="string" default="">
<cfparam name="badgeAssignType" type="string" default="">
<cfparam name="badgeUrl" type="string" default="">
<cfparam name="action" type="string" default="">
<cfparam name="getInfo" type="string" default="">
<cfparam name="sendEmail" type="integer" default="0">

<!---now find the details of the current instance based on instanceId--->
<cfset myInstance = getInstanceById(instanceSelected)>

<!--- Header / Navigation --->
<cfoutput>
	<h1>Achievement Badge Editor (#myInstance.instance_name#)</h1> 
	<cfinclude template="#application.appPath#/tools/badges/secondary-navigation.cfm">
</cfoutput>

<!---Functions--->
<cffunction name="countBadgeNameDuplicates">
	<cfargument name="badgeName" type="string">
	<cfquery datasource="#application.applicationDataSource#" name="countBadgeNameDuplicates">
		SELECT count(badge_name) AS "duplicates"
		FROM tbl_badges
		WHERE badge_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#badgeName#">
		AND active = 1
		AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	<cfreturn countBadgeNameDuplicates.duplicates>
</cffunction>

<cffunction name="getBadgeNameById">
	<cfargument name="badgeId" type="numeric">
	<cfquery datasource="#application.applicationDataSource#" name="getBadgeName">
		SELECT badge_name
		FROM tbl_badges
		WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#badgeId#">
		AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	<cfreturn getBadgeName.badge_name>
</cffunction>

<cffunction name="getBadgeInfo">
	<cfargument name="badgeId" type="numeric">
	<cfquery datasource="#application.applicationDataSource#" name="badgeInfo">
		SELECT TOP  1 b.*, m.category_id
		FROM tbl_badges b
		INNER JOIN tbl_badges_categories_match m ON m.badge_id = b.badge_id
		WHERE b.badge_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#badgeId#">
		AND b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	<cfreturn badgeInfo>
</cffunction>

<cffunction name="getBadgeCategory">
	<cfargument name="badgeId" type="numeric">
	<cfquery datasource="#application.applicationDataSource#" name="badgeCategoryQuery">
		SELECT TOP  1 m.category_id
		FROM tbl_badges b
		INNER JOIN tbl_badges_categories_match m ON m.badge_id = b.badge_id
		WHERE b.badge_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#badgeId#">
		AND b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	<cfif badgeCategoryQuery.recordCount EQ 1>
		<cfreturn badgeCategoryQuery.category_id>
	<cfelse>
		<cfreturn 0>
	</cfif>
</cffunction>

<cffunction name="deleteBadgeCategoryMatch">
	<cfargument name="badgeId" type="numeric">
	<cfargument name="categoryId" type="numeric">
	<cfquery name='updateBadge' datasource="#application.applicationdatasource#" >
		DELETE tbl_badges_categories_match
		WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#badgeId#">
		AND category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#categoryId#">
	</cfquery>
</cffunction>

<cffunction name="insertBadgeCategoryMatch">
	<cfargument name="badgeId" type="numeric">
	<cfargument name="categoryId" type="numeric">
	<cfquery name='updateBadge' datasource="#application.applicationdatasource#" >
		INSERT INTO  tbl_badges_categories_match(category_id, badge_id)
		VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#categoryId#">,
		<cfqueryparam cfsqltype="cf_sql_integer" value="#badgeId#">)
	</cfquery>
</cffunction>
						

<cfquery datasource="#application.applicationDataSource#" name="getBadgeCategories">
	SELECT c.category_id, c.name
	FROM tbl_badges_categories c
	WHERE active = 1
	AND c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
</cfquery>

<!---Once we have the instance--->
<cfif instanceSelected NEQ 0>
	<cfif action EQ "Create">
		<cfif badgeName NEQ "" AND badgeDescription NEQ "" && badgeCategory NEQ 0 && badgeAssignType NEQ "">
			<cfif countBadgeNameDuplicates(badgeName) EQ 0>
				<cftry>
 					<cfquery name='insertBadge' datasource="#application.applicationdatasource#" >
						INSERT INTO tbl_badges(badge_name, description, active, instance_id,image_url,send_email, assigned_by)
						OUTPUT inserted.badge_id AS return_badge_id
						VALUES (<cfqueryparam cfsqltype="cf_sql_string" value="#badgeName#">,
								<cfqueryparam cfsqltype="cf_sql_string" value="#badgeDescription#">,1,
								<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">,
								<cfqueryparam cfsqltype="cf_sql_string" value="#badgeUrl#">,
								<cfqueryparam cfsqltype="cf_sql_bit" value="#sendEmail#">,
								<cfqueryparam cfsqltype="cf_sql_string" value="#badgeAssignType#">)
					</cfquery>
					<cfset badgeId = insertBadge.return_badge_id>
					<cfset insertBadgeCategoryMatch(badgeId,badgeCategory)>			 
					<cfset badgeName = "">
					<cfset badgeDescription = "">
					<cfset badgeUrl = "">
					<p class="ok">
						<b>Success</b>
						Badge inserted!
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
					A badge with that name already exists!
				</p>
			</cfif>
		<cfelse>
			<p class="warning">
				<b>Error</b>
				Please fill in the badge's name, category, description, assigning group, and picture source to create a new badge.
			</p>
		</cfif>
	<cfelseif action EQ "Edit">
		<cfif badgeId NEQ 0 AND badgeName NEQ "" AND badgeDescription NEQ "" && badgeAssignType NEQ "">
			<cfif countBadgeNameDuplicates(badgeName) EQ 0 OR getBadgeNameById(badgeId) EQ badgeName>
				<cftry>
					<cfif badgeCategory NEQ 0>
						<cfquery name='updateBadge' datasource="#application.applicationdatasource#" >
							UPDATE tbl_badges
							SET badge_name = <cfqueryparam cfsqltype="cf_sql_string" value="#badgeName#">, 
							description = <cfqueryparam cfsqltype="cf_sql_string" value="#badgeDescription#">,
							image_url = <cfqueryparam cfsqltype="cf_sql_string" value="#badgeUrl#">,
							send_email = <cfqueryparam cfsqltype="cf_sql_bit" value="#sendEmail#">,
							assigned_by = <cfqueryparam cfsqltype="cf_sql_string" value="#badgeAssignType#">
							WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#badgeId#">
						</cfquery>
						<cfset oldCategoryId = getBadgeCategory(badgeId)>
						<cfif badgeCategory NEQ oldCategoryId>
							<!---remove old category match--->
							<cfset deleteBadgeCategoryMatch(badgeId,oldCategoryId)>
							<cfset insertBadgeCategoryMatch(badgeId,badgeCategory)>
						</cfif>
						<p class="ok">
							<b>Success</b>
							Badge inserted!
						</p>
					<cfelse>
						<cfoutput>
						<p class="warning">
						<b>Error</b>
						Please select a category for the badge.
						</p>
						</cfoutput>
					</cfif>
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
					A badge with that name already exists!
				</p>
			</cfif>
		<cfelse>
			<p class="warning">
				<b>Error</b>
				Please select the badge's name then fill in the badge's name, description, assigning group, and picture source to edit a badge.
			</p>
		</cfif>
	<cfelseif action EQ "Delete">
		<cfif badgeId NEQ 0>
		<cftry>
			<cfset oldCategoryId = getBadgeCategory(badgeId)>
			<cfset deleteBadgeCategoryMatch(badgeId,oldCategoryId)>
			<cfquery name='deleteBadge' datasource="#application.applicationdatasource#" >
				UPDATE tbl_badges
				SET active = 0
				WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#badgeId#">
			</cfquery>
			<p class="ok">
				<b>Success</b>
				Badge deleted!
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
				Please select the badge's name then click Delete to delete a badge.
			</p>
		</cfif>
	</cfif>
	
	<!---In the selectbox, if they change the value, we retrieve the info for it--->
	<cfif getInfo EQ "Edit" OR getInfo EQ "Delete">
		<cfset badgeInfo = getBadgeInfo(badgeId)>
		<cfloop query="badgeInfo">
			<cfset badgeId = badgeInfo.badge_id>
			<cfset badgeName = badgeInfo.badge_name>
			<cfset badgeDescription = badgeInfo.description>
			<cfset badgeUrl = badgeInfo.image_url>
			<cfset sendEmail = badgeInfo.send_email>
			<cfset categoryId = badgeInfo.category_id>
			<cfset badgeAssignType = badgeInfo.assigned_by>
		</cfloop>
	</cfif>
	
	<!---Queries--->
	<cfquery datasource="#application.applicationDataSource#" name="getBadges">
		SELECT * 
		FROM tbl_badges
		WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
		AND active = 1
		ORDER BY badge_name
	</cfquery>
	<!---HTML--->
	<cfoutput>
	<fieldset style="width:29%;display:inline-block;vertical-align:top;">
	<legend>Create Badge</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">
		<label for="createBadgeNameId">Name:</label>
			<input id="createBadgeNameId" type="text" value="<cfif action EQ "Create"><cfoutput>#badgeName#</cfoutput></cfif>"  name="badgeName">
		<br/><br/>
		<label for="badgeCategory">Category:</label>
			<select name="badgeCategory" name="badgeCategory">
				<option value="1">Select Category</option>
				<cfloop query="getBadgeCategories">
					<option <cfif badgeCategory EQ getBadgeCategories.category_id>selected="selected"</cfif> value="#getBadgeCategories.category_id#">#getBadgeCategories.name#</option>
				</cfloop>
			</select>
		<br/><br/>
		<label for="createBadgeDescriptionId">Description:</label>
			<textarea id="createBadgeDescriptionId" name="badgeDescription"><cfif action EQ "Create"><cfoutput>#badgeDescription#</cfoutput></cfif></textarea>
		<br/><br/>
		
		<label for="createBadgeUrlId">Image Url:</label>
		<input id="createBadgeUrlId" type="text" name="badgeUrl" value="<cfif action EQ "Create"><cfoutput>#badgeUrl#</cfoutput></cfif>">
		<br/><br/>
		<label for="badgeAssignType">Assigned By:</label>
		<select id="badgeAssignType"  name="badgeAssignType">
			<option value="">Select Assigning Group</option>
			<option value="Consultant Supervisors">Consultant Supervisors</option>
			<option value="Admin">Admin</option>
			<option value="Automation">Automation</option>
		</select>
		<br/><br/>
		<label for="sendEmailId">Sends Email</label>
		<input id="sendEmailId" type="checkbox" name="sendEmail" <cfif action EQ "Create" AND sendEmail EQ 1>checked</cfif> value="1">
		<br/><br/>
		<input type="submit"  name="action" value="Create">
	</form>
	</fieldset>
	
	<fieldset style="width:29%;display:inline-block;vertical-align:top;">
	<legend>Edit Badge</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="getInfo" value="Edit">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">
		<label for="editSelectBadgeId">Select Badge:</label>
		<select id="editSelectBadgeId"  name="badgeId" onchange="this.form.submit();">
			<option value="0">Select Badge</option>
		<cfloop query="getBadges">
			<cfif getInfo EQ "Edit" AND getBadges.badge_name EQ badgeName>
				<option value="#badge_id#" selected="selected">#badge_name#</option>
			<cfelse>
				<option value="#badge_id#">#badge_name#</option>
			</cfif>
		</cfloop>
		</select>
		<br/><br/>
		<label for="editBadgeNameId">Name:</label> 
		<input id="editBadgeNameId" type="text" value="<cfif getInfo EQ "Edit"><cfoutput>#badgeName#</cfoutput></cfif>"  name="badgeName">
		<br/><br/>
		<label for="badgeCategory">Category:</label>
		
		<select name="badgeCategory" name="badgeCategory">
			<option value="1">Select Category</option>
			<cfloop query="getBadgeCategories">
				<option <cfif getInfo EQ "Edit" AND categoryId EQ getBadgeCategories.category_id>selected="selected"</cfif> value="#getBadgeCategories.category_id#">#getBadgeCategories.name#</option>
			</cfloop>
		</select>
		<br/><br/>
		<label for="editBadgeDescriptionId">Description:</label>
			<textarea id="editBadgeDescriptionId" name="badgeDescription"><cfif getInfo EQ "Edit"><cfoutput>#badgeDescription#</cfoutput></cfif></textarea>
		<br/><br/>
		<label for="editBadgeUrlId">Image Url:</label>
		<input id="editBadgeUrlId" type="text" name="badgeUrl" value="<cfif getInfo EQ "Edit"><cfoutput>#badgeUrl#</cfoutput></cfif>">
		<br/><br/>
		<label for="sendEmailId">Sends Email</label>
		<input id="sendEmailId" type="checkbox" name="sendEmail" <cfif sendEmail EQ 1>checked</cfif> value="1">
		<br/><br/>
		<label for="badgeAssignType">Assigned By:</label>
		<select id="badgeAssignType"  name="badgeAssignType">
			<option value="">Select Assigning Group</option>
			<option value="Consultant Supervisors" <cfif badgeAssignType EQ 'Consultant Supervisors'>selected="selected"</cfif>>Consultant Supervisors</option>
			<option value="Admin" <cfif badgeAssignType EQ 'Admin'>selected="selected"</cfif>>Admin</option>
			<option value="Automation" <cfif badgeAssignType EQ 'Automation'>selected="selected"</cfif>>Automation</option>
		</select>
		<br/><br/>
		<input type="submit"  name="action" value="Edit">
	</form>
	</fieldset>

	<fieldset style="width:29%;display:inline-block;vertical-align:top;">
	<legend>Delete Badge</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="getInfo" value="Delete">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">
		<label for="deleteSelectBadgeId">Select Badge:</label>
		<select id="deleteSelectBadgeId" name="badgeId">
			<option value="0">Select Badge</option>
		<cfloop query="getBadges">
			<option value="#badge_id#">#badge_name#</option>
		</cfloop>
		</select>
		<br/><br/>
		<input type="submit"  name="action" value="Delete">
	</form>
	</fieldset>
	</cfoutput>
	
<cfelse>
	<p class="warning">
		<span>Error</span> - You do not belong to any instance.
	</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>