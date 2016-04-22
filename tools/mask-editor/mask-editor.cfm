<cfmodule template="#application.appPath#/header.cfm" title='Mask Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<h1>Mask Editor</h1>

<!---this is where we handle user input, wrap it in a cftry so we can throw folks back to the correct action handler.--->
<cfparam name="frmAction" type="string" default="View">
<cfparam name="frmMaskId" type="integer" default="0">
<cfparam name="frmMaskName" type="string" default="">
<cfparam name="frmMaskNotes" type="string" default="">
<cfparam name="frmChildMaskId" type="integer" default="0">

<!---this query will be reused in lots of places, it contains every mask, and all their relationships.--->
<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelationships">
	SELECT um.mask_id, um.mask_name, um.mask_notes,
		CASE
			WHEN mr.mask_id IS NULL THEN 0
			ELSE mr.mask_id
		END AS parent_mask_id
	FROM tbl_user_masks um
	LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
	LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
	ORDER BY um.mask_name
</cfquery>

<!---adding a new mask--->
<cftry>
	<cfif frmAction eq "addSubmit">
		<!---verify the new group's features are acceptable.--->
		<cfif len(trim(frmMaskName)) eq 0>
			<cfthrow type="custom" message="Missing Input" detail="Mask Name cannot be blank.">
		</cfif>
		<cfif find(",", frmMaskName)>
			<cfthrow type="custom" message="Bad Input" detail="Mask Name must not contain any commas.">
		</cfif>
		<cfif len(trim(frmMaskNotes)) eq 0>
			<cfthrow type="custom" message="Missing Input" detail="Mask Notes must describe who/what this mask covers.">
		</cfif>
		<cfif isNumeric(frmMaskName)>
			<cfthrow type="custom" message="Bad Input" detail="Mask Name cannot be a number, it must be a string.">
		</cfif>
		
		<!---at this point things look good, we commend this input to the database--->
		<cfquery datasource="#application.applicationDataSource#" name="addMask">
			INSERT INTO tbl_user_masks (mask_name, mask_notes)
			VALUES(<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMaskName#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMaskNotes#">)
		</cfquery>
		
		<!---if we're here it worked, find the mask_id, and take them to the editor page.--->
		<cfquery datasource="#application.applicationDataSource#" name="getNewMask">
			SELECT TOP 1 mask_id
			FROM tbl_user_masks
			ORDER BY mask_id DESC
		</cfquery>
		
		<cfloop query="getNewMask">
			<cflocation url="#cgi.script_name#?frmAction=Edit&frmMaskId=#mask_id#" addtoken="false">
		</cfloop>
		<p class="ok">
			<b>Success</b>
			Masks updated successfully.
		</p>
	</cfif>	
<cfcatch type="any">
	<cfset frmAction = "New"><!---send them back to the New Mask form.--->
	<cfoutput>
		<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.detail#
		</p>
	</cfoutput>
</cfcatch>
</cftry>

<!---edits to a mask--->
<cftry>
	<cfif frmAction eq "editSubmit">
		<!---verify the new group's features are acceptable.--->
		<cfif len(trim(frmMaskName)) eq 0>
			<cfthrow type="custom" message="Missing Input" detail="Mask Name cannot be blank.">
		</cfif>
		<cfif find(",", frmMaskName)>
			<cfthrow type="custom" message="Bad Input" detail="Mask Name must not contain any commas.">
		</cfif>
		<cfif len(trim(frmMaskNotes)) eq 0>
			<cfthrow type="custom" message="Missing Input" detail="Mask Notes must describe who/what this mask covers.">
		</cfif>
		<cfif isNumeric(frmMaskName)>
			<cfthrow type="custom" message="Bad Input" detail="Mask Name cannot be a number, it must be a string.">
		</cfif>
		
		<!---things look good, update the mask--->
		<cfquery datasource="#application.applicationDataSource#" name="updateMask">
			UPDATE tbl_user_masks
			SET mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMaskName#">,
				mask_notes = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMaskNotes#">
			WHERE mask_id = #frmMaskId#
		</cfquery>
		
		<!---It worked, so throw them back to the editor.--->
		<cflocation url="#cgi.script_name#?frmAction=Edit&frmMaskId=#frmMaskId#" addtoken="false">
	</cfif>
<cfcatch type="any">
	<cfset frmAction = "Edit"><!---send them back to the edit form--->
	<cfoutput>
		<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.detail#
		</p>
	</cfoutput>
</cfcatch>
</cftry>

<!---Add a child mask to the current mask--->
<cftry>
	<cfif frmAction eq "addMember">
		<cfif frmMaskId lte 0>
			<cfthrow message="Bad Input" detail="You must provide a valid Mask ID when adding members.">
		</cfif>
		<cfif frmChildMaskId lte 0>
			<cfthrow message="Bad Input" detail="You must provide a valid Child Mask ID when adding members.">
		</cfif>
		
		<!---at this point we have a frmMaskId and frmChildMaskId, make sure this relationship won't create a loop of permissions.--->
		<cfif alreadyInherits(frmMaskId, frmChildMaskId) OR alreadyInherits(frmChildMaskId, frmMaskId)>
			<cfthrow message="Bad Relationship" detail="The membership you have proposed already exists or would cause a permissions loop.">
		</cfif>
		
		<!---first find if there is an existing relationship. for frmMaskId--->
		<cfset relId = 0>
		<cfquery datasource="#application.applicationDataSource#" name="getRelationship">
			SELECT relationship_id
			FROM tbl_mask_relationships
			WHERE mask_id = #frmMaskid#
		</cfquery>
		
		<cfloop query="getRelationship">
			<cfset relId = relationship_id>
		</cfloop>
		
		<!---if there isn't one, create one to use.--->
		<cfif relId eq 0>
			<cfquery datasource="#application.applicationDataSource#" name="createRelationship">
				INSERT INTO tbl_mask_relationships (mask_id)
				VALUES (#frmMaskId#)
			</cfquery>
			
			<cfquery datasource="#application.applicationDataSource#" name="getRelationship">
				SELECT relationship_id
				FROM tbl_mask_relationships
				WHERE mask_id = #frmMaskid#
			</cfquery>
			<cfloop query="getRelationship">
				<cfset relId = relationship_id>
			</cfloop>
		</cfif>
		
		<cfif relId eq 0>
			<cfthrow message="Error" detail="Unable to find/create the relationship needed to add member.">
		</cfif>
		
		<!---at this point we've passed all our checks, we can insert the relationship member--->
		<cfquery datasource="#application.applicationDataSource#" name="addMember">
			INSERT INTO tbl_mask_relationships_members (relationship_id, mask_id)
			VALUES (#relId#, #frmChildMaskId#)
		</cfquery>
		
		<!---now having done all that we need to add masks to people who should rightly inherit them, now.--->
		<cfquery datasource="#application.applicationDataSource#" name="addInheritedMasks">
			INSERT INTO tbl_users_masks_match (user_id, mask_id)
			SELECT u.user_id, amu.mask_id
			FROM vi_all_masks_users_old amu
			INNER JOIN tbl_users u ON u.user_id = amu.user_id
			LEFT OUTER JOIN tbl_users_masks_match umm
				ON umm.user_id = amu.user_id
				AND umm.mask_id = amu.mask_id
			WHERE umm.matchId IS NULL
		</cfquery>
		
		<!---at this point it should have worked, take us back to the edit page.--->
		<cflocation url="#cgi.script_name#?frmAction=Edit&frmMaskId=#frmMaskId#" addtoken="false">
	</cfif>
<cfcatch type="any">
	<cfset frmAction = "Edit">
	<cfoutput>
		<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.detail#
		</p>
	</cfoutput>
</cfcatch>
</cftry>


<!---Remove a child mask of the current mask--->
<cftry>
	<cfif frmAction eq "delMember">
		<cfif frmMaskId lte 0>
			<cfthrow message="Bad Input" detail="You must provide a valid Mask ID when adding members.">
		</cfif>
		<cfif frmChildMaskId lte 0>
			<cfthrow message="Bad Input" detail="You must provide a valid Child Mask ID when adding members.">
		</cfif>
		
		<!---before we nuke this relationship, remove any orphans that will be created as a result.--->
		<cfset removeOrphanMasks(frmChildMaskId, frmMaskId)>
		
		<!---our id's seem to check out.  remove the child from the relationship.--->
		<cfquery datasource="#application.applicationDataSource#" name="delMember">
			DELETE rm
			FROM tbl_mask_relationships_members rm
			INNER JOIN tbl_mask_relationships r ON r.relationship_id = rm.relationship_id
			WHERE r.mask_id = #frmMaskId# /*parent mask*/
			AND rm.mask_id = #frmChildMaskId# /*child mask*/
		</cfquery>
		
		<!---at this point it should have worked, take us back to the edit page.--->
		<cflocation url="#cgi.script_name#?frmAction=Edit&frmMaskId=#frmMaskId#" addtoken="false">
	</cfif>
<cfcatch type="any">
	<cfset frmAction = "Edit">
	<cfoutput>
		<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.detail#
		</p>
	</cfoutput>
</cfcatch>
</cftry>


<!---
	This is where the forms are generated for user input.
--->

<cfif frmAction eq "Edit">
	<!---make sure the provided mask exists, if it doesn't send them back to select another.--->
	<cfquery datasource="#application.applicationDataSource#" name="getMask">
		SELECT mask_id, mask_name, mask_notes
		FROM tbl_user_masks
		WHERE mask_id = #frmMaskId#
	</cfquery>
	<cfif getMask.recordCount gt 0>
		<cfloop query="getMask">
			<!---use the values from the database, but don't overwrite user input.--->
			<cfif frmMaskName eq "">
				<cfset frmMaskName = mask_name>
			</cfif>
			<cfif frmMaskNotes eq "">
				<cfset frmMaskNotes = mask_notes>
			</cfif>
		</cfloop>
		
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<input type="hidden" name="frmAction" value="editSubmit">
		<input type="hidden" name="frmMaskId" value="<cfoutput>#frmMaskId#</cfoutput>">
		<table class='stripe'>
			<tr class='titlerow'>
				<th colspan="2" align="left">Revise Mask</th>
			</tr>
			<tr>
				<td>Mask Name</td>
				<td><input type="text" name="frmMaskName" value="<cfoutput>#htmlEditFormat(frmMaskName)#</cfoutput>" placeholder="Mask Name..."></td>
			</tr>
			<tr>
				<td>Mask Notes</td>
				<td><input type="text" name="frmMaskNotes" value="<cfoutput>#htmlEditFormat(frmMaskNotes)#</cfoutput>" placeholder="About mask..."></td>
			</tr>
			<tr>
				<td colspan="2" align="center">
					<input  type="submit" value="Update">
				</td>
			</tr>
		</table>
		</form>
		
		<h3 style="margin-bottom: 0px;">Member of</h3>
		<span style="font-size: small;">This mask is automatically inherited by users with these masks.</span><br/>
		
		<!---only draw the relationship, the relationship itself must be manage from the parent!  It's much less confusing this way.--->
		
		<!---loop over getAllMaskRelationships and build up parentList with the mask_id's' of frmMaskid's parents.--->
		<cfset parentList = "0">
		<cfloop query="getAllMaskRelationships">
			<cfif mask_id eq frmMaskId AND not listFind(parentList, parent_mask_id)><!---if we've found a match, and haven't already got it's parent in parentList, add it's parent to parentList.--->
				<cfset parentList = listAppend(parentList, parent_mask_id)>
			</cfif>
		</cfloop>
		
		<!---now, with duplicates stripped out by parentList, we can loop over getAllMaskRelationships again to populate getParentMasks--->
		<cfset getParentMasks = queryNew("parent_mask_id,mask_name,mask_notes","integer,varchar,varchar")>
		
		<cfloop query="getAllMaskRelationships">
			<cfif listFind(parentList, mask_id)>
				<cfset queryAddRow(getParentMasks)>
				<cfset querySetCell(getParentMasks, "parent_mask_id", mask_id)>
				<cfset querySetCell(getParentMasks, "mask_name", mask_name)>
				<cfset querySetCell(getParentMasks, "mask_notes", mask_notes)>
				
				<!---now stip out that item from parentList to prevent duplicates--->
				<cfset parentList = listDeleteAt(parentList, listFind(parentList, mask_id))>
			</cfif>
		</cfloop>
		
		<table class='stripe'>
		<cfset tableColumns = 4>
		<cfset loopCnt = 0>
		<cfoutput query="getParentMasks">
			<cfif loopCnt mod tableColumns eq 0>
				<cfif loopCnt gt 0></tr></cfif>
				<tr class='titlerow'>
			</cfif>
			<td>
				<a href="#cgi.script_name#?frmAction=Edit&frmMaskId=#parent_mask_id#" title="Edit #htmlEditFormat(mask_name)#">#mask_name#</a>
				<br/>
				<span style="font-size: small;">#mask_notes#</span>
			</td>
			<cfset loopCnt = loopCnt + 1>
		</cfoutput>
		<cfif getParentMasks.recordCount gt 0>
			</tr>
		<cfelse>
			<tr><td><em>None.</em></td></tr>
		</cfif>
		</table>
		
		<!---this is where the rubber meets the road.  Show the masks that belong to our mask, and present the ones that are available to belong to this mask.--->
		<h3 style="margin-bottom: 0px;">Members</h3>
		<span style="font-size: small;">Users with this mask automatically inherit these masks.</span><br/>
		
		<cfquery datasource="#application.applicationDataSource#" name="getChildMasks">
			SELECT m.mask_id AS child_mask_id, m.mask_name, m.mask_notes,
				CASE
					WHEN m.mask_id IN (SELECT rm.mask_id FROM tbl_mask_relationships_members rm INNER JOIN tbl_mask_relationships mr ON mr.relationship_id = rm.relationship_id WHERE mr.mask_id = #frmMaskId#) THEN 1
					ELSE 0
				END AS in_relationship
			FROM tbl_user_masks m
			/*exclude this mask from being a member of itself*/
			WHERE m.mask_id <> #frmMaskId#
			ORDER BY in_relationship DESC, mask_name
		</cfquery>
		
		<table border="1" class='stripe'>
		<cfoutput query="getChildMasks" group="in_relationship">
			<cfif loopCnt gt 0>
				</tr>
				<!---reset for the next "group" result--->
				<cfset loopCnt = 0>
			</cfif>
			<tr>
				<th colspan="#tableColumns#"><cfif in_relationship>Current<cfelse>Available</cfif></th>
			</tr>
			<cfoutput>
				<cfif loopCnt mod tableColumns eq 0>
					<cfif loopCnt gt 0></tr></cfif>
					<tr>
				</cfif>
				
				<!---weed out masks that already are inheritted by frmMaskId or the ones where child_mask_id already has frmMaskId as a member.--->
				<cfif in_relationship OR not (alreadyInherits(frmMaskId, child_mask_id) OR alreadyInherits(child_mask_id, frmMaskId))>
					<td>
						<a href="#cgi.script_name#?frmAction=Edit&frmMaskId=#child_mask_id#" title="Edit #htmlEditFormat(mask_name)#">#mask_name#</a>
						<span style="font-size: small;">
							<cfif in_relationship>
								[<a href="#cgi.script_name#?frmAction=delMember&frmMaskId=#frmMaskId#&frmChildMaskId=#child_mask_id#" onClick="return confirm('Are you sure you want to remove this mask from #htmlEditFormat(mask_name)#?');">remove</a>]
							<cfelse>
								[<a href="#cgi.script_name#?frmAction=addMember&frmMaskId=#frmMaskId#&frmChildMaskId=#child_mask_id#">add</a>]
							</cfif>
						</span>
						<br/>
						<span style="font-size: small;">#mask_notes#</span>
					</td>
					<cfset loopCnt = loopCnt + 1>
				</cfif>
			</cfoutput>
		</cfoutput>
		<cfif getChildMasks.recordCount gt 0>
			</tr>
		<cfelse>
			<tr><td><em>None.</em></td></tr>
		</cfif>
		</table>
		
		
		
		
	<cfelse>
		<p>No such mask found, please choose another.</p>
		<cfset frmAction = "View">
	</cfif>
</cfif><!---end of edit--->

<cfif frmAction eq "New">
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	<input type="hidden" name="frmAction" value="addSubmit">
	<table border="1" class='stripe'>
		<tr class='titlerow'>
			<th colspan="2" align="left">Create Mask</th>
		</tr>
		<tr>
			<td>Mask Name</td>
			<td><input type="text" name="frmMaskName" value="<cfoutput>#htmlEditFormat(frmMaskName)#</cfoutput>" placeholder="Mask Name..."></td>
		</tr>
		<tr>
			<td>Mask Notes</td>
			<td><input type="text" name="frmMaskNotes" value="<cfoutput>#htmlEditFormat(frmMaskNotes)#</cfoutput>" placeholder="About mask..."></td>
		</tr>
		<tr>
			<td colspan="2" align="center">
				<input  type="submit" value="Add">
			</td>
		</tr>
	</table>
	</form>
</cfif>

<!---no mask provided, offer to choose one.--->
<cfif frmAction eq "View">
	<!---Select a mask to edit.--->
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name, mask_notes
		FROM tbl_user_masks
		ORDER BY mask_name
	</cfquery>
	
	<cfset tableColumns = 4><!---wrap every four columns--->
	
	<table border="1" class='stripe'>
		<tr class='titlerow'>
			<th colspan="<cfoutput>#tableColumns#</cfoutput>" align="left">Select a Mask</th>
		</tr>
	<cfset loopCnt = 0>
	<cfoutput query="getAllMasks">
		<!---make a new row every time we hit tableColumns columns.--->
		<cfif loopCnt mod tableColumns eq 0>
			<cfif loopCnt gt 0></tr></cfif>
			<tr>
		</cfif>
		
		<td>
			<a href="#cgi.script_name#?frmAction=Edit&frmMaskId=#mask_id#">#mask_name#</a><br/>
			<span style="font-size: small;">#mask_notes#</span>
		</td>
		
		<cfset loopCnt = loopCnt + 1>
	</cfoutput>
	
	<cfif loopCnt gt 0>
		</tr>
	</cfif>
		<tr>
			<td colspan="<cfoutput>#tableColumns#</cfoutput>" align="center">
				<a href="<cfoutput>#cgi.script_name#?frmAction=New</cfoutput>">Create a new mask</a>
			</td>
		</tr>
	</table>
</cfif>

<cfif frmAction neq "View">
	<p>Return to <a href="<cfoutput>#cgi.script_name#</cfoutput>">Mask Editor</a></p>
</cfif>

<!---footer stuff--->
	</div>
	<div style="clear:both;"></div>
</div>
<cfmodule template="#application.appPath#/footer.cfm">


<!---this function sees if a mask already has another mask in it inheritance.  We can't have a mask made a "member of" something that is a member of it.--->
<cffunction name="alreadyInherits">
	<cfargument name="checkMask" type="numeric" required="true"><!---the parent mask--->
	<cfargument name="maskId" type="numeric" required="true"><!---the mask that might belong to the parent mask--->
	
	<cfset var parentsQuery = "">
	<cfset var found = false>
	
	
	<!---spider up the parents of our mask, if we ever encounter checkMask return true--->
	<cfset parentsQuery = getParentsByMask(maskId)>
	<!---cfdump var="#parentsQuery#"--->
	<cfloop query="parentsQuery">
		<cfif parent_mask_id eq checkMask>
			<cfset found = true>
		<cfelse>
			<!---how about in this mask's children?--->
			<cfset found = alreadyInherits(checkMask, parent_mask_id)>
		</cfif>
		
		<cfif found>
			<!---we found a match, it's true.  Get out of the loop and return true.--->
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn found>
</cffunction>


<cffunction name="getParentsByMask">
	<cfargument name="maskId" type="numeric" required="true">
	
	<cfset var getMaskParentsQuery = "">
	
	<cfquery dbtype="query" name="getMaskParentsQuery">
		SELECT DISTINCT parent_mask_id
		FROM getAllMaskRelationships
		WHERE mask_id = #maskId#
	</cfquery>
	
	
	<cfreturn getMaskParentsQuery>
</cffunction>

<!---when we delete a relationship recurs through the inheritance removing it for people who only got the mask by inheritting something we've removed.--->
<cffunction name="removeOrphanMasks">
	<cfargument name="childMaskId" type="numeric" required="true">
	<cfargument name="parentMaskId" type="numeric" required="true">
	<cfargument name="userList" type="string" default=""><!---as list of the user_id's who could have cascading permission deletions.--->
	
	<cfset var getOtherParents = "">
	<cfset var otherParentsList = "">
	<cfset var newUserList = "">
	<cfset var getGrandChildren = "">
	
	<!---it gets exciting.  Before we remove a relationship we need to remove the inherited mask for everyone who doesn't inherit it anywhere else.--->
	<cfquery datasource="#application.applicationDataSource#" name="getOtherParents">
		SELECT mr.mask_id AS parent_mask_id
		FROM tbl_mask_relationships mr
		INNER JOIN tbl_mask_relationships_members mrm ON mrm.relationship_id = mr.relationship_id
		WHERE mrm.mask_id = #childMaskId#/*the mask ID we'll be removing*/
		AND mr.mask_id <> #parentMaskId#/*the parent_mask_id, we're interested in relationships not involving it*/
	</cfquery>
	
	<!---loop over each of those, and find the users who only got childMaskId through a relationship with parentMaskId--->
	<cfloop query="getOtherParents">
		<cfset otherParentsList = listAppend(otherParentsList, parent_mask_id)>
	</cfloop>
	<br/>Other Parents:
	<cfdump var="#otherParentsList#">
	
	<!---Now we can remove the folks who shouldn't have this mask any more.--->
	<cfquery datasource="#application.applicationDataSource#" name="deleteOrphans">
		DELETE umm
		OUTPUT deleted.user_id
		FROM tbl_users_masks_match umm
	<!---if there are no other relationships, we know they must have gotten it from before.--->
	<cfif listLen(otherParentsList) gt 0>
		INNER JOIN tbl_users_masks_match umr
			ON umr.user_id = umm.user_id
		<!---this check is only needed on the first pass--->
		<cfif listLen(userList) eq 0>
			AND umr.mask_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#parentMaskId#"> /*the parent in the relationship that is being removed*/
		</cfif>
			/*now we can use a sub-query to exclude folks who get the child mask from someother relationship*/
			AND umr.user_id NOT IN (
				SELECT user_id
				FROM tbl_users_masks_match
				WHERE mask_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#otherParentsList#" list="true">)/*a list of the other parents that provide the child we want to remove*/
			)
	</cfif>
		WHERE umm.mask_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#childMaskId#">/*The child mask we will ultimately remove.*/
	<cfif listLen(userList) gt 0>
		AND umm.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userList#" list="true">)
	</cfif>
	</cfquery>
	<cfdump var="#deleteOrphans#">
	
	<!---loop over the list of users hit by deleteOrphans, and call removeOrphanMasks again for any orphans we just created for these users.--->
	<cfset newUserList = "">
	<cfloop query="deleteOrphans">
		<cfset newUserList = listAppend(newUserList, user_id)>
	</cfloop>
	<cfdump var="#newUserList#">
	<!---only recurse if we have users to follow-up on--->
	<cfif listLen(newUserList)>
		<!---fetch the children of the child we just removed, to see what new orphans we may have created.--->
		<cfquery datasource="#application.applicationDataSource#" name="getGrandChildren">
			SELECT mrm.mask_id AS grandchild_id, um.mask_name
			FROM tbl_mask_relationships mr
			INNER JOIN tbl_mask_relationships_members mrm ON mrm.relationship_id = mr.relationship_id
			INNER JOIN tbl_user_masks um ON mrm.mask_id = um.mask_id
			WHERE mr.mask_id = #childMaskId#
		</cfquery>
		<cfdump var="#getGrandChildren#">
		<cfloop query="getGrandChildren">
			<cfset removeOrphanMasks(grandchild_id, childMaskId, newUserList)><!---childMaskId becomes our new parent--->
		</cfloop>
	</cfif>
</cffunction>
