<cfmodule template="#application.appPath#/header.cfm" title='Routes'>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Consultant">

<h1>Routes & Sites</h1>

<!---some custom styling--->
<style type="text/css">
	div.route {
		width: 40%;
		display: inline-block;
		vertical-align: text-top;
		margin: 0.5em;
	}
</style>

<!---fetch all the Instances/Sites/Routes the user can view--->
<cfquery datasource="#application.applicationDataSource#" name="getRoutesSites">
	SELECT s.site_id, s.instance_id, i.instance_name, s.site_name, s.site_long_name,
		r.route_id,
		CASE 
			WHEN r.route_name IS NULL THEN 'Ungrouped Sites'
			ELSE r.route_name
		END AS route_name,
		CASE
			WHEN r.sort_order IS NULL THEN 999999999999
			ELSE r.sort_order
		END AS sort_order
	FROM vi_sites s
	INNER JOIN tbl_instances i ON i.instance_id = s.instance_id
	LEFT OUTER JOIN vi_routes_sites rs
		ON rs.instance_id = s.instance_id
		AND rs.site_id = s.site_id
	LEFT OUTER JOIN vi_routes r 
		ON r.instance_id = rs.instance_id
		AND r.route_id = rs.route_id
	WHERE s.retired = 0
	AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
	ORDER BY i.instance_name ASC, sort_order, route_name, s.site_long_name, s.site_name
</cfquery>


<!---find and draw our routes--->
<cfquery dbtype="query" name="getInstances">
	SELECT DISTINCT instance_id, instance_name
	FROM getRoutesSites
	ORDER BY instance_name
</cfquery>

<cfloop query="getInstances">
	<h2><cfoutput>#instance_name#</cfoutput></h2>
	
	<!---now fetch the sites/routes for this instance--->
	<cfquery dbtype="query" name="getInstanceRoutesSites">
		SELECT site_id, site_name, site_long_name, route_id, route_name
		FROM getRoutesSites
		WHERE instance_id = #instance_id#
		ORDER BY sort_order, route_name, site_long_name, site_name
	</cfquery>
	
	<cfoutput query="getInstanceRoutesSites" group="route_id">
		<div class="shadow-border route">
			<div class="heading">#route_name#</div>
			
			<ul>
			<cfoutput>
				<li>#site_long_name#(#site_name#)</li>
			</cfoutput>
			</ul>
		</div>
	</cfoutput>
</cfloop>

<cfmodule template="#application.appPath#/footer.cfm">