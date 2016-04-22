<cfmodule template="#application.appPath#/header.cfm" title='Past Winners'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include external functions --->
<cfinclude template="#application.appPath#/tools/photoshop-contest/psc-functions.cfm">
<cfinclude template="#application.appPath#/tools/filemanager/file_functions.cfm">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- fetch the active contest for this instance, if there is one --->
<cfset getContest = getActiveContest()>

<cfset folderId = 0>

<!--- get the base info for our photoshop contests --->
<cfset contestPath = "/Photoshop Contest/#myInstance.instance_name#">
<cfset contestFolderId = pathToFolderId(contestPath)>

<!--- Header / Navigation --->
<!--- block off the source images and gallery links if there is not an active contest --->
<h1><cfoutput>Photoshop Contest #myInstance.instance_mask#</cfoutput></h1>
<cfif getContest.recordCount GT 0>
	<cfset drawNavigation()>
<cfelse>
	<cfset drawNavigationClosed()>
</cfif>

<!--- query up the winners and send them to the gallery module --->
<h2>Past Winners</h2>

<cfquery datasource="#application.applicationDataSource#" name="getImages">
	SELECT pc.contest_name, pe.file_id, pw.runner_up
	FROM tbl_psc_winners pw
	INNER JOIN tbl_psc_entries pe ON pe.entry_id = pw.entry_id
	INNER JOIN tbl_psc_contests pc ON pc.contest_id = pw.contest_id
	WHERE pc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	ORDER BY pc.contest_id ASC, pw.runner_up ASC
</cfquery>

<cfmodule template="#application.appPath#/tools/photoshop-contest/mod-gallery.cfm"
		  images="#getImages#" psc="1" psc_winners="1">

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>