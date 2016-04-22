<!--- This is a module used to ensure the user has a valid instance, and force him or her to choose one if not. --->

<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfparam name="attributes.referrer" type="string" default="#cgi.SCRIPT_NAME#">

<cfset valid = 1>

<!--- check the current primary instance for validity --->
<!--- the primary instance is invalid if it is zero, or if the user does not possess the necessary masks --->
<cfif Session.primary_instance EQ 0>
	<cfset valid = 0>
<cfelse>
	<cfquery datasource="#application.applicationDataSource#" name="checkInstance">
		SELECT i.instance_mask
		FROM tbl_instances i
		WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	</cfquery>
	<cfif NOT hasMasks(#checkInstance.instance_mask#)>
		<cfset valid = 0>
	</cfif>
</cfif>

<!--- if the primary instance is invalid, pop the user to the selection page--->
<cfif valid EQ 0>

	<!---before we send them cache the form and url structs,
	  We also have to prevent form elements from one page leaking
	  into another, so constrain by using cgi.CF_TEMPLATE_PATH
	   --->
	<cflock scope="Session" timeout="30" type="Exclusive">
		<cfif not isDefined("session.temp_path")><cfset session.temp_path = cgi.CF_TEMPLATE_PATH></cfif>

		<cfif not isDefined("session.temp_form") OR not isDefined("session.temp_url") OR session.temp_path neq cgi.script_name>
			<cfset session.temp_form = structNew()>
			<cfset session.temp_url = structNew()>
			<cfset session.temp_path = cgi.script_name>
		</cfif>

		<cfscript>
			structAppend(session.temp_form, form);
			structAppend(session.temp_url, url);
		</cfscript>
	</cflock>

	<cflocation url="#application.apppath#/tools/instance/instance_selector.cfm?referrer=#urlEncodedFormat(attributes.referrer)#" addtoken="false">

</cfif>