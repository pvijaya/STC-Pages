<cfmodule template="#application.appPath#/header.cfm" title='Community Page' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfparam name="frmAction" type="string" default="">
<cfmodule template="#application.appPath#/modules/jsonParam.cfm" varName="frmRoute" default='{"instance_id":0,"site_id":0}'>

<h1>Community Message Board</h1>
<a href="https://pie.iu.edu/apps/tetra/documents/article.cfm?articleId=11486">Rules to write message </a>
<cfif hasMasks("Admin")>
	<cfoutput>
	| <a href="community_manager.cfm"> Community Manager </a>
	</cfoutput>
</cfif>
<cfif frmAction neq "">
	| <a href="community.cfm">Select Another Community</a>
</cfif>

<cfif frmAction eq "saveEdit">
	<!---our user submitted a new version of the article, mark all previous revisions as unused, and add the new one.--->
	<cfparam name="frmArticleContent" type="string" default="">

	<cftry>
		<cfset myComm = getCommunity(frmRoute.instance_id, frmRoute.site_id)>

		<cfquery datasource="#application.applicationDataSource#" name="updateArticle">
			BEGIN TRANSACTION

				UPDATE tbl_articles_revisions
				SET use_revision = 0
				WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myComm.article_id#">

				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, approved, use_revision, revision_date)
				VALUES(
					<cfqueryparam cfsqltype="cf_sql_integer" value="#myComm.article_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmRoute.site_name# Community Article">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmArticleContent#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					1,
					1,
					GETDATE()
				)

			IF @@ERROR <> 0
				ROLLBACK
			ELSE
				COMMIT
		</cfquery>

		<!---if that worked it updated.  Show them the result.--->
		<div class="alert alert-success" role="alert">
			Comments updated successfully.
		</div>
		<cfset frmAction = "showRoute">

	<cfcatch>
		<!---we hit some snag, show the error and take them back to the editor.--->
		<cfoutput>
			<div class="alert alert-danger" role="alert">
				#cfcatch.message#<br/>
				<span class="tinytext">#cfcatch.detail#</span>
			</div>
		</cfoutput>
		<cfset frmAction = "showEditor">
	</cfcatch>
	</cftry>


</cfif>


<cfif frmAction eq "showRoute" AND frmRoute.site_id neq 0>

	<div class="col-sm-offset-3">
		<h2><cfoutput>#frmRoute.site_name# Community</cfoutput></h2>
		<!---fetch the most recent information for our community--->
		<cfset myComm = getCommunity(frmRoute.instance_id, frmRoute.site_id)>

		<!---if we don't already have a community for this route, the admin have access to lab manager which enable them to create it.--->
		<cfif myComm.recordCount eq 0>
			<!---<cfset myComm = addCommunity(frmRoute)>--->
			<div class="alert alert-warning" role="alert">
				The community does not exist. Please contact Admin to create a new community.
			</div>
		</cfif>

		<cfoutput query="myComm">
			<cfif not active>
				<h3>(Retired)</h3>
			</cfif>

			<div class="tinytext">
				Last revised #dateTimeFormat(revision_date, "mmm d, yyyy h:nn tt")# by #username#
			</div>
			<div class="well">
				#revision_content#
			</div>
		</cfoutput>
	</div>
	<!---a form for editing the community article--->
	<form method="post">
		<cfset bootstrapHiddenField("frmAction", "showEditor")>
		<cfset bootstrapHiddenField("frmRoute", SerializeJSON(frmRoute) )>
		<cfset bootstrapSubmitField("frmSubmit", "Edit")>
	</form>

<cfelseif frmAction eq "showEditor">
	<h2><cfoutput>#frmRoute.site_name# Community</cfoutput></h2>
	<cfset myComm = getCommunity(frmRoute.instance_id, frmRoute.site_id)>
	<cfif not isDefined("frmArticleContent")>
		<cfparam name="frmArticleContent" type="string" default="#myComm.revision_content#">
	</cfif>

	<!---have our user edit the community message.--->
	<form method="post">
		<cfset bootstrapHiddenField("frmAction", "saveEdit")>
		<cfset bootstrapHiddenField("frmRoute", SerializeJSON(frmRoute) )>
		<cfset bootstrapEditorField("frmArticleContent", "Revised Comments",frmArticleContent)>
		<cfset bootstrapSubmitField("frmSubmit", "Save")>
	</form>

<cfelse>
	<!---this is our default case, to draw a selector of all the routes/communities--->
	<form method="post">
		<cfset bootstrapHiddenField("frmAction", "showRoute")>
		<cfset bootstrapSelectField("frmRoute", getRoutesObj(), "Choose a message board", frmRoute, "The lab name.")>
		<cfset bootstrapSubmitField("frmSubmit", "Submit")>
	</form>

</cfif>


<cfmodule template="#application.appPath#/footer.cfm">

<cffunction name="getRoutesObj">
<!---	<cfset var routesArray = arrayNew(1)>--->
	<cfset var routesArray = [{"name": "", "value": {"site_id":0}}]>
	<cfset var getRoutes = "">
	<cfquery datasource="#application.applicationDataSource#" name="getRoutes">
		SELECT c.community_id, s.site_name,  s.instance_id, s.site_id, c.active, i.instance_mask, m.mask_id AS instance_mask_id
		FROM tbl_communities c
		INNER JOIN vi_sites s
			ON s.instance_id = c.instance_id
			AND s.site_id = c.site_id
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		INNER JOIN tbl_user_masks m ON m.mask_name = i.instance_mask
		WHERE community_id IS NOT NULL
			AND s.retired = 0
			AND s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			AND c.active = 1
		ORDER BY s.instance_id, s.site_name
	</cfquery>

	<cfloop query="getRoutes">
		<cfset arrayAppend(routesArray, {"name": site_name, "value": {"instance_id": instance_id, "instance_mask": instance_mask, "site_id": site_id, "site_name": site_name} })>
	</cfloop>



	<cfreturn routesArray>
</cffunction>

<cffunction name="getCommunity">
	<cfargument name="instanceId"  type="numeric" required="true">
	<cfargument name="siteId"  type="numeric" required="true">

	<cfset var getCommunityQuery = "">

	<cfquery datasource="#application.applicationDataSource#" name="getCommunityQuery">
		SELECT c.community_id, c.article_id, c.active, ar.revision_content, revision_date, u.username
		FROM tbl_communities c
		LEFT OUTER JOIN tbl_articles_revisions ar
			ON ar.article_id = c.article_id
			AND ar.use_revision = 1
		LEFT OUTER JOIN tbl_users u ON u.user_id = ar.user_id

		WHERE  c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND  c.site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#siteId#">
	</cfquery>

	<cfreturn getCommunityQuery>
</cffunction>

<cffunction name="addCommunity">
	<cfargument name="route" type="struct" required="true">

	<cfset var createArticle = "">
	<cfset var createArticleMasks = "">
	<cfset var createArticleRevision = "">
	<cfset var createCommunity = "">

	<!---we start by adding an article--->
	<cfquery datasource="#application.applicationDataSource#" name="createArticle">
		INSERT INTO tbl_articles (category_id, creator_id, sort_order)
		OUTPUT inserted.article_id
		VALUES (507, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, 0)
	</cfquery>

	<!---every article needs a mask restricting its access to Consultants.--->
	<cfquery datasource="#application.applicationDataSource#" name="createArticleMasks">
		INSERT INTO tbl_articles_masks (article_id, mask_id)
		SELECT <cfqueryparam cfsqltype="cf_sql_integer" value="#createArticle.article_id#">, mask_id
		FROM tbl_user_masks
		WHERE mask_name IN ('Consultant', <cfqueryparam cfsqltype="cf_sql_varchar" value="#route.instance_mask#">)
	</cfquery>

	<!---every article needs an initial revision.--->
	<cfquery datasource="#application.applicationDataSource#" name="createArticleRevision">
		INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, approved, use_revision, revision_date)
		VALUES(
			<cfqueryparam cfsqltype="cf_sql_integer" value="#createArticle.article_id#">,
			<cfqueryparam cfsqltype="cf_sql_varchar" value="#route.site_name# Community Article">,
			<cfqueryparam cfsqltype="cf_sql_varchar" value="#route.site_name# initial note.">,
			<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
			1,
			1,
			GETDATE()
		)
	</cfquery>

	<!---lastly we're ready to create the entry in tbl_communities--->
	<cfquery datasource="#application.applicationDataSource#" name="createCommunity">
		INSERT INTO tbl_communities (instance_id, site_id, article_id)
		VALUES (
		<cfqueryparam cfsqltype="cf_sql_integer" value="#route.instance_id#">,
		<cfqueryparam cfsqltype="cf_sql_integer" value="#route.site_id#">,
		<cfqueryparam cfsqltype="cf_sql_integer" value="#createArticle.article_id#">
		)
	</cfquery>

	<!---with that complete we can return our newly created community--->
	<cfset var newComm = getCommunity(route.instance_id, route.site_id)>

	<cfreturn newComm>
</cffunction>
