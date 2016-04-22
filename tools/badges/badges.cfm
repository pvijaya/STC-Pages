<cfmodule template="#application.appPath#/header.cfm" title='Achievement Badges' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
<!--- cfparams --->
<cfparam name="instanceId" type="integer" default="#Session.primary_instance#">

<!---now find the details of the current instance based on instanceId--->
<cfset myInstance = getInstanceById(instanceId)>

<!--- Header / Navigation --->
<cfoutput>
	<h1>Achievement Badges (#myInstance.instance_name#)</h1> 
	<cfinclude template="#application.appPath#/tools/badges/secondary-navigation.cfm">
</cfoutput>

<blockquote>
	Achievement = Something accomplished successfully, especially by means of exertion, skill, practice, or perseverance. <br/><br/>
	Our TCC Achievement Badge System is a program founded with a gaming premise.  It allows staff to have more control over their own merit recognition.  
	Each badge has its own individual requirements and staff monitor their progress.  
	When requirements are met, staff should request the earned Achievement Badge from their mentor.  
	Achievement Badges are high profile recognition, as they are visible to all staff on TETRA, by scrolling over active usernames.  
	You can also search on the Achievement Badge entry page by consultant or badge.  It's fun and competitive.  Good Luck earning your Achievement Badges!
</blockquote>

<br/>

<!--- Fetch the badges corresponding to the user's primary instance. --->
<cfquery datasource="#application.applicationDataSource#" name="getBadges">
	SELECT c.name, b.badge_name, b.description, b.image_url, b.assigned_by, b.category_order
	FROM tbl_badges b
	INNER JOIN tbl_badges_categories_match m ON m.badge_id = b.badge_id
	INNER JOIN tbl_badges_categories c ON c.category_id = m.category_id
	WHERE b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
	AND b.active = 1
	GROUP BY c.name, b.badge_name, b.badge_id, b.image_url, b.description, b.assigned_by, b.category_order
	ORDER BY c.name, b.category_order
</cfquery>

<!--- Draw the results from getBadges. --->
<cfoutput query="getBadges" group="name">
	<h2 style="border-bottom:1px solid ##ccc;">#getBadges.name#</h2>
	<cfoutput>
		<div class="block-card" style="padding:5px;margin:5px;overflow:auto;display:inline-block;vertical-align:top;">
		<img src="#image_url#" style="width:100px;float:left;vertical-align:top;">
			<div style="width:200px;display:inline-block;padding-left:5px;vertical-align:top;" />			
				<strong>#badge_name#</strong><br/><hr/>
				#description# <br/>
				Awarded By: #assigned_by#
			</div>
		</div>
	</cfoutput>
</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>