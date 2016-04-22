<cfmodule template="#application.appPath#/header.cfm" title="Retired Articles">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">

<h1>Retired Articles</h1>

<cfparam name="frmCatId" type="integer" default="0"><!---the category_id we want to have open upon initially viewing this page.--->

<cfmodule template="mod_browse.cfm" width="100%" catId="#frmCatId#" sortable="1" useRetired="1">

<cfmodule template="#application.appPath#/footer.cfm">