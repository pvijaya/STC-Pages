<cfmodule template="#application.appPath#/header.cfm" title="Recent Revisions">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Article Editor">

	<div style="width:25%;float:left;margin-right:15px;" class="print-hide">
		<cfmodule template="#application.appPath#/documents/mod_browse.cfm" width="100%">
	</div>

<cfparam name="category" type="integer" default="0">	
<cfparam name="action" type="string" default="">
<cfparam name="count" type="integer" default="100">

<cfset allCats = getAllCategoriesQuery(0)>

<cfif action EQ "Clear">
	<cfset category = "0">	
</cfif>

<div style="float:right;"  id="articleId">

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" id="trainform" method="post" 
	class="form" enctype="multipart/form-data">
		
		<fieldset>
	
			<legend>Filter Results</legend>
			
			<p>
				<label for="category">Category</label><br />
				<cfoutput>#drawCategorySelect("category", category, "", allCats)#</cfoutput>
		    </p>
		    		    
			<p class="submit">
				<input type="submit" value="Submit" name="action" />
				<input type="submit" value="Clear" name="action">
			</p>
				
		</fieldset>
		
	</form>
	
	<cfquery name="getRecentRevisions" datasource="#application.applicationDataSource#">
		SELECT TOP 100 a.article_id, ar.revision_id, ar.title,  ar.approved, ar.revision_date, a.category_id, ac.category_name, u.username 
		FROM tbl_articles_revisions ar 
		JOIN tbl_users u ON u.user_id = ar.user_id
		INNER JOIN tbl_articles a ON a.article_id = ar.article_id 
		INNER JOIN tbl_articles_categories ac ON ac.category_id = a.category_id 
		WHERE a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" 
											  value="#getCategoryChildrenList(category, allCats)#" 
											  list="true">)
		ORDER BY ar.revision_date DESC, ac.category_name ASC, a.article_id ASC 
	</cfquery>
			
	<!--->	<h1>Recent Revisions - <cfoutput>#getFormattedParentList(category,allCats)#</cfoutput></h1> --->
	<h1>Recent Revisions</h1>
	<table class="stripe" style="padding:0px;">
		<tr class="titlerow" style="padding:5px;">
			<th>Link</th>
			<th>Title</th>
			<th>Submitted By</th>
			<th>Date</th>
		</tr>
		<cfloop query="getRecentRevisions">
			<cfoutput>
				<tr>
					<td><a href="#application.appPath#/documents/article.cfm?articleId=#article_id#&revisionId=#revision_id#">Link</a><br/>
					    <span class="tinytext">
					    	<cfif #approved# EQ "-1">
								rejected
							<cfelseif #approved# EQ "0">
								pending
							<cfelseif #approved# EQ "1">
								approved
							</cfif></span></td>
					<td>#title# <br/>
					    <span class="tinytext">#getFormattedParentList(category_id,allCats)#</span></td>
					<td>#getRecentRevisions.username#</td>
					<td class="tinytext">#dateFormat(revision_date,  "MMM d, yyyy")# 
						#timeFormat(revision_date, "h:mm tt")#</td>
				</tr>	
			</cfoutput>	
		</cfloop>
	</table>

</div>

<cfmodule template="#application.appPath#/footer.cfm" title="Article Editor">