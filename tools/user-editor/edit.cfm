<cfmodule template="#application.appPath#/header.cfm" title='User Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">

		
<cfparam name="currentUserId" type="integer" default="-1">
<cfparam name="frmUsername" type="string" default="">
<cfparam name="frmLastName" type="string" default="">
<cfparam name="frmFirstName" type="string" default="">
<cfparam name="frmPreferred" type="string" default="">
<cfparam name="frmPicture" type="string" default="">
<cfparam name="frmEmail" type="string" default="">
<cfparam name="frmIgnorePie" type="boolean" default="0">
<cfparam name="frmSubmit" type="string" default="">


<cfif frmSubmit neq "addForm">
	<h1>User Editor</h1>
<cfelse>
	<h1>Add User</h1>
</cfif>

<!---Select all masks once here to save the number of database calls.  LEFT JOIN with relationships, to see if this mask has child masks..  If relationship_id is null it's just a regular mask. --->
<cfquery datasource="#application.applicationdatasource#" name="getAllMasks">
	SELECT r.relationship_id, m.mask_id AS mask_id, m.mask_name, m.mask_notes
	FROM tbl_user_masks m
	LEFT OUTER JOIN tbl_mask_relationships r ON r.mask_id = m.mask_id
	ORDER BY m.mask_name
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

<!---catch user input, remember checkboxes are picky, so we want a cfparam for all possible masks.--->

<cfparam name="frmSubmit" type="string" default="">
<!---now catch any and all masks the user might have submitted.--->
<cfloop query="getAllMasks">
	<cfparam name="frmMask#mask_id#" type="boolean" default="0">
</cfloop>

<!---handle user input, update and remove which masks are checked-off--->
<cfif frmSubmit eq "Update">
	<cftry>
		<!---verify that the user's input is good.--->
		<cfif trim(frmLastName) eq "">
			<cfthrow message="Last Name" detail="Cannot be left blank.">
		</cfif>
		
		<cfif trim(frmFirstName) eq "">
			<cfthrow message="First Name" detail="Cannot be left blank.">
		</cfif>
		
		<cfif trim(frmPreferred) eq "">
			<cfset frmPreferred = frmFirstName>
		</cfif>
		
		<cfif not isValid("email", frmEmail)>
			<cfthrow message="Email" detail="Must be a valid email address, you provided <em>#frmEmail#</em>.">
		</cfif>
		
		<cfquery name="updateUser" datasource="#application.applicationdatasource#">
			UPDATE tbl_users 
			SET 
				username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">,
				last_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmLastName#">,
				first_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFirstName#">,
				preferred_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmPreferred#">,
				picture_source = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmPicture#">,
				email = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmEmail#">,
				ignore_pie_level = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmIgnorePie#">
			WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#currentUserId#">
		</cfquery>
		
		<!---Now we can apply the masks that the viewer selected..--->
		<cfset updateMasks()>
		
		<p class="ok">
			<b>Success</b>
			Information and masks updated successfully.
		</p>
		
		<!---at this point we're done, blank all checkboxes provided by the user.--->
		<cfloop query="getAllMasks">
			<cfset "frmMask#mask_id#" = 0>
		</cfloop>
		
		<!---having finished, we can reset our action, too.--->
		<cfset frmSubmit = "">
	<cfcatch>
		<cfoutput>
			<p class="warning">
				<b>Error</b>
				#cfcatch.message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
<cfelseif frmSubmit eq "Add">
	<cftry>
		<!---we need to both validate the users input, and make sure we send them back to the correct form.
			 If a user is created we need to move to the editing form, not the creation form.
		--->
		<cfset frmSubmit = "addForm">
		
		<cfif trim(frmLastName) eq "">
			<cfthrow message="Last Name" detail="Cannot be left blank.">
		</cfif>
		
		<cfif trim(frmFirstName) eq "">
			<cfthrow message="First Name" detail="Cannot be left blank.">
		</cfif>
		
		<cfif trim(frmPreferred) eq "">
			<cfset frmPreferred = frmFirstName>
		</cfif>
		
		<cfif not isValid("email", frmEmail)>
			<cfthrow message="Email" detail="Must be a valid email address, you provided <em>#frmEmail#</em>.">
		</cfif>
		
		<!---the user's input is good, add them to the DB.--->
		<cfquery datasource="#application.applicationDataSource#" name="addUser">
			INSERT INTO tbl_users (username, last_name, first_name, preferred_name, picture_source, email, ignore_pie_level)
			OUTPUT inserted.user_id
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmLastName#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFirstName#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmPreferred#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmPicture#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmEmail#">,
				<cfqueryparam cfsqltype="cf_sql_bit" value="#frmIgnorePie#">
			)
		</cfquery>
		
		<!---at this point we've added our user, and have a user ID, switch to the edit form--->
		<cfset currentUserId = addUser.user_id>
		<cfset frmSubmit = "">
		
		<!---Now that we have our user's id, we can apply the masks that the viewer selected..--->
		<cfset updateMasks()>
		
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
<!---end of user input handling.--->


<!---our default form to select a user.--->
<p>Please select the user or <a href='<cfoutput>#cgi.script_name#?frmSubmit=addForm</cfoutput>'>create new user</a></p>
<form action='<cfoutput>#cgi.script_name#</cfoutput>' method="POST">
	<!---draw all users, past and present, in case we ever want to re-activate someone.--->
	<cfscript>drawConsultantSelector("", "", currentUserId);</cfscript>
	
	<input type="submit"  name="action" value="Select">
</form>
	
<!---Now, if a user is selected, we draw the full form for them.--->
<!---usually we want to preserve user input, only do this if we haven't already submitted the form.--->
<cfif frmSubmit eq "">
	<cfquery name="getConsultantInfo" datasource="#application.applicationDataSource#">
		SELECT user_id, username, last_name, first_name, preferred_name, picture_source, email, ignore_pie_level
		FROM tbl_users
		WHERE user_id = <cfqueryparam value="#currentUserId#" cfsqltype="CF_SQL_INTEGER">
	</cfquery>
	
	<cfloop query='getConsultantInfo'>
		<cfset frmUsername = username>
		<cfset frmLastname = last_name>
		<cfset frmFirstname = first_name>
		<cfset frmPreferred = preferred_name>
		<cfset frmPicture = picture_source>
		<cfset frmEmail = email>
		<cfset frmPicture = picture_source>
		<cfset frmIgnorePie = ignore_pie_level>
	</cfloop>
</cfif>


<!---now we can draw the form itself.--->
<cfif currentUserId gte 0 OR frmSubmit eq "addForm">	
	<!---draw the user's icon--->
	<cfscript>displayUserSpecial(currentUserId);</cfscript>
	
	<h3>
		Step 1:
		<cfif frmSubmit eq "addForm">Provide<cfelse>Change</cfif> Information
	</h3>
	
	<!---fetch all the masks currently in use by our user, and set them as checked.
		 We may have done this before when adding or updating the user, but this makes sure we're using the latest info from the DB.--->
	<cfquery datasource="#application.applicationDataSource#" name="getUserMasks">
		SELECT umm.mask_id, um.mask_name
		FROM tbl_users_masks_match umm<!---this is a SQL view I wrote that does the recursion for us on the database!--->
		INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
		WHERE umm.user_id = #currentUserId#
	</cfquery>
	<cfloop query="getUserMasks">
		<cfset "frmMask#mask_id#" = 1>
	</cfloop>
	
	
	<!---now we start drawing the form.--->
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	<input type="hidden" name="currentUserId" value="<cfoutput>#currentUserId#</cfoutput>">
	<cfoutput>
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="2">User Information</td>
		</tr>
		
		<tr>
			<td>
				<label for="frmUsername">Username:</label>
			</td>
			<td>
				<input style='width:175px;' type="text" id="frmUsername" name="frmUsername" value="#htmlEditFormat(frmUsername)#"/>
			</td>
		</tr>
		
		<tr>
			<td>
				<label for="frmLastName">Last Name:</label>
			</td>
			<td>
				<input style='width:175px;' type="text" id="frmLastName" name="frmLastName" value="#htmlEditFormat(frmLastName)#"/>
			</td>
		</tr>
		
		<tr>
			<td>
				<label for="frmFirstName">First Name:</label>
			</td>
			<td>
				<input style='width:175px;' type="text" id="frmFirstName" name="frmFirstName" value="#htmlEditFormat(frmFirstName)#"/>
			</td>
		</tr>
		
		<tr>
			<td>
				<label for="frmPreferred">Display Name:</label>
			</td>
			<td>
				<input style='width:175px;' type="text" id="frmPreferred" name="frmPreferred" value="#htmlEditFormat(frmPreferred)#"/>
			</td>
		</tr>
		
		<tr>
			<td>
				<label for="frmEmail">Email:</label>
			</td>
			<td>
				<input style='width:175px;' type="text" id="frmEmail" name="frmEmail" value="#htmlEditFormat(frmEmail)#"/>
			</td>
		</tr>
		
		<tr>
			<td>
				<label for="frmPicture">Picture Source:</label>
			</td>
			<td>
				<input style='width:500px;' type="text" id="frmPicture" name="frmPicture" value="#htmlEditFormat(frmPicture)#"/>
			</td>
		</tr>
		
		<tr>
			<td colspan="2">
				<fieldset>
					<legend>Ignore PIE Level:</legend>
					<label title="Do NOT update the user's status based on information from PIE.">
						<input type="radio" name="frmIgnorePIe" value="1" <cfif frmIgnorePIe>checked="true"</cfif>> Yes
					</label>
					<label title="Update the user's status based on information from PIE.">
						<input type="radio" name="frmIgnorePIe" value="0" <cfif not frmIgnorePIe>checked="true"</cfif>> No
					</label>
				</fieldset>
			</td>
		</tr>
	</table>
	</cfoutput>
	
	
	<!---do a sub-query to just return masks that have relationships.--->
	<cfquery dbtype="query" name="getCategories">
		SELECT *
		FROM getAllMasks
		WHERE relationship_id IS NOT NULL
	</cfquery>
	
	
	<h3>Step 2: Edit Permission Masks</h3>
	<blockquote>
		<!---first draw all the categories and mention what masks come included.--->
		<cfoutput query="getCategories">
			<!---was this item checked off because of a parent?  If so we want to disable it, and show why it's checked.--->
			<cfset parentString = "">
			
			<cfloop query="getAllMaskRelationships">
				<!---loop until we find a relationship that the mask we're drawing belongs to.--->
				<cfif getAllMaskRelationships.mask_id eq getCategories.mask_id AND getAllMaskRelationships.parent_id neq 0 AND getAllMaskRelationships.parent_id neq getCategories.mask_id>
					<!---having found the parent, add its name to parentString--->
					<cfloop query="getUserMasks">
						<!---if the user has this parent mask, add it's name to parentString.--->
						<cfif getUserMasks.mask_id eq getAllMaskRelationships.parent_id>
							<cfif not listFind(parentString, getUserMasks.mask_name)><!---this prevents duplicates.--->
								<cfset parentString = listAppend(parentString, getUserMasks.mask_name)>
							</cfif>
							<cfbreak>
						</cfif>
					</cfloop>
				</cfif>
			</cfloop>
			
			
			<h4 style='margin-bottom:0px;'>
				<label>
					<input type="checkbox" name="frmMask#mask_id#" value="1" <cfif evaluate("frmMask#mask_id#")>checked</cfif> <cfif len(parentString) gt 0>disabled</cfif>>
					#mask_name#
				</label>
				<cfif len(parentString) gt 0>
					<span style="font-size: small;font-weight: normal;">(Inherited from <em>#parentString#)</em></span>
				</cfif>
			</h4>
			<cfif trim(mask_notes) neq ""><p><em>#mask_notes#</em></p></cfif>
			<span class="trigger">See Permission Details</span>
			<ul id='#mask_name#' style='display:none;'><cfset drawChildrenByMaskId(mask_id)></ul>
			<div style='clear:both;'></div>
			<hr/>
		</cfoutput>
	</blockquote>
	
	<!---with the big, related items out of the way we can now draw the a la carte options--->
	<cfquery dbtype="query" name="getAlaCarteMasks">
		SELECT *
		FROM getAllMasks
		WHERE relationship_id IS NULL
	</cfquery>
	
	
	<blockquote>
		<fieldset>
		<legend>A la Carte Permissions</legend>
		<cfoutput query="getAlaCarteMasks">
			<!---was this item checked off because of a parent?  If so we want to disable it, and show why it's checked.--->
			<cfset parentString = "">
			
			<cfloop query="getAllMaskRelationships">
				<!---loop until we find a relationship that the mask we're drawing belongs to.--->
				<cfif getAllMaskRelationships.mask_id eq getAlaCarteMasks.mask_id AND getAllMaskRelationships.parent_id neq 0 AND getAllMaskRelationships.parent_id neq getAlaCarteMasks.mask_id>
					<!---having found the parent, add its name to parentString--->
					<cfloop query="getUserMasks">
						<!---if the user has this parent mask, add it's name to parentString.--->
						<cfif getUserMasks.mask_id eq getAllMaskRelationships.parent_id>
							<cfif not listFind(parentString, getUserMasks.mask_name)><!---this prevents duplicates.--->
								<cfset parentString = listAppend(parentString, getUserMasks.mask_name)>
							</cfif>
							<cfbreak>
						</cfif>
					</cfloop>
				</cfif>
			</cfloop>
			
			<div>
				<label title='#mask_notes#'>
					<input type="checkbox" name="frmMask#mask_id#" value="1" <cfif evaluate("frmMask#mask_id#")>checked</cfif> <cfif len(parentString) gt 0>disabled</cfif> > #mask_name#
				</label>
				
				<cfif len(parentString) gt 0>
					<span class="tinytext">(Inherited from <em>#parentString#</em>)</span>
				</cfif>
			</div>
		</cfoutput>
		</fieldset>
	</blockquote>
	<div style="clear: both;"></div>
	
	<h3>Step 3: Submit Form</h3>
	
	<cfif frmSubmit neq "addForm">
		<input type="submit"   name="frmSubmit" value="Update">
	<cfelse>
		<input type="submit"   name="frmSubmit" value="Add">
	</cfif>
	<input type="reset"  value="Reset">
	
	</form>

</cfif>			

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>


<!---updates the masks for the selected user in the database.--->
<cffunction name="updateMasks">
	<cfset var deleteMasks = "">
	<cfset var loopCnt = "">
	<cfset var addMasks = "">
	<cfset var userMaskList = "0"><!---this way we never have a list length of 0, and that saves some checking.--->
	<cfset var newMasksQuery = "">
	<cfset var getInheritedMasks = "">
	
	<!---since we disabled all the checkboxes that are inherited we can simply nuke the user's current users_mask_match and add the new rows.--->
	<cfquery datasource="#application.applicationdatasource#" name="deleteMasks">
		DELETE FROM tbl_users_masks_match
		WHERE user_id = #currentUserId#
	</cfquery>
	
	<!---before we attempt to insert any records we need to know how many we will be inserting - this'll let us cram all the values into one insert query--->
	<cfloop query="getAllMasks">
		<!---adding logic to weed out duplicates from another source would be good, but not strictly necissary.--->
		<cfif evaluate("frmMask#mask_id#")><!---the variable exists and it's true--->
			<cfset userMaskList = listAppend(userMaskList, mask_id)>
		</cfif>
	</cfloop>
	
	<cfquery datasource="#application.applicationDataSource#" name="newMasksQuery">
		SELECT #currentUserId# AS user_id, 'fake' AS username, um.mask_id, um.mask_name
		FROM tbl_user_masks um 
		WHERE um.mask_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userMaskList#" list="true">)
	</cfquery>
	
	<!---now we can use the buildMyMasks() function from common functions to find all the masks they should be inheriting as well.--->
	<cfset getInheritedMasks = buildMyMasks(newMasksQuery, getAllMaskRelationships)>
	
	<cfif getInheritedMasks.recordCount gt 0>
		<cfset loopCnt = 1>
		<cfquery datasource="#application.applicationdatasource#" name="addMasks">
			INSERT INTO tbl_users_masks_match (user_id, mask_id, value)
			VALUES
			<cfloop query="getInheritedMasks">
				(#currentUserId#, #mask_id#, 1)<cfif loopCnt lt getInheritedMasks.recordCount>,</cfif>
				<cfset loopCnt = loopCnt + 1>
			</cfloop>
		</cfquery>
	</cfif>
	
	<!---having stored all our updates to the DB, clear out the user submitted values, so when the form is drawn next it's only showing data pulled from the DB.--->
	<cfloop query="getAllMasks">
		<cfset "frmMask#mask_id#" = 0>
	</cfloop>
</cffunction>

<!---this function is used to draw the childen of a mask conveniently.--->
<cffunction name="drawChildrenByMaskId">
	<cfargument name="maskId" type="numeric" required="true">
	
	<cfset var maskName = "unkown">
	<cfset var getName = "">
	<cfset var getChildren = "">
	
	<!---first get the name of this mask--->
	<cfquery dbtype="query" name="getName">
		SELECT mask_name
		FROM getAllMasks
		WHERE mask_id = #maskId#
	</cfquery>
	<cfloop query="getName"><cfset maskName = mask_name></cfloop>
	
	
	<!---find any children for this mask, and draw them.--->
	<cfquery datasource="#application.applicationdatasource#" name="getChildren">
		SELECT rm.mask_id
		FROM tbl_mask_relationships_members rm
		INNER JOIN tbl_mask_relationships r ON r.relationship_id = rm.relationship_id
		WHERE r.mask_id = #maskId#
	</cfquery>
	
	<!---if this mask has children wrap the call to drawChildrenByMaskId() in a pair of UL tags to index the list--->
	<cfoutput>
		<li>#maskName#</li>
		<cfif getChildren.recordCount gt 0>
			<ul>
				<cfloop query="getChildren">
					<cfset drawChildrenByMaskId(mask_id)>
				</cfloop>
			</ul>
		</cfif>
	</cfoutput>	
</cffunction>