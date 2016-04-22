<cfmodule template="#application.appPath#/header.cfm" title="Approve Articles">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Article Editor">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="frmRevisionId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="view">
<cfparam name="frmComment" type="string" default="">
<cfparam name="fromArticle" type="boolean" default="0">

<cfset myId = "content" & createUUID()><!---myId is a unique ID so we don't clobber other CSS and javascript classes.--->

<!--- HEADER / NAVIGATION --->
<h1>Approve Articles</h1>

<!--- QUERIES --->
<!--- fetch all categories the user possesses the owner masks for --->
<cfquery datasource="#application.applicationDataSource#" name="getUserCats">
	SELECT category_id, parent_cat_id, category_name, sort_order, retired
	FROM tbl_articles_categories c
	WHERE 0 NOT IN (
		SELECT 
			CASE
				WHEN mu.mask_id IS NULL THEN 0
				ELSE 1
			END AS has_mask
		FROM tbl_articles_categories_owner co
		LEFT OUTER JOIN vi_all_masks_users mu
			ON mu.mask_id = co.mask_id
			AND mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		WHERE co.category_id = c.category_id
	)
	AND c.retired = 0
</cfquery>

<cfif frmRevisionId GT 0>
	<!--- fetch the revision information --->
	<cfquery datasource="#application.applicationDataSource#" name="getRevision">
		SELECT a.article_id, a.category_id, ar.title, ar.revision_date, ar.approved, ar.use_revision, u.username
		FROM tbl_articles_revisions ar
		INNER JOIN tbl_articles a ON a.article_id = ar.article_id
		INNER JOIN tbl_users u ON u.user_id = ar.user_id
		WHERE ar.revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRevisionId#">
	</cfquery>
	
	<!--- look for a fallback revision --->
	<cfquery datasource="#application.applicationDataSource#" name="getFallback">
		SELECT TOP 1 ar.revision_id, ar.title, ar.revision_date, u.username
		FROM tbl_articles_revisions ar
		INNER JOIN tbl_users u ON u.user_id = ar.user_id
		WHERE ar.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getRevision.article_id#">
		      AND ar.approved = 1
		      AND ar.revision_id <> #frmRevisionId#
		ORDER BY revision_date DESC
	</cfquery>
</cfif>

<!--- HANDLE USER INPUT --->
<cftry>
	
	<!--- if the user hits cancel, send them back to the article or reload the page --->
	<cfif frmAction EQ "Cancel">
		<cfif NOT fromArticle>
			<cfset frmAction EQ "View">
		<cfelse>
			<cflocation url="article.cfm?articleId=#getRevision.article_id#&revisionId=#frmRevisionId#" addtoken="false">
		</cfif>
	</cfif>
	
	<!--- check inputs for validity --->
	<cfif frmAction EQ "Approve" OR frmAction EQ "Reject">
		
		<!--- ensure the revision id is valid --->
		<cfif getRevision.recordCount eq 0>
			<cfthrow message="Invalid Input" detail="Revision with ID #frmRevisionId# does not exist.">
		</cfif>
		
		<!--- ensure we aren't approving an approved revision --->
		<cfif frmAction EQ "Approve" AND getRevision.approved eq 1>
			<cfthrow message="Already Approved" detail="Revision with ID #frmRevisionId# has already been approved.">
		</cfif>
		
		<!--- if the revision id is sound, check the user masks against the cateogry owner masks --->
		<cfset ownerMasks = getInheritedOwnerMasks(getRevision.category_id)>
		
		<cfif not hasMasks(ownerMasks)>
			<cfthrow message="Permission" detail="You do not possess owner masks for this category.">
		</cfif>
		
		<!--- fetch the id of the user who created the article revision in question --->
		<cfquery datasource="#application.applicationDataSource#" name="getRequesterId">
			SELECT user_id
			FROM tbl_users
			WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#getRevision.username#">
		</cfquery>
		
		<cfset requesterId = 0>
		<cfif getRequesterId.recordCount GT 0>
			<cfset requesterId = getRequesterId.user_id>
		</cfif>
	
	</cfif>
	
	<cfif frmAction EQ "Approve">
		
		<!--- approve the revision and set it as the published one --->
		<cfquery datasource="#application.applicationDataSource#" name="approveRevision">
			BEGIN TRANSACTION
				UPDATE tbl_articles_revisions
				SET approved = 1,
					use_revision = 1
				WHERE revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRevisionId#">
				
				UPDATE tbl_articles_revisions
				SET use_revision = 0
				WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getRevision.article_id#">
				AND revision_id <> <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRevisionId#">
				
				IF @@ERROR <> 0
					ROLLBACK
				ELSE
					COMMIT
		</cfquery>
		
		<!--- build up audit string and insert it --->
		<cfset auditText = "<ul>">
		<cfset auditText = auditText & "<li>Approved revision #frmRevisionId#: <em>#htmlEditFormat(getRevision.title)#</em> entered by #getRevision.username# on #dateTimeFormat(getRevision.revision_date, 'mmm d, yyyy h:nn aa')#</li>">
		<cfset auditText = auditTExt & "<li><b>Revision ID</b> changed to <em>#frmRevisionId#</em></li>">
		<cfset auditText = auditText & "</ul>">
		
		<cfquery datasource="#application.applicationDataSource#" name="auditChange">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#getRevision.article_id#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		
		<p class="ok">
			Revision <strong><cfoutput>#getRevision.title#</cfoutput></strong> has been approved.
			<cfoutput>
				[<a href="#application.appPath#/documents/article.cfm?articleId=#getRevision.article_id#">View Article</a>]
			</cfoutput>
		</p>
		
		<!--- notify the revision author --->
		<cfset sendNotificationEmail(requesterId, session.cas_uid, getRevision.article_id, "Accepted", auditText)>
		
		<!--- toss the user back to the view form --->
		<cfset frmAction = "view">
	
	<cfelseif frmAction EQ "Reject">
		
		<!--- reject the revision and adjust use_revision if necessary --->
		<cfquery datasource="#application.applicationDataSource#" name="rejectRevision">
			BEGIN TRANSACTION
			
				UPDATE tbl_articles_revisions
				SET approved = -1
				WHERE revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRevisionId#">
				
				<cfif getRevision.use_revision eq 1 AND getFallback.recordCount gt 0>
					UPDATE tbl_articles_revisions
					SET use_revision = 1
					WHERE revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getFallBack.revision_id#">
					
					/*un-use other revisions*/
					UPDATE tbl_articles_revisions
					SET use_revision = 0
					WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getRevision.article_id#">
					AND revision_id <> <cfqueryparam cfsqltype="cf_sql_integer" value="#getFallBack.revision_id#">
				</cfif>
				
			IF @@ERROR <> 0
					ROLLBACK
				ELSE
					COMMIT
		</cfquery>
		
		<!--- build up audit text and insert it --->
		<cfset auditText = "<ul>">
		<cfset auditText = auditText & "<li>Rejected revision #frmRevisionId#</li>">
		<cfif trim(frmComment) NEQ "">
			<cfset auditText = auditText & "<li><b>Comments:</b> #nl2br(stripTags(frmComment))#</li>">
		</cfif>
		<cfif getRevision.use_revision EQ 1 AND getFallback.recordCount gt 0>
			<cfset auditText = auditText & "<li><b>Revision ID</b> changed to <em>#getFallBack.revision_id#</em></li>">
		</cfif>
		<cfset auditText = auditText & "</ul>">
		
		<cfquery datasource="#application.applicationDataSource#" name="auditChange">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#getRevision.article_id#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		
		<p class="ok">
			Revision <b><cfoutput>#getRevision.title#</cfoutput></b> has been rejected.
			<cfoutput>
				[<a href="#application.appPath#/documents/article.cfm?articleId=#getRevision.article_id#">View Article</a>]
			</cfoutput>
		</p>
		
		<!--- notify the revision author --->
		<cfset sendNotificationEmail(requesterId, session.cas_uid, getRevision.article_id, "Rejected", auditText)>
		
		<!--- toss the user back to the view form --->
		<cfset frmAction = "view">
	
	</cfif>
	
<cfcatch>
	<!--- toss the user back to the view form --->
	<cfset frmAction = "view">
	<cfoutput>
		<p class="warning">
			#cfcatch.message# - #cfcatch.detail#
		</p>
	</cfoutput>	
</cfcatch>
	
</cftry>

<!--- DRAW FORMS --->
<cfif frmAction EQ "Reject-Confirm">

	<h2 style="margin-bottom:0em;margin-top:0.5em;">Reject Revision</h2>
	
	<!--- provide the basic revision info here --->									
	<cfoutput>
		<em><p>#getRevision.title# by #getRevision.username# on #dateTimeFormat(getRevision.revision_date, "mmm d, yyyy h:nn aa")#</p></em>
	</cfoutput>
	
	<!--- provide fallback information if rejecting the active revision, or warn if none exists --->
	<cfif getRevision.use_revision eq 1>
	
		<cfif getFallback.recordCount GT 0>
			<p class="tinytext">
				Rejecting this revision will make the article revert to <cfoutput>#getFallback.title# by #getFallback.username# on #dateTimeFormat(getFallback.revision_date, "mmm d, yyyy h:nn aa")#</cfoutput> 
			</p>
		<cfelse>
			<p class="alert">
				There are no other approved reversions to fall back on.  If you reject this version the article will no longer be viewable by non-editors.
			</p>		
		</cfif>
		
	</cfif>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<cfoutput>
			<input type="hidden" name="frmRevisionId" value="#frmRevisionId#">
			<input type="hidden" name="fromArticle" value="#fromArticle#">
		</cfoutput>
		<p>
			<label>
				Comment (optional):<br/>
				<textarea name="frmComment" cols="30" rows="5"><cfoutput>#htmlEditFormat(frmComment)#</cfoutput></textarea>
			</label>
		</p>
		
		<p>
			<input name="frmAction" type="submit" value="Reject">
			<input name="frmAction" type="submit" value="Cancel">
		</p>
	</form>

<cfelse>

	<h2>Articles to Review</h2>
	
	<blockquote>
		Note: 
		Each link below signifies an unapproved revision of an existing article that you possess owner masks for.
		Approving a revision will make that version of the article immediately viewable by users.
		Rejecting a revision will remove a published version of an article; it will be replaced by an older approved
		article if one exists.
		If no other approved revisions exist, the article will no longer be viewable by users.
	</blockquote>
	
	<!--- fetch all unapproved articles that the user possesses owner masks for --->
	<cfquery datasource="#application.applicationDataSource#" name="getArticlesToApprove">
		SELECT a.article_id, a.category_id, a.retired, ar.revision_id, ar.title, ar.use_revision, 
		       ar.approved, a.sort_order, ar.revision_date
		FROM tbl_articles a
		INNER JOIN tbl_articles_revisions ar ON ar.article_id = a.article_id
		/*This where cluase looks tricky, but it limits us to articles that the user has the masks to view.*/
		WHERE 0 NOT IN (
			SELECT 
				CASE
					WHEN mu.mask_id IS NULL THEN 0
					ELSE 1
				END AS has_mask
			FROM tbl_articles_masks am
			LEFT OUTER JOIN vi_all_masks_users mu
				ON mu.mask_id = am.mask_id
				AND mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			WHERE am.article_id = a.article_id
		)
		AND a.retired = 0
		AND ar.approved = 0
	</cfquery>
	
	<cfset drawCat()>

</cfif>

<cffunction name="sendNotificationEmail">
	<cfargument name="requesterId" type="numeric" default="0">
	<cfargument name="approverId" type="numeric" default="0">
	<cfargument name="articleId" default="0">
	<cfargument name="status" type="string" default="">
	<cfargument name="reason" type="string" default="">

	<cfquery name='getRequesterInfo' datasource="#application.applicationDataSource#">
		SELECT DISTINCT username, email, preferred_name
		FROM tbl_users u 
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#requesterId#">
	</cfquery>
	
	<cfquery name='getApproverInfo' datasource="#application.applicationDataSource#">
		SELECT DISTINCT username, email, preferred_name
		FROM tbl_users u 
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#approverId#">
	</cfquery>
	
	<cfmail from="#getApproverInfo.email#" to="#getRequesterInfo.email#" subject="Your Article Revision Request" type="text/html">
		<html>	
			<body>
				<center>	
					<h1>Article Revision Status: #status#</h1>
					<p>#getApproverInfo.preferred_name# (#getApproverInfo.username#) #status# your <a href="<cfoutput>https://#cgi.server_name##application.appPath#/documents/article.cfm?articleId=#articleId#</cfoutput>">article revision</a>.</p>
					<cfif reason NEQ "">
					<p>Additonal notes: #reason#</p>
					</cfif>
					<br/>
					<p style="font-size:8px;">This email was sent from Tetra at #dateTimeFormat(Now())#,</p>
				</center>
			</body>
		</html>
	</cfmail>
	
</cffunction>

<!---these functions are adapted from mod_browse.cfm, I hate to reuse them but they differ a bit.--->
<!---the functions needed to draw the categories and their links.--->
<cffunction name="drawCat">
	<cfargument name="catId" type="numeric" default="0">
	<cfargument name="level" type="numeric" default="0">
	
	<cfset var getChildCats = getChildCategoriesByParent(catId, getUserCats)>
	<cfset var hasChildren = ""><!---does this category have child categories with articles in them?--->
	<cfset var getCatInfo = ""><!---fetch the current category's information and draw it.--->
	<cfset var catName = "">
	<cfset var childList = getCategoryChildrenList(catId, getUserCats)><!---used to see if the global attributes.catId is in this categories children, if it is it should use the triggerexpanded instead of trigger class.--->
	
	<cfquery dbtype="query" name="getCatInfo">
		SELECT category_name
		FROM getUserCats
		WHERE category_id = #catId#
	</cfquery>
	<cfloop query="getCatInfo">
		<cfset catName = category_name>
	</cfloop>
	
	<!---draw the opening of this categories div tag.--->
	<cfoutput>
		<cfif catId neq 0>
			<li>#catName#</li>
			<ul>
		<cfelse>
			<ul>
		</cfif>
	</cfoutput>
	<cfloop query="getChildCats">
		<cfset hasChildren = hasChildArticles(category_id, getUserCats)>
		
		<!---we only draw categories that have articles for our users in them.--->
		<cfif hasChildren>
			<cfset drawCat(category_id, level + 1)>
		</cfif>
	</cfloop>
	
	<!---having drawn the child categories, now draw this level's links--->
	<cfset drawCatArticles(catId)>
	
	<!---now close that dangling div tag.--->
	</ul>
</cffunction>

<cffunction name="hasChildArticles">
	<cfargument name="catId">
	
	<!---fetch all the child categories for catId--->
	<cfset var childList = getCategoryChildrenList(catId, getUserCats)>
	<cfset var getArticles = "">
	
	<cfquery dbtype="query" name="getArticles">
		SELECT article_id
		FROM getArticlesToApprove
		WHERE category_id IN (#childList#)
	</cfquery>
	
	<cfif getArticles.recordCount gt 0>
		<cfreturn 1>
	<cfelse>
		<cfreturn 0>
	</cfif>
</cffunction>

<cffunction name="drawCatArticles">
	<cfargument name="catId" type="numeric" required="true">
	
	<cfset var getArticles = "">
	
	<cfquery dbtype="query" name="getArticles">
		SELECT *
		FROM getArticlesToApprove
		WHERE category_id = #catId#
		ORDER BY sort_order ASC, title ASC
	</cfquery>
	
	<cfif getArticles.recordCount gt 0>
		<cfoutput>
			
			<cfloop query="getArticles">
				<li>
					<span class="tinytext">(#dateTimeFormat(revision_date, 'mm/dd/yyyy')#)</span>
					<a href="#application.appPath#/documents/article.cfm?articleId=#article_id#&revisionId=#revision_id#">#stripTags(title)#</a>
					<span class="tinytext">
						[<a href="my_approvals.cfm?frmAction=approve&frmRevisionId=#revision_id#" onClick="return(confirm('Approving this revision will make it visible to everyone who views this article.'));">approve</a>]
						[<a href="my_approvals.cfm?frmAction=reject-confirm&frmRevisionId=#revision_id#">reject</a>]
					</span>
				</li>
			</cfloop>
			
		</cfoutput>
	</cfif>
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">