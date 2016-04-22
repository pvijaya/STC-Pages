<cfmodule template="#application.appPath#/header.cfm" title="Newsletter">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- fetch all article categories to speed up certain queries and reduce database pings --->
<cfset getCategories = getAllCategoriesQuery(0)> <!--- don't include retired categories. --->

<!--- get the newsletter's cat id - 7 --->
<cfset newsletter = 7>

<!--- we need to determine which campus we are at, and default to that one --->
<!--- fetch the newsletter cat associated with the user's Session.primary_instance --->
<cfquery datasource="#application.applicationDataSource#" name="getNLInstance">
	SELECT ac.category_id 
	FROM tbl_articles_categories ac
	INNER JOIN tbl_articles_categories_owner aco ON aco.category_id = ac.category_id
	INNER JOIN tbl_user_masks um ON um.mask_id = aco.mask_id
	WHERE um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
		  AND ac.parent_cat_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newsletter#">
</cfquery>

<!--- fetch the newsletter cats - the children of the instance cat found above --->
<cfset getNewsletters = getChildCategoriesByParent(getNLInstance.category_id, getCategories)>

<!--- now, fetch the newsletter kittens (children of cats) --->
<!--- this list will contain the newsletters and their descendents --->
<cfset nlCatList = getCategoryChildrenList(getNLInstance.category_id, getCategories)>

<!--- fetch info about all our newsletters' articles, so we can find out which ones are published. --->
<cfquery datasource="#application.applicationDataSource#" name="getArticles">
	SELECT TOP 1 category_id
	FROM tbl_articles a
	INNER JOIN tbl_articles_revisions ar ON ar.article_id = a.article_id
	WHERE a.retired = 0
		  AND ar.approved = 1
		  AND ar.use_revision = 1
		  AND a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#nlCatList#" list="true">)
		  ORDER BY revision_date DESC
</cfquery>

<!---at this point we should have a category_id, pass it and the user's masks along to mod_read_category.cfm--->
<cfset getMasks = getMasks()>

<cfset maskList = "">
<cfloop query="#getMasks#">
	<cfset maskList = listAppend(maskList, mask_name)>
</cfloop>

<div id="articleId" style="width:75%;margin:0px auto;padding:5px;" class="shadow-border">

<!---draw the correct header image based on instances--->
<cfoutput>
	<cfif myInstance.instance_mask EQ "IUB">	
			<img src="#application.appPath#/tools/filemanager/get_file.cfm?filePath=%2FNewsletter%2FNewletter%20header%2Ejpg" width="100%">
	<cfelseif myInstance.instance_mask EQ "IUPUI">
			<img src="#application.appPath#/tools/filemanager/get_file.cfm?filePath=%2FNewsletter%2FNewsletter%20IUPUI%20Header.jpg" width="100%">
	</cfif>
</cfoutput>

<cfmodule template="#application.appPath#/documents/mod_read_category.cfm" 
		  categoryId="#getArticles.category_id#" masks="#maskList#" toc="false">
</div>

<cfmodule template="#application.appPath#/footer.cfm">