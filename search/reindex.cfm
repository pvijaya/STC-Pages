<cfmodule template="#application.appPath#/header.cfm" title="Rebuild Search Index">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">

<!---Clear out our current solr search index, and repopulate it from scratch.--->

<!---first purge our index so we can start over.--->
<cfindex collection="v4-search" action="purge">

<!---snag all our top-level article categories - those are our cats.--->
<cfquery datasource="#application.applicationDataSource#" name="getTopCats">
	SELECT category_id, category_name
	FROM tbl_articles_categories
	WHERE parent_cat_id = 0
	AND retired = 0
	ORDER BY sort_order, category_name
</cfquery>

<cfloop query="getTopCats">
	<h2><cfoutput>#category_name#</cfoutput></h2>
	
	<!---find all the child categories for this top-level category, so we can snag all the articles in one fell swoop.--->
	<cfset catList = getCategoryChildrenList(category_id)>
	
	<!---this query returns too many results because we're fetching the masks, too, we'll cook it down to one cleaner query we can use with cfoutput and group options.--->
	<cfquery datasource="#application.applicationDataSource#" name="grossGetArticles">
		SELECT a.article_id, ar.title, ar.revision_content, ar.revision_date, um.mask_id, um.mask_name
		FROM tbl_articles a
		INNER JOIN tbl_articles_revisions ar 
			ON ar.article_id = a.article_id
			AND ar.use_revision = 1
		LEFT OUTER JOIN tbl_articles_masks am ON am.article_id = a.article_id
		LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
		WHERE a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#catList#" list="true">)
		AND a.retired = 0
		ORDER BY a.article_id, um.mask_name
	</cfquery>
	
	<cfset getArticles = queryNew("id,article_title,article_body,required_masks,article_date,article_url,category", "varchar,varchar,varchar,varchar,date,varchar,varchar")>
	
	<cfoutput query="grossGetArticles" group="article_id">
		<cfset maskList = "">
		<!---build-up our list of required masks.--->
		<cfoutput>
			<cfset maskList = listAppend(maskList, mask_name)>
		</cfoutput>
		
		<cfset queryAddRow(getArticles)>
		<cfset querySetCell(getArticles, "id", article_id)>
		<cfset querySetCell(getArticles, "article_title", reReplace(title, "<[^>]*>", "", "all"))><!---trim out html tags and store the title--->
		<cfset querySetCell(getArticles, "article_body", reReplace(revision_content, "<[^>]*>", "", "all"))>
		<cfset querySetCell(getArticles, "required_masks", maskList)>
		<cfset querySetCell(getArticles, "article_date", revision_date)>
		<cfset querySetCell(getArticles, "article_url", "#application.appPath#/documents/article.cfm?articleId=#article_id#")>
		<cfset querySetCell(getArticles, "category", #getTopCats.category_name#)>
	</cfoutput>
	
	<!---at this point we can run the sanitizer on the results and store them in our search index.--->
	<cfset indexSearchQuery(getArticles)>
	<p>Done.</p>
</cfloop>

<!---now do the same for files.--->
<h2>Files</h2>
<cfquery datasource="#application.applicationDatasource#" name="grossGetFiles">
	SELECT f.file_id, f.file_name, f.file_description, fv.version_date, fv.version_file_name, um.mask_name
	FROM tbl_filemanager_files f
	INNER JOIN tbl_filemanager_files_versions fv
		ON f.file_id = fv.file_id
		AND fv.use_version = 1
	LEFT OUTER JOIN tbl_filemanager_files_masks fm ON fm.file_id = f.file_id
	LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = fm.mask_id
	
	ORDER BY f.file_id, um.mask_name
</cfquery>

<cfset getFiles = queryNew("id,article_title,article_body,required_masks,article_date,article_url,category", "varchar,varchar,varchar,varchar,date,varchar,varchar")>
<cfoutput query="grossGetFiles" group="file_id">
	<cfset maskList = "">
	<cfoutput>
		<cfset maskList = listAppend(maskList, mask_name)>
	</cfoutput>
	
	<cfset queryAddRow(getFiles)>
	<cfset querySetCell(getFiles, "id", file_id)>
	<cfset querySetCell(getFiles, "article_title", reReplace(file_name, "<[^>]*>", "", "all"))><!---trim out html tags and store the title--->
	<cfset querySetCell(getFiles, "article_body", reReplace(file_description & " " & file_name, "<[^>]*>", "", "all"))>
	<cfset querySetCell(getFiles, "required_masks", maskList)>
	<cfset querySetCell(getFiles, "article_date", version_date)>
	<cfset querySetCell(getFiles, "article_url", "#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#")>
	<cfset querySetCell(getFiles, "category", "Files")>
</cfoutput>

<!---we should have a well-formatted query.  Add it all to the index.--->
<cfset indexSearchQuery(getFiles)>
<p>Done.</p>

<h2>Site Map</h2>

<cfquery datasource="#application.applicationDataSource#" name="grossGetLinks">
	SELECT hl.link_id, hl.text, hl.link, um.mask_name
	FROM tbl_header_links hl
	LEFT OUTER JOIN tbl_header_links_masks hlm ON hlm.link_id = hl.link_id
	LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = hlm.mask_id
	WHERE retired = 0
	ORDER BY hl.link_id, um.mask_name
</cfquery>


<cfset getLinks = queryNew("id,article_title,article_body,required_masks,article_date,article_url,category", "varchar,varchar,varchar,varchar,date,varchar,varchar")>
<cfoutput query="grossGetLinks" group="link_id">
	<cfset maskList = "">
	<cfoutput>
		<cfset maskList = listAppend(maskList, mask_name)>
	</cfoutput>
	
	<!---some links are complete URLS, some are relative.--->
	<cfset myLink = link>
	<cfif not isValid('url', link) AND link neq "##">
		<cfset myLink = application.appPath & '/' & link>
	</cfif>
	
	<cfif myLink neq "##"><!---naturally we don't want links that don't go anywhere.--->
		<cfset queryAddRow(getLinks)>
		<cfset querySetCell(getLinks, "id", link_id)>
		<cfset querySetCell(getLinks, "article_title", reReplace(text, "<[^>]*>", "", "all"))><!---trim out html tags and store the title--->
		<cfset querySetCell(getLinks, "article_body", reReplace(myLink, "<[^>]*>", "", "all"))>
		<cfset querySetCell(getLinks, "required_masks", maskList)>
		<cfset querySetCell(getLinks, "article_date", NOW())>
		<cfset querySetCell(getLinks, "article_url", myLink)>
		<cfset querySetCell(getLinks, "category", "Site&nbsp;Map")><!---weirdly categories can't contain a space.--->
	</cfif>
</cfoutput>

<!---we should have a well-formatted query.  Add it all to the index.--->
<cfset indexSearchQuery(getLinks)>


<cfinclude template="#application.appPath#/footer.cfm">