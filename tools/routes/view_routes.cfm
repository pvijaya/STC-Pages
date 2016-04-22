<cfmodule template="#application.appPath#/header.cfm" title="Routes"> 
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="frmRouteId" type="string" default="i0r0"> <!--- in the form of i1r2 --->

<cfset myInstance = getInstanceById(session.primary_instance)>

<cfif session.primary_instance GT 0>
	<cfoutput><h1>#myInstance.instance_mask# Routes</h1></cfoutput>
<cfelse>
	<h1>Routes</h1>
</cfif>

<cfset routeStruct = parseRoute(frmRouteId)>
<cfset instanceId = routeStruct.instance>
<cfset routeId = routeStruct.route>

<!--- STYLE --->
<style type="text/css">

	fieldset {
		margin-top:2em;
	}
	
	table {
		display:inline-block;
		vertical-align:top;
	}

</style>

<!--- if the user currently has a shift on a route, select that one by default --->
<cfif instanceId eq 0 OR routeId eq 0>

	<!--- fetch the rich info for the instances that the user has access to, --->
	<!--- in particular we need the instance_id and datasource to pull info from the correct PIE. --->
	<!--- use the primary instance only to coincide with the rest of tetra --->
	<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
		SELECT i.instance_id, i.instance_name, i.instance_mask, i.datasource
		FROM tbl_instances i
		WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#"> 
	</cfquery>
	
	<!--- 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask) --->
	
	<cfloop query="getUserInstances">
		<!--- reach into this instance's PIE and look for a current shift for our user.  --->
		<!--- Specifically a shift that has a route, all others will be ignored. --->
		<cfquery datasource="#application.applicationDataSource#" name="getShift">
			SELECT TOP 1 sb.site_id, si.site_name, r.route_id, r.retired
			FROM [#datasource#].dbo.shift_blocks sb
			/*this could restrict us to folks who are currently checked in.
			INNER JOIN tbl_checkins ci ON ci.checkin_id = sb.checkin_id
			*/
			INNER JOIN [#datasource#].dbo.tbl_consultants c ON c.ssn = sb.ssn
			INNER JOIN [#datasource#].dbo.tbl_sites si ON si.site_id = sb.site_id
			INNER JOIN [#datasource#].dbo.tbl_routes r ON r.mentor_site_id = sb.site_id
			WHERE LOWER(c.username) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">)
			AND GETDATE() BETWEEN sb.shift_time AND DATEADD(hour, 1, sb.shift_time)
		</cfquery>
		
		<cfloop query="getShift">
			<!---we've hit a shift on a route, set the global values and bust out of these loops.--->
			<cfset instanceId = getUserInstances.instance_id>
			<cfif not retired><!---don't try to work with sites on retired routes--->
				<cfset routeId = route_id>
			<cfelse>
				<cfset routeId = 0>
			</cfif>
		</cfloop>
		
		<cfif instanceId neq 0 AND routeId neq 0>
			<!---we've got legit values, break out of the loop.--->
			<cfbreak>	
		</cfif>
		
	</cfloop>	
</cfif>

<!--- draw route select --->

<cfquery datasource="#application.applicationDataSource#" name="getRoutes">
	SELECT i.instance_id, i.instance_name, i.datasource, r.route_id, r.route_name, r.color, r.sort_order
	FROM vi_routes r
	INNER JOIN tbl_instances i ON i.instance_id = r.instance_id
	/*limit to instances the user has masks to view.*/
	WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#"> 	
		  AND r.access_level >= 3
	ORDER BY i.instance_name, r.sort_order
</cfquery>

<!--- if at this point we still don't have a route for our user default to the first one available --->
<!--- if user is IUB admin AND in IUB instance, default to Supervisor Route --->
<cfif instanceId eq 0 AND routeId eq 0 AND hasMasks('ADMIN') AND hasMasks('IUB')
	  AND session.primary_instance eq 1>
		<cfset instanceId = 1>
		<cfset routeId = 7>
<cfelseif instanceId eq 0 AND routeId eq 0>
	<cfloop query="getRoutes">
		<cfset instanceId = instance_id>
		<cfset routeId = route_id>
		<cfbreak> <!---leave the loop, we're done.--->
	</cfloop>
</cfif>

<form>
	<label>Select a Route:
	<select  name="frmRouteId">
		<cfoutput query="getRoutes" group="instance_id">
			<optgroup label="#htmlEditFormat(instance_name)#">
				<cfoutput>
					<option value="i#instance_id#r#route_id#" style="color: #color#;" 
						<cfif instanceId eq instance_id AND routeId eq route_id>selected="selected"</cfif>>
							#route_name#
					</option>
				</cfoutput>
			</optgroup>
		</cfoutput>
	</select>
	</label>
	<input type="submit"  value="Go">
</form>

<cfquery datasource="#application.applicationDataSource#" name="getRouteSites">
	SELECT i.instance_id, i.instance_name, r.route_id, r.route_name, m.site_name AS mentor_site, r.color, s.site_id, s.site_name, s.site_long_name, s.staffed
	FROM tbl_instances i
	INNER JOIN vi_routes r 
		ON r.instance_id = i.instance_id
	INNER JOIN vi_routes_sites rs
		ON rs.instance_id = r.instance_id
		AND rs.route_id = r.route_id
	INNER JOIN vi_sites s
		ON s.instance_id = rs.instance_id
		AND s.site_id = rs.site_id
	/*now find the route's mentor*/
	LEFT OUTER JOIN vi_sites m
		ON m.instance_id = r.instance_id
		AND m.site_id = r.mentor_site_id
	
	WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		  AND r.route_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#routeId#">
		  AND s.retired = 0
		  AND r.access_level = 3
	ORDER BY i.instance_name, r.sort_order, r.route_name, r.route_id, s.staffed DESC
</cfquery>

<cfoutput query="getRouteSites" group="instance_id">
	
	<cfoutput group="route_id">
	
		<h2 style="margin-bottom:0.5em;">#route_name#</h2>
			
		<div class="shadow-border" style="padding:5px;">	
			
			<a href="#application.appPath#/tools/shift-report/shift-report.cfm?frmRouteId=i#instance_id#r#route_id#">
				View Shift Report
			</a>
			
			<br/>
			
			Supervisor: <strong>#mentor_site#</strong>
			
			<br/><br/>
			
			<cfoutput group="staffed">
			
				<table class="stripe">
					<cfif staffed>
						<tr class="titlerow"><td colspan="2">Staffed Labs</td></tr>
					<cfelse>
						<tr class="titlerow"><td colspan="2">Unstaffed Labs</td></tr>
					</cfif>
					
					<cfoutput>
						<tr><td>#site_long_name#</td><td>#site_name#</td></tr>
					</cfoutput>
				</table>
				
			</cfoutput>
			
		</div>
		
	</cfoutput>
</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm">