<cfmodule template="#application.appPath#/header.cfm">

<!---mark the user as logged out in the database for this session.--->
<cfif isDefined("session.token_uuid")>
	<cfquery datasource="#application.applicationDataSource#" name="logoutQuery">
		UPDATE tbl_authentication_log
		SET logged_out = GETDATE()
		WHERE token_uuid = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.token_uuid#">
		AND username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">
	</cfquery>
</cfif>

<cflock timeout="30" scope="Session" type="Exclusive">
        <cfset StructClear(Session)>
</cflock>

<center>
	<br/><br/>
	<p>You have been <strong>logged out</strong> of the TCC Internal Pages.  You may <strong>log back in <a href="index.cfm">here</a></strong>.</p>
	<p>You are still logged in to the Central Authentication Service (CAS).</p>
	<br/><br/>
	<p>	You may completely logout using the following link:</p>
	<br /> 
	<a href="https://cas.iu.edu/cas/logout"><br/><img alt="Logout of CAS" src="https://onestart.iu.edu/my2-prd/images/cas-buttons-logout.gif"></a>
	<br/><br/><br/><br/>
</center>
<cfinclude template="footer.cfm">
