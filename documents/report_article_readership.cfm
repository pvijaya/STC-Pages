<cfmodule template="#application.appPath#/header.cfm" title="Readership Report">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="CS">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="frmArticleId" type="integer" default="0">

<!--- set instance --->
<cfset myInstance = getInstanceById(Session.primary_instance)>

<h1>Article Readership Report</h1>

<cfif frmArticleId GT 0>	
	<cfmodule template="mod_article_readership.cfm" articleId="#frmArticleId#">
</cfif>

<cfmodule template="#application.appPath#/footer.cfm">