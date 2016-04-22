<cfmodule template="#application.appPath#/header.cfm" title="Inventory Menu" drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<h1>Inventory Menu</h1>

<p>
	In Tetra, Inventory covers all sorts of "items."  Every "item" has a "type", and types can belong to other types. <br/>
	An example would be an 8000 series roller.  The type would be "roller" and the item would be "8000 series". <br/>
	In general, items with the same type are grouped together.
</p>

<h2>Management</h2>
<ul>
	<li><a href="manage-types.cfm">Type Manager</a> - Add/Edit the Types that apply to inventory items.</li>
	<li><a href="manage-items.cfm">Item Manager</a> - Add/Edit/Retire inventory items.</li>
	<li><a href="manage-site-items.cfm">Lab Manager</a> - Pair items with labs, set reorder levels, and email settings.</li>
	<li><a href="manage-emails.cfm">Email Manager</a> - Set recipients and title of the various emails sent by inventory activity.</li>
</ul>

<h2>Reporting</h2>
<ul>
	<li><a href="report_incomplete.cfm">Labs Without Supply Reports for Today</a></li>
	<li><a href="report_summary.cfm">Levels Summary</a></li>
	<li><a href="report_site_graph.cfm">Levels Graph</a></li>
	<li><a href="report_thresholds.cfm">Threshold Levels</a></li>
</ul>
<cfmodule template="#application.appPath#/footer.cfm">