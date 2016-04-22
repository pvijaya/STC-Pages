<cfprocessingdirective suppresswhitespace="true"><!---and we don't want extra verbage coming along for the ride.--->

<!---This file contains all of the functions we can use across our website--->

<cffunction name="getMasks">
	<cfargument name="userId" type="numeric" default="#Session.cas_uid#">

	<cfset var getUserMasks="">

	<cfquery datasource="#application.applicationDataSource#" name="getUserMasks">
		SELECT um.mask_name
		FROM vi_all_masks_users mu
		INNER JOIN tbl_user_masks um ON um.mask_id = mu.mask_id
		WHERE mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
	</cfquery>

	<cfreturn getUserMasks>

</cffunction>

<cffunction name="hasMasks" output="false">
	<cfargument name="maskList" type="string" required="true"><!---this can be a list of mask_names or mask_ids, even mixed and matched.  If it's numeric it matches by mask_id--->
	<cfargument name='memberId' type='numeric' default=0>

	<cfset var foundMask = 0>
	<cfset var myMask = "">
	<cfset var getMyMasks = "">
	<cfset var getAllMaskRelationships = "">
	<cfset var getUserMasks = "">

	<!---catch cases where user is not logged in--->
	<cfif memberId lte 0 AND isDefined("session.cas_uid")>
		<cfset memberId = session.cas_uid>
	</cfif>

	<!---fetch all the masks the user explicitly has--->
	<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
		SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
		FROM tbl_users u
		INNER JOIN tbl_users_masks_match umm ON u.user_id = umm.user_id
		INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
		WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#memberId#">
	</cfquery>

	<!---fetch the table of masks' parent->child relationships so we can get all the user's inheritted masks--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelationships">
		SELECT um.mask_id, um.mask_name,
			CASE
				WHEN mr.mask_id IS NULL THEN 0
				ELSE mr.mask_id
			END AS parent_id
		FROM tbl_user_masks um
		LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
		LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
		ORDER BY um.mask_id
	</cfquery>
	<!---we did this query here so we can pass it to the helper functions, rather than pester the database for it a bunch of times.--->

	<!---now use our helper function to build get a query of all masks the user has, both explicitly and inheritted.--->
	<cfset getUserMasks = buildMyMasks(getMyMasks, getAllMaskRelationships)>

	<cfloop list="#maskList#" index="myMask">
		<cfset foundMask = 0>

		<!---sometimes folks put spaces in lists, that's bad for us trim out leading or trailing whitespace.--->
		<cfset myMask = trim(myMask)>

		<cfloop query="getUserMasks">
			<cfif myMask eq mask_name OR myMask eq mask_id>
				<cfset foundMask = 1>
				<cfbreak>
			</cfif>
		</cfloop>

		<cfif foundMask eq 0>
			<cfreturn 0>
		</cfif>
	</cfloop>

	<cfreturn 1>
</cffunction>

<!---we pass the result of bulkGetuserMasks to this function so we don't make so many database calls. then we give it a username and list of masks it must satisfy.--->
<cffunction name="bulkHasMasks" output="true">
	<cfargument name="ourMasks" type="query" required="true">
	<cfargument name="uname" type="string" required="true">
	<cfargument name="maskList" type="string" required="true">

	<cfset var hasMask = 0>
	<cfset var n = "">
	<cfset var myMasks = "">
	<cfset var useIds = 1><!---the user may pass maskList as mask_names or mask_ids, if they've exclusively passed numbers then we are looking at mask_id's.--->

	<!---if maskList is empty the user obviously satisfies the requirements.--->
	<cfif listLen(maskList) eq 0>
		<cfreturn true>
	</cfif>

	<cfloop list="#maskList#" index="n">
		<cfif not isValid("integer", trim(n))>
			<cfset useIds = 0><!---we found something that isn't a mask_id, so we're using mask_names.--->
			<cfbreak>
		</cfif>
	</cfloop>

	<!---loop over ourMasks, and build a list of masks the user we're checking has.--->

	<cfloop query="ourMasks">
		<cfif username eq uname>
			<!---The iif just determines if we should use the mask_id or mask_name for the list.--->
			<cfset myMasks = listAppend(myMasks, iif(useIds, de(mask_id), de(mask_name)))>
		</cfif>
	</cfloop>


	<cfloop list="#maskList#" index="n">
		<cfset n = trim(n)><!---whitespace in our search term can be a real killer--->
		<cfif listFindNoCase(myMasks, n)>
			<cfset hasMask = 1>
		<cfelse>
			<!---they are missing at least one mask, return false.--->
			<cfset hasMask = 0>
			<cfbreak>
		</cfif>
	</cfloop>


	<cfreturn hasMask>
</cffunction>

<!---sometimes we want to find the masks for a lot of users at once, and this can require a lot of db calls, let's try to condensce that as much as we can.--->
<cffunction name="bulkGetUserMasks" output="false">
	<cfargument name="userList" type="string" default="#session.cas_username#">

	<cfset var sanitaryList = ""><!---sometimes extra whitespace ends up in lists, we'll use this to clean-up user input.--->
	<cfset var getUsersMasks = "">
	<cfset var getAllMaskRelationships = "">
	<cfset var ourMasks = "">
	<cfset var qoq = "">
	<cfset var n = "">
	<cfset var userArray = arrayNew(1)>
	<cfset var maskStruct = structNew()>
	<cfset var cachedLimit = createTimeSpan(0,0,0,8)><!---this query could see a lot of use, reuse the results if they were pulled in the last 8 seconds.--->

	<cfloop list="#userList#" index="n">
		<cfset sanitaryList = listAppend(sanitaryList, trim(n))>
	</cfloop>

	<!---just like in has masks we'll fetch all the masks users explicitly have.--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsersMasks" cachedwithin="#cachedLimit#">
		SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
		FROM tbl_users u
		INNER JOIN tbl_users_masks_match umm ON u.user_id = umm.user_id
		INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
		WHERE u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#sanitaryList#" list="true">)
		ORDER BY u.user_id
	</cfquery>

	<!---fetch the table of masks' parent->child relationships so we can get all the user's inheritted masks--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelationships" cachedwithin="#cachedLimit#">
		SELECT um.mask_id, um.mask_name,
			CASE
				WHEN mr.mask_id IS NULL THEN 0
				ELSE mr.mask_id
			END AS parent_id
		FROM tbl_user_masks um
		LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
		LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
		ORDER BY um.mask_id
	</cfquery>

	<cfset ourMasks = buildMyMasks(getUsersMasks, getAllMaskRelationships)>

	<cfreturn ourMasks>
</cffunction>

<!---used by hasMasks().  Takes two queries.  One with a user's explicite masks, columns mask_id and mask_name, and a second of mask relationships so it can add all the inheritted masks to the first query.--->
<cffunction name="buildMyMasks" output="false">
	<cfargument name="myMasks" type="query" required="true">
	<cfargument name="maskRelationShips" type="query" required="true">

	<cfset var newMyMasks = queryNew("user_id,username,mask_id,mask_name", "integer,varchar,integer,varchar")>
	<cfset var hasMatch = 0>

	<cfloop query="myMasks">
		<!---each existing row should be in newMyMasks, so if they don't already have it, add it.--->
		<cfset hasMatch = 0>
		<cfloop query="newMyMasks">
			<cfif myMasks.user_id eq newMyMasks.user_id AND myMasks.mask_id eq newMyMasks.mask_id>
				<cfset hasMatch = 1>
				<cfbreak>
			</cfif>
		</cfloop>

		<cfif not hasMatch>
			<cfset queryAddRow(newMyMasks)>
			<cfset querySetCell(newMyMasks, "user_id", myMasks.user_id)>
			<cfset querySetCell(newMyMasks, "username", myMasks.username)>
			<cfset querySetCell(newMyMasks, "mask_id", myMasks.mask_id)>
			<cfset querySetCell(newMyMasks, "mask_name", myMasks.mask_name)>
		</cfif>

		<!---see if this mask has any children our user doesn't already have--->
		<cfloop query="maskRelationShips">
			<cfif myMasks.mask_id eq maskRelationShips.parent_id>
				<!---if they don't already have this mask add it to newMyMasks--->
				<cfset hasMatch = 0>
				<cfloop query="newMyMasks">
					<cfif myMasks.user_id eq newMyMasks.user_id AND maskRelationShips.mask_id eq newMyMasks.mask_id>
						<cfset hasMatch = 1>
						<cfbreak>
					</cfif>
				</cfloop>

				<cfif not hasMatch>
					<cfset queryAddRow(newMyMasks)>
					<cfset querySetCell(newMyMasks, "user_id", myMasks.user_id)>
					<cfset querySetCell(newMyMasks, "username", myMasks.username)>
					<cfset querySetCell(newMyMasks, "mask_id", maskRelationShips.mask_id)>
					<cfset querySetCell(newMyMasks, "mask_name", maskRelationShips.mask_name)>
				</cfif>
			</cfif>
		</cfloop>
	</cfloop>

	<!---if we got new masks we need to check for their children, too--->
	<cfif myMasks.recordCount neq newMyMasks.recordCount>
		<cfset newMyMasks = buildMyMasks(newMyMasks, maskRelationShips)>
	</cfif>

	<cfreturn newMyMasks>
</cffunction>

<cffunction name='userHasInstanceList'><!---Get all of user's instances (campus)--->
	<cfargument name='memberId' type='numeric' default="#session.cas_uid#">

	<cfset var instanceObj = structNew()>

	<cfset var getUserInstances = "">

	<cfset instanceObj.nameList = "">
	<cfset instanceObj.idList = "">
	<cfset instanceObj.instanceList = "">

	<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
		SELECT i.instance_id, mu.mask_id, m.mask_name
		FROM vi_all_masks_users mu
		INNER JOIN tbl_user_masks m ON m.mask_id = mu.mask_id
		INNER JOIN tbl_instances i ON i.instance_mask = m.mask_name
		WHERE mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#memberId#">
	</cfquery>

	<cfloop query="getUserInstances">
		<cfset instanceObj.nameList = listAppend(instanceObj.nameList, mask_name)>
		<cfset instanceObj.idList = listAppend(instanceObj.idList, mask_id)>
		<cfset instanceObj.instanceList = listAppend(instanceObj.instanceList, instance_id)>
	</cfloop>

	<cfreturn instanceObj>
</cffunction>

<cffunction name="getInstanceById">
	<cfargument name="instanceId" type="numeric" required="true">

	<cfset var getInstance = "">
	<cfset var instanceObj = structNew()>

	<cfset instanceObj.instance_id = 0>
	<cfset instanceObj.instance_name = "Unknown">
	<cfset instanceObj.instance_mask = "">
	<cfset instanceObj.datasource = "">
	<cfset instanceObj.pie_path = "">
	<cfset instanceObj.institution_name = "">
	<cfset instanceObj.institution_url = "">

	<cfquery datasource="#application.applicationDataSource#" name="getInstance">
		SELECT *
		FROM tbl_instances
		WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
	</cfquery>

	<cfloop query="getInstance">
		<cfset instanceObj.instance_id = instance_id>
		<cfset instanceObj.instance_name = instance_name>
		<cfset instanceObj.instance_mask = instance_mask>
		<cfset instanceObj.datasource = datasource>
		<cfset instanceObj.pie_path = pie_path>
		<cfset instanceObj.institution_name = institution_name>
		<cfset instanceObj.institution_url = institution_url>
	</cfloop>


	<cfreturn instanceObj>
</cffunction>

<cffunction name="setDefaultInstance"><!---Sets a default instance in a session, primarily to maintain the default chat for those with multiple instance masks--->
	<cfargument name="instanceValue">
	<cflock scope="Session" timeout="30" type="Exclusive">
		<cfset Session.primary_instance = instanceValue>
	</cflock>
</cffunction>

<!---<cffunction name='drawConsultantSelector'> <!---Draws a select box with "currentUserId" as the default name that allows the user to pick another user--->
	<cfargument name='maskList'><!---masks the user must have to be listed--->
	<cfargument name='negMaskList'><!---masks the user must NOT have to be listed--->
	<cfargument name='currentUserId' type="numeric" default=0>
	<cfargument name='autoSubmit' type="numeric" default=0>
	<cfargument name='elementName' type="string" default="currentUserId">

	<cfset var getUsers = "">
	<cfset var getNegUsers = "">
	<cfset var userList = ""><!---list of users from getUsers--->
	<cfset var bulkMasks = "">
	<cfset var passes = ""><!---has the user passed he tests of both maskList and negMaskList?--->
	<cfset var myMask = ""><!---used when looping over maskLists--->
	<cfset var userArray = arrayNew(1)>
	<cfset var tempStruct = "">

	<!---use a query to fetch all the users who satisfy the requirements of maskList, then use bulkGetUserMasks() and bulkHasMasks() to check if they violate negMaskList--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
		FROM tbl_users u
		LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
		LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
		<cfif listLen(maskList) gt 0>
			WHERE 0 = 1
			<cfloop list="#maskList#" index="myMask">
				OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myMask#">
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
			<cfset tempStruct = structNew()>

			<cfset tempStruct['value'] = "#last_name#, #first_name#(#username#)">
			<cfset tempStruct['id'] = user_id>
			<cfset arrayAppend(userArray, tempStruct)>
		</cfif>
	</cfloop>

	<label for='currentUsers'>User: </label>
	<input type="text" id="currentUsers" name="<cfoutput>#elementName#</cfoutput>SuperSelecter" class="username">
	<input type="hidden" name="<cfoutput>#elementName#</cfoutput>" value="<cfoutput>#currentUserId#</cfoutput>">
	<script>
		$(document).ready(function(){
			<cfoutput>SuperSelector( #serializeJSON(userArray)#, "input[name='#elementName#SuperSelecter']", "input[name='#elementName#']", #currentUserId#,#autoSubmit#);</cfoutput>
		});
	</script>
</cffunction>--->

<cffunction name='drawConsultantSelector'> <!---Draws a select box with "currentUserId" as the default name that allows the user to pick another user--->
	<cfargument name='maskList'><!---masks the user must have to be listed--->
	<cfargument name='negMaskList'><!---masks the user must NOT have to be listed--->
	<cfargument name='currentUserId' type="numeric" default=0>
	<cfargument name='autoSubmit' type="numeric" default=0>
	<cfargument name='elementName' type="string" default="currentUserId">

	<cfset var getUsers = "">
	<cfset var getNegUsers = "">
	<cfset var userList = ""><!---list of users from getUsers--->
	<cfset var bulkMasks = "">
	<cfset var passes = ""><!---has the user passed he tests of both maskList and negMaskList?--->
	<cfset var myMask = ""><!---used when looping over maskLists--->
	<cfset var userArray = arrayNew(1)>
	<cfset var tempStruct = "">

	<!---use a query to fetch all the users who satisfy the requirements of maskList, then use bulkGetUserMasks() and bulkHasMasks() to check if they violate negMaskList--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
		FROM tbl_users u
		LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
		LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
		<cfif listLen(maskList) gt 0>
			WHERE 0 = 1
			<cfloop list="#maskList#" index="myMask">
				OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myMask#">
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
			<cfset tempStruct = structNew()>

			<cfset tempStruct['value'] = "#last_name#, #first_name#(#username#)">
			<cfset tempStruct['id'] = user_id>
			<cfset arrayAppend(userArray, tempStruct)>
		</cfif>
	</cfloop>

	<div class="form-group">
		<label class=" col-sm-3 control-label" for='currentUsers'>User: </label>
		<div class="col-sm-9">
			<input type="text"  class=" form-control" id="currentUsers" name="<cfoutput>#elementName#</cfoutput>SuperSelecter" class="username">
		</div>
		<input type="hidden"  class=" col-sm-9 form-control" name="<cfoutput>#elementName#</cfoutput>" value="<cfoutput>#currentUserId#</cfoutput>">
	</div>
	<script>
		$(document).ready(function(){
			<cfoutput>SuperSelector( #serializeJSON(userArray)#, "input[name='#elementName#SuperSelecter']", "input[name='#elementName#']", #currentUserId#,#autoSubmit#);</cfoutput>
		});
	</script>
</cffunction>

<cffunction name="insertUserBadge">
	<cfargument name="badgeId"  type="numeric">
	<cfargument name="consultantId" type="numeric">
	<cfargument name="assignerId" type="numeric">
	<cfargument name="errorFeedback" type="numeric" default="0">

	<!---scope the variables used in this function--->
	<cfset var checkSendEmail = "">
	<cfset var insertUserBadge = "">
	<cfset var matchId = "">
	<cfset var insertUserBadgeAudit = "">
	<cfset var getUserEmail = "">

	<cfquery name='checkSendEmail' datasource="#application.applicationdatasource#" >
		SELECT *
		FROM tbl_badges
		WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_string" value="#badgeId#">
	</cfquery>
	<!---insert user badge match--->
	<cfquery name='insertUserBadge' datasource="#application.applicationdatasource#" >
		INSERT INTO tbl_badges_users_matches (badge_id, user_id, assigner_id, active)
		OUTPUT inserted.match_id AS return_match_id
		VALUES (<cfqueryparam cfsqltype="cf_sql_string" value="#badgeId#">,
		<cfqueryparam cfsqltype="cf_sql_string" value="#consultantId#">),
		<cfqueryparam cfsqltype="cf_sql_string" value="#assignerId#">,1
	</cfquery>
	<cfset matchId = addUserBadge.return_match_id>
	<!---insert audit record--->
	<cfquery name='insertUserBadgeAudit' datasource="#application.applicationdatasource#" >
		INSERT INTO tbl_badges_users_matches_audit(match_id,modifier_id, audit_text)
		VALUES (<cfqueryparam cfsqltype="cf_sql_string" value="#matchId#">,
		<cfqueryparam cfsqltype="cf_sql_string" value="#assignerId#">,
		'Added Badge')
	</cfquery>
	<cfif checkSendEmail.send_email EQ 1>
		<cfquery name='getUserEmail' datasource="#application.applicationDataSource#">
			SELECT email
			FROM tbl_users
			WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#consultantId#">
		</cfquery>
		<cfoutput query="checkSendEmail">
			<cfmail from="tccwm@iu.edu" to="#getUserEmail.email#"	subject="You Earned an Achievement Badge!" type="text/html">
				<html>
					<body>
						<center>
							 <h1>Congratulations!</h1>
							 <h2>You just earned</h2>
							<div style="padding:5px;display:inline-block;vertical-align:top;width:140px;"  title="#description#">
								<strong>#badge_name#</strong><br/>
								<div style="margin:5px 0px;text-align:center;"><img src="#image_url#" style="width:125px;vertical-align:top;" /></div>
							</div>
						</center>
					</body>
				</html>
			</cfmail>
		</cfoutput>
	</cfif>
	<cfif errorFeedback EQ 1>
		<p class="ok">
			<b>Success</b>
			Badge inserted!
		</p>
	</cfif>
</cffunction>

<cffunction name="getRavesByType">
	<cfargument name="datasource" type="string" required="true"><!---Because the two instances varry so much we can't just use a view and an instance_id to split the difference, we need to actually pull the raves from a particular datasource(found in tbl_instances).--->
	<cfargument name="groupId" type="numeric" required="true"><!---groupId determines which set of questions we're looking for.  1 = GoldStars, 2 = PDIs, 3 = communication RAVEs, 16 = logistics raves, 29 = 12 hour minimum, and 42 = Ticket Observations.  It's haphazzard, but that's the bitter fruit of the Control Panels wonky design.--->
	<cfargument name="start_date" type="date" default="#dateAdd('d', -30, now())#">
	<cfargument name="end_date" type="date" default="#now()#">
	<cfargument name="username" type="string" default=""><!---the username of the assignee, blank means anyone.--->
	<cfargument name="includeUnApproved" type="boolean" default="false"><!---By default we don't want to see RAVEs that haven't been approved, but there are things like 12 Hour Minimum RAVEs that might go un-appealed and still be valid.--->
	<cfargument name="limitByLevel" type="boolean" default="true"><!---do we want to limit the user to only seeing RAVEs about users with a lower level than their own?  BE SUPER CAREFUL to not set this to true with things like PDIs or 12 hour minimums.  This breaks users expectation of privacy, but is needed for certain reports, like the GoldStar hall of fame.--->
	<cfargument name="orderAsc" type="boolean" default="true"><!---the sort order for our RAVEs, oldest first is the default.--->

	<cfset var getRaves = "">

	<cfquery datasource="#datasource#" name="getRaves">
		SELECT a.ANSWER_GROUP, a.QUESTION_ID, a.ANSWERED_BY, a.ANSWERED_ABOUT, a.ANSWER, a.ts,
		q.question, q.GROUP_ID, r.review_id, r.reviewed_date, r.approved, r.status_id, rs.status, rs.color,
		cAbout.USERNAME AS about_username, cAbout.LAST_NAME AS about_last_name, cAbout.FIRST_NAME AS about_first_name,
		cBy.USERNAME AS answered_by_username, cBy.LAST_NAME AS answered_by_last_name, cBy.FIRST_NAME AS answered_by_first_name,
		rBy.username AS reviewed_by_username, aTo.username AS assigned_to_username,
		CASE
			WHEN qrc.comment_count IS NULL THEN 0
			ELSE qrc.comment_count
		END AS comment_count

		FROM tbl_questions_answers a
		INNER JOIN TBL_QUESTIONS q ON q.question_id = a.question_id
		INNER JOIN tbl_questions_reviewed r ON a.ANSWER_GROUP = r.ANSWER_GROUP
		INNER JOIN tbl_questions_reviewed_status rs ON r.status_id = rs.status_id
		INNER JOIN tbl_consultants cBy ON cBy.SSN = a.ANSWERED_BY
		INNER JOIN tbl_consultants cAbout ON cAbout.SSN = a.ANSWERED_ABOUT
		LEFT OUTER JOIN rave_cons aTo ON aTo.ssn = r.assigned_to
		LEFT OUTER JOIN tbl_consultants rBy ON rBy.SSN = r.REVIEWED_BY
		/*get the number of comments for each RAVE*/
		LEFT OUTER JOIN (
			SELECT review_id, COUNT(comment_id) AS comment_count
			FROM tbl_questions_reviewed_comments
			WHERE access_level <= <cfqueryparam cfsqltype="cf_sql_integer" value="#getPielevel(session.cas_uid)#">
			GROUP BY review_id
		) qrc ON qrc.review_id = r.review_id

		WHERE q.group_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#groupID#">
		/*date constraints*/
		AND (
			(a.TS >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#start_date#"> AND a.TS <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#end_date#">)
			OR (r.reviewed_date >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#start_date#"> AND r.reviewed_date <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#end_date#">)
		)
		<!---do we only want RAVEs that have been Approved?--->
		<cfif not includeUnApproved>
			AND r.approved = 1
		</cfif>

		<cfif len(trim(username)) gt 0>
			AND cAbout.USERNAME = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
		</cfif>

		<cfif limitByLevel>
			/*limit to viewing RAVEs of those beneath you in rank*/
			AND cAbout.ACCESS_LEVEL < <cfqueryparam cfsqltype="cf_sql_integer" value="#getPielevel(session.cas_uid)#">
		</cfif>


		ORDER BY a.answer_group<cfif not orderAsc> DESC</cfif>, q.group_order, a.ts
	</cfquery>

	<cfreturn getRaves>
</cffunction>

<cffunction name="drawRaveComments">
	<cfargument name="datasource" type="string" required="true"><!---Because the two instances varry so much we can't just use a view and an instance_id to split the difference, we need to actually pull the raves from a particular datasource(found in tbl_instances).--->
	<cfargument name="answerGroup" type="numeric" required="true">
	<cfargument name="pieLevel" type="numeric" default="#getPieLevel(session.cas_uid)#">
	<!--- you could add an argument here to strip out status/assignment change comments here.--->

	<cfset var getComments = "">

	<cfquery datasource="#datasource#" name="getComments">
		SELECT qrc.comment_id, qrc.access_level, c.username, qrc.comment, qrc.comment_date
		FROM tbl_questions_reviewed qr
		INNER JOIN tbl_questions_reviewed_comments qrc ON qrc.review_id = qr.review_id
		INNER JOIN tbl_consultants c ON c.ssn = qrc.commenter
		WHERE qr.answer_group = <cfqueryparam cfsqltype="cf_sql_integer" value="#answerGroup#">
		AND qrc.access_level <= <cfqueryparam cfsqltype="cf_sql_integer" value="#pielevel#">
		ORDER BY qrc.comment_date ASC
	</cfquery>
	<span class="trigger">Show Comments</span>
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="2">Additional Comments</td>
		</tr>
		<tr class="titlerow2">
			<th>Author</th>
			<th>Comment</th>
		</tr>

	<cfoutput query="getComments">
		<tr>
			<td class="tinytext" valign="top" align="right">
				#username#<br/>
				#dateFormat(comment_date, "mmm d, yyyy")#<br/>
				#timeFormat(comment_date, "h:mmtt")#<br/>
				<cfswitch expression="#access_level#">
					<cfcase value="4">
						<span class="adminOnly">Admin Only</span>
					</cfcase>
					<cfcase value="3">
						<span class="ssOnly">CS Only</span>
					</cfcase>
				</cfswitch>
			</td>
			<td valign="top">
				#comment#
			</td>
		</tr>
	</cfoutput>

	</table>

</cffunction>
<!---Function takes username or user_id and spits out pie's access_level for that user--->
<cffunction name='getPieLevel' output="false">
	<cfargument name='userVar' required="true">
	<cfset var getUser = ''>
	<cfif not isNumeric(userVar)>
		<cfquery name='getUser' datasource="#application.applicationDataSource#">
			SELECT user_id
			FROM tbl_users
			WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#userVar#">
		</cfquery>
		<cfloop query="getUser">
			<cfset userVar = user_id>
		</cfloop>
	</cfif>
	<cfif hasMasks('Admin',userVar)>
		<cfset userVar = 4>
	<cfelseif hasMasks('CS',userVar)>
		<cfset userVar = 3>
	<cfelseif hasMasks('Consultant',userVar)>
		<cfset userVar = 1>
	<cfelseif hasMasks('Logistics',userVar)>
		<cfset userVar = 2>
	<cfelse>
		<cfset userVar = 0>
	</cfif>

	<cfreturn userVar>
</cffunction>


<cffunction name="drawSitesSelector"><!---a common function to draw all available sites, and it can do so for a single site_id or as a multiple select.--->
	<cfargument name="formElementName" default="frmSiteId">
	<cfargument name="selectedSites" type="string" default=""><!---selected sites should be in the format of "i#instance_id#s#site_id#,i#next_instance_id#s#next_site_id#"--->
	<cfargument name="multiple" type="boolean" default="0">

	<cfset var getAllSites = "">
	<cfquery datasource="#application.applicationDataSource#" name="getAllSites">
		SELECT s.site_id, s.instance_id, i.instance_name, s.site_name, s.site_long_name
		FROM vi_sites s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE s.retired = 0
		AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		ORDER BY i.instance_name ASC, s.site_long_name, s.site_name
	</cfquery>

	<select id="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>"  name="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>" <cfif multiple>multiple="true" size="15"</cfif> class="siteSelector">
	<cfoutput query="getAllSites" group="instance_id">
		<optgroup label="#instance_name#">
		<cfoutput>
			<cfset curvalue = "i#instance_id#s#site_id#">
			<option value="#curvalue#" <cfif listFind(selectedSites, curvalue)>selected</cfif>>#site_long_name#(#site_name#)</option>
		</cfoutput>
		</optgroup>
	</cfoutput>
	</select>
</cffunction>


<cffunction name="drawLabsSelector"><!---a common function to draw all available labs, and it can do so for a single lab_id or as a multiple select.--->
	<cfargument name="formElementName" default="frmLabId">
	<cfargument name="selectedLabs" type="string" default=""><!---selected labs should be in the format of "i#instance_id#l#lab_id#,i#next_instance_id#s#next_site_id#"--->
	<cfargument name="multiple" type="boolean" default="0">
	<cfargument name="blankOption" type="boolean" default="0"> <!--- adds a blank default option --->

	<cfset var getAllLabs = "">
	<cfquery datasource="#application.applicationDataSource#" name="getAllLabs">
		SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name
		FROM vi_labs_sites ls /*only labs that we have paired to STC sites*/
		INNER JOIN vi_labs l
			ON l.instance_id = ls.instance_id
			AND l.lab_id = ls.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = ls.instance_id
		WHERE l.active = 1
		AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
	</cfquery>

	<select id="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>"  name="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>" <cfif multiple>multiple="true" size="15"</cfif> class="siteSelector">
	<cfoutput query="getAllLabs" group="instance_id">
		<cfif blankOption><option value="i0l0"></option></cfif>
		<optgroup label="#instance_name#">
		<cfoutput group="building_name">
			<optgroup label="&nbsp;&nbsp;&nbsp;&nbsp;#htmlEditFormat(building_name)#">
			<cfoutput>
				<cfset curvalue = "i#instance_id#l#lab_id#">
				<option value="#curvalue#" <cfif listFind(selectedLabs, curvalue)>selected</cfif>>&nbsp;&nbsp;&nbsp;&nbsp;#lab_name#</option>
			</cfoutput>
			</optgroup>
		</cfoutput>
		</optgroup>
	</cfoutput>
	</select>
</cffunction>

<cffunction name="drawLabsSelectorByInstance"><!---a common function to draw all available labs, and it can do so for a single lab_id or as a multiple select.--->
	<cfargument name="formElementName" default="frmLabId">
	<cfargument name="selectedLabs" type="string" default=""><!---selected labs should be in the format of "i#instance_id#l#lab_id#,i#next_instance_id#s#next_site_id#"--->
	<cfargument name="multiple" type="boolean" default="0">
	<cfargument name="blankOption" type="boolean" default="0"> <!--- adds a blank default option --->

	<cfset var getAllLabs = "">

	<cfquery datasource="#application.applicationDataSource#" name="getAllLabs">
		SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name
		FROM vi_labs_sites ls /*only labs that we have paired to STC sites*/
		INNER JOIN vi_labs l
			ON l.instance_id = ls.instance_id
			AND l.lab_id = ls.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = ls.instance_id
		WHERE l.active = 1
		<cfif session.primary_instance NEQ 0>
			AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		<cfelse>
			AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		</cfif>
		ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
	</cfquery>

	<select id="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>"  name="<cfoutput>#htmlEditFormat(formElementName)#</cfoutput>" <cfif multiple>multiple="true" size="15"</cfif> class="siteSelector">
		<cfoutput query="getAllLabs" group="instance_id">
			<cfif blankOption><option value="i0l0">---</option></cfif>
			<optgroup label="#instance_name#">
			<cfoutput group="building_name">
				<optgroup label="&nbsp;&nbsp;&nbsp;&nbsp;#htmlEditFormat(building_name)#">
				<cfoutput>
					<cfset curvalue = "i#instance_id#l#lab_id#">
					<option value="#curvalue#" <cfif listFind(selectedLabs, curvalue)>selected</cfif>>&nbsp;&nbsp;&nbsp;&nbsp;#lab_name#</option>
				</cfoutput>
				</optgroup>
			</cfoutput>
			</optgroup>
		</cfoutput>
	</select>

</cffunction>

<!---Parses an absolute lab that includes "i instance_id l lab_id" Ex: i1l2--->
<cffunction name="parseLabName">
	<cfargument name="n" type="string" required="true"><!---n should be something like "i1s25"--->
	<cfset var siteStruct = structNew()>
	<cfset var instanceId = "">
	<cfset var labId = "">


	<cftry>
		<!---find the instanceId--->
		<cfset instanceId = mid(n, find("i", n)+1, (find("l", n) - 1 - find("i", n)))>
		<!---find the siteId, depending where it is in the list--->
		<cfset labId = right(n, len(n) - find("l", n))>
		<!---at this point we should have a valid instanceID and labId, if we do add them to the structure, and add that structure to the array.--->
		<cfif isNumeric(instanceId) AND isNumeric(labId)>
			<cfset siteStruct['instance'] = instanceId>
			<cfset siteStruct['lab'] = labId>
		<cfelse>
			<cfset siteStruct['instance'] = 0>
			<cfset siteStruct['lab'] = 0>
		</cfif>

	<cfcatch type="any">
		<!---if we encounter any sort of error return 0, 0--->
		<cfset siteStruct['instance'] = 0>
		<cfset siteStruct['lab'] = 0>
	</cfcatch>
	</cftry>

	<cfreturn siteStruct>
</cffunction>

<cffunction name="getLabsById"><!---now a function to return a query of lab data based on the value from a drawlabsSelector value--->
	<cfargument name="labList" type="string" default="">

	<cfset var labsArray = arrayNew(1)>
	<cfset var labStruct = "">
	<cfset var n = "">
	<cfset var getlabs = "">

	<cfloop list="#labList#" index="n">
		<cfset labStruct = parseLabName(n)>

		<cfset arrayAppend(labsArray, labStruct)>
	</cfloop>

	<cfquery datasource="#application.applicationDataSource#" name="getlabs">
		SELECT l.instance_id, i.instance_name, l.lab_id, l.lab_name, b.building_name, l.active
		FROM vi_labs l
		INNER JOIN tbl_instances i ON i.instance_id = l.instance_id
		LEFT OUTER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		<!---if there are no items in the array return no rows--->
		WHERE 1 = 0
		<cfloop array="#labsArray#" index="n">
			OR (l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#n['instance']#"> AND l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#n['lab']#">)
		</cfloop>
	</cfquery>

	<cfreturn getLabs>
</cffunction>

<cffunction name='drawSemesterSelector'><!---Draws a select box with "semester" as the name that allows the user to pick the semester--->
	<cfargument name='semesterOptions' default="future">
	<cfargument name='semesterCount' default=10>
	<cfargument name="instanceId" type="numeric" default="0">
	<cfargument name="semesterId" type="numeric" default="0">

	<cfset var getAllSemesters = "">

	<!---now we can fetch all the semesters that apply to this user that are of the types we are interested in.--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllSemesters">
		SELECT
		<cfif isValid('integer', semesterCount)>
			TOP (<cfqueryparam cfsqltype="cf_sql_integer" value="#semesterCount#" list="true">)
		</cfif>
		i.instance_id, i.instance_name, i.instance_mask, s.semester_id, s.semester_name, s.start_date, s.end_date
		FROM vi_semesters s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)/*this limits us to semesters the user can view*/
		AND s.semester_name IN ('Fall','Spring','Summer')/*this is not always desireable, and is likely to change in the future, you'd probably be better off limitting to semesters of a certain length - and making doing so optional.*/
		<cfif semesterOptions EQ "future">
			AND s.end_date >= GETDATE()
			ORDER BY start_date ASC
		<cfelseif semesterOptions EQ "past">
			AND s.start_date <= GETDATE()
			ORDER BY start_date DESC
		</cfif>
	</cfquery>

	<!---this is a little confusing, but we need to do a second query, the first one limitted us to the 'semesterCount' most recent semesters, now do a query of queries to put them in the correct order for grouping.--->
	<cfquery dbtype="query" name="getAllSemesters">
		SELECT *
		FROM getAllSemesters
		ORDER BY instance_name, start_date <cfif semesterOptions eq "past">DESC<cfelse>ASC</cfif>
	</cfquery>

	<label>Semester:
		<select name="frmSemester">
		<cfoutput query="getAllSemesters" group="instance_id">
			<optgroup label="#htmlEditFormat(instance_name)#">
			<cfoutput>
				<option value="i#instance_id#s#semester_id#" <cfif instanceId eq instance_id AND semesterId eq semester_id>selected</cfif>>#semester_name# #dateFormat(start_date, "yyyy")# (#dateFormat(start_date, "mm/dd")# to #dateFormat(end_date, "mm/dd")#)</option>
			</cfoutput>
			</optgroup>
		</cfoutput>
		</select>
	</label>
</cffunction>

<!---Parses an absolute site than includes "i instance_id s site_id" Ex: i1s2--->
<cffunction name="parseSitename">
	<cfargument name="n" type="string" required="true"><!---n should be something like "i1s25"--->
	<cfset var siteStruct = structNew()>
	<cfset var instanceId = "">
	<cfset var siteId = "">


	<cftry>
		<!---find the instanceId--->
		<cfset instanceId = mid(n, find("i", n)+1, (find("s", n) - 1 - find("i", n)))>
		<!---find the siteId, depending where it is in the list--->
		<cfset siteId = right(n, len(n) - find("s", n))>
		<!---at this point we should have a valid instanceID and siteId, if we do add them to the structure, and add that structure to the array.--->
		<cfif isNumeric(instanceId) AND isNumeric(siteId)>
			<cfset siteStruct['instance'] = instanceId>
			<cfset siteStruct['site'] = siteId>
		<cfelse>
			<cfset siteStruct['instance'] = 0>
			<cfset siteStruct['site'] = 0>
		</cfif>

	<cfcatch type="any">
		<!---if we encounter any sort of error return 0, 0--->
		<cfset siteStruct['instance'] = 0>
		<cfset siteStruct['site'] = 0>
	</cfcatch>
	</cftry>

	<cfreturn siteStruct>
</cffunction>

<!---Parses an absolute route than includes "i instance_id r route_id" Ex: i1r2--->
<cffunction name="parseRoute">
	<cfargument name="n" type="string" required="true"><!---n should be something like "i1r25"--->
		<cfset var routeStruct = structNew()>
		<cfset var instanceId = "">
		<cfset var routeId = "">

		<!---set defaults for our struct--->
		<cfset routeStruct.instance = 0>
		<cfset routeStruct.route = 0>

		<cftry>
			<!---find the instanceId--->
			<cfset instanceId = mid(n, find("i", n)+1, (find("r", n) - 1 - find("i", n)))>
			<!---find the route, depending where it is in the list--->
			<cfset routeId = right(n, len(n) - find("r", n))>
			<!---at this point we should have a valid instanceID and route, if we do add them to the structure, and add that structure to the array.--->
			<cfif isNumeric(instanceId) AND isNumeric(routeId)>
				<cfset routeStruct['instance'] = instanceId>
				<cfset routeStruct['route'] = routeId>
			<cfelse>
				<cfset routeStruct['instance'] = 0>
				<cfset routeStruct['route'] = 0>
			</cfif>
		<cfcatch><!---just fail silently---></cfcatch>
		</cftry>
		<cfreturn routeStruct>
</cffunction>

<cffunction name='displayUserSpecial'><!---Used for user selections.--->
	<cfargument name='userId'>
	<cfquery name='showUser' datasource="#application.applicationDataSource#">
		SELECT username, preferred_name, picture_source
		FROM tbl_users
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#userId#">
	</cfquery>
	<cfoutput query='showUser'>
		<div class='block-card' style='width:140px;'>
			<img src="#picture_source#" width="120px" style='margin:5px 0px;'/>
			<div class='name'>(#username#)
			</div>
			<div class='name'>#preferred_name#
			</div>
		</div>
	</cfoutput>
</cffunction>

<cffunction name="getSitesById"><!---now a function to return a query of site data based on the value from a drawSitesSelector value--->
	<cfargument name="sitesList" type="string" default="">

	<cfset var sitesArray = arrayNew(1)>
	<cfset var siteStruct = "">
	<cfset var n = "">
	<cfset var instanceId = "">
	<cfset var siteId = "">
	<cfset var getSites = "">


	<cfloop list="#sitesList#" index="n">
		<!---n at this point shoudl be something like "i1s25"--->
		<cfset siteStruct = structNew()>

		<!---find the instanceId--->
		<cfset instanceId = mid(n, find("i", n)+1, (find("s", n) - 1 - find("i", n)))>

		<!---find the siteId, depending where it is in the list--->
		<cfset siteId = right(n, len(n) - find("s", n))>

		<!---at this point we should have a valid instanceID and siteId, if we do add them to the structure, and add that structure to the array.--->
		<cfif isNumeric(instanceId) AND isNumeric(siteId)>
			<cfset siteStruct['instance'] = instanceId>
			<cfset siteStruct['site'] = siteId>

			<cfset arrayAppend(sitesArray, siteStruct)>
		</cfif>

	</cfloop>

	<cfquery datasource="#application.applicationDataSource#" name="getSites">
		SELECT s.instance_id, i.instance_name, s.site_id, s.site_name, s.site_long_name, s.retired
		FROM vi_sites s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		<!---if there are no items in the array return no rows--->
		WHERE 1 = 0
		<cfloop array="#sitesArray#" index="n">
			OR (s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#n['instance']#"> AND s.site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#n['site']#">)
		</cfloop>
	</cfquery>

	<cfreturn getSites>
</cffunction>


<!---Location functions from PIE--->

<!---take an ip address and return the lab name(s)of the applicable labs by finding the workstation_id of the ip address.--->
<cffunction name="ipToLabs" output="false">
	<cfargument name="ipAddress" type="string" required="true">
	<cfset var wsName = ipToWorkstationName(ipAddress)>
	<cfset var labName = "">
	<cfset var getBuildings = "">
	<cfset var buildingList = "???"><!---default is we don't know where the user is.--->


	<cfif listLen(wsName, "-") eq 3 AND (left(wsName, 4) eq "STC-" OR left(wsName, 5) eq "IULB-")><!---It looks like we have a legit stc workstation name, eg. stc-bh308-4, try to match it to a lab.--->
		<cfset labName = listGetAt(wsName, 2, "-")><!---computer names are in the format "STC-labname-tableNumber"--->
		<cfquery datasource="#application.applicationDataSource#" name="getBuildings">
			SELECT DISTINCT l.lab_name
			FROM vi_labs l
			INNER JOIN vi_buildings b
				ON l.instance_id = b.instance_id
				AND b.building_id = l.building_id
			WHERE l.lab_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#labName#">
		</cfquery>

		<!---if we found building blank our buildingList, and then build it up.--->
		<cfif getBuildings.recordCount gt 0>
			<cfset buildingList = "">
		<cfelse>
			<!---we found a workstation, and have data that should be a building, but didn't find a matching lab.  Return the "labName"--->
			<cfset buildingList = left(lcase(labName), iif(5 lt len(labName), len(labName), 5))><!---labs are in the format xxnnn, make sure we catch as much of it as we can.--->
		</cfif>
		<cfloop query="getBuildings">
			<cfset buildingList = listAppend(buildingList, lcase(lab_name))>
		</cfloop>

	<cfelseif wsName neq "Unknown">
		<!---we found a legitimate workstation, but can't find a building for it--->
		<cfset var buildingList = "STC">
	</cfif>

	<cfreturn buildingList>
</cffunction>

<cffunction name="ipToWorkstation" output="false"><!---this function takes an IP address and returns the workstation_id, 0 if no match is found.--->
	<cfargument name="guest_ip">

	<cfset var getWorkStation = "">
	<cfset var myWS = 0>

	<cfquery datasource="#application.applicationDataSource#" name="getWorkStation">
		SELECT workstation_id
		FROM vi_workstations_ips
		WHERE workstation_ip = <cfqueryparam cfsqltype="cf_sql_varchar" value="#guest_ip#">
	</cfquery>
	<cfloop query="getWorkStation">
		<cfset myWS = workstation_id>
	</cfloop>

	<cfreturn myWS>
</cffunction>

<cffunction name="ipToWorkstationName" output="false"><!---return the name of a workstation, not just its ID.--->
	<cfargument name="guest_ip">

	<cfset var getWorkStation = "">
	<cfset var myWS = "Unknown">

	<cfquery datasource="#application.applicationDataSource#" name="getWorkStation">
		SELECT w.workstation_name
		FROM vi_workstations_ips wi
		INNER JOIN vi_workstations w
			ON w.instance_id = wi.instance_id
			AND w.workstation_id = wi.workstation_id
		WHERE wi.workstation_ip = <cfqueryparam cfsqltype="cf_sql_varchar" value="#guest_ip#">
	</cfquery>
	<cfloop query="getWorkStation">
		<cfset myWS = workstation_name>
	</cfloop>

	<!---we only want the hostname, not the extra domain info.--->
	<cfset myWS = shortWorkstationName(myWS)>

	<cfreturn myWS>
</cffunction>


<cffunction name="ipToLabId" output="false">
	<cfargument name="ipAddress" type="string" required="true">
	<cfset var wsName = ipToWorkstationName(ipAddress)>
	<cfset var labName = "">
	<cfset var getLab = "">
	<cfset var labId = 0>

	<cfif listLen(wsName, "-") eq 3><!---It looks like we have a legit stc workstation name, try to match it to a lab.--->
		<cfset labName = listGetAt(wsName, 2, "-")><!---computer names are in the format "STC-labname-tableNumber"--->
		<cfquery datasource="#application.applicationDataSource#" name="getLab">
			SELECT l.lab_id
			FROM vi_labs l
			WHERE l.lab_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#labName#">
		</cfquery>

		<cfloop query="getLab">
			<cfset labId = lab_id>
		</cfloop>
	</cfif>

	<cfreturn labId>
</cffunction>

<cffunction name="shortWorkstationName" output="false"><!---from LDAP we get a FQDN for each workstation, we really just want a hostname, this trims it down for us.--->
	<cfargument name="wsName" type="string" required="true">
	<cfset var shortName = "Unknown">

	<cfif trim(wsName) neq "">
		<cfset shortName = listGetAt(wsName, 1, ".")>
	</cfif>

	<cfreturn shortName>
</cffunction>

<!---end of PIE's location functions--->


<!---functions for fetching semesters.--->
<cffunction name="getSemesterById">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="semId" type="Numeric" required="true">

	<cfset var getSemester = "">
	<cfset var semStruct = structNew()>

	<cfquery datasource="#application.applicationDataSource#" name="getSemester">
		SELECT s.semester_id, s.start_date, s.end_date, s.semester_code_id, s.semester_name, i.instance_name
		FROM vi_semesters s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND s.semester_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#semId#">
	</cfquery>

	<cfloop query="getSemester">
		<cfset semStruct['semester_id'] = semester_id>
		<cfset semStruct['start_date'] = start_date>
		<cfset semStruct['end_date'] = end_date>
		<cfset semStruct['semester_code_id'] = semester_code_id>
		<cfset semStruct['semester_name'] = semester_name>
		<cfset semStruct['instance_id'] = instanceId>
		<cfset semStruct['instance_name'] = instance_name>
	</cfloop>

	<cfif structIsEmpty(semStruct)>
		<p>An error was encountered when executing getSemesterById(<cfoutput>#instanceId#,#semId#</cfoutput>)</p>
		<cfabort>
	</cfif>

	<cfreturn semStruct>
</cffunction>

<!---find the most recent semester, given by a date, keep in mind that some end_dates and start_dates appear to overlap--->
<cffunction name="getSemesterByDate">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="date" type="Date" required="false" default="#now()#">

	<cfset var getSemester = "">
	<cfset var semStruct = structNew()>

	<!---the top and order by are to ensure we only return the most specific semester matching our criteria--->
	<cfquery datasource="#application.applicationDataSource#" name="getSemester">
		SELECT TOP 1 s.semester_id, s.start_date, s.end_date, s.semester_code_id, s.semester_name, i.instance_name
		FROM vi_semesters s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND s.start_date <= <cfqueryparam cfsqltype="cf_sql_date" value="#date#">
		AND s.end_date >= <cfqueryparam cfsqltype="cf_sql_date" value="#date#">
		ORDER BY s.end_date DESC
	</cfquery>

	<cfloop query="getSemester">
		<cfset semStruct['semester_id'] = semester_id>
		<cfset semStruct['start_date'] = start_date>
		<cfset semStruct['end_date'] = end_date>
		<cfset semStruct['semester_code_id'] = semester_code_id>
		<cfset semStruct['semester_name'] = semester_name>
		<cfset semStruct['instance_id'] = instanceId>
		<cfset semStruct['instance_name'] = instance_name>
	</cfloop>

	<cfif structIsEmpty(semStruct)>
		<p>An error was encountered when executing getSemesterByDate(<cfoutput>#date#</cfoutput>), no matching semester was found.</p>
		<cfabort>
	</cfif>

	<cfreturn semStruct>
</cffunction>

<cffunction name="getNextSemesterById">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="semId" type="numeric" required="true">

	<cfset var getSemester = "">
	<cfset var semStruct = structNew()>
	<cfset var prevSemester = getSemesterById(instanceId, semId)>

	<!---here we could maybe use getSemesterByDate, but this handles an overlaps a bit more robustly.--->
	<cfquery datasource="#application.applicationDataSource#" name="getSemester">
		SELECT TOP 1 s.semester_id, s.start_date, s.end_date, s.semester_code_id, s.semester_name, i.instance_name
		FROM vi_semesters s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE s.start_date >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#prevSemester['end_date']#">
		ORDER BY s.start_date ASC
	</cfquery>

	<cfloop query="getSemester">
		<cfset semStruct['semester_id'] = semester_id>
		<cfset semStruct['start_date'] = start_date>
		<cfset semStruct['end_date'] = end_date>
		<cfset semStruct['semester_code_id'] = semester_code_id>
		<cfset semStruct['semester_name'] = semester_name>
		<cfset semStruct['instance_id'] = instanceId>
		<cfset semStruct['instance_name'] = instance_name>
	</cfloop>

	<!---if there are no results, just return the provided semester.--->
	<cfif getSemester.recordCount eq 0>
		<cfset semStruct = prevSemester>
	</cfif>

	<cfreturn semStruct>
</cffunction>

<cffunction name="getPrevSemesterById">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="semId" type="numeric" required="true">

	<cfset var getSemester = "">
	<cfset var semStruct = structNew()>
	<cfset var prevSemester = getSemesterById(instanceId, semId)>

	<!---here we could maybe use getSemesterByDate, but this handles an overlaps a bit more robustly.--->
	<cfquery datasource="#application.applicationDataSource#" name="getSemester">
		SELECT TOP 1 s.semester_id, s.start_date, s.end_date, s.semester_code_id, s.semester_name, i.instance_name
		FROM vi_semesters s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		WHERE s.start_date < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#prevSemester['start_date']#">
		ORDER BY s.start_date DESC
	</cfquery>

	<cfloop query="getSemester">
		<cfset semStruct['semester_id'] = semester_id>
		<cfset semStruct['start_date'] = start_date>
		<cfset semStruct['end_date'] = end_date>
		<cfset semStruct['semester_code_id'] = semester_code_id>
		<cfset semStruct['semester_name'] = semester_name>
		<cfset semStruct['instance_id'] = instanceId>
		<cfset semStruct['instance_name'] = instance_name>
	</cfloop>

	<!---if there are no results, just return the provided semester.--->
	<cfif getSemester.recordCount eq 0>
		<cfset semStruct = prevSemester>
	</cfif>

	<cfreturn semStruct>
</cffunction>
<!---end of semester functions--->

<!---limits a string to a certain number of characters while not truncating mid-word--->
<cffunction name="trimString" output="false">
	<cfargument name="stringGiven" type="string" required="true">
	<cfargument name="stringLength" type="numeric" required="true">
	<cfif len(stringGiven) gt stringLength>
		<cfset stringGiven = trim(left(stringGiven, stringLength))>
		<cfset splitWord = ListLast(stringGiven, " ")>
		<cfset stringGiven = trim(left(stringGiven, len(stringGiven)-len(splitword)))&"..." >
	</cfif>
	<cfreturn stringGiven>
</cffunction>

<!---remove HTML/XML tags from a string and return what's left.--->
<cffunction name="stripTags" output="false">
	<cfargument name="answer" type="string" required="true">
	<cfset var newAnswer = ReReplaceNoCase(answer, '<[^>]*>','','all')>

	<cfreturn newAnswer>
</cffunction>

<!---this works just like PHP's nl2br(), give it a string and it turns hard returns into <br/> tags.--->
<cffunction name="nl2br">
	<cfargument name="myString" type="string" required="true">

	<cfset var newString = replace(myString, "#chr(10)##chr(13)#", "<br/>", "all")>

	<cfreturn newString>
</cffunction>

<!---Often undeeded XML metadata hitches a ride when text is pasted from MS Word, this strips that away--->
<cffunction name="stripMSXML">
	<cfargument name="answer" type="String" required="true">
	<cfset var newAnswer = answer>
	<cfset var tempNewAnswer = "">
	<cfset var startIndex = 1><!---start of msxml, set to 1 for use with the following CFLOOP--->
	<cfset var endIndex = 0><!---end of msxml--->

	<cfloop condition="startIndex NEQ 0">
		<cfset startIndex = find("<!--[if gte mso ", newAnswer)>
		<cfif startIndex>
			<cfset endIndex = find("<![endif]-->", newAnswer, startIndex)>
			<cfif endIndex>
				<!---trim out the space between startIndex and endIndex--->
				<cfset tempNewAnswer = mid(newAnswer, 1, startIndex-1)><!---store everything from before the MSXML--->
				<!---unless we've hit the end of the text append the remaining text after the msxml we just removed.--->
				<cfif len(newAnswer) - (endIndex + 11) gt 0>
					<cfset tempNewAnswer = tempNewAnswer & right(newAnswer, len(newAnswer) - (endIndex + 11))><!---11 corresponds to the length of "<![endif]-->".--->
				</cfif>

				<cfset newAnswer = tempNewAnswer>
			</cfif>
		</cfif>
	</cfloop>

	<!---sometimes chrome inserts zero-width-space characters from ckeditor.  These are a pain.  Strip them out, too--->
	<cfset newAnswer = replaceNoCase(newAnswer, chr(8203), "", "all")>

	<cfreturn newAnswer>
</cffunction>


<!---functions for drawing a common multi-mask selector--->
<!---functions used for generating a common multi-mask selector.  Requires javascript functions in common.js--->
<cffunction name="drawMasksSelector">
	<cfargument name="formName" type="string" required="true"><!---NB: The form name is used for element id's so each one MUST be unique on a given page.--->
	<cfargument name="selectedMasks" type="string" default="9"><!---a list of masks already selected.  By default select the "consultant" mask.--->
	<cfargument name="myLabel" type="string" default="#formName#">
	<cfargument name="myHelp" type="string" default="">

	<cfset var getAllMaskRelations = "">
	<cfset var maskStruct = "">
	<cfset var availList = arrayNew(1)>
	<cfset var usedList = arrayNew(1)>
	<cfset var allMasks = arrayNew(1)>

	<!---we also want a mask of all the masks in relationships, and if our user has them, to drawChildMaskOptions()--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelations">
		SELECT DISTINCT um.mask_id, um.mask_name, um.mask_name, um.mask_notes,
			CASE
				WHEN mr.mask_id IS NULL THEN 0
				ELSE mr.mask_id
			END AS parent_mask_id,
			CASE
				WHEN umm.user_id  IS NULL THEN 0
				ELSE 1
			END AS user_has_mask
		FROM tbl_user_masks um
		LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
		LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
		LEFT OUTER JOIN tbl_users_masks_match umm
			ON umm.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			AND umm.mask_id = um.mask_id

		ORDER BY um.mask_name
	</cfquery>

	<cfset var masksObj = makeMaskObj(getAllMaskRelations, 0)>

	<cfoutput>
		<div class="form-group #formName#"></div>
	<!---remember those arrays we built earlier?  We're going to try to append them to our select for future use.--->
	<script type="text/javascript">
		$(document).ready(function(){
				var #formName#Obj = new MultiChoiceSelectElement("div.#formName#", "#formName#", "", #serializeJSON(masksObj)#, #serializeJSON(listToArray(selectedMasks))#);
				//now make sure the label is what we actually want the user to see.
				#formName#Obj.setLabel("#htmlEditFormat(myLabel)#", "#htmlEditFormat(myHelp)#");
			});
		</script>
	</cfoutput>


</cffunction>

<cffunction name="makeMaskObj">
	<cfargument name="getAllMaskRelations" type="query" required="true">
	<cfargument name="parentId" type="numeric" required="true">
	<cfargument name="indentLevel" type="numeric" default="0">

	<cfset var myMaskArray = arrayNew(1)>
	<cfset var childMasks = arrayNew(1)>
	<cfset var myMask = structNew()>
	<cfset var i = "">

	<cfloop query="getAllMaskRelations">
		<cfif parent_mask_id eq parentId><!---limit to masks belonging to this parent--->
			<cfif user_has_mask><!---but only masks our user actually has should be added.--->
				<cfset myMask = structNew()>

				<cfset myMask["name"] = mask_name>
				<cfset myMask["value"] = mask_id>

				<!---prepend spaces for each indentLevel--->
				<cfloop from="1" to="#indentLevel#" index="i">
					<cfset myMask['name'] = "&nbsp;&nbsp;" & myMask['name']>
				</cfloop>

				<!---Add myMask to myMaskArray--->
				<cfset arrayAppend(myMaskArray, myMask)>

				<!---get any child masks for the mask our user has--->
				<cfset childMasks = makeMaskObj(getAllMaskRelations, mask_id, indentLevel + 1)>
				<cfif arrayLen(childMasks) gt 0>
					<cfset arrayAppend(myMaskArray, childMasks, true)>
				</cfif>

			<cfelse>
				<!---now hunt for any child masks that our user might have even though they don't have THIS parent.--->
				<cfset childMasks = makeMaskObj(getAllMaskRelations, mask_id, indentLevel)>
				<cfif arrayLen(childMasks) gt 0>
					<cfset arrayAppend(myMaskArray, childMasks, true)>
				</cfif>
			</cfif>
		</cfif>
	</cfloop>

	<cfreturn myMaskArray>
</cffunction>

<!---end multi-mask selector.--->


<!---Document Category functions--->
<!---a function to fetch all categories from the databse.--->
<cffunction name="getAllCategoriesQuery" output="false">
	<cfargument name="includeRetired" type="boolean" default="1">
	<cfset var getAllCats = "">

	<cfquery datasource="#application.applicationDataSource#" name="getAllCats">
		SELECT category_id, parent_cat_id, category_name, sort_order, retired
		FROM tbl_articles_categories
		<cfif not includeRetired>
			WHERE retired = 0
		</cfif>
		ORDER BY sort_order, category_name
	</cfquery>

	<cfreturn getAllCats>
</cffunction>

<!---this function returns a query of the details of all children for a parent ID. It relies upon the global query "getAllCats"--->
<cffunction name="getChildCategoriesByParent" output="false">
	<cfargument name="parentId" type="numeric" required="true">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var getChildren = queryNew("category_id,parent_cat_id,category_name,sort_order,retired","integer,integer,varchar,integer,bit")>

	<cfloop query="allCategories">
		<cfif parentId eq parent_cat_id>
			<cfset queryAddRow(getChildren)>

			<cfset querySetCell(getChildren, "category_id", category_id)>
			<cfset querySetCell(getChildren, "parent_cat_id", parent_cat_id)>
			<cfset querySetCell(getChildren, "category_name", category_name)>
			<cfset querySetCell(getChildren, "sort_order", sort_order)>
			<cfset querySetCell(getChildren, "retired", retired)>
		</cfif>
	</cfloop>

	<cfreturn getChildren>
</cffunction>

<cffunction name="drawCategorySelect">
	<cfargument name="formName" type="string" default="frmParentId">
	<cfargument name="curVal" type="numeric" default="0"><!---the currently selected value for the select box.--->
	<cfargument name="disableList" type="string" default=""><!---the list of items that should not be selectable, because an item cannot be its own (grand)parent--->
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfoutput>
		<select name="#htmlEditFormat(formName)#" id="#htmlEditFormat(formName)#">
			<option value="0"<cfif listFind(disableList, 0)>disabled="true"</cfif>><em>No Parent</em></option>
			<!---now go through and draw options--->
			<cfset drawCategoryOptions(0, curVal, disableList, 0, allCategories)>
		</select>
	</cfoutput>
</cffunction>

<cffunction name="drawCategoryOptions">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="curVal" type="numeric" default="0"><!---the currently selected value for the select box.--->
	<cfargument name="disableList" type="string" default=""><!---the list of items that should not be selectable, because an item cannot be its own (grand)parent--->
	<cfargument name="indentLevel" type="numeric" default="0"><!---how many levels deep of recursion are we?--->
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var getChildren = getChildCategoriesByParent(parentId, allCategories)><!---call getChildren with the global getAllCats query to save DB calls--->
	<cfset var indent = "&nbsp;&nbsp;&nbsp;&nbsp;">
	<cfset var n = ""><!---protecting index of our loop--->

	<cfoutput query="getChildren">
		<option value="#category_id#" <cfif category_id eq curVal>selected</cfif> <cfif listFind(disableList, category_id)>disabled="true"</cfif> ><cfloop from="1" to="#indentLevel#" index="n">#indent#</cfloop>#category_name#</option>
		<!---draw any child categories--->
		<cfset drawCategoryOptions(category_id, curVal, disableList, indentLevel + 1, allCategories)>
	</cfoutput>
</cffunction>

<!---get a list of all unacceptable parents for a given category.--->
<cffunction name="getCategoryChildrenList" output="false">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var childList = catId><!--- by default an item cannot be its own parent.--->
	<cfset var getChildren = getChildCategoriesByParent(catId, allCategories)>

	<!---if catId is the root level we don't want that as the seed of our list.--->
	<cfif catId eq 0>
		<cfset childList = "">
	</cfif>

	<cfloop query="getChildren">
		<cfset childList = listAppend(childList, getCategoryChildrenList(category_id, allCategories))>
	</cfloop>

	<cfreturn childList>
</cffunction>

<!---get a list of all parents for a category--->
<cffunction name="getCategoryParentList" output="false">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var parentList = catId>
	<cfset var getParent = queryNew("parent_cat_id","integer")>

	<cfloop query="allCategories">
		<cfif category_id eq catId>
			<cfset queryAddRow(getParent)>
			<cfset querySetCell(getParent, "parent_cat_id", parent_cat_id)>
		</cfif>
	</cfloop>

	<!---if we've reached the top, we're done.--->
	<cfif catId eq 0>
		<cfset parentList = "">
	</cfif>

	<cfloop query="getParent">
		<cfset parentList = listAppend(parentList, getCategoryParentList(parent_cat_id, allCategories))>
	</cfloop>

	<cfreturn parentList>
</cffunction>

<cffunction name="getFormattedParentList" output="false">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var parentList = getCategoryParentList(catId, allCategories)>
	<cfset var newParentList = ""><!---the list we get is backwards, this helps us put it in the right order.--->
	<cfset var n = "">
	<cfset var getParentDetails = ""><!---as query-of-queries we'll use to draw the parent's data.--->
	<cfset var outputString = "">
	<cfset var cnt = 1>

	<!---reverse our list.--->
	<cfloop from="#listLen(parentList)#" to="1" step="-1" index="n">
		<cfset newParentList = listAppend(newParentList, listGetAt(parentList, n))>
	</cfloop>


	<cfloop list="#newParentList#" index="n">
		<cfquery dbtype="query" name="getParentDetails">
			SELECT category_name, retired
			FROM allCategories
			WHERE category_id = #n#
		</cfquery>

		<cfset outputString = outputString & " " & getParentDetails.category_name>

		<cfif getParentDetails.retired>
			<cfset outputString = outputString & "(retired)">
		</cfif>

		<cfif cnt lt listLen(newParentList)>
			<cfset outputString = outputString & " &gt; ">
		</cfif>

		<cfset cnt =  cnt + 1>
	</cfloop>

	<cfreturn outputString>
</cffunction>

<cffunction name="getInheritedOwnerMasks" output="false">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#"><!---this way we can pass the global query, or just default to a DB call.--->

	<cfset var parentCatList = getCategoryParentList(catId)><!---fetch all the parents for the provided category--->
	<cfset var getParentOwnerMasks = "">

	<cfset var parentOwners = "">

	<!---by default getCategoryParentList() appends the given catId, we don't want that in our list.
	<cftry>
		<cfset parentCatList = listDeleteAt(parentCatList, listFind(parentCatList, catId))>

		<cfcatch>
			<cfset parentCatList = "">
		</cfcatch>
	</cftry>--->

	<cfif listLen(parentCatList) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="getParentOwnerMasks">
			SELECT DISTINCT m.mask_id, m.mask_name
			FROM tbl_articles_categories_owner co
			INNER JOIN tbl_user_masks m ON m.mask_id = co.mask_id
			WHERE co.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#parentCatList#" list="true">)
		</cfquery>

		<cfloop query="getParentOwnerMasks">
			<cfset parentOwners = listAppend(parentOwners, mask_name)>
		</cfloop>
	</cfif>

	<cfreturn parentOwners>
</cffunction>

<cffunction name="getCatName">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="allCategories" type="query" default="#getAllCategoriesQuery()#">

	<cfset var catName = "">

	<cfloop query="allCategories">
		<cfif category_id EQ catId>
			<cfset catName = category_name>
		</cfif>
	</cfloop>

	<cfreturn catName>

</cffunction>

<!---End Document Category functions--->


<!---Search Indexing Functions--->
<!---indexSearchQuery is used to build up our solr search index.  Carefuly crafted queries are littered throughout the STCPAGEs whenever an article is created, revised, or deleted.--->

<!---this function takes the results of sanitizeSearchQuery and uses some java to stash int information in the Solr search index.--->
<cffunction name="indexSearchQuery">
	<cfargument name="sourceQuery" type="query" required="true">

	<cfset var mySolr = createObject("java", "org.apache.solr.client.solrj.impl.CommonsHttpSolrServer").init("http://localhost:8985/solr/v4-search")>
	<cfset var myArticle = "">
	<cfset var articlesArray = arrayNew(1)><!---an array of myArticle objects to be added to our Solr index--->
	<cfset var prefix = ""><!---is this an article or a file, preface the id with "a" or "f" to get a unique uid--->

	<cfloop query="sourceQuery">
		<cfif category eq "Files">
			<cfset prefix = "f">
		<cfelseif category eq "Site&nbsp;Map">
			<cfset prefix = "s">
		<cfelse>
			<cfset prefix = "a">
		</cfif>

		<cfscript>
			myArticle = createObject("java", "org.apache.solr.common.SolrInputDocument");

			myArticle.addField("uid", prefix & id);
			myArticle.addField("key", prefix & id);
			myArticle.addField("title", article_title);
			myArticle.addField("contents", article_body);
			myArticle.addField("required_masks", required_masks);
			myArticle.addField("url", article_url);
			myArticle.addField("revised", article_date);
			myArticle.addField("category", category);

			arrayAppend(articlesArray, myArticle);
		</cfscript>
	</cfloop>

	<!---add those articles to the solr index--->
	<cfif arrayLen(articlesArray) gt 0>
		<cfset mySolr.add(articlesArray)><!---add actually works like update, and does not create duplicates.--->
		<cfset mySolr.commit()><!---actually store them--->
		<cfset mySolr.optimize()><!---optimize the way the records are stored--->
	</cfif>
</cffunction>


<!---End Search Indexing Functions--->

<!---a function to pull user email addresses from LDAP--->
<!---use LDAP to find an IU user's correct email address.--->
<cffunction name="getUserEmail">
	<cfargument name="username" type="string" required="true">

	<cfset var userEmail = "#username#@indiana.edu">
	<cfset var user_email = "">

	<cftry>
		<cfldap name="user_email"
			username="#application.ldap_user#"
			password="#application.ldap_password#"
			action="query"
			server="ads.iu.edu"
			start="ou=accounts,dc=ads,dc=iu,dc=edu"
			filter="cn=#username#"
			attributes="mail"
			port="389"
			timeout="5000"
		>

		<cfloop query="user_email">
			<cfset userEmail = mail>
		</cfloop>

		<cfcatch type="any">
			<cfmail to="tccpie@indiana.edu" from="pie@indiana.edu" subject="LDAP Failure" type="text/html">
				<p>Failed LDAP attempt from getUserEmail('#username#').</p>
				<p>#cfcatch.message# - #cfcatch.detail#</p>
			</cfmail>
		</cfcatch>
	</cftry>

	<cfreturn userEmail>
</cffunction>

<!---strip illegal characters when returning JSON results--->
<cffunction name="jsonSanitize" output="false">
	<cfargument name="input" type="string" required="true">
	<cfset var output = htmlEditFormat(input)>

	<!---now also strip out hard returns--->
	<cfset output = replace(output, chr(10), "\n", "all")>
	<cfset output = replace(output, chr(13), "\r", "all")>
	<cfset output = replace(output, chr(9), "\t", "all")>

	<!---trim out the leading " "--->


	<cfreturn output>
</cffunction>

<!---date handling functions --->
<cffunction name="convertTimeToUtcDate" output="False">
	<cfargument name="datetime" type="date" required="true">
	<cfset datetime = dateConvert( "local2utc", datetime )>
	<cfreturn dateFormat( datetime, "yyyy-mm-dd" ) & "T" & timeFormat( datetime, "HH:mm:ss" ) & "Z">
</cffunction>

<!---
	Bootstrap input functions.
---->
<cffunction name="bootstrapTextDisplay">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myLabel" type="string" default="">
	<cfargument name="myValue" type="string" default="">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="placeholder" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>
	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var bs#myId# = new TextDisplay("div.#myId#", "#myName#", "#myHelp#", "#placeholder#");
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value
			bs#myId#.setValue("#jsStringFormat(arguments.myValue)#");
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapHiddenField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myValue" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>
	<cfoutput>
		<div class="form-group #myId#" style="display:none;"></div>
		<script type="text/javascript">
			var bs#myId# = new HiddenElement("div.#myId#", "#myName#");

			//Set its default value
			bs#myId#.setValue("#jsStringFormat(arguments.myValue)#");
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapCharField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="string" default="">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="myplaceholder" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var bs#myId# = new TextElement("div.#myId#", "#myName#", "#htmlEditFormat(myHelp)#", "#htmlEditFormat(myplaceholder)#");
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value
			bs#myId#.setValue("#jsStringFormat(myValue)#");
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapDateField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="string" default="">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="myplaceholder" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var bs#myId# = new DateElement("div.#myId#", "#myName#", "#htmlEditFormat(myHelp)#");
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value
			<cfif isDate(myValue)>
				bs#myId#.setValue("#jsStringFormat(dateFormat(myValue, 'mmm d, yyyy'))#");
			<cfelse>
				bs#myId#.setValue("#jsStringFormat(myValue)#");
			</cfif>
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapSubmitField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myValue" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var bs#myId# = new SubmitElement("div.#myId#", "#myName#", "#jsStringFormat(myValue)#")
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapEditorField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="string" default="">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="editorOptions" type="struct" default="#structNew()#">

	<cfset var myId = replace(createUUID(), "-", "", "all")>
	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var escape#myId# = document.createElement('textarea');
			escape#myId#.innerHTML = "##";
			var bs#myId# = new EditorElement("div.#myId#", "#myName#", "#myHelp#", #serializeJSON(editorOptions)#);
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value

			<!---we need to sanitize the value our user provided so it can be passed as a value to the setValue() method.--->
			var sanitizedVal = #serializeJson(arguments.myValue)#
			bs#myId#.setValue(sanitizedVal);
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapRadioField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myOptions" type="array" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="any" default="">
	<cfargument name="myHelp" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var bs#myId# = new RadioElement("div.#myId#", "#myName#", #serializeJSON(myOptions)#, "#htmlEditFormat(myHelp)#");
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			bs#myId#.setValue(#serializeJSON(myValue)#);
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapCheckField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myOptions" type="array" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="any" default="">
	<cfargument name="myHelp" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			var bs#myId# = new CheckElement("div.#myId#", "#myName#", #serializeJSON(myOptions)#, "#htmlEditFormat(myHelp)#");
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			bs#myId#.setValue(#serializeJSON(myValue)#);
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapSelectField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myOptions" type="array" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="any" default="">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="disabledItems" type="array" default="#arrayNew(1)#">

	<cfset var myId = replace(createUUID(), "-", "", "all")>
	<cfset var disableString = "">

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			//make our selector.
			var bs#myId# = new SelectElement("div.#myId#", "#myName#", #serializeJSON(myOptions)#, "#htmlEditFormat(myHelp)#");
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value
			bs#myId#.setValue(#serializeJSON(myValue)#);

			<!---now disable any options in disabledItems--->
			<cfif arrayLen(disabledItems) gt 0>
				<cfset disableString = serializeJSON(disabledItems)>
				var dis#myId# = #disableString#;

				for(var a = 0; a < dis#myId#.length; a++) {
					bs#myId#.disableOption(dis#myId#[a]);
				}
			</cfif>
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapMultiChoiceSelectField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myOptions" type="array" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="array" default="#arrayNew(1)#">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="disabledItems" type="array" default="#arrayNew(1)#">

	<cfset var myId = replace(createUUID(), "-", "", "all")>
	<cfset var disableString = "">

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			//make our selector.
			var bs#myId# = new MultiChoiceSelectElement("div.#myId#", "#myName#", "#htmlEditFormat(myHelp)#", #serializeJSON(myOptions)#)
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value
			bs#myId#.setValue(#serializeJSON(myValue)#);

			<!---now disable any options in disabledItems--->
			<cfif arrayLen(disabledItems) gt 0>
				<cfset disableString = serializeJSON(disabledItems)>
				var dis#myId# = #disableString#;

				for(var a = 0; a < dis#myId#.length; a++) {
					bs#myId#.input.disableOption(dis#myId#[a]);
				}
			</cfif>
		</script>
	</cfoutput>
</cffunction>

<cffunction name="bootstrapMultiChoiceTextField">
	<cfargument name="myName" type="string" required="true">
	<cfargument name="myLabel" type="string" default="#myName#">
	<cfargument name="myValue" type="array" default="#arrayNew(1)#">
	<cfargument name="myHelp" type="string" default="">
	<cfargument name="myPlaceholder" type="string" default="">

	<cfset var myId = replace(createUUID(), "-", "", "all")>
	<cfset var disableString = "">

	<cfoutput>
		<div class="form-group #myId#"></div>
		<script type="text/javascript">
			//make our selector.
			var bs#myId# = new MultiChoiceTextElement("div.#myId#", "#myName#", "#htmlEditFormat(myHelp)#", '', "#htmlEditFormat(myPlaceholder)#");
			//label it correctly.
			bs#myId#.setLabel("#htmlEditFormat(myLabel)#");
			//Set its default value
			bs#myId#.setValue(#serializeJSON(myValue)#);
		</script>
	</cfoutput>
</cffunction>
</cfprocessingdirective>