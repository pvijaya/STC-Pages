<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfset x = structNew()>
<cfset x['total'] = chkTotalCount()>
<cfset x['personal'] = chkMyCount()>
<cfoutput>#SerializeJSON(x)#</cfoutput>

<cffunction name="chkTotalCount">

   <cfquery datasource="#application.applicationDataSource#" name="getContacts">
    	SELECT COUNT(DISTINCT c.contact_id) AS totalcontacts
			FROM tbl_contacts c
			INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
			WHERE c.instance_id=<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
			AND created_ts >'2015-12-11'
			<!---AND c.created_ts >= CAST(CURRENT_TIMESTAMP AS DATE)
			AND c.created_ts < DATEADD(DD, 1, CAST(CURRENT_TIMESTAMP AS DATE))--->

   </cfquery>

    <cfreturn getContacts.totalcontacts>
 </cffunction>


<cffunction name="chkMyCount">

   <cfquery datasource="#application.applicationDataSource#" name="getContacts">
    	SELECT COUNT(DISTINCT c.contact_id) AS eachcontacts
			FROM tbl_contacts c
			INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
			WHERE c.instance_id=<cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
			AND user_id=<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			AND created_ts >'2015-12-11'
			<!---AND c.created_ts >= CAST(CURRENT_TIMESTAMP AS DATE)
			AND c.created_ts < DATEADD(DD, 1, CAST(CURRENT_TIMESTAMP AS DATE))--->

   </cfquery>

    <cfreturn getContacts.eachcontacts>
 </cffunction>






