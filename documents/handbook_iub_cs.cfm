<cfmodule template="#application.appPath#/header.cfm" title="IUB CS Handbook">

<cfquery datasource="#application.applicationDataSource#" name="getCategory">
	SELECT ac.category_id
	FROM tbl_articles_categories ac
	WHERE ac.category_name = 'Consultant Supervisor Handbook'
</cfquery>

<cfif getCategory.recordCount EQ 0>

	<p class="warning">The category could not be found. Please contact TCCWM or TCCPIE.</p>

<cfelse>

	<div id="articleId" class="shadow-border">
		<cfmodule template="#application.appPath#/documents/mod_read_category.cfm" 
		          categoryId="#getCategory.category_id#" masks="IUB,CS">
	</div>
	
</cfif>	
	
<cfmodule template="#application.appPath#/footer.cfm">