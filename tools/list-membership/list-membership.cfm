<cfmodule template="#application.appPath#/header.cfm" title='Mailing List Membership' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#"><!---we need an instance selected, too--->


<cfset sender = 'tccwm@indiana.edu'><!---IU List still thinks of tccwm@indiana.edu, instead of @iu.edu, as the owner of our mailing lists.--->
<cfset list_password = 'ma1l_th1s_$tuff'>

<cfset sympaURL = "https://list.indiana.edu">
<cfif session.primary_instance eq 2>
	<cfset sympaURL = "https://list.iupui.edu">
</cfif>


<h2>Mailing List Membership</h2>

<p>This page pulls the current membership of TCC's mailing lists from <a href="<cfoutput>#htmlEditFormat(sympaURL)#</cfoutput>">IU List</a>.</p>

<!---fetch a cookie from IU List so we can suck out the other lists--->
<cfset sympaCookie = getCookieStruct()>
<cfset sympaCookie = sympaCookie[1]['sympa_session']>


<cfset listsList = "tcc-consultants-l,tcc-cs-l,tcc-techteam-l,tcc-subplea-l,tcc-pr-l">
<cfif session.primary_instance eq 2>
	<cfset listsList = "tcc-consultants-l,tcc-support-l,tcc-subplea-l,tcc-techteam-l">
</cfif>

<cfloop list="#listsList#" index="list">
	<div class="shadow-border" style="min-width:185px;display:inline-block;vertical-align:top;margin:5px;">
	<cfoutput>
		<h3>#list#</h3>
	</cfoutput>
	<cfset mailList = fetchList(list, sympaCookie)>
	<ol>
	<cfoutput query="mailList">
		<li>#username#</li>
	</cfoutput>
	</ol>
	</div>
</cfloop>

<!---for both campuses we get the IU Wide lists.--->
<cfset sympaURL = "https://list.iu.edu">
<!---fetch a cookie from IU List so we can suck out the other lists--->
<cfset sympaCookie = getCookieStruct()>
<cfset sympaCookie = sympaCookie[1]['sympa_session']>

<cfset listsList = "tcc-3dprint-l">
<cfloop list="#listsList#" index="list">
	<div class="shadow-border" style="min-width:185px;display:inline-block;vertical-align:top;margin:5px;">
	<cfoutput>
		<h3>#list#@iu.edu</h3>
	</cfoutput>
	<cfset mailList = fetchList(list, sympaCookie)>
	<ol>
	<cfoutput query="mailList">
		<li>#username#</li>
	</cfoutput>
	</ol>
	</div>
</cfloop>


<cfinclude template="#application.appPath#/footer.cfm">
<!---
<h3>tcc-consultants-l</h3>
<cfset consList = fetchList("tcc-consultants-l", sympaCookie)>
<cfdump var="#consList#">

<h3>tcc-cs-l</h3>
<cfset csList = fetchList("tcc-cs-l", sympaCookie)>
<cfdump var="#csList#">

<h3>tcc-techteam-l</h3>
<cfset techTeamList = fetchList("tcc-techteam-l", sympaCookie)>
<cfdump var="#techTeamList#">

<h3>tcc-subplea-l</h3>
<cfset subPleasList = fetchList("tcc-subplea-l", sympaCookie)>
<cfdump var="#subPleasList#">
--->


<!---talk to IU List.  take a cfhttp response , and return the cookie parsed as a struct.--->
<cffunction name="getCookieStruct">
	<cfset var response = "">
	<cfset var cookieArray = arrayNew(1)>
	<cfset var cookieStruct = structNew()>
	<cfset var myCookie = "">
	<cfset var n = "">
	<cfset var cPart = "">
	<cfset var key = "">
	<cfset var value = "">

	<!---Connect to IU List to get a cookie--->
	<cfhttp method="post" url="#sympaURL#/sympa" redirect="false" result="response"><!---if you follow the redirect it negates our cookie from logging in.--->
		<cfhttpparam type="formfield" name="previous_action" value="">
		<cfhttpparam type="formfield" name="previous_list" value="">
		<cfhttpparam type="formfield" name="referer" value="">
		<cfhttpparam type="formfield" name="list" value="">
		<cfhttpparam type="formfield" name="action" value="login">
		<cfhttpparam type="formfield" name="email" value="#sender#">
		<cfhttpparam type="formfield" name="passwd" value="#list_password#">
		<cfhttpparam type="formfield" name="action_login" value="Login">
	</cfhttp>

	<cfif structKeyExists(response.ResponseHeader, "Set-Cookie")>
		<cfset myCookie = response.ResponseHeader["Set-Cookie"]>

		<!---each item is a list of values--->
		<cfloop list="#myCookie#" delimiters=";" index="cPart">
			<!---cPart is then a key=value pair--->
			<cfset key = listFirst(cPart, "=")>
			<cfset value = listLast(cPart, "=")>

			<cfset cookieStruct[key] = value>
		</cfloop>

		<!---add the struct to our array of cookies--->
		<cfset arrayAppend(cookieArray, cookieStruct)>

	</cfif>

	<cfreturn cookieArray>
</cffunction>

<cffunction name="fetchList">
	<cfargument name="listName" type="string" required="true">
	<cfargument name="cookie" type="string" required="true">

	<cfset var response = "">
	<cfset var item = "">
	<cfset var usersQuery = queryNew("username","varchar")>

	<cfhttp url="#sympaURL#/sympa/dump/#urlEncodedFormat(listName)#/light" method="get" result="response">
		<cfhttpparam type="cookie" name="sympa_session" value="#cookie#">
	</cfhttp>


	<cfloop list="#response.filecontent#" delimiters="#chr(10)#" index="item">
		<cfif not isValid("email", item)>
			<cfthrow type="custom" message="Invalid Email Found" detail="Failure encountered when parsing IU List's #listName#.">
		</cfif>

		<!---at this point we are looking at a valid email, pare it down to just the username and add it to usersQuery--->
		<cfset queryAddRow(usersQuery)>
		<cfset querySetCell(usersQuery, "username", left(item, find("@", item)-1))>
	</cfloop>

	<cfreturn usersQuery>
</cffunction>