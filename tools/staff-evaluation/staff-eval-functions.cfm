<!--- like the common functions consultant selector, except that maskList is interpreted more strictly --->
<!--- users must possess ALL masks in maskList to be listed --->
<cffunction name="drawConsultantSelect">
	<cfargument name="maskList" type="string" default="">
	<cfargument name="negMaskList" type="string" default="">
	<cfargument name="currentUserId" type="numeric" default="0">
	<cfargument name="elementName" type="string" default="frmUserId">

		<cfquery datasource="#application.applicationDataSource#" name="getUsers">
			SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
			FROM tbl_users u
			LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
			<cfif listLen(maskList) gt 0>
				WHERE 1 = 1
				<cfloop list="#maskList#" index="myMask">
					AND EXISTS (
					 SELECT um.mask_id
					 FROM vi_all_masks_users amu
					 INNER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id 
					 WHERE um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myMask#">
					 	   AND amu.user_id = u.user_id
					 )
				</cfloop>
			</cfif>
			ORDER BY last_name, first_name, username
		</cfquery>
		
		<cfset var userList = "">
		<cfloop query="getUsers">
			<cfset var userList = listAppend(userList, user_id)>
		</cfloop>
		
		<!--- now, if we have a negMaskList, we want to make sure none of our users have masks we don't want. 
		      Run a query to find the undesired users. --->
		<cfif listLen(negMaskList) gt 0>
			<cfquery datasource="#application.applicationDataSource#" name="getNegUsers">
				SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
				FROM tbl_users u
				LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
				LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
				<cfif listLen(negMaskList) gt 0>
					WHERE 0 = 1
					<cfloop list="#negMaskList#" index="myMask">
						OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#trim(myMask)#">
					</cfloop>
				</cfif>
				AND u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userList#" list="true">)
				ORDER BY last_name, first_name, username
			</cfquery>
		</cfif>
		
		<cfset var negUserList = "">
		<cfloop query="getNegUsers">
			<cfset var negUserList = listAppend(negUserList, user_id)>
		</cfloop>
		
		<cfset var goodUsers = "">
		
		<cfloop list="#userList#" index="user_id">
			
			<cfif NOT listFindNoCase(negUserList, user_id)>
				<cfset goodUsers = listAppend(goodUsers, user_id)>
			</cfif>
			
		</cfloop>
		
		<cfquery datasource="#application.applicationDataSource#" name="getGoodUsers">
			SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name, i.instance_name, 
							i.instance_id, dbo.userHasMasks(u.user_id, 'Admin') AS is_admin
			FROM tbl_users u
			INNER JOIN tbl_instances i ON i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
			WHERE u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#goodUsers#" list="true">)
			ORDER BY is_admin DESC, last_name, first_name, username
		</cfquery>
		
		<select name="frmUserId" id="currentUsers">
			<cfoutput query="getGoodUsers" group="instance_id">
				<optgroup label="#instance_name#">
				
				<cfoutput group="is_admin">
				
					<cfif is_admin>
						<optgroup label="&nbsp;&nbsp;Admins">
					<cfelse>
						<optgroup label="&nbsp;&nbsp;Supervisors">
					</cfif>
					
					<cfoutput>
						<option value="#user_id#" <cfif currentUserId EQ user_id>selected="true"</cfif>>
							#last_name#, #first_name# (#username#)
						</option>
					</cfoutput>
					
					</optgroup>
				</cfoutput>
				</optgroup>
			</cfoutput>
		</select>
	
</cffunction>

<cffunction name="drawSemesterSelect">
	<cfargument name="semesterOptions" default="future">
	<cfargument name="instanceId" type="numeric" default="0">
	<cfargument name="semesterId" type="numeric" default="0">
	<cfargument name="elementName" type="string" default="">
	
	<cfset var getAllSemesters = "">
	
	<!---now we can fetch all the semesters that apply to this user that are of the types we are interested in.--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllSemesters">
		SELECT TOP 5
		i.instance_id, i.instance_name, i.instance_mask, s.semester_id, s.semester_name, s.start_date, s.end_date
		FROM vi_semesters s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
		AND s.semester_name IN ('Fall','Spring','Summer') 
		<cfif semesterOptions EQ "future">
			AND s.end_date >= GETDATE() 
			ORDER BY start_date ASC
		<cfelseif semesterOptions EQ "past">
			AND s.start_date <= GETDATE() 
			ORDER BY instance_name, start_date DESC
		</cfif>
	</cfquery>
	
	<select name="frmSemester" id="currentSemesters">
		<cfoutput query="getAllSemesters" group="instance_id">
			<optgroup label="#htmlEditFormat(instance_name)#">
			<cfoutput>
				<option value="i#instance_id#s#semester_id#" 
					<cfif instanceId eq instance_id AND semesterId eq semester_id>selected</cfif>>#semester_name# #dateFormat(start_date, "yyyy")# (#dateFormat(start_date, "mm/dd")# to #dateFormat(end_date, "mm/dd")#)</option>
			</cfoutput>
			</optgroup>
		</cfoutput>
	</select>
	
</cffunction>