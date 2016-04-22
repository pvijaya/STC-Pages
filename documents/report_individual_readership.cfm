<cfmodule template="#application.appPath#/header.cfm" title="Readership Report">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="CS">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- use the current semester and instance as the default date ranges --->
<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT instance_id, instance_name
	FROM tbl_instances i
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
</cfquery>

<cfset curSem = getSemesterByDate(getInstances.instance_id)>

<!--- cfparams --->
<cfparam name="frmUid" type="integer" default="0">
<cfparam name="frmCatId" type="integer" default="0">
<cfparam name="frmRead" type="boolean" default="0">
<cfparam name="frmStart" type="date" default="#curSem.start_date#">
<cfparam name="frmEnd" type="date" default="#curSem.end_date#">
<cfparam name="frmAction" type="string" default="">

<!--- set instance --->
<cfset myInstance = getInstanceById(Session.primary_instance)>
<cfset maskBlacklist = "Admin, Logistics">
<cfif not hasMasks("CS")>
	<cfset maskBlacklist = listAppend(maskBlackList, "CS")>
</cfif>

<h1>Article Readership Report</h1>

<cfif frmAction EQ "Clear">
	<cfset frmUid = 0>
	<cfset frmCatId = 0>
	<cfset frmRead = 0>
	<cfset frmStart = curSem.start_date>
	<cfset frmEnd = curSem.end_date>
</cfif>

<!--- sanitize our dates --->
<cfset frmStart = dateFormat(frmStart, "mmm d, yyyy")>
<cfset frmEnd = dateFormat(frmEnd, "mmm d, yyyy")>

<!---fetch all categories for use with functions later.--->
<cfset allCats = getAllCategoriesQuery(0)> <!---don't include retired categories.--->

<span class="triggerexpanded">Search Parameters</span>
<div>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

		<fieldset>

			<legend>Choose Search Parameters</legend>

			<table>

				<tr>
					<td><label for="currentUsers">User:</label></td>
					<td><cfset drawConsultantSelect("Consultant, #myInstance.instance_mask#", maskBlacklist, frmUid, 0, "frmUid")></td>
				</tr>

				<tr>
					<td><label for="currentCats">Category:</label></td>
					<td><cfset drawCatSelect()></td>
				</tr>

				<tr>
					<td>Read Status:</td>
					<td>
						<label>
							<input type="radio" name="frmRead" value="1" <cfif frmRead>checked="true"</cfif>> Read Articles
						</label>
						<label>
							<input type="radio" name="frmRead" value="0" <cfif not frmRead>checked="true"</cfif>> Unread Articles
						</label>
					</td>
				</tr>

				<tr>
					<td><label for="startDate">Start Date:</label></td>
					<td>
						<input type="text" class="calendar" name="frmStart" id="startDate"
						       value="<cfoutput>#htmlEditFormat(frmStart)#</cfoutput>">
					</td>
				</tr>

				<tr>
					<td><label for="endDate">End Date:</label></td>
					<td>
						<input type="text" class="calendar" name="frmEnd" id="endDate"
					       	   value="<cfoutput>#htmlEditFormat(frmEnd)#</cfoutput>">
					</td>
				</tr>

			</table>

			<script type="text/javascript">
				$(document).ready(function(){
					//make our date picker, limit it to when articles could possibly have been created.
					$("input.calendar").datepicker({
						dateFormat: 'M d, yy',
						changeMonth: true,
						changeYear: true,
						minDate: "Jan 1, 1999",
						maxDate: "<cfoutput>#dateFormat(now(), 'mmm d, yyyy')#</cfoutput>",
						yearRange: "1999:<cfoutput>#dateFormat(now(), 'yyyy')#</cfoutput>"
					});
				});
			</script>

			<input type="submit" value="Search" name="frmAction">
			<input type="submit" value="Clear" name="frmAction">

		</fieldset>

	</form>

</div>


<cfif frmUid gt 0>
	<cfmodule template="mod_individual_readership.cfm" uid="#frmUid#" read="#frmRead#" catId="#frmCatId#" start="#frmStart#" end="#frmEnd#">
</cfif>

<cffunction name='drawConsultantSelect'> <!---Draws a select box with "currentUserId" as the default name that allows the user to pick another user--->
	<cfargument name='maskList'><!---masks the user must have to be listed--->
	<cfargument name='negMaskList'><!---masks the user must NOT have to be listed--->
	<cfargument name='currentUserId' type="numeric" default=0>
	<cfargument name='autoSubmit' type="numeric" default=0>
	<cfargument name='elementName' type="string" default="currentUserId">

	<cfset var getUsers = "">
	<cfset var getNegUsers = "">
	<cfset var userList = "0"><!---list of users from getUsers--->
	<cfset var bulkMasks = "">
	<cfset var passes = ""><!---has the user passed he tests of both maskList and negMaskList?--->
	<cfset var myMask = ""><!---used when looping over maskLists--->
	<cfset var goodUsers = queryNew("user_id,username,last_name,first_name","integer,varchar,varchar,varchar")>

	<!---use a query to fetch all the users who satisfy the requirements of maskList, then use bulkGetUserMasks() and bulkHasMasks() to check if they violate negMaskList--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
		FROM tbl_users u
		LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
		LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
		<cfif listLen(maskList) gt 0>
			WHERE 0 = 1
			<cfloop list="#maskList#" index="myMask">
				OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#trim(myMask)#">
			</cfloop>
		</cfif>
		ORDER BY last_name, first_name, username
	</cfquery>

	<!---build a list of users who have the masks we do want to know about.--->
	<cfloop query="getUsers">
		<cfset userList = listAppend(userList, user_id)>
	</cfloop>


	<!---now, if we have a negMaskList, we want to make sure none of our users have masks we don't want. Run a query to find the undesired users.--->
	<cfif listLen(negMaskList) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="getNegUsers">
			SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
			FROM tbl_users u
			LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
			LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
			<cfif listLen(maskList) gt 0>
				WHERE 0 = 1
				<cfloop list="#negMaskList#" index="myMask">
					OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#trim(myMask)#">
				</cfloop>
			</cfif>
			AND u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userList#" list="true">)/*constrain to users we've decided could be included*/
			ORDER BY last_name, first_name, username
		</cfquery>
	</cfif>

	<cfloop query="getUsers">
		<cfset passes = 1><!---assume they've passed--->

		<!---if we have a negative mask list we need to make sure this user doesn't have any of those masks--->
		<cfif listLen(negMaskList) gt 0>
			<cfloop query="getNegUsers">
				<cfif getNegUsers.user_id eq getUsers.user_id>
					<cfset passes = 0>
					<cfbreak>
				</cfif>
			</cfloop>
		</cfif>

		<cfif passes>
			<cfset queryAddRow(goodUsers)>
			<cfset querySetCell(goodUsers, "user_id", user_id)>
			<cfset querySetCell(goodUsers, "username", username)>
			<cfset querySetCell(goodUsers, "last_name", last_name)>
			<cfset querySetCell(goodUsers, "first_name", first_name)>
		</cfif>
	</cfloop>

	<select  name="<cfoutput>#elementName#</cfoutput>" id='currentUsers' <cfif autoSubmit EQ 1>onchange="this.form.submit();"</cfif>>
			<option value="-1">---</option>
		<cfoutput query='goodUsers'>
			<option value="#user_id#" <cfif user_id EQ currentUserId>selected</cfif>>#last_name#, #first_name# (#username#)</option>
		</cfoutput>
	</select>

</cffunction>

<cffunction name="drawCatSelect">

	<cfoutput>
		<select name="frmCatId" id="currentCats">
			<option value="0"><em>---</em></option>
			<!---now go through and draw options--->
			<cfset drawCategoryOptions(0, frmCatId, "", 0, allCats)>
		</select>
	</cfoutput>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">