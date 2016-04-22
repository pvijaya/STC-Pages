<cfmodule template="#application.appPath#/header.cfm" title="V3 Importer">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">

<cfsetting requesttimeout="400">
<cfsetting showdebugoutput="false"><!---just to speed things up, really.--->

<cfset v3iub = "iub-internal">
<cfset v3iupui = "iupui-internal">

<!---first we need to import all the v3 users.
<h2>Import V3 Users</h2>
<cfset storeUsers()>
<p>Done.</p>
--->

<!--- 
<h2>Import V3 Filemanager Folders</h2>
<cfquery datasource="#application.applicationDataSource#" name="getV3Folders">
	SELECT 1 as instance_id, folder_id, parent_folder_id, folder_name
	FROM [iub-internal].dbo.filemanager_folders
	UNION
	SELECT 2 as instance_id, folder_id, parent_folder_id, folder_name
	FROM [iupui-internal].dbo.filemanager_folders
</cfquery>

<h3>IUB</h3>
<cfset storeFolders(1,0,0)>
<p>Done.</p>

<h3>IUPUI</h3>
<cfset storeFolders(2,0,0)>
<p>Done.</p>
--->

<!--- 
<h2>Import V3 Filemanager Files</h2>
<cfset storeFiles()>
<p>Done.</p>
--->

<!---
<!---now let's snag all the old V3 categories, this is used over and over as we recurse our way through it.--->
<cfquery datasource="#application.applicationDataSource#" name="getV3Cats">
	SELECT cat_id, cat_name, 1 AS instance_id,
	CASE
		WHEN parent_category IS NULL THEN 0
		WHEN parent_category = cat_id THEN 0
		ELSE parent_category
	END AS parent_category
	FROM [iub-internal].dbo.content_categories
	
	UNION
	
	SELECT
		/*IUPUI badly has a cat_id of 0, which messes things up*/
		CASE
			WHEN cat_id = 0 THEN -1
			ELSE cat_id
		END AS cat_id,
		cat_name, 2 AS instance_id,
		CASE
			WHEN parent_category IS NULL THEN 0
			WHEN parent_category = cat_id THEN 0
			ELSE parent_category
		END AS parent_category
		
	FROM [iupui-internal].dbo.content_categories
</cfquery>

<h2>Import V3 Article Categories</h2>
<h3>IUB</h3>
<cfset storeCats(1,0,2)>
<p>Done.</p>

<h3>IUPUI</h3>
<cfset storeCats(2,0,2)>
<p>Done.</p>


<h2>Import V3 Articles</h2>
<cfset storeArticles()>
<p>Done.</p>
--->

<!---
<h2>Import V3 Handbook Categories</h2>
<!---fetch all handbook categories, I may need to rejigger it to include sorting orders.--->
<cfquery datasource="#application.applicationDataSource#" name="getV3Cats">
	SELECT 1 AS instance_id, cat_id, cat_name, cat_priority, 
		CASE
			WHEN parent_category IS NULL THEN 0
			ELSE parent_category
		END AS parent_category
	FROM [iub-internal].dbo.handbook_categories
	
	UNION
	
	SELECT 2 AS instance_id, cat_id, cat_name, cat_priority, 
		CASE
			WHEN parent_category IS NULL THEN 0
			ELSE parent_category
		END AS parent_category
	FROM [iupui-internal].dbo.handbook_categories
</cfquery>

<h3>IUB</h3>
<cfset storeHandbookCats(1,0,4)>
<p>Done.</p>

<h3>IUPUI</h3>
<cfset storeHandbookCats(2,0,5)>
<p>Done.</p>
 
<h2>Import V3 Handbook Articles</h2>
<cfset storeHandbookArticles()>
<p>Done.</p>
 --->

<!--- 
<h2>Import V3 Newsletter Categories</h2>
<cfset storeNewsletterCats()>
<p>Done.</p>

<h2>Import V3 Newsletter Articles</h2>
<cfset storeNewsletterArticles()>
<p>Done.</p>
--->

<!--- 
<h2>Import V3 Announcement Articles</h2>
<cfset storeAnnouncementArticles()>
<p>Done.</p>

<!---the next few queries are needed for converting links in articles articles from V3 to V4--->
<!---both storeRevisions() and cleanArticle() use the following query.--->
<cfquery datasource="#application.applicationDataSource#" name="getArticleConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_articles
</cfquery>

<!---and the same for handbook articles.--->
<cfquery datasource="#application.applicationDataSource#" name="getHandbookConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_handbook_articles
</cfquery>

<!--- and handbook categories--->
<cfquery datasource="#application.applicationDataSource#" name="getHandbookCatConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_handbook_categories
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getFileConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_filemanager_files
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getAnnouncementConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_announcements
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getNewsletterConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_newsletter_articles
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getNewsletterCatConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_newsletter_categories
</cfquery>

<h2>Import V3 Article Versions</h2>
<cfset storeRevisions()>
<p>Done.</p>
--->
<h2>Import Chat Logs</h2>
<cfset storeChats()>
<p>Done.</p>

<cfabort>

<h2>Import Announcement Content</h2>
<cfset storeAnnouncemntContent()>
<p>Done.</p>

<h2>Import Handbook Content</h2>
<cfset storeHandbookContent()>
<p>Done.</p>

<h2>Import Newsletter Content</h2>
<cfset storeNewsletterContent()>

<cfmodule template="#application.appPath#/footer.cfm">

<cffunction name="storeUsers" output="false">
	<cfset var getusers = "">
	<cfset var getAllMasks = "">
	<cfset var getDupes = "">
	<cfset var addUser = "">
	<cfset var addMatch = "">
	<cfset var getMasks = "">
	<cfset var addMasks = "">
	<cfset var maskList = "">
	<cfset var maskIdList = "">
	<cfset var hasMasks = "">
	<cfset var newId = 0>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name
		FROM tbl_user_masks
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT 1 AS instance_id, u.uid, LOWER(u.username) AS username, u.Access_Level, u.ignore_pie_level, LOWER(u.Username) + '@indiana.edu' AS email, u.Picture_URL AS picture_source,
			CASE
				WHEN c.first_name IS NULL THEN u.username
				ELSE c.first_name
			END AS first_name,
			CASE
				WHEN c.last_name IS NULL THEN u.username
				ELSE c.last_name
			END AS last_name,
			CASE
				WHEN u.Display_Name IS NULL OR u.display_name = '' THEN u.username
				ELSE u.display_name
			END AS preferred_name,
			CASE
				WHEN u.added IS NULL THEN '1999-01-01'
				ELSE u.added
			END AS date_added
		FROM [iub-internal].dbo.users u
		LEFT OUTER JOIN [iu-tcc-dev].dbo.tbl_consultants c ON LOWER(c.username) = LOWER(u.Username)
		
		UNION
		
		SELECT 2 AS instance_id, u.uid, LOWER(u.username) AS username, u.Access_Level, u.ignore_pie_level, LOWER(u.Username) + '@iupui.edu' AS email, u.Picture_URL AS picture_source,
			CASE
				WHEN c.first_name IS NULL THEN u.username
				ELSE c.first_name
			END AS first_name,
			CASE
				WHEN c.last_name IS NULL THEN u.username
				ELSE c.last_name
			END AS last_name,
			CASE
				WHEN u.Display_Name IS NULL OR u.display_name = '' THEN u.username
				ELSE u.display_name
			END AS preferred_name,
			CASE
				WHEN u.added IS NULL THEN '1999-01-01'
				ELSE u.added
			END AS date_added
		FROM [iupui-internal].dbo.users u
		LEFT OUTER JOIN [iupui-stc-dev].dbo.tbl_consultants c ON LOWER(c.username) = LOWER(u.Username)
	</cfquery>
	
	<!---loop over all the users, check if the already exist in v4, if they don't - add them.  In both cases add the match for the old instance and uid to the match table.--->
	<cfloop query="getUsers">
		<!---check if they already exist--->
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT TOP 1 user_id
			FROM tbl_users
			WHERE LOWER(username) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">)
		</cfquery>
		<cfif getDupes.recordCount gt 0>
			<cfset newId = getDupes.user_id>
		<cfelse>
			<!---we didn't find a match, so add the user to tbl_users--->
			<cfquery datasource="#application.applicationDataSource#" name="addUser">
				INSERT INTO tbl_users (username, first_name, last_name, preferred_name, email, picture_source, ignore_pie_level, date_added)
				OUTPUT inserted.user_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#first_name#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#last_name#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#preferred_name#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#email#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#picture_source#">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="#ignore_pie_level#">,
					<cfqueryparam cfsqltype="cf_sql_timestamp" value="#date_added#">
				)
			</cfquery>
			
			<cfset newId = addUser.user_id>
		</cfif>
		
		<!---either way we have our newId, now, so add the match to tbl_conversion_users--->
		<cftry><!---just wrapping this in a try tag for events where we violate the unique key--->
			<cfquery datasource="#application.applicationDataSource#" name="addMatch">
				INSERT INTO tbl_conversion_users (instance_id, old_id, new_id)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#uid#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
				)
			</cfquery>
		<cfcatch></cfcatch>
		</cftry>
		
		
		<!---We also need to add the correct masks for the user--->
		<cfquery datasource="#application.applicationDataSource#" name="getMasks">
			SELECT m.mask_id, m.mask_name
			FROM vi_all_masks_users mu
			INNER JOIN tbl_user_masks m ON m.mask_id = mu.mask_id
			WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
		</cfquery>
		
		<!---build-up a mask list based on this user's current V3 record, then use that list to see if anything needes added.--->
		<cfset maskList = "">
		<cfif access_level gt 0>
			<cfswitch expression="#instance_id#">
				<cfcase value="2">
					<cfset maskList = listAppend(maskList, "IUPUI")>
				</cfcase>
				<cfdefaultcase>
					<cfset maskList = listAppend(maskList, "IUB")>
				</cfdefaultcase>
			</cfswitch>
		</cfif>
		
		<cfif access_level gt 30>
			<cfset maskList = listAppend(maskList, "Admin")>
		<cfelseif access_level gt 20>
			<cfset maskList = listAppend(maskList, "CS")>
		<cfelseif access_level gt 14>
			<cfset maskList = listAppend(maskList, "Logistics")>
		<cfelseif access_level gt 0>
			<cfset maskList = listAppend(maskList, "Consultant")>
		</cfif>
		
		<!---ok, we've got a list of masks for the user, trim out the ones they already have and convert them to their numeric value, too.--->
		<cfloop list="#maskList#" index="mask">
			<cfquery dbtype="query" name="hasMask">
				SELECT *
				FROM getMasks
				WHERE mask_name = '#mask#'
			</cfquery>
			
			<cfif hasMask.recordCount eq 0>
				<!---find the numeric ID for the mask, and insert it.--->
				<cfquery dbtype="query" name="hasMask">
					SELECT mask_id
					FROM getAllMasks
					WHERE mask_name = '#mask#'
				</cfquery>
				
				<!---if we got a match, insert it.--->
				<cfloop query="hasMask">
					<cfquery datasource="#application.applicationDataSource#" name="addMasks">
						INSERT INTO tbl_users_masks_match (mask_id, user_id, value)
						VALUES (#mask_id#, <cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">, 1)
					</cfquery>
				</cfloop>
			</cfif>
		</cfloop>
		
	</cfloop>
</cffunction>

<!---this still leaves a few orphans, but they weren't reachable in V3, either.--->
<cffunction name="storeCats">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="newParent" type="numeric" required="true">
	
	<cfset var getDetails = "">
	<cfset var getDupes = "">
	<cfset var newId = 0>
	<cfset var addFolder = "">
	<cfset var getChildren = "">
	
	<cfquery dbtype="query" name="getDetails">
		SELECT *
		FROM getV3Cats
		WHERE instance_id = #instanceId#
		AND cat_id = #catId#
	</cfquery>
	
	<cfloop query="getDetails">
		<!---is there already a folder in this level with the same name?--->
		<cfset newId = 0>
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT category_id
			FROM tbl_articles_categories
			WHERE parent_cat_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newParent#">
			AND LOWER(category_name) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#cat_name#">)
		</cfquery>
		
		<cfif getDupes.recordCount gt 0>
			<cfset newId = getDupes.category_id>
		<cfelse>
			<!---there isn't a dupe, add that sumbitch.--->
			<cfquery datasource="#application.applicationDataSource#" name="addFolder">
				INSERT INTO tbl_articles_categories (parent_cat_id, category_name)
				OUTPUT inserted.category_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newParent#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#cat_name#">
				)
			</cfquery>
			
			<cfset newId = #addFolder.category_id#>
			
		</cfif>
		
		<!---add the match to the conversion table, wrap it in a try in case we create any duplicates.--->
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="addMatch">
				INSERT INTO tbl_conversion_articles_categories (instance_id, old_id, new_id)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#cat_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
				)
			</cfquery>
		<cfcatch></cfcatch>
		</cftry>
	</cfloop>
	
	<cfquery dbtype="query" name="getChildren">
		SELECT *
		FROM getV3cats
		WHERE instance_id = #instanceId#
		AND parent_category = #catId#
		ORDER BY cat_name
	</cfquery>
	
	<!---if we're at the top level newId shouldn't be 0, it should be '2' to constrain itself to the documents folder in v4--->
	<cfif newId eq 0>
		<cfset newId = 2>
	</cfif>
	
	<cfloop query="getChildren">
		<cfset storeCats(instanceId, cat_id, newId)>
	</cfloop>
</cffunction>

<!---because we have to store our matches somewhere else we can't just reuse storeCats()--->
<cffunction name="storeHandbookCats">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="catId" type="numeric" required="true">
	<cfargument name="newParent" type="numeric" required="true">
	
	<cfset var getDetails = "">
	<cfset var getDupes = "">
	<cfset var newId = 0>
	<cfset var addFolder = "">
	<cfset var getChildren = "">
	
	<cfquery dbtype="query" name="getDetails">
		SELECT *
		FROM getV3Cats
		WHERE instance_id = #instanceId#
		AND cat_id = #catId#
	</cfquery>
	
	<cfloop query="getDetails">
		<!---is there already a folder in this level with the same name?--->
		<cfset newId = 0>
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT category_id
			FROM tbl_articles_categories
			WHERE parent_cat_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newParent#">
			AND LOWER(category_name) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#cat_name#">)
		</cfquery>
		
		<cfif getDupes.recordCount gt 0>
			<cfset newId = getDupes.category_id>
		<cfelse>
			<!---there isn't a dupe, add that sumbitch.--->
			<cfquery datasource="#application.applicationDataSource#" name="addFolder">
				INSERT INTO tbl_articles_categories (parent_cat_id, category_name, sort_order)
				OUTPUT inserted.category_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newParent#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#cat_name#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#cat_priority#">
				)
			</cfquery>
			
			<cfset newId = #addFolder.category_id#>
			
		</cfif>
		
		<!---add the match to the conversion table, wrap it in a try in case we create any duplicates.--->
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="addMatch">
				INSERT INTO tbl_conversion_handbook_categories (instance_id, old_id, new_id)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#cat_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
				)
			</cfquery>
		<cfcatch></cfcatch>
		</cftry>
	</cfloop>
	
	<cfquery dbtype="query" name="getChildren">
		SELECT *
		FROM getV3cats
		WHERE instance_id = #instanceId#
		AND parent_category = #catId#
		ORDER BY cat_name
	</cfquery>
	
	<!---if we're at the top level newId shouldn't be 0, it should be '2' to constrain itself to the documents folder in v4--->
	<cfif newId eq 0>
		<cfset newId = newParent>
	</cfif>
	
	<cfloop query="getChildren">
		<cfset storeHandbookCats(instanceId, cat_id, newId)>
	</cfloop>
</cffunction>


<!---because we have to store our matches somewhere else we can't just reuse storeCats()--->
<cffunction name="storeNewsletterCats">
	<cfset var getCats = "">
	<cfset var getDupes = "">
	<cfset var newId = "">
	<cfset var addCat = "">
	<cfset var addMatch = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getCats">
		SELECT 1 AS instance_id, newsletter_id, issue, published
		FROM [iub-internal].dbo.newsletter_issues
		
		UNION
		
		SELECT 2 AS instance_id, newsletter_id, issue, published
		FROM [iupui-internal].dbo.newsletter_issues
	</cfquery>
	
	<cfloop query="getCats">
		<!---check for duplicates--->
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT nc.new_id
			FROM tbl_conversion_newsletter_categories nc
			INNER JOIN tbl_articles_categories c ON c.category_id = nc.new_id
			WHERE nc.old_id = #newsletter_id#
		</cfquery>
		
		<cfset newId = 0>
		<!---if we didn't find a match add the category--->
		<cfif getDupes.recordCount gt 0>
			<cfset newId = getDupes.new_id>
		<cfelse>
			<!---Add it--->
			<cfquery datasource="#application.applicationDataSource#" name="addCat">
				INSERT INTO tbl_articles_categories (parent_cat_id, category_name, retired)
				OUTPUT inserted.category_id
				VALUES (
					7,/*the newsletter category*/
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#issue#">,
					#iif(published, 0, 1)#
				)
			</cfquery>
			
			<cfset newId = addCat.category_id>
		</cfif>
		
		<!---record the match for future conversions--->
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="addMatch">
				INSERT INTO tbl_conversion_newsletter_categories (instance_id, old_id, new_id)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newsletter_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
				)
			</cfquery>
		<cfcatch></cfcatch>
		</cftry>
		
	</cfloop>
	
</cffunction>

<cffunction name="storeNewsletterArticles">
	<cfset var getUsers = ""><!---used to convert between v3 and v4 users--->
	<cfset var getAllMasks = "">
	<cfset var getArticles = "">
	<cfset var getDupes = "">
	<cfset var newId = "">
	<cfset var getV4Cat = "">
	<cfset var catId = "">
	<cfset var addArticle = "">
	<cfset var getMaskId = "">
	<cfset var addMask = "">
	<cfset var addMatch = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name
		FROM tbl_user_masks
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getArticles">
		SELECT 1 AS instance_id, a.article_id, a.newsletter_id, a.article_order, a.article_title,
			CASE
				WHEN a.access_level > 30 THEN 'IUB,Admin'
				WHEN a.access_level > 20 THEN 'IUB,CS'
				ELSE 'IUB,Consultant'
			END AS mask,
			CASE
				WHEN u.Uid IS NULL THEN 0
				ELSE u.uid
			END AS uid,
			CASE
				WHEN ni.date_created IS NULL THEN ni.issue + '-1'
				ELSE ni.date_created
			END AS the_date
		FROM [iub-internal].dbo.newsletter_articles a
		INNER JOIN [iub-internal].dbo.newsletter_issues ni ON ni.newsletter_id = a.newsletter_id
		LEFT OUTER JOIN [iub-internal].dbo.users u ON u.username = a.author
		
		UNION
		
		SELECT 2 AS instance_id, a.article_id, a.newsletter_id, a.article_order, a.article_title,
			CASE
				WHEN a.access_level > 30 THEN 'IUPUI,Admin'
				WHEN a.access_level > 20 THEN 'IUPUI,CS'
				ELSE 'IUPUI,Consultant'
			END AS mask,
			CASE
				WHEN u.Uid IS NULL THEN 0
				ELSE u.uid
			END AS uid,
			CASE
				WHEN ni.date_created IS NULL THEN ni.issue + '-1'
				ELSE ni.date_created
			END AS the_date
		FROM [iupui-internal].dbo.newsletter_articles a
		INNER JOIN [iupui-internal].dbo.newsletter_issues ni ON ni.newsletter_id = a.newsletter_id
		LEFT OUTER JOIN [iupui-internal].dbo.users u ON u.username = a.author
	</cfquery>
	
	<cfloop query="getArticles">
		<cfset articleDate = replace(the_date, "(", "", "all")>
		<cfset articleDate = replace(articleDate, ")", "", "all")>
		<cfset articleDate = parseDateTime(articleDate)>
		
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT n.new_id
			FROM tbl_conversion_newsletter_articles n
			INNER JOIN tbl_articles a ON a.article_id = n.new_id
			WHERE n.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">
			AND n.old_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">
		</cfquery>
		
		<cfset newId = 0>
		<cfif getDupes.recordCount gt 0>
			<cfset newId = getDupes.new_id>
		<cfelse>
			<!---we didn't find a match, insert our article, start by finding the correct V4 category_id--->
			<cfset catId = 0>
			<cfquery datasource="#application.applicationDataSource#" name="getV4Cat">
				SELECT nc.new_id
				FROM tbl_conversion_newsletter_categories nc
				INNER JOIN tbl_articles_categories c ON c.category_id = nc.new_id
				WHERE nc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">
				AND nc.old_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newsletter_id#">
			</cfquery>
			
			<cfloop query="getV4Cat">
				<cfset catId = new_id>
			</cfloop>
			
			<cfif catId neq 0>
				<!---we found a category_id, add the article--->
				<cfquery datasource="#application.applicationDataSource#" name="addArticle">
					INSERT INTO tbl_articles (category_id, creator_id, sort_order, created_date)
					OUTPUT inserted.article_id
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#catId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, uid, getUsers)#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#article_order#">,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#articleDate#">
					)
				</cfquery>
				
				<cfset newId = addArticle.article_id>
			</cfif>
		</cfif>
		
		<!---at this point we should have a new article_id, record its match--->
		<cfif newId neq 0>
			<cftry>
				<cfquery datasource="#application.applicationDataSource#" name="addMatch">
					INSERT INTO tbl_conversion_newsletter_articles (instance_id, old_id, new_id)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
					)
				</cfquery>
			<cfcatch></cfcatch>
			</cftry>
			
			<!---now record the masks--->
			
			<cfquery dbtype="query" name="getMaskId">
				SELECT mask_id
				FROM getAllMasks
				WHERE mask_name IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#mask#" list="true">)
			</cfquery>
			
			<cftry>
				<cfloop query="getMaskId">
					<cfquery datasource="#application.applicationDataSource#" name="addMask">
						INSERT INTO tbl_articles_masks (article_id, mask_id)
						VALUES(
							<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">,
							<cfqueryparam cfsqltype="cf_sql_integer" value="#mask_id#">
						)
					</cfquery>
				</cfloop>
				<cfcatch></cfcatch>
			</cftry>
		</cfif>
	</cfloop>
</cffunction>

<cffunction name="storeNewsletterContent">
	<cfset var instanceId = "">
	<cfset var myDsn = "">
	<cfset var getArticles = "">
	<cfset var getUsers = ""><!---a query to match v3 users to v4 users.--->
	<cfset var addArticle = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<!---we cant UNION the body of the articles, so we have to loop through the instances--->
	<cfloop from="1" to="2" index="instanceId">
		<cfif instanceId eq 1>
			<cfset myDsn = "iub-internal">
		<cfelse>
			<cfset myDsn = "iupui-internal">
		</cfif>
		
		<cfquery datasource="#application.applicationDataSource#" name="getArticles">
			SELECT ca.instance_id, ca.new_id, na.article_title, na.article_text, 
				CASE
					WHEN u.uid IS NULL THEN 0
					ELSE u.uid
				END AS uid
			FROM [#myDsn#].dbo.newsletter_articles na
			INNER JOIN [iu-v4].dbo.tbl_conversion_newsletter_articles ca 
				ON ca.instance_id = #instanceId#
				AND ca.old_id = na.article_id
			INNER JOIN [iu-v4].dbo.tbl_articles a ON a.article_id = ca.new_id
			LEFT OUTER JOIN [#myDsn#].dbo.users u ON u.username = na.author
			LEFT OUTER JOIN [iu-v4].dbo.tbl_articles_revisions ar ON ar.article_id = a.article_id
			WHERE ar.revision_id IS NULL
		</cfquery>
		
		<cfoutput><p>#myDsn# - #getArticles.recordCount#</p></cfoutput>
		
		<cfloop query="getArticles">
			<cfquery datasource="#application.applicationDataSource#" name="addArticle">
				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, use_revision)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#new_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#article_title#">,
					<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#article_text#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, uid, getUsers)#">,
					1
				)
			</cfquery>
		</cfloop>
		
	</cfloop>
	
</cffunction>


<cffunction name="storeFolders">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="folderId" type="numeric" required="true">
	<cfargument name="newParent" type="numeric" required="true">
	
	<cfset var getDetails = "">
	<cfset var getDupes = "">
	<cfset var newId = 0>
	<cfset var addFolder = "">
	<cfset var getChildren = "">
	
	<cfquery dbtype="query" name="getDetails">
		SELECT *
		FROM getV3Folders
		WHERE instance_id = #instanceId#
		AND folder_id = #folderId#
	</cfquery>
	
	<cfloop query="getDetails">
		<!---is there already a folder in this level with the same name?--->
		<cfset newId = 0>
		<cfquery datasource="#application.applicationDataSource#" name="getDupes">
			SELECT folder_id
			FROM tbl_filemanager_folders
			WHERE parent_folder_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newParent#">
			AND LOWER(folder_name) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#folder_name#">)
		</cfquery>
		
		<cfif getDupes.recordCount gt 0>
			<cfset newId = getDupes.folder_id>
		<cfelse>
			<!---there isn't a dupe, add that sumbitch.--->
			<cfquery datasource="#application.applicationDataSource#" name="addFolder">
				INSERT INTO tbl_filemanager_folders (parent_folder_id, folder_name)
				OUTPUT inserted.folder_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newParent#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#folder_name#">
				)
			</cfquery>
			
			<cfset newId = #addFolder.folder_id#>
		</cfif>
		
		<!---add the match to the conversion table, wrap it in a try in case we create any duplicates.--->
		<cftry>
			<cfquery datasource="#application.applicationDataSource#" name="addMatch">
				INSERT INTO tbl_conversion_filemanager_folders (instance_id, old_id, new_id)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#folder_id#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">
				)
			</cfquery>
		<cfcatch></cfcatch>
		</cftry>
	</cfloop>
	
	<cfquery dbtype="query" name="getChildren">
		SELECT *
		FROM getV3Folders
		WHERE instance_id = #instanceId#
		AND parent_folder_id = #folderId#
		ORDER BY folder_name
	</cfquery>
	
	<cfloop query="getChildren">
		<cfset storeFolders(instanceId, folder_id, newId)>
	</cfloop>
</cffunction>

<cffunction name="storeFiles">
	<cfset var getAllMasks = ""><!---a query of all the masks, so we can match mask names to their mask_id--->
	<cfset var instanceId = "">
	<cfset var getFiles = "">
	<cfset var newFileId = "">
	<cfset var checkDupes = "">
	<cfset var addFile = "">
	<cfset var addMatch = "">
	<cfset var getMaskId = "">
	<cfset var addMasks = "">
	<cfset var getVersions = "">
	<cfset var addVersion = "">
	<cfset var getAudits = "">
	<cfset var addAudit = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name
		FROM tbl_user_masks
	</cfquery>
	
	
	<!---because the description is a text field we need to do IUB and IUPUI seperately.--->
	<cfloop from="1" to="2" index="instanceId">
		<!---fetch the files, and where they should be going for this instnace--->
		<cfquery datasource="#application.applicationDataSource#" name="getFiles">
			SELECT f.file_id, f.file_name, f.file_access_level, f.file_description, 
				CASE
					WHEN ff.new_id IS NULL THEN 0
					ELSE ff.new_id
				END AS new_folder_id,
				CASE
					WHEN f.file_access_level > 30 THEN 'Admin'
					WHEN f.file_access_level > 20 THEN 'CS'
					WHEN f.file_access_level > 0 THEN 'Consultant'
					ELSE ''
				END AS mask
			FROM [#iif(instanceId eq 1, de('IUB'), de('IUPUI'))#-internal].dbo.filemanager_files f
			LEFT OUTER JOIN [iu-v4].dbo.tbl_conversion_filemanager_folders ff 
				ON ff.old_id = f.folder_id
				AND ff.instance_id = #instanceId#
		</cfquery>
		
		<cfloop query="getFiles">
			<!---check if the file exists, if it doesn't add add it.--->
			<cfset newFileId = 0>
			<cfquery datasource="#application.applicationDataSource#" name="checkDupes">
				SELECT file_id
				FROM tbl_filemanager_files
				WHERE folder_id = #new_folder_id#
				AND file_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#file_name#">
			</cfquery>
			
			<cfif checkDupes.recordCount gt 0>
				<cfset newFileId = checkDupes.file_id>
			<cfelse>
				<cfquery datasource="#application.applicationDataSource#" name="addFile">
					INSERT INTO tbl_filemanager_files (folder_id, file_name, file_description)
					OUTPUT inserted.file_id
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#new_folder_id#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#file_name#">,
						<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#file_description#">
					)
				</cfquery>
				
				<cfset newFileId = addFile.file_id>
			</cfif>
			
			<!---now we know the correct file ID, we can bring in the masks, revisions, and add the match to the database.--->
			<cftry>
				<!---record the match--->
				<cfquery datasource="#application.applicationDataSource#" name="addMatch">
					INSERT INTO tbl_conversion_filemanager_files (instance_id, old_id, new_id)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#file_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#newFileId#">
					)
				</cfquery>
			<cfcatch type="any">
				<!---
				<p>Error adding match.</p>
				<p><cfoutput>#cfcatch.message# - #cfcatch.detail#</cfoutput></p>
				--->
			</cfcatch>
			</cftry>
			
			<!---set the masks--->
			<cftry>
				<cfquery dbtype="query" name="getMaskId">
					SELECT mask_id
					FROM getAllMasks
					WHERE mask_name IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#mask#" list="true">)
				</cfquery>
				
				<cfloop query="getMaskId">
					<cfquery datasource="#application.applicationDataSource#" name="addMasks">
						INSERT INTO tbl_filemanager_files_masks (file_id, mask_id)
						VALUES (
							#newFileId#,
							#mask_id#
						)
					</cfquery>
				</cfloop>
			<cfcatch type="any">
				<!---
				<p>Error adding mask.</p>
				<p><cfoutput>#cfcatch.message# - #cfcatch.detail#</cfoutput></p>
				--->
			</cfcatch>
			</cftry>
			
			<!---now fetch the versions for each file and set them up.--->
			<cftry>
				<cfquery datasource="#application.applicationDataSource#" name="getVersions">
					SELECT version_date, use_version, version_file_name
					FROM [#iif(instanceId eq 1, de('IUB'), de('IUPUI'))#-internal].dbo.filemanager_files_versions
					WHERE file_id = #file_id#
					ORDER BY version_date ASC 
				</cfquery>
				
				<cfloop query="getVersions">
					<cfquery datasource="#application.applicationDataSource#" name="addVersion">
						INSERT INTO tbl_filemanager_files_versions (file_id, version_date, use_version, version_file_name)
						VALUES (
							<cfqueryparam cfsqltype="cf_sql_integer" value="#newFileId#">,
							<cfqueryparam cfsqltype="cf_sql_timestamp" value="#version_date#">,
							<cfqueryparam cfsqltype="cf_sql_bit" value="#use_version#">,
							<cfqueryparam cfsqltype="cf_sql_varchar" value="#version_file_name#">
						)
					</cfquery>
				</cfloop>
			<cfcatch type="any">
				<!---
				<p>Error adding versions.</p>
				<p><cfoutput>#cfcatch.message# - #cfcatch.detail#</cfoutput></p>
				--->
			</cfcatch>
			</cftry>
			
			<!---now add the audit trail for a file--->
			<cftry>
				<cfquery datasource="#application.applicationDataSource#" name="getAudits">
					SELECT file_id, change_by, change_time, audit_text
					FROM [#iif(instanceId eq 1, de('IUB'), de('IUPUI'))#-internal].dbo.filemanager_files_audit
					WHERE file_id = #file_id#
				</cfquery>
				
				<cfloop query="getAudits">
					<cfquery datasource="#application.applicationDataSource#" name="addAudit">
						INSERT INTO tbl_filemanager_files_audit (file_id, change_by, change_time, audit_text)
						VALUES (
							<cfqueryparam cfsqltype="cf_sql_integer" value="#newFileId#">,
							<cfqueryparam cfsqltype="cf_sql_varchar" value="#change_by#">,
							<cfqueryparam cfsqltype="cf_sql_timestamp" value="#change_time#">,
							<cfqueryparam cfsqltype="cf_sql_varchar" value="#audit_text#">
						)
					</cfquery>
				</cfloop>
			<cfcatch type="any">
				<!---
				<p>Error adding audits.</p>
				<p><cfoutput>#cfcatch.message# - #cfcatch.detail#</cfoutput></p>
				--->
			</cfcatch>
			</cftry>
		</cfloop>
	</cfloop>
</cffunction>

<cffunction name="storeArticles">
	<cfset var getV3docs = ""><!---snag all the docs.--->
	<cfset var getCats = ""><!---a query to find all our categories and how to convert between v3 categories--->
	<cfset var getUsers = ""><!---a query to convert v3 user ID's to v4 user ID's--->
	<cfset var getAllMasks = ""><!---a query of all the masks, so we can match mask names to their mask_id--->
	<cfset var getExistingMatches = ""><!---a query of existing v3 to v4 matches so we don't create duplicates.--->
	
	<cfset var getCatArticles = ""><!---a query to fetch the articles of a v3 category from getV3docs--->
	<cfset var instanceId = "">
	<cfset var oldCat = "">
	<cfset var newCat = "">
	
	<cfset var getArticleMatch = ""><!---a query to find if an article already has a V4 version.--->
	<cfset var addArticle = "">
	<cfset var newArticleId = "">
	<cfset var addMatch = "">
	<cfset var addAudit = "">
	<cfset var addMasks = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getCats">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_articles_categories
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getV3docs">
		SELECT 1 AS instance_id, article_id, ca.article_cat,
			CASE
				WHEN ca.article_level > 30 THEN 'IUB,Admin'
				WHEN ca.article_level > 20 THEN 'IUB,CS'
				ELSE 'IUB,Consultant'
			END AS mask,
			CASE
				WHEN cc.uid IS NULL THEN 3
				ELSE cc.uid
			END AS creator_id,
			CASE
				WHEN ch.article_last_modified IS NULL THEN ca.article_last_modified
				ELSE ch.article_last_modified
			END AS date_created
		FROM [iub-internal].dbo.content_articles ca
		LEFT OUTER JOIN [iub-internal].dbo.content_changelog cc 
			ON cc.article_edited = ca.article_id
			AND cc.log_id = (SELECT TOP 1 log_id FROM [iub-internal].dbo.content_changelog WHERE article_edited = ca.article_id ORDER BY timestamp DESC)
		LEFT OUTER JOIN [iub-internal].dbo.content_articles_history ch 
			ON ch.rev_id = (SELECT TOP 1 rev_id FROM [iub-internal].dbo.content_articles_history WHERE orig_id = ca.article_id ORDER BY article_last_modified ASC)
		WHERE (ca.article_url = '' OR ca.article_url IS NULL)
		
		UNION
		
		SELECT 2 AS instance_id, article_id, 
			/*IUPUI has some funky categories, and we need to account for that.*/
			CASE
				WHEN ca.article_cat = 0 THEN -1
				ELSE ca.article_cat
			END AS article_cat,
			CASE
				WHEN ca.article_level > 30 THEN 'IUPUI,Admin'
				WHEN ca.article_level > 20 THEN 'IUPUI,CS'
				ELSE 'IUPUI,Consultant'
			END AS mask,
			CASE
				WHEN cc.uid IS NULL THEN 3
				ELSE cc.uid
			END AS creator_id,
			CASE
				WHEN ch.article_last_modified IS NULL THEN ca.article_last_modified
				ELSE ch.article_last_modified
			END AS date_created
		FROM [iupui-internal].dbo.content_articles ca
		LEFT OUTER JOIN [iupui-internal].dbo.content_changelog cc 
			ON cc.article_edited = ca.article_id
			AND cc.log_id = (SELECT TOP 1 log_id FROM [iupui-internal].dbo.content_changelog WHERE article_edited = ca.article_id ORDER BY timestamp DESC)
		LEFT OUTER JOIN [iupui-internal].dbo.content_articles_history ch 
			ON ch.rev_id = (SELECT TOP 1 rev_id FROM [iupui-internal].dbo.content_articles_history WHERE orig_id = ca.article_id ORDER BY article_last_modified ASC)
		WHERE (ca.article_url = '' OR ca.article_url IS NULL)
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getExistingMatches">
		SELECT ca.instance_id, ca.old_id, ca.new_id
		FROM tbl_conversion_articles ca
		INNER JOIN tbl_articles a ON ca.new_id = a.article_id
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name
		FROM tbl_user_masks
	</cfquery>
	
	<cfloop query="getCats">
		<cfset instanceId = instance_id>
		<cfset oldCat = old_id>
		<cfset newCat = new_id>
		
		<cfquery dbtype="query" name="getCatArticles">
			SELECT instance_id, article_id, mask, creator_id, date_created
			FROM getV3Docs
			WHERE instance_id = #instanceId#
			AND article_cat = #oldCat#
		</cfquery>
		
		<!---loop over our articles.  Add the article, add its masks, and audit that it has been imported--->
		<cfloop query="getCatArticles">
			<!---does the article already exist on V4?--->
			<cfquery dbtype="query" name="getArticleMatch">
				SELECT instance_id, old_id, new_id
				FROM  getExistingMatches
				WHERE instance_id = #instance_id#
				AND old_id = #article_id#
			</cfquery>
			
			<cfif getArticleMatch.recordCount eq 0>
				<!---add the article to V4's database--->
				<cfquery datasource="#application.applicationDataSource#" name="addArticle">
					INSERT INTO tbl_articles (category_id, creator_id, created_date)
					OUTPUT inserted.article_id
					VALUES(
						<cfqueryparam cfsqltype="cf_sql_integer" value="#newCat#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, creator_id, getUsers)#">,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#date_created#">
					)
				</cfquery>
				
				<cfset newArticleId = addArticle.article_id>
				
				<!---add the match to the databse--->
				<cfquery datasource="#application.applicationDataSource#" name="addMatch">
					INSERT INTO tbl_conversion_articles (instance_id, old_id, new_id)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#addArticle.article_id#">
					)
				</cfquery>
				
				<!---add the audit of this article's import.--->
				<cfquery datasource="#application.applicationDataSource#" name="addAudit">
					INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#addArticle.article_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
						'<ul><li>Article imported from V3</li></ul>'
					)
				</cfquery>
			<cfelse>
				<cfset newArticleId = getArticleMatch.new_id>
			</cfif>
			
			<!---now add the masks for this article--->
			<cfloop list="#mask#" index="n">
				<cfloop query="getAllMasks">
					<cfif mask_name eq trim(n)>
						<!---we found our mask, try to add it to the v4db.--->
						<cftry><!---wrap this in a try in case we end-up violating the unique key.--->
							<cfquery datasource="#application.applicationDataSource#" name="addMasks">
								INSERT INTO tbl_articles_masks (article_id, mask_id)
								VALUES (
									<cfqueryparam cfsqltype="cf_sql_integer" value="#newArticleId#">,
									<cfqueryparam cfsqltype="cf_sql_integer" value="#mask_id#">
								)
							</cfquery>
						<cfcatch></cfcatch>
						</cftry>
					</cfif>
				</cfloop>
			</cfloop>
		</cfloop>
	</cfloop>
</cffunction>

<!---This looks like a carbon copy of storeArticles(), because it is, but it's been tweaked to bring in handbook articles.--->
<cffunction name="storeHandbookArticles">
	<cfset var getV3docs = ""><!---snag all the docs.--->
	<cfset var getCats = ""><!---a query to find all our categories and how to convert between v3 categories--->
	<cfset var getUsers = ""><!---a query to convert v3 user ID's to v4 user ID's--->
	<cfset var getAllMasks = ""><!---a query of all the masks, so we can match mask names to their mask_id--->
	<cfset var getExistingMatches = ""><!---a query of existing v3 to v4 matches so we don't create duplicates.--->
	
	<cfset var getCatArticles = ""><!---a query to fetch the articles of a v3 category from getV3docs--->
	<cfset var instanceId = "">
	<cfset var oldCat = "">
	<cfset var newCat = "">
	
	<cfset var getArticleMatch = ""><!---a query to find if an article already has a V4 version.--->
	<cfset var addArticle = "">
	<cfset var newArticleId = "">
	<cfset var addMatch = "">
	<cfset var addAudit = "">
	<cfset var addMasks = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getCats">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_handbook_categories
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getV3docs">
		SELECT 1 AS instance_id, ca.article_id, ca.article_cat, ca.article_priority,
			CASE
				WHEN ca.article_level > 30 THEN 'IUB,Admin'
				WHEN ca.article_level > 20 THEN 'IUB,CS'
				ELSE 'IUB,Consultant'
			END AS mask,
			CASE
				WHEN cc.uid IS NULL THEN 3
				ELSE cc.uid
			END AS creator_id,
			CASE
				WHEN ch.article_last_modified IS NULL THEN ca.article_last_modified
				ELSE ch.article_last_modified
			END AS date_created
		FROM [iub-internal].dbo.handbook_articles ca
		LEFT OUTER JOIN [iub-internal].dbo.handbook_changelog cc 
			ON cc.article_edited = ca.article_id
			AND cc.log_id = (SELECT TOP 1 log_id FROM [iub-internal].dbo.handbook_changelog WHERE article_edited = ca.article_id ORDER BY timestamp DESC)
		LEFT OUTER JOIN [iub-internal].dbo.handbook_history ch 
			ON ch.rev_id = (SELECT TOP 1 rev_id FROM [iub-internal].dbo.handbook_history WHERE article_id = ca.article_id ORDER BY article_last_modified ASC)
		WHERE (ca.article_url = '' OR ca.article_url IS NULL)
		
		UNION
		
		SELECT 2 AS instance_id, ca.article_id, ca.article_cat, ca.article_priority,
			CASE
				WHEN ca.article_level > 30 THEN 'IUPUI,Admin'
				WHEN ca.article_level > 20 THEN 'IUPUI,CS'
				ELSE 'IUPUI,Consultant'
			END AS mask,
			CASE
				WHEN cc.uid IS NULL THEN 3
				ELSE cc.uid
			END AS creator_id,
			CASE
				WHEN ch.article_last_modified IS NULL THEN ca.article_last_modified
				ELSE ch.article_last_modified
			END AS date_created
		FROM [iupui-internal].dbo.handbook_articles ca
		LEFT OUTER JOIN [iupui-internal].dbo.handbook_changelog cc 
			ON cc.article_edited = ca.article_id
			AND cc.log_id = (SELECT TOP 1 log_id FROM [iupui-internal].dbo.handbook_changelog WHERE article_edited = ca.article_id ORDER BY timestamp DESC)
		LEFT OUTER JOIN [iupui-internal].dbo.handbook_history ch 
			ON ch.rev_id = (SELECT TOP 1 rev_id FROM [iupui-internal].dbo.handbook_history WHERE article_id = ca.article_id ORDER BY article_last_modified ASC)
		WHERE (ca.article_url = '' OR ca.article_url IS NULL)
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getExistingMatches">
		SELECT ca.instance_id, ca.old_id, ca.new_id
		FROM tbl_conversion_handbook_articles ca
		INNER JOIN tbl_articles a ON ca.new_id = a.article_id
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name
		FROM tbl_user_masks
	</cfquery>
	
	<cfloop query="getCats">
		<cfset instanceId = instance_id>
		<cfset oldCat = old_id>
		<cfset newCat = new_id>
		
		<cfquery dbtype="query" name="getCatArticles">
			SELECT instance_id, article_id, article_priority, mask, creator_id, date_created
			FROM getV3Docs
			WHERE instance_id = #instanceId#
			AND article_cat = #oldCat#
		</cfquery>
		
		<!---loop over our articles.  Add the article, add its masks, and audit that it has been imported--->
		<cfloop query="getCatArticles">
			<!---does the article already exist on V4?--->
			<cfquery dbtype="query" name="getArticleMatch">
				SELECT instance_id, old_id, new_id
				FROM  getExistingMatches
				WHERE instance_id = #instance_id#
				AND old_id = #article_id#
			</cfquery>
			
			<cfif getArticleMatch.recordCount eq 0>
				<!---add the article to V4's database--->
				<cfquery datasource="#application.applicationDataSource#" name="addArticle">
					INSERT INTO tbl_articles (category_id, creator_id, sort_order, created_date)
					OUTPUT inserted.article_id
					VALUES(
						<cfqueryparam cfsqltype="cf_sql_integer" value="#newCat#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, creator_id, getUsers)#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#article_priority#">,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#date_created#">
					)
				</cfquery>
				
				<cfset newArticleId = addArticle.article_id>
				
				<!---add the match to the databse--->
				<cfquery datasource="#application.applicationDataSource#" name="addMatch">
					INSERT INTO tbl_conversion_handbook_articles (instance_id, old_id, new_id)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#addArticle.article_id#">
					)
				</cfquery>
				
				<!---add the audit of this article's import.--->
				<cfquery datasource="#application.applicationDataSource#" name="addAudit">
					INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#addArticle.article_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
						'<ul><li>Article imported from V3</li></ul>'
					)
				</cfquery>
			<cfelse>
				<cfset newArticleId = getArticleMatch.new_id>
			</cfif>
			
			<!---now add the masks for this article, we do it seperately incase any where ever missed.--->
			<cfloop list="#mask#" index="n">
				<cfloop query="getAllMasks">
					<cfif mask_name eq trim(n)>
						<!---we found our mask, try to add it to the v4db.--->
						<cftry><!---wrap this in a try in case we end-up violating the unique key.--->
							<cfquery datasource="#application.applicationDataSource#" name="addMasks">
								INSERT INTO tbl_articles_masks (article_id, mask_id)
								VALUES (
									<cfqueryparam cfsqltype="cf_sql_integer" value="#newArticleId#">,
									<cfqueryparam cfsqltype="cf_sql_integer" value="#mask_id#">
								)
							</cfquery>
						<cfcatch></cfcatch>
						</cftry>
					</cfif>
				</cfloop>
			</cfloop>
		</cfloop>
	</cfloop>
</cffunction>

<cffunction name="storeHandbookContent">
	<cfset var instanceId = "">
	<cfset var myDsn = "">
	<cfset var getArticles = "">
	
	<cfset var tidyText = ""><!---store the sanitized output--->
	<cfset var prevText = ""><!---the output of the previous check--->
	
	<cfset var addVersion = ""><!---the query that actually adds the version.--->
	
	<cfloop from="1" to="2" index="instanceId">
		<cfif instanceId eq 1>
			<cfset myDsn = "iub-internal">
		<cfelse>
			<cfset myDsn = "iupui-internal">
		</cfif>
		
		<!---fetch the current articles.--->
		<cfquery datasource="#application.applicationDataSource#" name="getArticles">
			SELECT ch.new_id, ha.article_id, ha.article_title, ha.article_body, ha.article_last_modified
			FROM [#myDsn#].dbo.handbook_articles ha
			INNER JOIN [iu-v4].dbo.tbl_conversion_handbook_articles ch 
				ON ch.instance_id = #instanceId#
				AND ch.old_id = ha.article_id
			LEFT OUTER JOIN [iu-v4].dbo.tbl_articles_revisions ar
				ON ar.article_id = ch.new_id
				AND ar.revision_date = ha.article_last_modified
				AND ar.title = ha.article_title
			/*We're only interested in versions that haven't been brought over yet.*/
			WHERE ar.revision_id IS NULL
		</cfquery>
		
		
		<ol>
		<cfloop query="getArticles">
			<!---fix any v3 links, then store the content--->
			<cfset prevText = article_body>
			<cfset tidyText = cleanArticle(instanceId, article_body)>
			<cfloop condition="prevText neq tidyText">
				<!---clean up for our next pass.--->
				<cfset prevText = tidyText>
				<cfset tidyText = cleanArticle(instanceId, prevText)>
			</cfloop>
			
			<!---on this side of the loop we're looking at corrected text, store it.--->
			<cfquery datasource="#application.applicationDataSource#" name="addVersion">
				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, use_revision, revision_date)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#new_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#article_title#">,
					<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#tidyText#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#0#">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="#1#">,
					<cfqueryparam cfsqltype="cf_sql_timestamp" value="#article_last_modified#">
				)
			</cfquery>
		</cfloop>
		</ol>
		
		<!---now do the same for earlier revisions--->
		<cfquery datasource="#application.applicationDataSource#" name="getArticles">
			SELECT ch.new_id, ha.article_id, ha.article_title, ha.article_body, ha.article_last_modified
			FROM [#myDsn#].dbo.handbook_history ha
			INNER JOIN [iu-v4].dbo.tbl_conversion_handbook_articles ch 
				ON ch.instance_id = #instanceId#
				AND ch.old_id = ha.article_id
			LEFT OUTER JOIN [iu-v4].dbo.tbl_articles_revisions ar
				ON ar.article_id = ch.new_id
				AND ar.revision_date = ha.article_last_modified
				AND ar.title = ha.article_title
			/*We're only interested in versions that haven't been brought over yet.*/
			WHERE ar.revision_id IS NULL
		</cfquery>
		
		<ol>
		<cfloop query="getArticles">
			<!---fix any v3 links, then store the content--->
			<cfset prevText = article_body>
			<cfset tidyText = cleanArticle(instanceId, article_body)>
			<cfloop condition="prevText neq tidyText">
				<!---clean up for our next pass.--->
				<cfset prevText = tidyText>
				<cfset tidyText = cleanArticle(instanceId, prevText)>
			</cfloop>
			
			<!---on this side of the loop we're looking at corrected text, store it.--->
			<cfquery datasource="#application.applicationDataSource#" name="addVersion">
				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, use_revision, revision_date)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#new_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#article_title#">,
					<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#tidyText#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#0#">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="#0#">,
					<cfqueryparam cfsqltype="cf_sql_timestamp" value="#article_last_modified#">
				)
			</cfquery>
		</cfloop>
		</ol>
		
	</cfloop>
</cffunction>

<cffunction name="convertV3UserId">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="v3Id" type="numeric" required="true">
	<cfargument name="usersQuery" type="query" required="true">
	
	<cfset var v4id = 0>
	
	<cfloop query="usersQuery">
		<cfif instance_id eq instanceId AND old_id eq v3id>
			<cfset v4id = new_id>
			<cfbreak>
		</cfif>
	</cfloop>
	
	<cfreturn v4id>
</cffunction>

<cffunction name="storeAnnouncementArticles">
	<cfset var instanceId = "">
	<cfset var myDsn = "">
	<cfset var myMask = "">
	<cfset var newId = 0>
	<cfset var getAnnouncements = "">
	<cfset var getUsers = ""><!---a query used to match v3 users to v4 users--->
	<cfset var getAllMasks = ""><!---a query of all the masks, so we can match mask names to their mask_id--->
	<cfset var checkDupes = "">
	<cfset var addArticle = "">
	<cfset var addMatch = "">
	<cfset var addMasks = "">
	
	
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllMasks">
		SELECT mask_id, mask_name
		FROM tbl_user_masks
	</cfquery>
	
	<cfloop from="1" to="2" index="instanceId">
		<cfif instanceId eq 1>
			<cfset myDsn = "iub-internal">
			<cfset myMask = "IUB">
		<cfelse>
			<cfset myDsn = "iupui-internal">
			<cfset myMask = "IUPUI">
		</cfif>
		
		<!---fetch the announcments for this instance--->
		<cfquery datasource="#application.applicationDataSource#" name="getAnnouncements">
			SELECT #instanceId# AS instance_id, a.ann_id, a.ann_title, a.ann_body, ann_date_posted, deleted,
				CASE
					WHEN a.ann_access_level > 30 THEN '#myMask#,Admin'
					WHEN a.ann_access_level > 20 THEN '#myMask#,CS'
					ELSE '#myMask#,Consultant'
				END AS mask,
				CASE
					WHEN u.Uid IS NULL THEN 0
					ELSE u.uid
				END AS uid
			FROM [#myDsn#].dbo.announcements a
			LEFT OUTER JOIN [#myDsn#].dbo.users u ON u.username = a.poster
		</cfquery>
		
		<!---first add the v4 articles for these announcements, and record the conversion.--->
		<cfloop query="getAnnouncements">
			<!---check if there is already a match for this announcement--->
			<cfquery datasource="#application.applicationDataSource#" name="checkDupes">
				SELECT ca.new_id
				FROM tbl_conversion_announcements ca
				INNER JOIN tbl_articles a ON a.article_id = ca.new_id 
				WHERE ca.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">
				AND ca.old_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#ann_id#">
			</cfquery>
			
			<cfif checkDupes.recordCount eq 0>
				<!---record the article itself.--->
				<cfquery datasource="#application.applicationDataSource#" name="addArticle">
					INSERT INTO tbl_articles (category_id, creator_id, created_date, retired)
					OUTPUT inserted.article_id
					VALUES(
						3,/*thats "Announcements"*/
						<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, uid, getUsers)#">,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#ann_date_posted#">,
						<cfqueryparam cfsqltype="cf_sql_bit" value="#deleted#">
					)
				</cfquery>
				
				<cfset newId = addArticle.article_id>
				
				<!---record the match--->
				<cfquery datasource="#application.applicationDataSource#" name="addMatch">
					INSERT INTO tbl_conversion_announcements (instance_id, old_id, new_id)
					VALUES (
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instance_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#ann_id#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#addArticle.article_id#">
					)
				</cfquery>
			<cfelse>
				<cfset newId = checkDupes.new_id>
			</cfif>
			
			<!---now add the masks for this article, we do it seperately incase any where ever missed.--->
			<cfloop list="#mask#" index="n">
				<cfloop query="getAllMasks">
					<cfif mask_name eq trim(n)>
						<!---we found our mask, try to add it to the v4db.--->
						<cftry><!---wrap this in a try in case we end-up violating the unique key.--->
							<cfquery datasource="#application.applicationDataSource#" name="addMasks">
								INSERT INTO tbl_articles_masks (article_id, mask_id)
								VALUES (
									<cfqueryparam cfsqltype="cf_sql_integer" value="#newId#">,
									<cfqueryparam cfsqltype="cf_sql_integer" value="#mask_id#">
								)
							</cfquery>
						<cfcatch></cfcatch>
						</cftry>
					</cfif>
				</cfloop>
			</cfloop>
		</cfloop>
	</cfloop>	
</cffunction>


<cffunction name="storeAnnouncemntContent">
	<cfset var getUsers = "">
	<cfset var instanceId = "">
	<cfset var myDsn = "">
	<cfset var getAnnouncements = "">
	<cfset var addArticle = "">
	
	<cfset var tidyText = ""><!---store the sanitized output--->
	<cfset var prevText = ""><!---the output of the previous check--->
	
	<!---used to convert between v3 users and v4 users--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<cfloop from="1" to="2" index="instanceId">
		<cfif instanceId eq 1>
			<cfset myDsn = "iub-internal">
		<cfelse>
			<cfset myDsn = "iupui-internal">
		</cfif>
		
		<!---fetch the announcments for this instance--->
		<cfquery datasource="#application.applicationDataSource#" name="getAnnouncements">
			SELECT ca.instance_id, ca.new_id, a.ann_id, a.ann_title, a.ann_body, ann_date_posted, deleted,
				CASE
					WHEN a.ann_access_level > 30 THEN 'IUB,Admin'
					WHEN a.ann_access_level > 20 THEN 'IUB,CS'
					ELSE 'IUB,Consultant'
				END AS mask,
				CASE
					WHEN u.Uid IS NULL THEN 0
					ELSE u.uid
				END AS uid
			FROM [#myDsn#].dbo.announcements a
			INNER JOIN [iu-v4].dbo.tbl_conversion_announcements ca ON ca.instance_id = #instanceId# AND ca.old_id = a.ann_id
			LEFT OUTER JOIN [iu-v4].dbo.tbl_articles_revisions ar ON ar.article_id = ca.new_id
			LEFT OUTER JOIN [#myDsn#].dbo.users u ON u.username = a.poster
			WHERE ar.article_id IS NULL/*only show announcements that don't already have content.*/
		</cfquery>
		
		<ol>
		<cfloop query="getAnnouncements">
			<!---fix any v3 links, then store the content--->
			<cfset prevText = ann_body>
			<cfset tidyText = cleanArticle(instance_id, ann_body)>
			<cfloop condition="prevText neq tidyText">
				<!---clean up for our next pass.--->
				<cfset prevText = tidyText>
				<cfset tidyText = cleanArticle(instance_id, prevText)>
			</cfloop>
			
			<!---on this side of the loop we're looking at corrected text, store it.--->
			<cfquery datasource="#application.applicationDataSource#" name="addArticle">
				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, use_revision, revision_date)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#new_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#ann_title#">,
					<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#ann_body#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, uid, getUsers)#">,
					1,
					<cfqueryparam cfsqltype="cf_sql_timestamp" value="#ann_date_posted#">
				)
			</cfquery>
			
		</cfloop>
		</ol>
	</cfloop>
</cffunction>

<cffunction name="storeChats">
	<cfset var instanceId = "">
	<cfset var myDsn = "">
	<cfset var getChats = "">
	<cfset var prevText = "">
	<cfset var tidyText = "">
	<cfset var addChat = "">
	
	<cfloop from="1" to="2" index="instanceId">
		<cfif instanceId eq 1>
			<cfset myDsn = "iub-internal">
		<cfelse>
			<cfset myDsn = "iupui-internal">
		</cfif>
		
		<cfquery datasource="#application.applicationDataSource#" name="getChats">
			INSERT INTO tbl_chat_messages (instance, user_id, date_time, message, from_ip, visible)
			SELECT #instanceId# as instance, cu.new_id as user_id, c.date_time, c.Message, c.from_ip,
				CASE
					WHEN c.visible = 'Y' THEN 1
					ELSE 0
				END AS visible
			FROM [#myDsn#].dbo.chat c
			INNER JOIN tbl_conversion_users cu 
				ON cu.old_id = c.uid
				AND cu.instance_id = #instanceId#
			LEFT OUTER JOIN tbl_chat_messages cm
				ON cm.user_id = cu.new_id
				AND cm.date_time = c.date_time
			WHERE cm.message_id IS NULL
		</cfquery>
	</cfloop>
</cffunction>

<cffunction name="storeRevisions">
	<cfset var getusers = "">
	<cfset var getArticles = ""><!---query to snag the v4 and v3 article_id's--->
	<cfset var instanceId = "">
	<cfset var myDsn = ""><!---use the IUB or IUPUI data source?--->
	<cfset var tidyText = ""><!---where we'll store our sanitized version of the article's body.--->
	<cfset var prevText = ""><!---used when we're looping over changes to see if we're done cleaning the text--->
	<cfset var addRevision = "">
	
	<!---used to convert between v3 users and v4 users--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT instance_id, old_id, new_id
		FROM tbl_conversion_users
	</cfquery>
	
	<cfloop from="1" to="2" index="instanceId">
		<cfif instanceId eq 1>
			<cfset myDsn = "iub-internal">
		<cfelse>
			<cfset myDsn = "iupui-internal">
		</cfif>
		
		<!---fetch all current revision for articles that don't have one yet.--->
		<cfquery datasource="#application.applicationDataSource#" name="getArticles">
			SELECT ca.instance_id, ca.new_id, a.article_id, a.article_title, a.article_body, a.article_last_modified,
				CASE
					WHEN cc.uid IS NULL THEN 0
					ELSE cc.uid
				END as uid
			FROM [#myDsn#].dbo.content_articles a
			INNER JOIN [iu-v4].dbo.tbl_conversion_articles ca
				ON ca.instance_id = #instanceId#
				AND ca.old_id = a.article_id
			LEFT OUTER JOIN [iu-v4].dbo.tbl_articles_revisions ar 
				ON ar.article_id = ca.new_id
				AND ar.title = a.article_title
				AND ar.revision_date = a.article_last_modified
			/*try to find the user who made the change.*/
			LEFT OUTER JOIN [#myDsn#].dbo.content_changelog cc 
				ON cc.article_edited = a.article_id
				AND cc.log_id = (SELECT TOP 1 log_id FROM [#myDsn#].dbo.content_changelog WHERE article_edited = a.article_id ORDER BY timestamp DESC)
			WHERE ar.revision_id IS NULL
		</cfquery>
		
		<cfloop query="getArticles">
			<cfset prevText = article_body>
			<cfset tidyText = cleanArticle(instance_id, prevText)>
			
			<cfloop condition="prevText neq tidyText">
				<cfset prevText = tidyText>
				<cfset tidyText = cleanArticle(instance_id, prevText)>
			</cfloop>
			
			<!---at this point tidyText should have all our corrected links.  Store it as the current revision.--->
			<cfquery datasource="#application.applicationDataSource#" name="addRevision">
				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, use_revision, revision_date)
				VALUES(
					<cfqueryparam cfsqltype="cf_sql_integer" value="#new_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#article_title#">,
					<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#tidyText#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, uid, getUsers)#">,
					1,
					<cfqueryparam cfsqltype="cf_sql_timestamp" value="#article_last_modified#">
				)
			</cfquery>
		</cfloop>
		
		<!---now do the same for older revisions--->
		<cfquery datasource="#application.applicationDataSource#" name="getArticles">
			SELECT ca.instance_id, ca.new_id, a.orig_id, a.article_title, a.article_body, a.article_last_modified,
				CASE
					WHEN cc.uid IS NULL THEN 0
					ELSE cc.uid
				END as uid
			FROM [#myDsn#].dbo.content_articles_history a
			INNER JOIN [iu-v4].dbo.tbl_conversion_articles ca
				ON ca.instance_id = #instanceId#
				AND ca.old_id = a.orig_id
			LEFT OUTER JOIN [iu-v4].dbo.tbl_articles_revisions ar 
				ON ar.article_id = ca.new_id
				AND ar.title = a.article_title
				AND ar.revision_date = a.article_last_modified
			/*try to find the user who made the change.*/
			LEFT OUTER JOIN [#myDsn#].dbo.content_changelog cc 
				ON cc.article_edited = a.orig_id
				AND cc.log_id = (SELECT TOP 1 log_id FROM [#myDsn#].dbo.content_changelog WHERE article_edited = a.orig_id AND timestamp <= a.article_last_modified ORDER BY timestamp DESC)
			WHERE ar.revision_id IS NULL
		</cfquery>
		
		<cfloop query="getArticles">
			<cfset prevText = article_body>
			<cfset tidyText = cleanArticle(instance_id, prevText)>
			
			<cfloop condition="prevText neq tidyText">
				<cfset prevText = tidyText>
				<cfset tidyText = cleanArticle(instance_id, prevText)>
			</cfloop>
			
			<!---at this point tidyText should have all our corrected links.  Store it as the current revision.--->
			<cfquery datasource="#application.applicationDataSource#" name="addRevision">
				INSERT INTO tbl_articles_revisions (article_id, title, revision_content, user_id, use_revision, revision_date)
				VALUES(
					<cfqueryparam cfsqltype="cf_sql_integer" value="#new_id#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#article_title#">,
					<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#tidyText#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#convertV3UserId(instance_id, uid, getUsers)#">,
					0,
					<cfqueryparam cfsqltype="cf_sql_timestamp" value="#article_last_modified#">
				)
			</cfquery>
		</cfloop>
		
	</cfloop>
</cffunction>


<cffunction name="cleanArticle">
	<cfargument name="instanceId" type="numeric" required="1"><!---which instance's records should we be looking in when fixing links?--->
	<cfargument name="content" type="String" required="1">
	
	<cfset var match = ""><!---where our regex tests end up.--->
	<cfset var tempString = ""><!---a little work space for our edits.--->
	<cfset var v3IdTemp = "">
	<cfset var v3Id = 0>
	<cfset var v4Id = 0>
	<cfset var tstart = "">
	<cfset var tend = "">
	
	
	<!---first, let's try to catch and fix links to other articles.--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/view\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/view\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getARticleConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---there are still a few golden oldies knocking around with broken links to the original document viewer from before V3--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/content_view_article\.\s*cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/content_view_article\.\s*cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<!--- now that we have a v3id we can pair that up with the new v4id--->
		<cfset v4id = 0>
		<cfloop query="getARticleConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---in some of the tomes they used valid HTML that is a pain in the butt, just a ?article_id=nnn  Let's replace those with full URLs--->
	<cfset match = reFindNoCase('<a href="\?article_id=\d+', content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, '<a href="\?', '<a href="tetra/documents/article.cfm?')>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<!--- now that we have a v3id we can pair that up with the new v4id--->
		<cfset v4id = 0>
		<cfloop query="getARticleConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix links to handbook articles--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/+v3/docs/handbook/handbook_view_article\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/+v3/docs/handbook/handbook_view_article\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix older handbook links, too.--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/handbook/handbook\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/handbook/handbook\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---then fix EVEN OLDER handbook links.--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/content/handbook/handbook\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/content/handbook/handbook\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix old print handbook links--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/handbook/handbook_print\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_print\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix handbook categories--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/handbook/handbook_readthrough\.cfm\??[^'"">]*##cat_id_\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_readthrough\.cfm", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("cat_id_\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookCatConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "cat_id_\d+", "cat#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	<!---fix generic handbook readthrough links.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_readthrough\.cfm(?!##cat_id_\d+)", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm", "all")>
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook\.cfm\??[^'"">]*(?!article_id=\d+)", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm", "all")>
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook\.html", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm", "all")>
	
	<!---fix links to the announcement viewer--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/announcements/announcements_viewer\.cfm\?[^'"">]*ann_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/announcements/announcements_viewer\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("ann_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getAnnouncementConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "ann_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	<!---file manager links, there are two cases, one were we have a fileId and another where we have a filePath--->
	<cfif reFindNoCase("stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm", content)><!---this prevents infinite loops of re-detected v4 id's to change.--->
		
		<!---We're ready to find and fix filemanager ID based links.--->
		<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm\?[^'"">]*fileId=\d+", content, 1, true)>
		
		<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
			<cfset tempString = mid(content, match.pos[1], match.len[1])>
			
			<!---debugging
			<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
			
			<!---now we need to find the correct v4 file_id number for the one linked to.--->
			<cfset v3IdTemp = reFindNoCase("fileId=\d+", tempString, 1, true)>
			<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
			
			<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
			<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
			
			<!---now that we have our v3 ID we need to find the matching v4id--->
			<cfset v4id = 0>
			<cfloop query="getFileConversions">
				<cfif instance_id eq instanceId AND old_id eq v3id>
					<cfset v4id = new_id>
					<cfbreak>
				</cfif>
			</cfloop>
			
			<!---cfdump var="#tempString#"><br/--->
			
			<!---with both ID's we can make our replacement.--->
			<cfset tempString = reReplaceNoCase(tempString, "fileId=\d+", "fileId=#v4Id#")>
			<!---Also fix the start of the URL to use our new location--->
			<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm", "tetra/tools/filemanager/get_file.cfm", "one")>
			
			<!---cfdump var="#tempString#"--->
			
			<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
			<cfset tEnd = match.pos[1] + match.len[1]>
			<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
		</cfif>
		
		<!---We're ready to find and fix filemanager path based links, urls should have been preservered between versions.--->
		<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm\?[^'"">]*filePath=", content, 1, true)>
		
		<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
			<cfset tempString = mid(content, match.pos[1], match.len[1])>
			
			<!---this is much simpler than the fileId, as filePaths should have been preserved during importing of files, we just need to change the base url.--->
			<!---cfdump var="#tempString#"><br/--->
			
			<!---Fix the start of the URL to use our new location--->
			<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm", "tetra/tools/filemanager/get_file.cfm", "one")>
			
			<!---cfdump var="#tempString#"--->
			
			<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
			<cfset tEnd = match.pos[1] + match.len[1]>
			<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
		</cfif>
	</cfif>
	
	<!---fix links to the filemanager itself--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/filemanager/manager\.cfm", "tetra/tools/filemanager/manager.cfm", "all")>
	
	<!---fix newsletter links--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/newsletter/newsletter_view\.cfm\?[^'"">]*id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/newsletter/newsletter_view\.cfm", "tetra/documents/newsletter.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfset v4id = -1>
		<cfloop query="getNewsletterCatConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "id=\d+", "catId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	<!---fix links to the old newsletter main page.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/newsletter/(?![\w\s])", "tetra/documents/newsletter.cfm", "all")>
	
	
	<!---There are some old images in a static folder of v3, and some img tags use relative links to find them.  make them explicit.--->
	<cfset content = reReplaceNoCase(content, "src=[""]+images[/\\]?", "src=""stcpages/" & iif(instanceId eq 1, de("IUB"), de("IUPUI")) & "/v3/docs/images/", "all")><!---double-quoted url--->
	<cfset content = reReplaceNoCase(content, "src=[']+images[/\\]?", "src='stcpages/" & iif(instanceId eq 1, de("IUB"), de("IUPUI")) & "/v3/docs/images/", "all")><!---single-quoted url--->
	<cfset content = reReplaceNoCase(content, "src=images[/\\]?", "src=stcpages/" & iif(instanceId eq 1, de("IUB"), de("IUPUI")) & "/v3/docs/images/", "all")><!---un-quoted url--->
	
	<!---links to lab distrobution.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/utils/labdist/labdist\.cfm", "tetra/tools/lab-distribution/lab-distribution.cfm", "all")>
	
	<!---fix links to the trainings report--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/return/consults_report\.cfm", "tetra/tools/training-report/training-report.cfm", "all")>
	
	<!---fix links to the search--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/search/index\.cfm", "tetra/search.index.cfm", "all")>
	
	<!---fix links to the incident report form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/incident\.cfm", "tetra/tools/incident-report/incident-report.cfm", "all")>
	
	<!---fix links to the routes listing.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/labs\.cfm", "tetra/tools/routes/view_routes.cfm", "all")>
	
	<!---old awards have been phased out, we have a Gold Star Hall of Fame instead.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/AwardsReport\.cfm", "tetra/tools/awards/gold-stars-report.cfm", "all")>
	
	<!---catch the IC-Cleaning form--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/ic-cleaning/", "tetra/tools/ic-cleaning/", "all")>
	<cfset content = replaceNoCase(content, "tetra/tools/ic-cleaning/index.cfm", "tetra/tools/ic-cleaning/ic-cleaning.cfm", "all")>
	
	<!---replace the old content browser with the new one.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/content_index\.cfm", "tetra/documents/index.cfm", "all")>
	
	<!---fix urls for PIE thumbnails--->
	<cfset content = replaceNoCase(content, "../../../../iupuistc/thumbnails", "/apps/iupuistc/thumbnails", "all")>
	<cfset content = replaceNoCase(content, "../../../../tcc/thumbnails", "/apps/tcc/thumbnails", "all")>
	
	<!---fix some bad relative links to the old article tool so they're caught by the next pass.--->
	<cfset content = replaceNoCase(content, "../../../iub/v3/docs/view.cfm", "stcpages/iub/v3/docs/view.cfm", "all")>
	
	<!---fix links to the chat icon editor--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/chat3/chat_edit_icons\.cfm", "tetra/chat/chat_edit_icons.cfm", "all")>
	
	<!---fix links to the chat database search--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/chat3/chat_db\.cfm", "tetra/chat/chat-history.cfm", "all")>
	
	<!---fix links to the shift report--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/utils/cs/shiftreport\.cfm", "tetra/tools/shift-report/shift-report.cfm", "all")>
	
	<!---point folks to the new account check form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/account_check\.cfm", "tetra/tools/account-check/account-check.cfm", "all")>
	
	<!---view all announcements have changed.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/announcements/announcements_box\.cfm\?[^'"">]*viewall=((yes)|(true)|(1))", "tetra/documents/index.cfm?frmCatId=3", "all")>
	
	<!---fix links to the handbook acknowledgement form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_ack\.cfm", "tetra/handbook/acknowledgement-form.cfm", "all")>
	
	<!---fix links to the sub plea form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/sub_plea\.cfm", "tetra/tools/sub-plea/sub-plea.cfm", "all")>
	
	
	<!---	DONE	--->
	<!---Now just find random links and display them/replace them.
	<cfset match = reFindNoCase('\<[^\>]+src[^\>]+\>|\<[^\>]+href[^\>]+\>|\<[^\>]+url[^\>]+\>', content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		<cfoutput>
			<li <cfif findNoCase("v3", tempString)>style="background-color: yellow;"</cfif>>#htmlEditformat(tempString)#</li>
		</cfoutput>
		
		<!---now replace it so we can make our next pass.--->
		<cfset content = reReplaceNoCase(content, "\<[^\>]+src[^\>]+\>|\<[^\>]+href[^\>]+\>|\<[^\>]+url[^\>]+\>", "", "one")>
	</cfif>
	--->
	<cfreturn content>
</cffunction>