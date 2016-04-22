<cfmodule template="#application.appPath#/header.cfm" title='Assign Badges' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="instanceId" type="integer" default="#Session.primary_instance#">
<cfparam name="frmBadgeAddId" type="integer" default="0">
<cfparam name="frmMatchRemoveId" type="integer" default="0">
<cfparam name="frmUserAddId" type="integer" default="-1">
<cfparam name="frmUserRemoveId" type="integer" default="-1">
<cfparam name="frmAction" type="string" default="">
<cfparam name="auditText" type="string" default="">


<!---now find the details of the current instance based on instanceId--->
<cfset myInstance = getInstanceById(instanceId)>

<!--- Header / Navigation --->
<cfoutput>
	<h1>Assign Achievement Badges (#myInstance.instance_name#)</h1>
	<cfinclude template="#application.appPath#/tools/badges/secondary-navigation.cfm">
</cfoutput>

<!--- Queries --->
<cfquery datasource="#application.applicationDataSource#" name="getBadges">
	SELECT b.badge_id, b.badge_name 
	FROM tbl_badges b
	INNER JOIN tbl_badges_categories_match m ON m.badge_id = b.badge_id
	INNER JOIN tbl_badges_categories c ON c.category_id = m.category_id
	WHERE b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
	AND b.active = 1
	AND b.assigned_by <> 'Automation'
	ORDER BY b.badge_name
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getBlacklist">
	SELECT instance_mask 
	FROM tbl_instances i 
	WHERE 0 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getInstanceMasks">
	SELECT b.mask_id
	FROM tbl_instances a
	INNER JOIN tbl_user_masks b ON b.mask_name = a.instance_mask
	WHERE instance_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
</cfquery>

<!--- Handle User Input --->
<cfif frmAction EQ "Add Badge" OR frmAction EQ "Remove Badge">

	<cftry>
		
		<!--- Double check our inputs. --->
		<cfif frmAction EQ "Add Badge">
			<cfif frmBadgeAddId EQ 0>		
				<cfthrow message="Invalid Input" detail="Please select a valid badge.">			
			</cfif>
				
			<cfif frmUserAddId EQ -1>
				<cfthrow message="Invalid Input" detail="Please select a valid consultant.">
			</cfif>
		<cfelseif frmAction EQ "Remove Badge">
			<cfif frmMatchRemoveId EQ 0>		
				<cfthrow message="Invalid Input" detail="Please select a valid badge.">			
			</cfif>
				
			<cfif frmUserRemoveId EQ -1>
				<cfthrow message="Invalid Input" detail="Please select a valid consultant.">
			</cfif>
			
			<cfquery datasource="#application.applicationDataSource#" name="checkBadges">
				SELECT bum.badge_id
				FROM tbl_badges_users_matches bum
				WHERE bum.match_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmMatchRemoveId#">
					  AND bum.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserRemoveId#">
			</cfquery>
			
			<cfif checkBadges.recordCount EQ 0>
				<cfthrow message="Delete Error" detail="That user doesn't have that badge.">
			</cfif>
			
		</cfif>
		
		<cfset message = "">
		<cfset matchId = 0>
		<cfset userId = -1>
		
		<!--- If all is well, add or remove the badge. --->	
		<cfif frmAction EQ "Add Badge">
			
			<cfquery datasource="#application.applicationDataSource#" name="addUserBadge">
				INSERT INTO tbl_badges_users_matches (badge_id, user_id, assigner_id, active)
				OUTPUT inserted.match_id AS return_match_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmBadgeAddId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserAddId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">, 1
				)
			</cfquery>
			
			<cfset message = "Badge added successfully.">
			<cfset auditText = "Added Badge">
			<cfset matchId = addUserBadge.return_match_id>
			<cfset userId = frmUserAddId>
			
		<cfelseif frmAction EQ "Remove Badge">
			
			<cfquery datasource="#application.applicationDataSource#" name="removeUserBadge">
				UPDATE tbl_badges_users_matches 
				SET active = 0
				WHERE match_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmMatchRemoveId#">
				AND user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserRemoveId#">
			</cfquery>
			
			<cfset message = "Badge removed successfully.">
			<cfset auditText = "Removed Badge">
			<cfset matchId = frmMatchRemoveId>
			<cfset userId = frmUserRemoveId>
			
		</cfif>
		
		<!--- Finally, add the audit record. --->
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_badges_users_matches_audit (match_id, modifier_id, date_created, audit_text)
			OUTPUT inserted.audit_id
			VALUES(
				<cfqueryparam cfsqltype="cf_sql_integer" value="#matchId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_datetime" value="#dateTimeFormat(Now())#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		
		<cfset frmBadgeAddId = "0">
		<cfset frmUserAddId = "-1">
		<cfset frmMatchRemoveId = "0">
		<cfset frmUserRemoveId = "-1">
		<p class="ok"><cfoutput>#message#</cfoutput></p>
		
	<cfcatch>
		<cfoutput>
			<p class="warning">
				<cfoutput>#cfcatch.message# - #cfcatch.Detail#</cfoutput>
			</p>
		</cfoutput>
	</cfcatch>
	
	</cftry>
	
</cfif>

<!--- Draw Forms --->
<cfset drawBadgeField("Add",instanceId)>
<cfset drawBadgeField("Remove",instanceId,frmUserRemoveId)>


<cffunction name="getUserBadges">
	<cfargument name="instanceId" type="numeric">
	<cfargument name="userId" type="numeric" default="0">
	<cfquery datasource="#application.applicationDataSource#" name="getUserBadgesQuery">
		SELECT m.match_id, b.badge_name, m.time_assigned
		FROM tbl_badges b
		INNER JOIN tbl_badges_users_matches m ON m.badge_id = b.badge_id
		WHERE b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND b.active = 1
		AND m.active = 1
		AND m.user_id =  <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
		ORDER BY b.badge_name
	</cfquery>	
	<cfreturn getUserBadgesQuery>
</cffunction>


<!--- Given a string type "Add" or "Remove", draws the appropriate box. --->
<cffunction name="drawBadgeField">
	<cfargument name="fieldType" type="string" default="">
	<cfargument name="instanceId" type="numeric" default="0">
	<cfargument name="frmUserRemoveId" type="numeric" default="0">
	
	<!--- The user can't edit badges for Logistics, anyone of a higher mask level,  --->
	<!--- or anyone outside of their primary instance --->
	<cfset blackList = "Logistics">
	<cfif not hasMasks("Admin")>
		<cfset blackList = listAppend(blackList, "CS")>
		<cfset blackList = listAppend(blackList, "Admin")>
	</cfif>
	<cfloop query="getBlacklist">
		<cfset blackList = ListAppend(blackList, instance_mask)>
	</cfloop>
	<cfloop query="getInstanceMasks">
		<cfset blackList = listAppend(blacklist, mask_id)>
	</cfloop>

	
	<cfoutput>
		
		<fieldset style="width:29%;display:inline-block;vertical-align:top;">
			
			<legend>#fieldType# Badge</legend>
			
			<form action="#cgi.script_name#" method="POST">
				
				<input type="hidden" name="instanceId" value="#instanceId#">
				
				<cfif fieldType EQ "Add">
					
					#drawConsultantSelector('consultant', blackList, frmUserAddId, 0, 'frmUserAddId')#
					<br/><br/>
					
					<label for="frmBadgeAddId">Badge:</label>
					<select id="frmBadgeAddId"  name="frmBadgeAddId">
						<option value="0">Select Badge</option>				
						<cfloop query="getBadges">
							<option value="#badge_id#">#badge_name#</option>
						</cfloop>		
					</select>
					
				<cfelseif fieldType EQ "Remove">
				
					#drawConsultantSelector('consultant', blackList, frmUserRemoveId, 1, 'frmUserRemoveId')#
					<br/><br/>
					<cfset userBadges = getUserBadges(instanceId, frmUserRemoveId)>
					<label for="frmMatchRemoveId">Badge:</label>
					<select id="frmMatchRemoveId"  name="frmMatchRemoveId">
						<option value="0">Select Badge</option>				
						<cfloop query="userBadges">
							<option value="#match_id#">#badge_name# (#dateTimeFormat(time_assigned, 'yyyy-mm-dd')#)</option>
						</cfloop>		
					</select>
					
				</cfif>
				
				<br/><br/>
				
				<input type="submit"  name="frmAction" value="#fieldType# Badge">
				
			</form>
			
		</fieldset>
		
	</cfoutput>
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>