<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant" showMaskPermissions="False">

<cfparam name="instanceId" type="integer" default="#Session.primary_instance#">

<cfset myInstance = getInstanceById(session.primary_instance)>

<cfset frmCatId = 3>
<!---fetch all the child categories, too so we don't miss announcements in folders.--->
<cfset catList = getCategoryChildrenList(frmCatId)>
<cfset semesterObj = getSemesterByDate(instanceId)>

<h2>Announcements</h2>

<!---now, much like we do in hasMasks() from common functions get a query of all the masks a user has, both explicitly and inherited, this should help us avoid using vi_all_masks_users and stressing the DB.--->

<!--- first find all instance masks the user has that do not correspond to the primary instance --->
<cfquery datasource="#application.applicationDataSource#" name="getNegInstanceMasks">
	SELECT um.mask_id
	FROM tbl_instances i
	INNER JOIN tbl_user_masks um ON um.mask_name = i.instance_mask
	WHERE i.instance_mask != <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
</cfquery>

<cfset negMaskList = "0">
<cfloop query="getNegInstanceMasks">
	<cfset negMaskList = listAppend(negMaskList, mask_id)>
</cfloop>

<!---fetch all the masks the user explicitly has--->
<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
	SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
	FROM tbl_users u
	INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
	INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
	WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
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

<!---now use our helper function to build get a query of all masks the user has, both explicitly and inheritted.--->
<cfset getUserMasks = buildMyMasks(getMyMasks, getAllMaskRelationships)>

<!---now turn that into a list of mask_id's for use in the readership query below.--->
<cfset myMaskList = ""><!---a placeholder so we never have a list of length 0--->
<cfloop query="getUserMasks">
	<cfif NOT listFindNoCase(negMaskList, mask_id)>
		<cfset myMaskList = listAppend(myMaskList, mask_id)>
	</cfif>
</cfloop>


<cfquery datasource="#application.applicationDataSource#" name="getArticles">
	SELECT a.article_id, a.category_id, a.created_date, rev.title, rev.revision_content, r.first_view_date, r.recent_view_date, r.long_view, r.long_view_date, um.mask_name
	FROM tbl_articles a
	INNER JOIN tbl_articles_revisions rev
		ON rev.article_id = a.article_id
		AND rev.revision_id = (SELECT TOP 1 revision_id FROM tbl_articles_revisions WHERE article_id = a.article_id AND use_revision = 1 ORDER BY revision_date DESC)
	INNER JOIN tbl_articles_categories c
		ON c.category_id = a.category_id
		AND c.retired = 0 /*we aren't interested in articles in retired categories*/
	LEFT OUTER JOIN tbl_articles_readership r
		ON r.article_id = a.article_id
		AND r.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	LEFT OUTER JOIN tbl_articles_masks am ON a.article_id = am.article_id
	LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
	WHERE a.retired = 0 /*exclude retired articles*/
		AND r.read_id IS NULL
	AND a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#catList#" list="true">)<!---JDBC got SUPER pissy about those comments when they were right beside 'c.retired = 0' and wouldn't bind these parameters.--->
	AND a.created_date >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#semesterObj.start_date#">
	/*This cluase looks tricky, but it limits us to articles that the user has the masks to view.*/
	AND NOT EXISTS (
		SELECT am.mask_id
		FROM tbl_articles_masks am
		WHERE am.article_id = a.article_id
		AND am.mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#myMaskList#" list="true">)
	)
	ORDER BY a.article_id, um.mask_name
</cfquery>

<cfset counter = 0><!---a count of how many unique articles we've found for the user to read.--->

<cfloop query="getArticles" group="article_id">
	<cfset maskList = ""><!---build up a list of masks we found for this user.--->
	<cfloop>
		<cfif mask_name neq "">
			<cfset maskList = listAppend(maskList, mask_name)>
		</cfif>
	</cfloop>

	<cfset counter = counter + 1>

	<cfoutput>
		<p>
		<a style="display:block;" class="hover-box" href="#Application.appPath#/documents/article.cfm?articleId=#article_id#">
			<strong>#title#</strong><br/>
			<span class="tinytext">#dateTimeFormat(created_date, "MMM d, yyyy h:nn aa")#</span>
			<cfloop list="#maskList#" index="maskName">
				<span class="tinytext ui-state-default ui-corner-all">#maskName#</span>
			</cfloop>
			<br/>
			#trimString(stripTags(revision_content), 250)#
		</a>
		</p>
	</cfoutput>
</cfloop>

<cfif counter NEQ 0>
	<cfoutput>
		<div>
			You have <span id="announcementCount">#counter#</span> unread announcements.
		</div>
	</cfoutput>
<cfelseif counter EQ 0>
	<cfoutput>
		<h4>Congratulations!</h4>
		<p>You have read all of the announcements.</p>
		<p><a href="#application.appPath#/documents/article.cfm?catId=3">View old announcements</a></p>
	</cfoutput>
</cfif>

<!---cs and up could use the ability to post announcements.--->
<cfif hasMasks("CS")>
	<cfoutput>
		<p>
			<!---ideally we would provide the instance mask, too, but Jared's working on a solution.--->
			<a href="#application.appPath#/documents/article_editor.cfm?frmCatId=3">Create a New Announcement</a>
		</p>
	</cfoutput>
</cfif>
