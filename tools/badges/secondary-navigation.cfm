	<a href="badges.cfm">List of Badges</a> |
	<a href="search-badges.cfm">Search Assigned Badges</a> |
	<a href="assign-badges.cfm"> Assign Badges</a>
	<cfif Session.primary_instance EQ 2>
		| <a href="<cfoutput>#application.appPath#</cfoutput>/documents/article.cfm?articleId=8785">Documentation</a> 
	<cfelse>
		| <a href="<cfoutput>#application.appPath#</cfoutput>/documents/article.cfm?articleId=8508">Documentation</a> 
	</cfif>
	<cfif hasMasks('Badge Editor')> 
		| <a href="badge-editor.cfm">Badge Editor</a> 
		| <a href="badge-category-editor.cfm">Badge Category Editor</a> 
	</cfif>
	
	<br/><br/>