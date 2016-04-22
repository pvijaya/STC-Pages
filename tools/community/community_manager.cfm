<cfmodule template="#application.appPath#/header.cfm" title='Community Lab Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
<cfmodule template="#application.appPath#/modules/jsonParam.cfm" varName="frmRoute" default='{"instance_id":0,"site_id":0}'>
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="selector" default="[]">
<cfparam name="purgeInfo" type="string" default="Only Admin can delete the community messages. Purging is expected to be done before the beginning of each semester">
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmSubmit" type="string" default="">
<cfparam name="newCommunity" type="string" default=" ">
<cfparam name="frmRetired" type="boolean" default="0">

<h1>Community Manager</h1>

<!--- check for admin permissions to have the ability to purge --->
<cfset isAdmin = 0>
<cfif hasMasks("Admin")>
	<cfset isAdmin = 1>
</cfif>

<cfif hasMasks("Admin")>
	<cfoutput>
		<a href="#cgi.script_name#?frmSubmit=newCommunity">Create a new community</a>
	</cfoutput>
</cfif>

<cfif frmAction neq "" OR frmSubmit neq "">
	| <a href="community_manager.cfm">Go Back</a>
</cfif>
<cfif frmRoute.site_id EQ 0 and frmSubmit EQ ''>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
		<cfset bootstrapHiddenField("frmAction", "Edit")>
		<cfset bootstrapSelectField("frmRoute", getRoutesObj(), "Edit the Lab", frmRoute, "The lab name.")>
		<cfset bootstrapSubmitField("frmSubmit", "Submit")>
	</form>
</cfif>

<cfquery datasource="#application.applicationDataSource#" name="checkStatus">
		SELECT active
		FROM tbl_communities
		WHERE site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRoute.site_id#">
		AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
</cfquery>

<cfif frmAction EQ "Edit" AND frmRoute.site_id NEQ 0>
		<cfset bootstrapHiddenField("frmAction", "Update")>
		<cfset bootstrapTextDisplay(frmRoute.site_name, "Community", frmRoute.site_name, "Select a lab", "The lab name.")>
		<cfset labRadioOptions = ArrayNew(1)>
	<cfif checkStatus.active EQ 0>
			<cfset ArrayAppend(labRadioOptions, {"name" = "Active", "value" = 1})>
			<cfset ArrayAppend(labRadioOptions, {"name" = "Retired", "value" = 0})>
	<cfelse>
			<cfset ArrayAppend(labRadioOptions, {"name" = "Active", "value" = 0})>
			<cfset ArrayAppend(labRadioOptions, {"name" = "Retired", "value" = 1})>
	</cfif>

		<cfoutput>#bootstrapRadioField("frmRetired", labRadioOptions, "Status", frmRetired)#</cfoutput>
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">

		<cfset bootstrapHiddenField("frmRoute", SerializeJSON(frmRoute))>
		<cfset bootstrapHiddenField("frmAction", "Update")>
		<cfset bootstrapSubmitField("frmSubmit", "Update")>

	</form>
</cfif>

<!--- Purging the messages--->
<cfif frmAction EQ "" and frmSubmit EQ "">
<cfif isAdmin>
		<div class="col-sm-12" style="margin-top: 2em;">
			<form method="post" onsubmit="return confirm('Do you confirm to DELETE the messages of ALL communities?');">
				<cfoutput>
					<fieldset>
						<legend>Clear all community messages</legend>
							<cfset bootstrapHiddenField("frmAction", "purgeMessages")>
							<cfset bootstrapTextDisplay("purgeInfo", "", purgeInfo, "", "")>
							<cfset bootstrapSubmitField("frmSubmit", "Purge")>
					</fieldset>
				</cfoutput>
			</form>
		</div>
</cfif>
</cfif>

<!--- query to make purging --->
<cfif frmAction eq "purgeMessages">
	<cfif isAdmin>
		<cfquery datasource="#application.applicationDataSource#" name="updateRevisions">
			BEGIN TRANSACTION

			UPDATE tbl_articles_revisions
			SET use_revision=0
			WHERE article_id IN (
				SELECT tc.article_id
				FROM tbl_communities tc
				INNER JOIN tbl_articles a ON a.article_id = tc.article_id
				WHERE tc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
				AND a.retired = 0
			);


			INSERT INTO tbl_articles_revisions
				(article_id,title,revision_content,user_id,comment,approved,use_revision,revision_date)
				/*Limit to just one revision, the most recent one.*/
				SELECT tar.article_id,tar.title,' ', <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,tar.comment,tar.approved,1,GETDATE()
				FROM  tbl_articles_revisions tar
				INNER JOIN  tbl_communities tc ON tc.article_id = tar.article_id
				INNER JOIN tbl_articles a
					ON a.article_id = tc.article_id
					AND a.retired = 0
				WHERE tc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
				/*Limit to just one revision, the most recent one.*/
				AND tar.revision_id = (
					SELECT TOP 1 revision_id
					FROM tbl_articles_revisions
					WHERE article_id = tar.article_id
					ORDER BY revision_date DESC
				)

			IF @@ERROR <> 0
				ROLLBACK
			ELSE
				COMMIT

		</cfquery>
		<!---if that worked it updated.  Show them the result.--->
		<div class="alert alert-success" role="alert">
			Purged successfully.
		</div>

	<cfelse>
		<div class="alert alert-warning" role="alert">
			You must be an Admin to use the Purge Tool.
		</div>
  </cfif>
</cfif>



<cfif frmAction EQ "Update" AND frmRoute.site_id GT 0>
	<cfset myComm = getCommunity(frmRoute.instance_id, frmRoute.site_id)>
		<cfquery datasource="#application.applicationDataSource#" name="updateCommunity">

			<cfif checkStatus.active EQ 0>
				UPDATE tbl_communities SET active=1
				WHERE site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRoute.site_id#">
				AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">

				UPDATE tbl_articles SET retired=0
				WHERE category_id = 507
				AND article_id =<cfqueryparam cfsqltype="cf_sql_integer" value="#myComm.article_id#">

			<cfelseif checkStatus.active NEQ 0>
				UPDATE tbl_communities SET active=0
				WHERE site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmRoute.site_id#">
				AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">

				UPDATE tbl_articles SET retired=1
				WHERE category_id = 507
				AND article_id =<cfqueryparam cfsqltype="cf_sql_integer" value="#myComm.article_id#">

			</cfif>

		</cfquery>
		<!---if that worked it updated.  Show them the result.--->
		<div class="alert alert-success" role="alert">
			Updated successfully
		</div>

</cfif>
<cfif frmSubmit EQ 'newCommunity'>
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
		<cfset bootstrapHiddenField("frmAction", "Create")>
		<cfset bootstrapSelectField("frmRoute", getRoutesWithoutCommunity(), "Select a lab", frmRoute, "The lab name.")>
		<cfset bootstrapSubmitField("frmSubmit", "Create")>
	</form>

</cfif>
<cfif frmAction EQ 'Create' AND frmSubmit EQ "Create">

	<div class="col-sm-offset-3">
		<h2><cfoutput>#frmRoute.site_name# Community</cfoutput></h2>
		<!---fetch the most recent information for our community--->
		<cfset myComm = getCommunity(frmRoute.instance_id, frmRoute.site_id)>

		<!---if we don't already have a community for this route we need to create it.--->
		<cfif myComm.recordCount eq 0>
			<cfset myComm = addCommunity(frmRoute)>
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
		<div class="alert alert-success" role="alert">
			Community Added successfully
		</div>
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
			AND c.active IN (0,1)
		ORDER BY c.active DESC, s.site_name

	</cfquery>
	<cfloop query="getRoutes">
		<cfif getRoutes.active EQ 1>
			<cfset arrayAppend(routesArray, {"name": "#site_name#" , "value": {"instance_id": instance_id, "instance_mask": instance_mask, "site_id": site_id, "site_name": "#site_name#", active:"#active#"} })>
		<cfelse>
			<cfset arrayAppend(routesArray, {"name": "#site_name# (Retired)" , "value": {"instance_id": instance_id, "instance_mask": instance_mask, "site_id": site_id, "site_name": "#site_name#", active:"#active#"} })>
		</cfif>
	</cfloop>



	<cfreturn routesArray>
</cffunction>


<cffunction name="getRoutesWithoutCommunity">
<!---	<cfset var routesArray = arrayNew(1)>--->
	<cfset var routesArray = [{"name": "", "value": {"site_id":0}}]>
	<cfset var getRoutesWithoutCommunity = "">
	<cfquery datasource="#application.applicationDataSource#" name="getRoutesView">
		SELECT s.*,  i.instance_mask, m.mask_id AS instance_mask_id
		FROM vi_sites s
		INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
		INNER JOIN tbl_user_masks m ON m.mask_name = i.instance_mask
		LEFT OUTER JOIN tbl_communities c
			ON c.instance_id = s.instance_id
			AND c.site_id = s.site_id
		WHERE community_id IS NULL
		AND s.retired = 0
		AND s.staffed =1
		AND s.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">

	</cfquery>

	<cfloop query="getRoutesView">
		<cfset arrayAppend(routesArray, {"name": site_name , "value": {"instance_id": instance_id,  "instance_mask": instance_mask, "site_id": site_id, "site_name": site_name} })>
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
		WHERE c.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND c.site_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#siteId#">

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

