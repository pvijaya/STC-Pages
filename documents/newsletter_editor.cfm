<cfmodule template="#application.appPath#/header.cfm" title="Newsletter Editor">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Article Editor">

<!--- cfparams --->
<cfparam name="frmCatId" type="integer" default="0">
<cfparam name="frmArticleId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmSortOrder" type="integer" default="1">

<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#?frmCatId=#frmCatId#">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- set-up --->

<cfset newsletter = 7>

<!---build a referrer link for use with the sort_article.cfm form.--->
<cfoutput><cfset referrer = cgi.script_name & "?frmCatId=#frmCatId#"></cfoutput>

<!--- first things first, fetch all the categories once, so we can reuse this information.--->
<cfset getAllCats = getAllCategoriesQuery(0)>

<!--- fetch the users masks, so we can check which articles they can view.--->
<cfset userMasks = bulkGetUserMasks(session.cas_username)>

<!--- double check that this category is in the newsletter category.--->
<cfset parentList = getCategoryParentList(frmCatId, getAllCats)>
<cfif not listFind(parentList, newsletter)>
	<p class="alert">
		The category you provided does not appear to be a Newsletter, please go to the <a href="<cfoutput>#application.appPath#</cfoutput>/documents/newsletter_manager.cfm">Newsletter Manager</a> to select a Newsletter.
	</p>
	<cfmodule template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>

<!---now make sure we have all the masks required by category ownership to publish the articles.--->
<cfset getChildCats = getCategoryChildrenList(frmCatId, getAllCats)>
<cfset ownerMasks = "">

<cfloop list="#getChildCats#" index="catId">
	<!---fetch the ownership cats and add them to ownerMasks.--->
	<cfset catOwners = getInheritedOwnerMasks(catId, getAllCats)>
	<cfloop list="#catOwners#" index="mask">
		<cfif not listFind(ownerMasks, mask)>
			<cfset ownerMasks = listAppend(ownerMasks, mask)>
		</cfif>
	</cfloop>
</cfloop>

<!---now, build a list of owner masks that the viewer is missing.--->
<cfset missingOwnerMasks = "">
<cfloop list="#ownerMasks#" index="maskName">
	<cfif not bulkHasMasks(userMasks, session.cas_username, maskName)>
		<cfset missingOwnerMasks = listAppend(missingOwnerMasks, maskName)>
	</cfif>
</cfloop>
<!---if listLen(missingOwnerMasks) gt 0 then we are missing masks required to publish this newsletter.--->

<!---fetch all the articles in this category and its children.--->
<cfset getArticles = fetchArticles(frmCatId)>

<!---loop over the publication status of the articles, and set whether we have articles to publish, or not.--->
<cfset approvalList = "">
<cfloop query="getArticles">
	<cfif not listFind(approvalList, approved)>
		<cfset approvalList = listAppend(approvalList, approved)>
	</cfif>
</cfloop>

<!--- handle user input --->	
<cftry>
	
	<cfif frmAction EQ "remove">	
			
		<!---update the article, setting retired to true--->
		<cfquery datasource="#application.applicationDataSource#" name="retireArticle">
			UPDATE tbl_articles
			SET retired = 1
			WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
		</cfquery>
		
		<!---now, audit the change we made.--->
		<cfset auditText = "<ul>Article has been <li><b>Retired</b> from Newsletter Editor.</li></ul>">
		
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (#frmArticleId#, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, <cfqueryparam cfsqltype="cf_sql_longvarchar" value="#auditText#">)
		</cfquery>
		
		<!---lastly update the search index.--->
		<cfindex collection="v4-search" action="delete" type="custom" key="a#frmArticleId#">
		
		<p class="ok">
			<cfoutput>Article #frmArticleId# has been removed.</cfoutput>
		</p>
		
	<cfelseif frmAction EQ "publish">
	
		<cfloop query="getArticles">
			<cfif article_id EQ frmArticleId>
				<cfset revision = revision_id>
			</cfif>
		</cfloop>

		<cfquery datasource="#application.applicationDataSource#" name="publish">
			BEGIN TRANSACTION
				/*first, clear out all current use_version columns for all revisions of this article*/
				UPDATE tbl_articles_revisions
				SET use_revision = 0,
					approved = -1
				WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
				
				/* mark this revision as approved and use_version*/
				UPDATE tbl_articles_revisions
				SET	approved = 1,
					use_revision = 1
				WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
					  AND revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#revision#">
			IF @@ERROR <> 0
				ROLLBACK
			ELSE
				COMMIT
		</cfquery>
		
		<!--- that's done, now lets add our audit messages--->
		<cfset auditText = "<b>Revision #revision#</b> published by Newsletter Editor. All other revisions have been marked as rejected.">
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		
		<p class="ok">
			<cfoutput>Article #frmArticleId# has been successfully published.</cfoutput>
		</p>
		
	<cfelseif frmAction EQ "unpublish">
	
		<cfloop query="getArticles">
			<cfif article_id EQ frmArticleId>
				<cfset revision = revision_id>
			</cfif>
		</cfloop>
		
		<cfquery datasource="#application.applicationDataSource#" name="unpublish">
			UPDATE tbl_articles_revisions
			SET	approved = 0
			WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">
				  AND revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#revision#">
				  AND approved != -1 /*but keep rejected revisions rejected.*/
		</cfquery>
		
		<!---now audit those changes--->
		<cfset auditText = "<b>Revision #revision#</b> unpublished by Newsletter Editor.">
		<cfquery datasource="#application.applicationDataSource#" name="addAudit">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmArticleId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		
		<p class="ok">
			<cfoutput>Article #frmArticleId# has been successfully unpublished.</cfoutput> 
		</p>
			
	<cfelseif frmAction EQ "publishAll">

		<!---fetch the articles for this newsletter, the viewer doesn't have the masks for any of the articles prevent publication.--->
		<cfset getArticles = fetchArticles(frmCatId)>
		<cfloop query="getArticles">
			<cfif not has_masks>
				<cfthrow message="Missing Masks" detail="You do not have the masks required to publish the article ""#title#""">
			</cfif>
		</cfloop>
		
		<cfif listLen(missingOwnerMasks) gt 0>
			<cfthrow message="Missing Masks" detail="Some categories in this newsletter require certain masks to be published, you are missing: <em>#missingOwnerMasks#</em>">
		</cfif>
				
		<!---at this point we're in the clear, make the current revision ID both approved and use_version.--->
		
		<!---build up a list of articleId's and revisionId's--->
		<cfset articleList = "">
		<cfset revisionList = "">
		<cfloop query="getArticles">
			<cfset articleList = listAppend(articleList, article_id)>
			<cfset revisionList = listAppend(revisionList, revision_id)>
		</cfloop>
		
		<cfquery datasource="#application.applicationDataSource#" name="publishNewsletter">
			BEGIN TRANSACTION
				/*first, clear out all current use_version columns for all revisions of our articles*/
				UPDATE tbl_articles_revisions
				SET use_revision = 0,
					approved = -1
				WHERE article_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#articleList#" list="true">)
				
				/*mark these revisions as approved and use_version*/
				UPDATE tbl_articles_revisions
				SET	approved = 1,
					use_revision = 1
				WHERE revision_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#revisionList#" list="true">)
				
			IF @@ERROR <> 0
				ROLLBACK
			ELSE
				COMMIT
		</cfquery>
		
		<!--- that's done, now lets add our audit messages--->
		<cfloop query="getArticles">
			<cfset auditText = "<ul>">
			<cfset auditText = auditText & "<li><b>Revision #revision_id#</b> published by Newsletter Editor. All other revisions have been marked as rejected.</li>">
			<cfset auditText = auditText & "</ul>">
			<cfquery datasource="#application.applicationDataSource#" name="addAudit">
				INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
				)
			</cfquery>
		</cfloop>
		
		<p class="ok">
			All of the articles in this newsletter have been published.
		</p>
		
	<cfelseif frmAction EQ "unpublishAll">

		<!---This could be an emergency un-publishing, don't bother with the masks, just un-publish the articles.--->
		<cfset getArticles = fetchArticles(frmCatId)>
		<!---build a list of article_id's.--->
		<cfset articleList = "">
		<cfloop query="getArticles">
			<cfset articleList = listAppend(articleList, article_id)>
		</cfloop>
		
		<cfquery datasource="#application.applicationDataSource#" name="unpublishNewsletter">
			UPDATE tbl_articles_revisions
			SET	approved = 0
			WHERE article_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#articleList#" list="true">)
			AND approved <> -1/*but keep rejected revisions rejected.*/
		</cfquery>
		
		<!---now audit those changes--->
		<cfloop query="getArticles">
			<cfset auditText = "<ul>">
			<cfset auditText = auditText & "<li>All revisions <b>un-published</b> by Newsletter Editor.</li>">
			<cfset auditText = auditText & "</ul>">
			
			<cfquery datasource="#application.applicationDataSource#" name="addAudit">
				INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
				)
			</cfquery>
		</cfloop>
		
		<p class="ok">
			All of the articles in this newsletter are no longer published. 
		</p>

	</cfif>
		
<cfcatch type="any">
	<p class="warning">
		<cfoutput>#cfcatch.Message# - #cfcatch.detail#</cfoutput>
	</p>
</cfcatch>

</cftry>
	
<!--- --->	

<!---fetch all the articles in this category and its children.--->
<cfset getArticles = fetchArticles(frmCatId)>

<!---loop over the publication status of the articles, and set whether we have articles to publish, or not.--->
<cfset approvalList = "">
<cfloop query="getArticles">
	<cfif not listFind(approvalList, approved)>
		<cfset approvalList = listAppend(approvalList, approved)>
	</cfif>
</cfloop>

<!--- header / navigation --->
<div id="articleId" style="width:75%;margin:0px auto;padding:5px;" class="shadow-border">
	<h1><cfoutput>Newsletter Editor (#myInstance.instance_name#)</cfoutput></h1>
	<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
		[<a href="<cfoutput>#application.appPath#/documents/newsletter_manager.cfm</cfoutput>">Go Back</a>]	
		[<a href="<cfoutput>#application.appPath#/documents/article_editor.cfm?frmCatId=#frmCatId#&frmReferrer=#urlEncodedFormat(cgi.script_name & "?frmCatId=" & frmCatId)#&frmSortOrder=#getArticles.recordCount+1#</cfoutput>">Add Article</a>]	
		[<a href="<cfoutput>#application.appPath#/documents/sort_articles.cfm?frmCatId=#frmCatId#&frmReferrer=#urlEncodedFormat(cgi.script_name & "?frmCatId=" & frmCatId)#</cfoutput>">Sort Articles</a>]
		<cfif hasMasks('newsletter owner')> 	
			<cfif listFind(approvalList, 0)>
				[<a href="<cfoutput>#cgi.script_name#?frmCatId=#frmCatId#&frmAction=publishAll</cfoutput>"
					onClick="return(confirm('Every newsletter article will be published and visible in its current state. Is that okay?'))" 
					title="Publish All">Publish All Articles</a>]
			</cfif>
			<cfif listFind(approvalList, 1)>
				[<a href="<cfoutput>#cgi.script_name#?frmCatId=#frmCatId#&frmAction=unpublishAll</cfoutput>"
					onClick="return(confirm('Every newsletter article will be unpublished. Is that okay?'))" 
					title="Unpublish All">Un-Publish All Articles</a>]
			</cfif>	
		</cfif>
	</p>
<!--- --->

<!--- draw newsletter editor --->
	
	<hr/>	
	<!---draw our categories for this newsletter.--->
	<cfset drawCat(frmCatId)>	
	<hr/>
	
</div>
<!--- --->

<!--- functions --->

<!--- draws a category, and its articles.--->
<cffunction name="drawCat">
	<cfargument name="catId" type="numeric" required="true">
	
	<cfset var getChildCats = getChildCategoriesByParent(catId, getAllCats)>
	<cfset var referrer = "">
	
	<!---loop over getAllCategories until we reach catId, then draw it.--->
	<cfloop query="getAllCats">
		<cfif category_id eq catId>			
			<cfoutput>
				
				<cfif isDate(category_name)>
					<cfset NLName = LSDateFormat(parseDateTime(category_name), "mmmm yyyy")>
				<cfelse>
					<cfset NLName = category_name>
				</cfif>
				
				<h2>#NLName#</h2>

			</cfoutput>
		</cfif>
	</cfloop>
	
	<!---draw this categories articles.--->
	<cfset drawCatArticles(catId)>
	
	<!---now draw any child categories--->
	<cfloop query="getChildCats">
		<cfset drawCat(category_id)>
	</cfloop>
	
</cffunction>

<cffunction name="drawCatArticles">
	<cfargument name="catId" type="numeric" required="true">
	
	<cfset var referrer = "">
	
	<cfloop query="getArticles">
		<hr/>
		<cfif category_id eq catId>
			<cfoutput>
				<h3 style="margin-bottom:0em;">
					<a id="article<cfoutput>#article_id#</cfoutput>" 
					   href="#application.appPath#/documents/article.cfm?articleId=#article_id#&revisionId=#revision_id#" 
					   title="view individual article, history, and revisions">
						#title#
					</a>
					
					<!--- beneath every article title, display an alert message indicating the publish status. --->
					<!--- green (.ok) = article is published, viewing published revision --->
					<!--- yellow (.alert) = article is published, viewing an unpublished revision --->
					<!--- red (.warning) = article is not published --->
					
					<cfset published = approved>
					<!--- if the current revision is not being used, figure out whether there is another 
					revision of this article currently published. --->
					<cfif not use_revision>
						<cfquery datasource="#application.applicationDataSource#" name="getPublishStatus">
							SELECT ar.approved, ar.use_revision
							FROM tbl_articles_revisions ar
							WHERE ar.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">
								  AND ar.approved = 1
								  AND ar.use_revision = 1
						</cfquery>
						<cfset published = getPublishStatus.recordCount>
					</cfif>
					
					<span style="font-size: 8pt; font-weight: normal;font-style: italic;">
						<cfif published>
							<cfif use_revision>
								<p class="ok">Published</p>
							<cfelse>
								<p class="alert">Unpublished revision</p>
							</cfif>
						<cfelse>
							<p class="warning">Unpublished</p>
						</cfif>
					</span>
				</h3>				
			</cfoutput>
			
			<!---build the referrer link for use with editors.--->
			<cfset referrer = cgi.script_name & "?frmCatId=#frmCatId###article#article_id#">
			
			<!---If they have the masks, draw the article, if not show an alert.--->
			<cfif has_masks>
				
				<cfoutput>
					<p class="tinytext" style="padding: 0px;margin-top: 0em;margin-bottom: 0.5em;">
						[<a href="#application.appPath#/documents/article_editor.cfm?frmArticleId=#article_id#&frmRevisionId=#revision_id#&frmReferrer=#urlEncodedFormat(referrer)#">Edit Article</a>] 
						[<a href="#application.appPath#/documents/newsletter_editor.cfm?frmAction=remove&frmArticleId=#article_id#&frmCatId=#frmCatId#" 
							onClick="return confirm('Are you sure you want to remove this article?');">Remove Article</a>]
						<cfif not published>
							[<a href="#application.appPath#/documents/newsletter_editor.cfm?frmAction=publish&frmArticleId=#article_id#&frmCatId=#frmCatId#" 
								onClick="return confirm('Are you sure you want to publish this article? It will be visible to all viewers.');">Publish Article</a>]
						</cfif>
						<cfif published and not use_revision>
							[<a href="#application.appPath#/documents/newsletter_editor.cfm?frmAction=publish&frmArticleId=#article_id#&frmCatId=#frmCatId#" 
								onClick="return confirm('Are you sure you want to publish this revision?');">Publish Revision</a>]
						</cfif>
						<cfif published and use_revision>
							[<a href="#application.appPath#/documents/newsletter_editor.cfm?frmAction=unpublish&frmArticleId=#article_id#&frmCatId=#frmCatId#" 
								onClick="return confirm('Are you sure you want to unpublish this article? It will no longer be visible to viewers.');">Unpublish Article</a>]
						</cfif>
					</p>
					#revision_content#
				</cfoutput>
				
			<cfelse>
				<p class="alert">
					You do not have the masks required to view or publish this article.
				</p>
			</cfif>
			
		</cfif>
		
	</cfloop>
	
</cffunction>

<!---finds all child articles for a category(and child categories), and then marks if they have the masks required to view them.--->
<cffunction name="fetchArticles">
	<cfargument name="catId" type="numeric" required="true">
	
	<cfset var childList = getCategoryChildrenList(catId, getAllCats)><!---fetch all the child categories, so we can get the articles in one fell swoop.--->
	<cfset var getArticles = ""><!---the query that fetches the articles--->
	<cfset var articleList = ""><!---get all the articles, so we can get all their masks quickly, too.--->
	<cfset var getArticleMasks = ""><!---the query that fetches the masks for all our articles from the the DB.--->
	<cfset var masksList = ""><!---a list of the masks needed to view each article--->
	<cfset var outputQuery = queryNew("article_id, category_id, username, created_date, revision_id, title, revision_content, approved, sort_order, revision_date, has_masks, use_revision, retired", 
			"integer,integer,varchar,date,integer,varchar,varchar,bit,integer,date,bit,bit,bit")>
	
	<cfquery datasource="#application.applicationDataSource#" name="getArticles">
		SELECT a.article_id, a.category_id, u.username, a.created_date, ar.revision_id, ar.title, 
			   ar.revision_content, ar.approved, a.sort_order, ar.revision_date, ar.use_revision, a.retired
		FROM tbl_articles a
		INNER JOIN tbl_users u ON u.user_id = a.creator_id
		INNER JOIN tbl_articles_revisions ar 
			ON ar.article_id = a.article_id
			AND ar.revision_id = (SELECT TOP 1 revision_id 
								  FROM tbl_articles_revisions 
								  WHERE article_id = a.article_id 
								  	    AND approved != -1 /*not rejected revisions, either*/
								  ORDER BY revision_date DESC)/*limit to the most recent revision, approved or not.*/
		WHERE a.retired = 0
			  AND a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#childList#" list="true">)
	    ORDER BY a.sort_order, ar.title
	</cfquery>
		
	<!---build up a list of article id's so we catch fetch required masks--->
	<cfset articleList = "">
	<cfloop query="getArticles">
			<cfset articleList = listAppend(articleList, article_id)>
	</cfloop>
	
	<!---now fetch article masks.--->
	<cfquery datasource="#application.applicationDataSource#" name="getArticleMasks">
		SELECT am.article_id, am.mask_id, um.mask_name
		FROM tbl_articles_masks am
		INNER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
		WHERE am.article_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#articleList#" list="true">)
	</cfquery>
	
	<!---loop over each article, and add it to outputQuery, and determine if he viewer has the masks required to view each article.--->
	<cfloop query="getArticles">
		<cfset queryAddRow(outputQuery)>
		<cfset querySetCell(outputQuery, "article_id", article_id)>
		<cfset querySetCell(outputQuery, "category_id", category_id)>
		<cfset querySetCell(outputQuery, "username", username)>
		<cfset querySetCell(outputQuery, "created_date", created_date)>
		<cfset querySetCell(outputQuery, "revision_id", revision_id)>
		<cfset querySetCell(outputQuery, "title", title)>
		<cfset querySetCell(outputQuery, "revision_content", revision_content)>
		<cfset querySetCell(outputQuery, "approved", approved)>
		<cfset querySetCell(outputQuery, "sort_order", sort_order)>
		<cfset querySetCell(outputQuery, "revision_date", revision_date)>
		<cfset querySetCell(outputQuery, "use_revision", use_revision)>
		<cfset querySetCell(outputQuery, "retired", retired)>
		
		<cfset masksList = "">
		<cfloop query="getArticleMasks">
			<cfif getArticleMasks.article_id eq getArticles.article_id>
				<cfset masksList = listAppend(masksList, mask_name)>
			</cfif>
		</cfloop>
		
		<cfset querySetCell(outputQuery, "has_masks", bulkHasMasks(userMasks, session.cas_username, masksList))>
		
	</cfloop>
	
	<cfreturn outputQuery>
	
</cffunction>
	
<cfmodule template="#application.appPath#/footer.cfm">