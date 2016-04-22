<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfif not hasMasks("consultant")>
	<cfoutput>[]</cfoutput>
	<cfabort>
</cfif>

<cfparam name="frmContactId" type="integer" default="0"> <!--- a list of username strings --->

<cfset response = StructNew()>

<cftry>

	<cfquery datasource="#application.applicationDataSource#" name="getAllLabs">
		SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name
		FROM vi_labs_sites ls /*only labs that we have paired to STC sites*/
		INNER JOIN vi_labs l
			ON l.instance_id = ls.instance_id
			AND l.lab_id = ls.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = ls.instance_id
		WHERE l.active = 1
		<cfif session.primary_instance NEQ 0>
			AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		<cfelse>
			AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		</cfif>
		ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
	</cfquery>
	
	<cfset labArray = ArrayNew(1)>
	<cfloop query="getAllLabs">
		<cfset labStruct = StructNew()>
		<cfset labStruct['labId'] = "i#instance_id#l#lab_id#">
		<cfset labStruct['labName'] = lab_name>
		<cfset labStruct['buildingName'] = building_name>
		<cfset arrayAppend(labArray, labStruct)>
	</cfloop>
	
	<cfset response['message'] = "<p class='ok'>Labs found.</p>">
	<cfset response['labArray'] = #labArray#>
	
	<cfcatch>
		
		<cfset response['message'] = "<p class='alert'>#cfcatch.message# - #cfcatch.detail#</p>">
		<cfset response['labArray'] = ArrayNeq(1)>
		
	</cfcatch>
	
</cftry>

<cfset labResponse = serializeJSON(response)>
<cfoutput>#labResponse#</cfoutput>