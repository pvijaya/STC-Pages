<!---this page fetches the readership of a category, for articles created over a date-range, for a single user.--->
<cfif not isDefined("attributes")>
	<h1>Error</h1>
	<p>
		This page is to be exclusively used as a module, and cannot be browsed to.
	</p>
	<cfabort>
</cfif>

<!---since this is a module we may need to bring in our common functions.--->
<cfif not isDefined("getAllCategoriesQuery")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<!---we need this parameter before any others so users can view their own readership.--->
<cfparam name="attributes.uid" type="integer" default="0"><!---the user_id for our user.--->

<!---make sure the viewer has permission to view this module's output--->
<cfif not hasMasks("cs") AND session.cas_uid neq attributes.uid>
	<p>You do not have permission to use mod_individual_readership.cfm</p>
<cfelse>
	<!---they can view this report.--->
	<!---now gather up our parameters--->
	<cfparam name="attributes.catId" type="integer" default="0"><!---the category to look for (un)read articles in.--->
	<cfparam name="attributes.read" type="boolean" default="0"><!---are we looking for read or unread articles?--->
	<cfparam name="attributes.start" type="date" default="1999-01-01">
	<cfparam name="attributes.end" type="date" default="#now()#">

	<cfparam name="attributes.width" type="string" default="50%"><!---how wide should this item be?--->
	<cfparam name="attributes.indentation" type="string" default="2em"><!---how much should each item in a list be indented.--->
	<cfparam name="attributes.header" type="integer" default="1"><!---show the username and percent read?.--->

	<cfset myId = "readership" & createUUID()><!---myId is a unique ID so we don't clobber other CSS and javascript classes.--->

	<!---no matter how the date came in format it to our liking--->
	<cfset attributes.start = dateFormat(attributes.start, "mmm d, yyyy")>
	<cfset attributes.end = dateFormat(attributes.end, "mmm d, yyyy")>

	<!---fetch all categories for use with functions later.--->
	<cfset allCats = getAllCategoriesQuery(0)><!---don't include retired categories.--->

	<cfif attributes.uid gt 0>
		<!---if we've gotten this far we have a user and our dates. Report what they have and haven't read.--->

		<!---get the user's info.--->
		<cfquery datasource="#application.applicationDataSource#" name="getUser">
			SELECT username, last_name, first_name
			FROM tbl_users
			WHERE user_id = #attributes.uid#
		</cfquery>

		<cftry>

			<!---much like we do in hasMasks() from common functions get a query of all the masks a user has, both explicitly and inherited, this should help us avoid using vi_all_masks_users and stressing the DB.--->
			<!---fetch all the masks the user explicitly has--->
			<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
				SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
				FROM tbl_users u
				INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
				INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
				WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#attributes.uid#">
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
			<cfset myMaskList = "0"><!---a placeholder so we never have a list of length 0--->
			<cfloop query="getUserMasks">
				<cfset myMaskList = listAppend(myMaskList, mask_id)>
			</cfloop>

			<!---now, wrap all our output in our unique div tag--->
			<div id="<cfoutput>#myId#</cfoutput>">
			<cfoutput>
				<cfif attributes.header EQ 1>
					<h2 style="margin-bottom: 0px;">#getUser.first_name# #getUser.last_name# (#getUser.username#)</h2>
					<p style="margin-top: 5px;">
						#attributes.start# to #attributes.end#<br/>
						#getFormattedParentList(attributes.catId,allCats)#
					</p>
				</cfif>
			</cfoutput>
			<!---we need a list of all the child categories for the user selected category.--->
			<cfset childCats = getCategoryChildrenList(attributes.catId,allCats)>

			<cfquery datasource="#application.applicationDataSource#" name="getArticles">
				SELECT a.article_id, a.category_id, a.created_date, rev.title, r.first_view_date, r.recent_view_date, r.long_view, r.long_view_date
				FROM tbl_articles a
				INNER JOIN tbl_articles_revisions rev
					ON rev.article_id = a.article_id
					AND rev.revision_id = (SELECT TOP 1 revision_id FROM tbl_articles_revisions WHERE article_id = a.article_id AND use_revision = 1 AND approved = 1 ORDER BY revision_date DESC)
				INNER JOIN tbl_articles_categories c
					ON c.category_id = a.category_id
					AND c.retired = 0 /*we aren't interested in articles in retired categories*/
				LEFT OUTER JOIN tbl_articles_readership r
					ON r.article_id = a.article_id
					AND r.user_id = #attributes.uid#

				WHERE a.retired = 0 /*exclude retired articles*/
				AND a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#childCats#" list="true">)<!---JDBC got SUPER pissy about those comments when they were right beside 'c.retired = 0' and wouldn't bind these parameters.--->
				AND a.created_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#attributes.start#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#dateAdd('d', 1, attributes.end)#"><!---adding one day to attributes.end so content created on that day is included.--->
				/*This cluase looks tricky, but it limits us to articles that the user has the masks to view.*/
				AND NOT EXISTS (
					SELECT am.mask_id
					FROM tbl_articles_masks am
					WHERE am.article_id = a.article_id
					AND am.mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#myMaskList#" list="true">)
				)
			</cfquery>

			<!---using the categories of the articles, let's try to remove all the branches of categories with no articles.--->
			<cfset myCats = "">
			<cfquery dbtype="query" name="usedCats">
				SELECT DISTINCT category_id
				FROM getArticles
				<cfif attributes.read>
					WHERE first_view_date IS NOT NULL
				<cfelse>
					WHERE first_view_date IS NULL
				</cfif>
			</cfquery>


			<cfloop query="usedCats">
				<cfset tempList = getCategoryParentList(category_id, allCats)>

				<cfloop list="#tempList#" index="i">
					<cfif isNumeric(i) AND not listFind(myCats, i)>
						<cfset myCats = listAppend(myCats, i)>
					</cfif>
				</cfloop>
			</cfloop>

			<!---now we can really pare-down the number of categories to go over.--->
			<cfquery dbtype="query" name="allCats">
				SELECT *
				FROM allCats
				<cfif listLen(myCats) gt 0>
					WHERE category_id IN (#myCats#)
				<cfelse>
					WHERE 1 = 0
				</cfif>
			</cfquery>
			<!---end of pruning branches--->

			<cfif getArticles.recordCount eq 0>
				<p>No articles authored during this date range.</p>
			<cfelse>

				<!---find out how many of those articles they have read--->
				<cfset readTotal = getArticles.recordCount><!---total number of articles--->
				<cfset readCnt = 0><!---number of articles that have been read--->
				<cfloop query="getArticles">
					<cfif isDate(first_view_date)>
						<cfset readCnt = readCnt + 1>
					</cfif>
				</cfloop>


				<cfoutput>
					<cfif attributes.header EQ 1>
						<p>
							<span class="tinytext">#readCnt# of #readTotal# articles have been read:  #numberFormat((readCnt/readTotal)*100, 99.9)#% readership.</span>
						</p>
					</cfif>
				</cfoutput>

				<!---now draw the list of (un)read articles--->
				<cfset drawCat(0, childCats)>
			</cfif>

			<!---now close our containing div tag--->
			</div>

			<cfcatch>
				<p class="warning"><cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput></p>
			</cfcatch>
		</cftry>
	<cfelse>
		<p>You must provide a user, date range, and category to use this report.</p>
	</cfif>
</cfif>

<cffunction name="drawCat">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="catList" type="string" default=""><!---the list of categories we actually want to draw.--->

	<cfset var getChildCats = getChildCategoriesByParent(catId, allCats)>
	<cfset var getCatInfo = "">
	<cfset var getCatArticles = "">

	<cfif listFind(catList, catId)>
		<cfquery dbtype="query" name="getCatInfo">
			SELECT category_name
			FROM allCats
			WHERE category_id = #catId#
		</cfquery>
		<ul class="list-group">
		<li class="list-group-item">
			<b><cfoutput>#getCatInfo.category_name#</cfoutput></b>
			<!---now snag the articles for this category.--->
			<cfquery dbtype="query" name="getCatArticles">
				SELECT *
				FROM getArticles
				WHERE category_id = #catId#
				<cfif attributes.read>
					AND first_view_date IS NOT NULL
				<cfelse>
					AND first_view_date IS NULL
				</cfif>
				ORDER BY title
			</cfquery>

			<cfif getCatArticles.recordCount gt 0>
				<ul class="list-group">
				<cfoutput query="getCatArticles">
					<li class="list-group-item">
						<a href="#application.appPath#/documents/article.cfm?articleId=#article_id#">#title#</a>
						<div class="tinytext">
							Created: #dateTimeFormat(created_date, "mmm d, yyyy h:nn aa")#
							<cfif isDate(first_view_date)>
								<br/>
								First Viewed: #dateTimeFormat(first_view_date, "mmm d, yyyy h:nn aa")#<br/>
								Last Viewed: #dateTimeFormat(recent_view_date, "mmm d, yyyy h:nn aa")#<br/>
								Long View: <cfif long_view>
										   		Yes (#dateTimeFormat(long_view_date, "mmm d, yyyy h:nn aa")#)
										   <cfelse>
										   		No
										   </cfif>
							</cfif>
						</div>
					</li>
				</cfoutput>
				</ul>
			</cfif>
	</cfif>

	<cfloop query="getChildCats">
		<cfset drawCat(category_id, catList)>
	</cfloop>

	<cfif listFind(catList, catId)>
		</li>
		</ul>
	</cfif>
</cffunction>