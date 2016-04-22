<cfmodule template="#application.appPath#/header.cfm" title="Article Editor">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Article Editor">

<h1>Article Editor</h1>
<a href="article.cfm">View Articles</a>
<br/><br/>
<!---This page is intended to allow a user to create and edit article--->

<!---input for the article itself--->
<cfparam name="frmArticleId" type="integer" default="0">
<cfparam name="frmCatId" type="integer" default="0">
<cfparam name="frmRetired" type="boolean" default="0">
<cfparam name="frmSortOrder" type="integer" default="1">

<!---input for a given revision of an article--->
<cfparam name="frmRevisionId" type="integer" default="0">
<cfparam name="frmTitle" type="string" default="">
<cfparam name="frmContent" type="string" default="">
<cfparam name="frmComment" type="string" default="">

<cfset UseRevision = 1><!---by default say we are looking at the current revision of an article.--->

<!---input for permission masks for this article--->
<cfset tempInstances = userHasInstanceList().idList><!---Gives us default masks for Required_Masks--->

<!--- if the user has both IUB and IUPUI masks, use only the one corresponding the current Tetra instance --->
<!--- this is to prevent articles from defaulting to 'IUB, IUPUI, consultant' --->
<!--- To do this, remove all instance_ids from tempInstance that do not match the primary instance. --->
<cfquery datasource="#application.applicationDataSource#" name="getInstanceMask">
	SELECT b.mask_id
	FROM tbl_instances a
	INNER JOIN tbl_user_masks b ON b.mask_name = a.instance_mask
	WHERE instance_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
</cfquery>
<cfloop query="getInstanceMask">
	<cfset i = listFindNoCase(tempInstances, mask_id)>
	<cfif i gt 0>
		<cfset tempInstances = listDeleteAt(tempInstances, i)>
	</cfif>
</cfloop>

<cfset tempInstances = listAppend(tempInstances, 9)><!---default to limiting to consultant's being able to view articles.--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="Required_Masks" default="#serializeJSON(listToArray(tempInstances))#">
<cfset Required_Masks = arrayToList(Required_Masks)><!---the multi-selector always returns an array, but we want a list.--->
<!---cfparam name="Required_Masks" type="string" default="#tempInstances#"--->
<cfparam name="frmAction" type="string" default="Add">
<cfparam name="frmSubmit" type="string" default="">

<cfparam name="frmReferrer" type="string" default=""><!---if provided this is where the user should be taken upon a successful form submission.--->

<style type="text/css">
	td.label {
		text-align: right;
	}
</style>


<cfquery name='getUserEmail' datasource="#application.applicationDataSource#">
	SELECT email
	FROM tbl_users
	WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
</cfquery>



<!---start handling user input.--->
<cfif frmAction eq "Add" AND frmSubmit neq "">
	<cftry>
		<!---make sure the input is legit.--->

		<!---strip out the XML header/style information that sometimes hitches a ride when people paste from MS Office.--->
		<cfset frmContnet = stripMSXML(frmContent)>

		<cfif frmArticleId gt 0>
			<cfthrow message="Article Id" detail="You provided an Article ID when creating a document, edit the provided article instead.">
		</cfif>

		<cfif frmCatId eq 0>
			<cfthrow message="Category" detail="You must select a Category for this article.">
		</cfif>

		<cfif trim(frmTitle) eq "">
			<cfthrow message="Title" detail="Title cannot be left blank.">
		</cfif>

		<cfif trim(frmContent) eq "">
			<cfthrow message="Body" detail="You must provide actual content for this article.">
		</cfif>

		<cfif listLen(Required_Masks) gt 0>
			<cfloop list="#Required_Masks#" index="maskId">
				<cfif not isValid("integer", maskId)>
					<cfthrow message="Required Masks" detail="The Mask IDs you provide must all be valid integers.">
				</cfif>
			</cfloop>
		</cfif>

		<!---catch our comments, too.  Strip out any HTML tags and remove any leading or trailing whitespace.--->
		<cfset frmComment = stripTags(trim(frmComment))>
		<!---at this point we're all set, we can create our article.--->
		<cfquery datasource="#application.applicationDataSource#" name="createArticle">
			INSERT INTO tbl_articles (category_id, creator_id, sort_order)
			OUTPUT inserted.article_id
			VALUES (#frmCatId#, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#frmSortOrder#">)
		</cfquery>

		<!---before we create the actual content of the article we want to be sure to have our masks in place first - this way if mask creation fails our article isn't out flapping in the breeze.--->
		<cfif listLen(Required_Masks) gt 0>
			<cfset cnt = 1><!---this gets used to put a comma after each set of values, except for the last item in Required_Masks--->
			<cfquery datasource="#application.applicationDataSource#" name="addMasks">
				INSERT INTO tbl_articles_masks (article_id, mask_id)
				VALUES
				<cfloop list="#Required_Masks#" index="maskId">
					(<cfqueryparam cfsqltype="cf_sql_integer" value="#createArticle.article_id#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">)<cfif cnt lt listLen(Required_Masks)>,</cfif>
					<cfset cnt = cnt + 1>
				</cfloop>
			</cfquery>
		</cfif>

		<!---now we need to know if the article needs to be approved.--->
		<cfset ownerMasks = getInheritedOwnerMasks(frmCatId)>
		<cfset needsApproval = iif(listLen(ownerMasks) gt 0, 1, 0)>

		<!---with our masks in place we can now add the actual substance of the article.--->
		<cfquery datasource="#application.applicationDataSource#" name="addRevision">
			INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, comment, approved)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#createArticle.article_id#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTitle#">,
				<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#frmContent#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfif frmComment eq "">
					NULL,
				<cfelse>
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmComment#">,
				</cfif>

				<cfif needsApproval>0<cfelse>1</cfif>
			)
		</cfquery>

		<!---now update the search index.--->
		<cfset updateSearch(createArticle.article_id)>

		<!---if we've made it this far, we're set.--->
		<cfif needsApproval>
			<cfset sendAlertEmails(ownerMasks,createArticle.article_id, frmAction)>
		</cfif>
		<!---by default take them away to the viewer, but if we have a referrer use that--->
		<cfif trim(frmReferrer) eq "">
			<cflocation url="#application.apppath#/documents/article.cfm?articleId=#createArticle.article_id#" addtoken="false">
		<cfelse>
			<cflocation url="#frmReferrer#" addtoken="false">
		</cfif>

		<p class="ok">
			Article successfully created.  You may view it <a href="<cfoutput>#application.appPath#/documents/article.cfm?articleId=#createArticle.article_id#</cfoutput>">here</a>.
		</p>

	<cfcatch type="any">
		<cfset frmAction = "Add">
		<cfoutput>
			<p class="warning">
				<span>Error</span> - #cfcatch.message#. #cfcatch.detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

<cfelseif frmAction eq "Edit">
	<cftry>
		<!---verify that the user's input is good.--->

		<!---strip out the XML header/style information that sometimes hitches a ride when people paste from MS Office.--->
		<cfset frmContnet = stripMSXML(frmContent)>

		<cfif frmArticleId lte 0>
			<cfthrow message="Article ID" detail="You did not provide an article_id to be edited.">
		</cfif>
		<cfif frmCatId eq 0>
			<cfthrow message="Category" detail="You must select a Category for this article.">
		</cfif>

		<cfif trim(frmTitle) eq "">
			<cfthrow message="Title" detail="Title cannot be left blank.">
		</cfif>

		<cfif trim(frmContent) eq "">
			<cfthrow message="Body" detail="You must provide actual content for this article.">
		</cfif>

		<cfif listLen(Required_Masks) gt 0>
			<cfloop list="#Required_Masks#" index="maskId">
				<cfif not isValid("integer", maskId)>
					<cfthrow message="Required Masks" detail="The Mask IDs you provide must all be valid integers.">
				</cfif>
			</cfloop>
		</cfif>

		<!---catch our comments, too.  Strip out any HTML tags and remove any leading or trailing whitespace.--->
		<cfset frmComment = stripTags(trim(frmComment))>

		<!---fetch the current values from the database for comparisson later.--->
		<cfset oldVals = getArticleById(frmArticleId)>

		<!---add/update the values in the database.--->
		<!---first update the article itself.--->
		<cfquery datasource="#application.applicationDataSource#" name="updateArticle">
			UPDATE tbl_articles
			SET category_id = #frmCatId#,
				retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
			WHERE article_id = #frmArticleId#
		</cfquery>

		<!---clear the old masks, and replace them with the new ones--->
		<cfquery datasource="#application.applicationDataSource#" name="updateArticleMasks">
			BEGIN TRANSACTION
				DELETE FROM tbl_articles_masks
				WHERE article_id = #frmArticleId#

				<cfif listLen(Required_Masks) gt 0>
					<cfset cnt = 1><!---this gets used to put a comma after each set of values, except for the last item in Required_Masks--->
					INSERT INTO tbl_articles_masks (article_id, mask_id)
					VALUES
					<cfloop list="#Required_Masks#" index="maskId">
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">)<cfif cnt lt listLen(Required_Masks)>,</cfif>
						<cfset cnt = cnt + 1>
					</cfloop>
				</cfif>

				IF @@ERROR <> 0
					ROLLBACK
				ELSE
					COMMIT
		</cfquery>

		<!---now we need to know if the article needs to be approved.--->
		<cfset ownerMasks = getInheritedOwnerMasks(frmCatId)>
		<cfset needsApproval = iif(listLen(ownerMasks) gt 0, 1, 0)>

		<!---now add our new revision.--->
		<cfif  COMPARE(frmTitle, oldVals.title) NEQ 0 OR COMPARE(frmContent,oldVals.content) NEQ 0>
			<cfquery datasource="#application.applicationDataSource#" name="addNewRevision">

				DECLARE @revId int;
				BEGIN TRANSACTION
					INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, comment, use_revision, approved)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTitle#">,
						<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#frmContent#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
						<cfif frmComment eq "">
							NULL,
						<cfelse>
							<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmComment#">,
						</cfif>
					<cfif needsApproval>
						0, 0
					<cfelse>
						1, 1
					</cfif>
					)

					SET @revId = SCOPE_IDENTITY();

					<!---now, if apropriate, set all other revisions to not be used.--->
					<cfif not needsApproval>
						UPDATE tbl_articles_revisions
						SET use_revision = 0
						WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
						AND revision_id <> @revId
					</cfif>

					SELECT @revId AS "revisionId"

				IF @@ERROR <> 0
					ROLLBACK
				ELSE
					COMMIT
			</cfquery>

			<!---If the new version needs approval be sure to send an email to the owners.--->
			<cfif needsApproval>
				<cfset sendAlertEmails(ownerMasks,frmArticleId, frmAction, addNewRevision.revisionId)>
			</cfif>

		</cfif>

		<!---fetch the new values from the database so we can audit the differences.--->
		<cfset newVals = getArticleById(frmArticleId)>


		<!---now we audit our changes.---->
		<cfset auditText = "">

		<cfif oldVals.revision_id neq newVals.revision_id>
			<cfset auditText = auditText & "<li><b>Revision ID</b> changed to <em>" & newVals.revision_id & "</em></li>">
		</cfif>

		<cfif oldVals.category_id neq newVals.category_id>
			<cfset auditText = auditText & "<li><b>Category</b> changed from <em>" & getFormattedParentList(oldVals.category_id) & "</em></li>">

			<!---if the old category didn't need approval, but the new one does, we need to blank-out approvals just to be safe.--->
			<cfset needsReset = 0>
			<cfset oldOwnerMasks = getInheritedOwnerMasks(oldVals.category_id)>
			<cfloop list="#ownerMasks#" index="i">
				<cfif not listFind(oldOwnerMasks, i)>
					<!---we didn't find all the masks we need now in the old masks that were satisfied--->
					<cfset needsReset = 1>
					<cfbreak>
				</cfif>
			</cfloop>

			<!---if we need to reset, let's get it done.--->
			<cfif needsReset>
				<cfquery datasource="#application.applicationDataSource#" name="resetApprovals">
					UPDATE tbl_articles_revisions
					SET use_revision = 0,
						approved = 0
					WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
				</cfquery>

				<cfset auditText = auditText & "<li><b>Approval Reset</b> Article was moved to a new category, requiring new approvals.</li>">
			</cfif>

		</cfif>

		<cfif oldVals.maskList neq newVals.maskList>
			<cfset auditText = auditText & "<li><b>Required Masks</b> changed from <em>" & oldVals.maskNames & "</em></li>">
		</cfif>

		<cfif oldVals.title neq newVals.title>
			<cfset auditText = auditText & "<li><b>Title</b> changed from <em>" & htmlEditFormat(oldVals.title) & "</em></li>">
		</cfif>

		<cfif oldVals.retired neq newVals.retired>
			<cfset auditText = auditText & "<li><b>Retired</b> changed from <em>" & oldVals.retired & "</em></li>">
		</cfif>

		<!---if we have audit text, make it a real list.--->
		<cfif auditText neq "">
			<cfset auditText = "<ul>" & auditText & "</ul>">

			<!---take our audit text and store it in the database.--->
			<cfquery datasource="#application.applicationDataSource#" name="addAudit">
				INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
				VALUES (#frmArticleId#, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, <cfqueryparam cfsqltype="cf_sql_longvarchar" value="#auditText#">)
			</cfquery>
		</cfif>


		<!---now update the search index.--->
		<cfset updateSearch(frmArticleId)>

		<!---if we've gotten this far we're set, take them back to the view page.--->

		<!---by default take them away to the viewer, but if we have a referrer use that--->
		<cfif trim(frmReferrer) eq "">
			<cflocation url="#application.apppath#/documents/article.cfm?articleId=#frmArticleId#" addtoken="false">
		<cfelse>
			<cflocation url="#frmReferrer#" addtoken="false">
		</cfif>

		<p class="ok">
			Article successfully revised.  You may view it <a href="<cfoutput>#application.appPath#/documents/article.cfm?articleId=#frmArticleId#</cfoutput>">here</a>.
		</p>

	<cfcatch type="any">
		<cfset frmAction = "Edit">
		<cfoutput>
			<p class="warning">
				<span>Error</span> - #cfcatch.message#. #cfcatch.detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

<cfelseif frmAction eq "setVersion">
	<!---here we set the revision to be displayed by default for this article.--->
	<cftry>
		<cfif frmArticleId lte 0>
			<cfthrow message="Article ID" detail="You must provide an Article ID that you are selecting a revision for.">
		</cfif>
		<cfif frmRevisionId lte 0>
			<cfthrow message="Revision ID" detail="You must provide a Revision ID to use for this article.">
		</cfif>

		<!---is this an existing, active article?--->
		<cfquery datasource="#application.applicationDataSource#" name="getArticle">
			SELECT retired
			FROM tbl_articles
			WHERE article_id = #frmArticleId#
		</cfquery>
		<cfif getArticle.recordCount eq 0>
			<cfthrow message="Article ID" detail="The Article ID you provided was not found in the database.">
		</cfif>
		<cfloop query="getArticle">
			<cfif retired>
				<cfthrow message="Article ID" detail="The Article ID you provided is for an article that has been retired, the default revision has not been changed.">
			</cfif>
		</cfloop>

		<!---is the provided revisionId a real revision to this article?--->
		<cfquery datasource="#application.applicationDataSource#" name="getRevision">
			SELECT ar.use_revision
			FROM tbl_articles_revisions ar
			INNER JOIN tbl_users u ON u.user_id = ar.user_id
			WHERE ar.article_id = #frmArticleId#
			AND revision_id = #frmRevisionId#
		</cfquery>
		<cfif getRevision.recordCount eq 0>
			<cfthrow message="Revision ID" detail="The Revision ID you provided is not a valid revision of the Article ID you provided.">
		</cfif>

		<!---with those checks done mark the provided ID's use_version to 1, then set all others for the article to 0.--->
		<cfquery datasource="#application.applicationDataSource#" name="setRevision">
			UPDATE tbl_articles_revisions
			SET use_revision = 1
			WHERE article_id = #frmArticleId#
			AND revision_id = #frmRevisionId#

			/*clear the others*/
			UPDATE tbl_articles_revisions
			SET use_revision = 0
			WHERE article_id = #frmArticleId#
			AND revision_id <> #frmRevisionId#
		</cfquery>

		<!---now audit our change.--->
		<cfquery datasource="#application.applicationDataSource#" name="auditRevision">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (#frmArticleId#, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, '<ul><li><b>Revision ID</b> changed to <em>#frmRevisionId#</em></li></ul>')
		</cfquery>


		<!---now update the search index.--->
		<cfset updateSearch(frmArticleId)>

		<!---if we've gotten this far we're set, take them back to the view page.--->
		<p class="ok">
			Default revision changed.  You may view it <a href="<cfoutput>#application.appPath#/documents/article.cfm?articleId=#frmArticleId#</cfoutput>">here</a>.
		</p>

		<!---by default take them away to the viewer, but if we have a referrer use that--->
		<cfif trim(frmReferrer) eq "">
			<cflocation url="#application.apppath#/documents/article.cfm?articleId=#frmArticleId#" addtoken="false">
		<cfelse>
			<cflocation url="#frmReferrer#" addtoken="false">
		</cfif>

	<cfcatch type="any">
		<cfset frmAction = "Edit">
		<cfoutput>
			<p class="warning">
				<span>Error</span> - #cfcatch.message#. #cfcatch.detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
</cfif>


<!---if we have an article_id provided fetch those details to provide the correct default values in our form below.--->
<!---of course we have to deferr to any input the user submitted, so this gets a little uglier.--->
<cfif frmArticleId gt 0>
	<!---if we have an article_id we must be editing a document.--->
	<cfset frmAction = "Edit">

	<cfset curArticle = getArticleById(frmArticleId, frmRevisionId)>

	<cfset UseRevision = curArticle.use_revision>

	<cfif not isDefined("form.frmCatId") AND not isDefined("url.frmCatId")>
		<cfset frmCatId = curArticle.category_id>
	</cfif>
	<cfif not isDefined("form.frmRetired") AND not isDefined("url.frmRetired")>
		<cfset frmRetired = curArticle.retired>
	</cfif>

	<cfif not isDefined("form.frmTitle") AND not isDefined("url.frmTitle")>
		<cfset frmTitle = curArticle.title>
	</cfif>

	<cfif not isDefined("form.frmContent") AND not isDefined("url.frmContent")>
		<cfset frmContent = curArticle.content>
	</cfif>

	<cfif not isDefined("form.frmRevisionId") AND not isDefined("url.frmRevisionId")>
		<cfset frmRevisionId = curArticle.revision_id>
	</cfif>

	<cfif not isDefined("form.Required_Masks") AND not isDefined("url.Required_Masks")>
		<cfset Required_Masks = curArticle.maskList>
	</cfif>
</cfif>

<cfset ownerMasks = getInheritedOwnerMasks(frmCatId)>
<cfif listLen(ownerMasks) gt 0>
	<div class="alert">
		Changes to this article will need to be approved before they are seen.<br/>
		Masks required to approve article:
		<ul>
		<cfloop list="#ownerMasks#" index="mask">
			<li><cfoutput>#htmlEditFormat(mask)#</cfoutput></li>
		</cfloop>
		</ul>

		<cfif hasMasks(ownerMasks)>
			You can approve these changes <a href="my_approvals.cfm">here</a>.
		</cfif>
	</div><br/>
</cfif>

<cfoutput>



<form method="post" action="#cgi.script_name#" class="form-horizontal col-sm-10" >
	<input type="hidden" name="frmAction" value="#htmlEditFormat(frmAction)#">
	<cfif frmArticleId gt 0>
		<input type="hidden" name="frmArticleId" value="#frmArticleId#">
	</cfif>
	<input type="hidden" name="frmReferrer" value="#htmlEditFormat(frmReferrer)#">
	<input type="hidden" name="frmSortOrder" value="#htmlEditFormat (frmSortOrder)#">

	<!---if the user is looking at a non-current version of the file warn them--->
	<cfif not UseRevision>
		<div class="alert alert-danger">
			You are editing a non-current version of this article.
		</div>
	</cfif>
	<cfoutput>#bootstrapCharField("frmTitle", "Title", "#frmTitle#")#</cfoutput>
	<div class="form-group">
		<label class="col-sm-3 control-label" for="frmCatId">Category</label>
		<div class="col-sm-9">
			<cfset drawCategorySelect("frmCatId", frmCatId, 0, getAllCategoriesQuery(0))><!---we include a custom getAllCategoriesQuery, where we don't pull retired categories.--->
			<!---offer admins the chane to edit categories--->
			<cfif hasMasks("Admin")>
				<a class="tinytext" href="#application.appPath#/documents/category_editor.cfm">Edit Categories</a>
			</cfif>
		</div>
	</div>
	<cfset articleEditorOptions = {"customConfig" = "#application.appPath#/js/ckeditor/config.cfm"}>
	<cfset articleEditorOptions["filebrowserBrowseUrl"] = "#application.appPath#/tools/filemanager/manager.cfm?path=%2Fimages%2Farticles%2F">
	<cfset articleEditorOptions["filebrowserUploadUrl"] = "upload.cfm">
	<cfset articleEditorOptions["filebrowserWindowFeatures"] = "resizable=yes,scrollbars=yes">
	<cfoutput>#bootstrapEditorField("frmContent", "Body", frmContent, "", articleEditorOptions)#</cfoutput>

	<cfset drawMasksSelector("Required_Masks", Required_Masks, "Required Masks")>

	<cfif frmAction neq "Add">
		<cfset articleRadioOptions = ArrayNew(1)>
		<cfset ArrayAppend(articleRadioOptions, {"name" = "Active", "value" = 0})>
		<cfset ArrayAppend(articleRadioOptions, {"name" = "Retired", "value" = 1})>
		<cfoutput>#bootstrapRadioField("frmRetired", articleRadioOptions, "Status", frmRetired)#</cfoutput>
	</cfif>
	<div class="form-group">
		<label class="col-sm-3 control-label" for="frmComment">Comment</label>
		<div class="col-sm-9">
			<textarea class="form-control" name="frmComment" id="frmComment" >#htmlEditFormat(frmComment)#</textarea>
		</div>
	</div>
	<br/>
	<div class="form-group">
		<cfif frmAction eq "Add">
			<input class="btn btn-primary col-sm-offset-3" type="submit" name="frmSubmit"  value="Add Article">
		<cfelse>
			<input class="btn btn-primary col-sm-offset-3" type="submit" name="frmSubmit"  value="Update Article">
		</cfif>
	</div>
</form>


</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm">

<cffunction name="sendAlertEmails" output="false">
	<cfargument name="ownerMasks" type="string" default="">
	<cfargument name="articleId" default="0">
	<cfargument name="status" type="string" default="">
	<cfargument name="revisionId" type="string" default="">
	<!---Build our user list--->
	<cfquery name='getAllUsers' datasource="#application.applicationDataSource#">
		SELECT DISTINCT username,email
		FROM tbl_users u
		INNER JOIN tbl_users_masks_match m ON m.user_id = u.user_id
	</cfquery>
	<cfset usernameList = ''>
	<cfloop query="getAllUsers">
		<cfset usernameList = listAppend(usernameList,getAllUsers.username)>
	</cfloop>

	<!---Build our masks list--->
	<cfset userArray = bulkGetUserMasks(usernameList)>

	<!---Now find owners--->
	<cfset ownerEmails = ''>
	<cfloop query="getAllUsers">
		<cfif bulkHasMasks(userArray,getAllUsers.username,ownerMasks)>
			<cfset ownerEmails = listAppend(ownerEmails,getAllUsers.email)>
		</cfif>
	</cfloop>
	<cfif ListFind(ownerEmails, getUserEmail.email) EQ 0>
		<cfmail from="#getUserEmail.email#" to="#ownerEmails#" subject="Request for #ownerMasks# Approval" type="text/html">
			<html>
				<body>
					<center>
						<h1>Request for Approval Sent</h1>
						<cfif status EQ "Edit">
							<p><cfoutput>#session.cas_username#</cfoutput> has created a revision that is waiting for your approval.</p>
						</cfif>
						<p><a href="<cfoutput>https://#cgi.server_name##application.appPath#/documents/article.cfm?articleId=#articleId#<cfif revisionId neq "">&revisionId=#revisionId#</cfif></cfoutput>">See Revision</a></p>
						<br/>
						<p><a href="<cfoutput>https://#cgi.server_name##application.appPath#</cfoutput>/documents/my_approvals.cfm">View Approvals Page</a></p>
						<br/>
						<p style="font-size:8px;">This email was sent from Tetra at #dateTimeFormat(Now())#,</p>
					</center>
				</body>
			</html>
		</cfmail>
	</cfif>

</cffunction>

<!---Fetch the information for the article from the database--->
<cffunction name="getArticleById">
	<cfargument name="articleId" type="numeric" required="true">
	<cfargument name="revisionId" type="numeric" default="0">

	<cfset var artObj = structNew()>
	<cfset var getCurArticle = "">
	<cfset var getCurRevision = "">
	<cfset var getCurMasks = "">

	<!---if this fails in any way try to die with some grace.--->
	<cftry>
		<cfquery datasource="#application.applicationDataSource#" name="getCurArticle">
			SELECT category_id, retired
			FROM tbl_articles
			WHERE article_id = #frmArticleId#
		</cfquery>
		<cfif getCurArticle.recordCount eq 0>
			<cfthrow message="Not Found" detail="Query getCurArticle">
		</cfif>

		<cfloop query="getCurArticle">
			<cfset artObj.category_id = category_id>
			<cfset artObj.retired = retired>
		</cfloop>

		<cfquery datasource="#application.applicationDataSource#" name="getCurRevision">
			SELECT TOP 1 revision_id, title, revision_content, use_revision, approved
			FROM tbl_articles_revisions
			WHERE article_id = #frmArticleId#
			<cfif revisionId gt 0>
				AND  revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#revisionId#">
			<cfelse>
				AND use_revision = 1
			</cfif>
			ORDER BY revision_date DESC
		</cfquery>
		<cfif getCurRevision.recordCount eq 0>
			<cfthrow message="Not Found" detail="Query getCurRevision">
		</cfif>

		<cfloop query="getCurRevision">
			<cfset artObj.revision_id = revision_id>
			<cfset artObj.title = title>
			<cfset artObj.content = revision_content>
			<cfset artObj.use_revision = use_revision>
			<cfset artObj.approved = approved>
		</cfloop>

		<cfquery datasource="#application.applicationDataSource#" name="getCurMasks">
			SELECT am.mask_id, um.mask_name
			FROM tbl_articles_masks am
			LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
			WHERE am.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
			ORDER BY am.mask_id ASC
		</cfquery>

		<cfset artObj.maskList = "">
		<cfset artObj.maskNames = "">
		<cfloop query="getCurMasks">
			<cfset artObj.maskList = listAppend(artObj.maskList, mask_id)>
			<cfset artObj.maskNames = listAppend(artObj.maskNames, mask_name)>
		</cfloop>

	<cfcatch type="any">
		<p class="warning">
			<cfoutput>
				Error encountered in getArticleById(#articleId#, #revisionId#): #cfcatch.Message# - #cfcatch.Detail#
			</cfoutput>
		</p>

		<cfmodule template="#application.appPath#/footer.cfm">
		<cfabort>
	</cfcatch>
	</cftry>

	<cfreturn artObj>
</cffunction>

<!---take an article_id, fetch the current info for the article, and update our search index.--->
<cffunction name="updateSearch">
	<cfargument name="articleId" type="numeric" default="0">

	<cfset var getArticle = "">
	<cfset var articleQuery = queryNew("id,article_title,article_body,required_masks,article_date,article_url,category", "varchar,varchar,varchar,varchar,date,varchar,varchar")><!---our output query, where we collapse masks to a single list, and tidy it all up.--->
	<cfset var maskList = "">
	<cfset var getTopCat = ""><!---we need to find the topmost category for this article, and use that as its category in the search index.--->
	<cfset var topCat = "">
	<cfset var parentCats = "">

	<cfquery datasource="#application.applicationDataSource#" name="getArticle">
		SELECT a.article_id, a.category_id, ar.title, ar.revision_content, ar.revision_date, um.mask_id, um.mask_name
		FROM tbl_articles a
		INNER JOIN tbl_articles_revisions ar
			ON ar.article_id = a.article_id
			AND ar.use_revision = 1
			/*might need to add approval here, but if use_revision is toggled the article should have been approved.*/
		LEFT OUTER JOIN tbl_articles_masks am ON am.article_id = a.article_id
		LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
		WHERE a.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#articleId#">
		AND a.retired = 0
	</cfquery>

	<cfoutput query="getArticle" group="article_id">
		<cfset maskList = "">
		<!---build-up our list of required masks.--->
		<cfoutput>
			<cfset maskList = listAppend(maskList, mask_name)>
		</cfoutput>

		<!---now find our topCat--->
		<cfset parentCats = getCategoryParentList(category_id)>

		<cfquery datasource="#application.applicationDataSource#" name="getTopCat">
			SELECT TOP 1 category_name
			FROM tbl_articles_categories
			WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#parentCats#" list="true">)
			AND parent_cat_id = 0
		</cfquery>

		<cfloop query="getTopCat">
			<cfset topCat = category_name>
		</cfloop>

		<cfset queryAddRow(articleQuery)>
		<cfset querySetCell(articleQuery, "id", article_id)>
		<cfset querySetCell(articleQuery, "article_title", reReplace(title, "<[^>]*>", "", "all"))><!---trim out html tags and store the title--->
		<cfset querySetCell(articleQuery, "article_body", reReplace(revision_content, "<[^>]*>", "", "all"))>
		<cfset querySetCell(articleQuery, "required_masks", maskList)>
		<cfset querySetCell(articleQuery, "article_date", revision_date)>
		<cfset querySetCell(articleQuery, "article_url", "#application.appPath#/documents/article.cfm?articleId=#article_id#")>
		<cfset querySetCell(articleQuery, "category", topCat)>
	</cfoutput>


	<cfset indexSearchQuery(articleQuery)>

	<!---if the article is gone or retired, delete it from the search collection.--->
	<cfif getArticle.recordCount eq 0>
		<cfindex collection="v4-search" action="delete" type="custom" key="a#articleId#">
	</cfif>
</cffunction>
