<cfmodule template="#application.appPath#/header.cfm" title='Customer Contacts Resources and Reporting' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">

<h1>Customer Contacts Resources and Reporting</h1>

<cfoutput>
<h2>Resources</h2>
	<ul>
		<li>
			<a href="#application.appPath#/documents/article.cfm?articleId=608">Customer Contacts Defined</a> - Details about what constitutes a content, and expanded descriptions of contact categories.
		</li>
		<li>
			
			<a href="#application.appPath#/documents/article.cfm?articleId=8783">Customer Contacts - How To</a> - Information for getting the most out of the Customer Contacts system.
		</li>
	</ul>

<h2>Reports</h2>
	<ul>
		<li>
			<a href="#application.appPath#/tools/contacts/search.cfm">Search</a> - Find and view Customer Contacts based on several criteria.
		</li>
		<li>
			<a href="#application.appPath#/tools/contacts/report-sunburst.cfm">Sunburst Graph</a> - Concentric pie charts showing the volume of contacts by category or lab.
		</li>
		<li>
			<a href="#application.appPath#/tools/contacts/report-plot.cfm">Plot Graph</a> - Line graphs showing the number of contacts and the time spent on them over a time span.
		</li>
		
		<!---we don't want other consultants checking up on eachother.--->
		<cfif hasMasks("CS")>
			<li>
				<a href="#application.appPath#/tools/contacts/report-consultants.cfm">Consultant Statistics</a> - Shows the number of contacts vs. hours worked for consultants who have entered any Customer Contacts over a time span.
			</li>
		</cfif>
		
		<li>
			<a href="#application.appPath#/tools/contacts/report-force.cfm">Contact Relationship Graph</a> - Shows a given Customer Contact's relationship to other contacts.
		</li>
		
		
	</ul>
	
	<cfif hasMasks("Admin")>
		<h2>Tools</h2>
		<ul>
			<a href="#application.appPath#/tools/contacts/manage-categories.cfm">Manage Categories</a> - Add, reorganize, and retire the categories available for Customer Contacts.
		</ul>
	</cfif>
</cfoutput>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>