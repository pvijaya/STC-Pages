<cfmodule template="#application.appPath#/header.cfm" title="Sort Articles">
<!---notice we aren't checking access here, we want to base what is displayed based on whatever the viewer is authorized to view.--->

<cfsetting showdebugoutput="true">

<cfparam name="frmCatId" type="integer" default="0"><!---the category_id we want to have open upon initially viewing this page.--->

<h1>Sort Articles Selector</h1>
<br/><br/>
<cfmodule template="mod_browse.cfm" width="100%" catId="0" sortable="1" hideOptions="1">


<cfmodule template="#application.appPath#/footer.cfm">