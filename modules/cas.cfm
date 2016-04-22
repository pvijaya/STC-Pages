<!--- // CAS Login

// ColdFusion MX 6.1 code that uses CAS 2.0

// Christian Stuck
// stuckc@rider.edu
// Westminster Choir College
// Princeton, New Jersey

Modified by JKF to test an alternative CAS method.
--->
	<cflock scope="Session" type="ReadOnly" timeout="30" throwontimeout="no">
		<cfset Username=Iif(IsDefined("Session.CAS_Username"),"Session.CAS_Username",DE(""))>
		<cfset MM_UserAuthorization=Iif(IsDefined("Session.MM_UserAuthorization"),"Session.MM_UserAuthorization",DE(""))>
	</cflock>

	<!--- // Insert name of CAS Server at your location --->

	<cfset CAS_Server = "https://cas.iu.edu/cas/"><!---current production--->
	<!---<cfset CAS_Server = "https://cas-reg.uits.iu.edu/cas/">regression testing--->
	<!--- // Insert public name of IIS Server hosting this script
	// Note: CGI.HTTP_HOST or anything based on
	// the HTTP "Host" header should NOT be used; this header is supplied by
	// the client and isn't trusted. --->
	<cfset MyServer = "https://piedev.indiana.edu/apps/stcpages/IUB">

	<!--- See if already logged on, if not get their credentials. --->
	<cfif Username EQ "" OR username eq 'unknown'>
		<!--- Check for ticket returned by CAS redirect --->
		<cfset ticket=Iif(IsDefined("URL.casticket"),"URL.casticket",DE(""))>
		<cfif ticket EQ "">
			<!--- No session, no ticket, Redirect to CAS Logon page --->
			<cfset casurl = #CAS_Server# & "login?cassvc=IU&casurl=https://#cgi.SERVER_NAME##cgi.script_name#">

			<!---before we send them cache the form and url structs,
			We also have to prevent form elements from one page leaking
			into another, so constrain by using cgi.CF_TEMPLATE_PATH
			--->
			<cflock scope="Session" timeout="30" type="Exclusive">
				<cfif not isDefined("session.temp_path")><cfset session.temp_path = cgi.CF_TEMPLATE_PATH></cfif>

				<cfif not isDefined("session.temp_form") OR not isDefined("session.temp_url") OR session.temp_path neq cgi.CF_TEMPLATE_PATH>
					<cfset session.temp_form = structNew()>
					<cfset session.temp_url = structNew()>
					<cfset session.temp_path = cgi.CF_TEMPLATE_PATH>
				</cfif>

				<cfscript>
					structAppend(session.temp_form, form);
					structAppend(session.temp_url, url);
				</cfscript>
			</cflock>

			<cflocation url="#casurl#" addtoken="no">
		<cfelse>
			<!--- Back from CAS, validate ticket and get userid --->
			<cfset casurl = #CAS_Server# & "validate?cassvc=IU&casticket=" & #URL.casticket# & "&" & "casurl=https://#cgi.SERVER_NAME##cgi.script_name#">
			<!---http.open("GET",url,false); // HTTP transaction to CAS server    http.send(); --->

			<cfhttp url="#casurl#" method="get"></cfhttp>
			<!---replacing with IU specific verification
			<cfset objXML = xmlParse(cfhttp.filecontent)>
			<cfset SearchResults = XmlSearch(objXML, "cas:serviceResponse/cas:authenticationSuccess/cas:user")>
			<cfif NOT ArrayIsEmpty(SearchResults)>
				<cfset NetId = #SearchResults[1].XmlText#>
			<cfelse>
				<cfset casurl = #CAS_Server# & "login?" & "service=" & #MyServer# & "/psal/casexample.cfm">
				<cflocation url="#casurl#" addtoken="no">
			</cfif>--->

			<cfif Find('yes', #CFHTTP.FileContent#)>
				<!--- CAS authentication validated --->

				<!--- We already know the response contains a yes code, so we need to isolate the username,
					which should be in the second element of the CAS_auth_info array. --->
				<cfset CAS_auth_info = ListToArray(#CFHTTP.FileContent#, "#chr(13)##chr(10)#")>
				<cfset NetId = CAS_auth_info[2]>

				<!---populate form and url structures with what was initially submitted--->
				<cfif (isDefined("session.temp_form") or isDefined("session.temp_url")) AND session.temp_path eq cgi.CF_TEMPLATE_PATH>
					<!---<cfset form = StructAppend(form,session.temp_form)>
					<cfset url = StructAppend(url,session.temp_url)> --->
					<!--- form for new request --->
					<cfset firstPass = 1>
					<cfset newLocation = cgi.script_name>
					<cfloop collection="#session.temp_url#" item="key">
						<cfif firstPass><cfset newLocation = newLocation & "?"><cfelse><cfset newLocation = newLocation & "&"></cfif>
						<cfset newLocation = newLocation & key & "=" & urlEncodedFormat(session.temp_url[key])>
						<cfset firstPass = 0>
					</cfloop>
					<cfoutput>
						<form method="post" action="#newLocation#" id="redirForm">
							<!---now generate a form for and posted items--->
							<cfloop collection="#session.temp_form#" item="key">
								<input type="hidden" name="#htmleditFormat(key)#" value="#htmlEditFormat(session.temp_form[key])#">
							</cfloop>
							You should be automatically redirected to your requested page, but if you are not click this button.<br/>
							<input type="submit" value="Proceed">
						</form>
						<script type="text/javascript">
							//automatically submit the form for the user.
							document.forms["redirForm"].submit();
						</script>
					</cfoutput>

					<!---and deallocate them--->
					<cflock scope="Session" timeout="30" type="Exclusive">
						<cfset session.temp_form = structNew()>
						<cfset session.temp_url = structNew()>
					</cflock>
				<cfelse>
					<!---and deallocate them--->
					<cflock scope="Session" timeout="30" type="Exclusive">
						<cfset session.temp_form = structNew()>
						<cfset session.temp_url = structNew()>
						<cfset session.temp_path = cgi.CF_TEMPLATE_PATH>
					</cflock>
				</cfif>
			<cfelse>
				<!--- Any other response means CAS validation failed.  Do whatever is needed
					to handle the failure.  Keep in mind that url.returnpage should have the
					URL that we should go back to.
				<cfset Session.CAS_Authenticated = 0>
				<cfset casurl = #CAS_Server# & "login?cassvc=IU&casurl=" & #MyServer# & "/psal/casexample.cfm">
			    <cflocation url="#casurl#" addtoken="no"--->
				<cfoutput>There was a problem verifying your identity from CAS.  The CAS Ticket passed by the URL appears to be invalid.<br/></cfoutput>
				<!---blank the temp session variables--->
				<cflock scope="Session" timeout="30" type="Exclusive">
					<cfset session.temp_form = structNew()>
					<cfset session.temp_url = structNew()>
				</cflock>
				<cfabort>
			</cfif>
		</cfif>

		<cfset MM_redirectLoginSuccess="victory.cfm">
		<cfset MM_redirectLoginFailed="fail.cfm">

		<!--- Your SQL Statement to access authorized user table/view --->
		<cfquery  name="MM_rsUser" datasource="#application.applicationdatasource#">
			SELECT TOP 1 	user_id, preferred_Name, Username
			FROM 			tbl_users
			WHERE 			Username = <cfqueryparam value="#netid#" cfsqltype="cf_sql_varchar">
		</cfquery>

		<!--- all authorization is now done by checking masks, so just build a session for them, whether we found them in tbl_users or not. --->
		<cfif MM_rsUser.RecordCount NEQ 0>
			<cfset myUid = trim(#MM_rsUser.user_id#)>
			<cfset myDisplayName = MM_rsUser.preferred_Name>
		<cfelse>
			<cfset myUid = -1>
			<cfset myDisplayName = netid>
		</cfif>

		<cftry>
		<cfset uuid = insert("-", CreateUUID(), 23)><!---ms takes a proprietary uuid format, grr.--->
		<!---record this sign-in attempt--->
		<CFQUERY Name="Authentication" Datasource="#application.applicationDataSource#">
			INSERT		INTO TBL_AUTHENTICATION_LOG (token_uuid, TIMESTAMP, USERNAME, IP_ADDRESS, MESSAGE, DSN, PAGE, AGENT)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#uuid#">,
				'#DateFormat(now(),"yyyy/mm/dd")# #timeFormat(now(), "H:mm:ss.l")#',
				<cfqueryparam value="#netid#" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="#cgi.REMOTE_ADDR#" cfsqltype="cf_sql_varchar">,
				'CAS Login',
				<cfqueryparam value="#left(application.applicationdatasource,9)#" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="#cgi.SCRIPT_NAME#" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="#CGI.USER_AGENT#" cfsqltype="cf_sql_varchar">
				)
		</cfquery>

		<cflock scope="Session" timeout="30" type="Exclusive">
			<cfset Session.CAS_Username = netid>
			<cfset Session.CAS_Uid = myUid>
			<cfset Session.CAS_Display_Name = myDisplayName>
			<cfset Session.token_uuid = uuid><!---stash the token_uuid for AJAX calls to PIE--->
			<!---cfset Session.MM_firstName=MM_rsUser.firstName>
			<cfset Session.MM_lastName=MM_rsUser.lastName>
			<cfset Session.MM_UserAuthorization=""--->
			<cfset Session.primary_instance = 0>
		</cflock>

		<cfif IsDefined("URL.accessdenied") AND true>
			<cfset MM_redirectLoginSuccess=URL.accessdenied>
		</cfif>
		<!--->cflocation url="#MM_redirectLoginSuccess#" addtoken="no"--->
		<cfabort>
		<cfcatch type="Lock">
			<!--- code for handling timeout of cflock --->
			<cfoutput>A problem was encountered setting the session variables.  Exiting<br/></cfoutput>
			<cfabort>
		</cfcatch>
		</cftry>

	</cfif>

	<!---we've been using a variable username here, but we don't want to use it outside of application.cfm--->
	<cfset structDelete(variables, "username")>