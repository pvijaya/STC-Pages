<!---if common functions aren't available we need to include them.--->

<cffunction name="hideMessage">
	<cfargument name="message_id">
	<cfquery name="hideMessage" datasource="#application.applicationDatasource#">
		UPDATE		tbl_chat_messages
		SET			Visible = <cfqueryparam value="0" cfsqltype="cf_sql_varchar">
		WHERE		Message_ID = <cfqueryparam value="#message_id#" cfsqltype="cf_sql_integer">
	</cfquery>
</cffunction>

<cffunction name="hideAllMessages">
	<cfset var ContentEmailReport = "">
	<cfset var messageList = "">
	<cfset var hideMessage = "">

	<cfquery name="ContentEmailReport" datasource="#application.applicationDatasource#">
		SELECT TOP (250)	m.Date_Time, u.username, u.picture_source, u.preferred_name, m.Message, m.Message_ID
		FROM 				tbl_chat_messages m, tbl_users u
		WHERE 				m.user_id = u.user_id
			AND				DATEDIFF("hh", m.Date_Time, GETDATE()) <= 1
		ORDER BY 			m.Message_ID ASC
	</cfquery>

	<cfloop query="contentEmailReport">
		<cfset messageList = ListAppend(messageList, message_id)>
	</cfloop>

	<cfmail to="tccwm@iu.edu" from="tccwm@iu.edu" subject="Cleared Chat History" type="html">
		<p>The chat was cleared at #TimeFormat(Now())# on #DateFormat(Now())# by #username#.  The proceeding hour of chat activity is included.</p>

		<p>If you are reading this message with Outlook and it appears distorted, it is because Outlook auto-removed some of the line breaks.  There should be an option at the top of this message window to restore them.</p>
		---------------------------------------------------
		<ul>
		<cfloop query="ContentEmailReport">
			<li>[#Message_ID#] #TimeFormat(Date_Time)# - #username#: #Message#</li>
		</cfloop>
		</ul>
		---------------------------------------------------<br/>
		End of report.
	</cfmail>

	<cfquery name="hideMessage" datasource="#application.applicationDatasource#">
		UPDATE		tbl_chat_messages
		SET			Visible = <cfqueryparam value="0" cfsqltype="cf_sql_varchar">
		WHERE		message_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#messageList#" list="true">)
	</cfquery>
</cffunction>

<!--- Function for parsing links only STARTS --->
<cffunction name="parseLinks">
	<cfargument name="ModMessage">
	<cfset ModMessage=REReplaceNoCase(#ModMessage#,
		"(https?://.+?)(\s|$)", "(<a href=""\1"" title=""\1"" target=""_blank"">link</a>)\2", 'all')>
	<cfreturn ModMessage>
</cffunction>
<!--- Function for parsing links only ENDS --->

<cffunction name="convertPrefixes">
	<cfargument name="active_access">
	<cfscript>
		switch(active_access){
			case "11":
				Prefix="HM: ";
				break;
			case "12":
				Prefix="COM: ";
				break;
			case "13":
				Prefix="COS: ";
				break;
			default:
				Prefix="";
				break;
		}
	</cfscript>
</cffunction>



<cffunction name="convertPRLinks">
	<cfargument name="ModMessage">
	<cfset ModMessage=REReplaceNoCase(#ModMessage#,
		"PR##(\d+?)(\b)", "PR##<a href=""https://stcweb.stc.indiana.edu/framework/apps/Problem/ViewProblemTicket.cfm?TicketID=\1"" target=""_blank"">\1</a>\2", 'all')>
	<cfreturn ModMessage>
</cffunction>

<cffunction name="filterProfanity">
	<cfargument name="ModMessage">
	<cfset ModMessage=REReplaceNoCase(#ModMessage#,
	  "(^|\s)(?:hells|hellish|hell|bastards|bastard|bitches|bitch|damnable|damn|fucking|fuckers|fucker|motherfucker|motherfuckers|fuck|phuck|phuk|crap|craptastic|crapola|asshole|ass|shit|shat|pissed|cunt|cunts|twat|puss|pussy|dick|dickhead|dickheads|orgy|fag|faggot|faggots|queer|queers|muthafuckas|boobs|boobies|tits|tit)(\s|\W|$)",
	  "\1!##$*\2", 'all')>
	<cfreturn ModMessage>
</cffunction>

<cffunction name="getWebPath" access="public" output="false" returntype="string" hint="Gets the absolute path to the current web folder.">
   <cfargument name="url" required="false" default="#getPageContext().getRequest().getRequestURI()#" hint="Defaults to the current path_info" />
   <cfargument name="ext" required="false" default="\.(cfml?.*|html?.*|[^.]+)" hint="Define the regex to find the extension. The default will work in most cases, unless you have really funky urls like: /folder/file.cfm/extra.path/info" />
   <!---// trim the path to be safe //--->
   <cfset var sPath = trim(arguments.url) />
   <!---// find the where the filename starts (should be the last wherever the last period (".") is) //--->
   <cfset var sEndDir = reFind("/[^/]+#arguments.ext#$", sPath) />
   <cfreturn left(sPath, sEndDir) />
</cffunction>


<cffunction name="chatIconReplace">
	<cfargument name="ModMessage">

	<cfset var GetChatReplacements = "">
	<cfset var MatchList = "">
	<cfset var RepList = "">
	<!--- Get MatchList & RepList when this file is included, not every IconReplace() call. --->
	<cfquery name="GetChatReplacements" datasource="#application.applicationDatasource#">
		SELECT 		match, replacement
		FROM 		tbl_chat_Replace r
		ORDER BY	match
	</cfquery>

	<cfset MatchList = ValueList(GetChatReplacements.Match)>
	<cfset RepList = ValueList(GetChatReplacements.Replacement)>

	<!---cfif showIcons---><!---show icons is a user's preference--->
		<cfset ModMessage=ReplaceList(ModMessage, MatchList, RepList)>
	<!---/cfif--->
	<cfreturn ModMessage>
</cffunction>

<!--- Get MatchUsers & RepUsers when this file is included, not every IconReplace() call. --->
<cfquery name="GetChatReplacements2" datasource="#application.applicationDatasource#">
	SELECT Username,
	REPLACE(preferred_name, '"x', '" alt="who" />') AS preferred_name
	FROM 		tbl_users
	ORDER BY	Username
</cfquery>
<cfscript>
	MatchUser = ValueList(GetChatReplacements2.Username);
	RepUser = ValueList(GetChatReplacements2.preferred_name);
</cfscript>
<cffunction name="chatUsernameRemove">
	<cfargument name="ModMessage">
	<cfif Find(":", #ModMessage#) AND showUsername>
		<cfset ModMessage=ReplaceList(ModMessage, MatchUser, RepUser)>
	</cfif>
	<cfreturn ModMessage>
</cffunction>


<!--- Get current shift for a username and return a span tag with that info --->
<cffunction name="currentSSShift">
	<cfargument name="sitename">

	<cfswitch expression="#sitename#">
		<!--- STC IUB shifts --->
		<cfcase value="SHIFT SUP">
			<cfset shiftSpan='SS'>
		</cfcase>
		<cfcase value="LEAD_WEST">
			<cfset shiftSpan='W'>
		</cfcase>
		<cfcase value="LD_SOUTH">
			<cfset shiftSpan='S'>
		</cfcase>
		<cfcase value="LEAD_NORTH">
			<cfset shiftSpan='N'>
		</cfcase>
		<cfcase value="LEAD_EAST">
			<cfset shiftSpan='E'>
		</cfcase>

		<!--- STC IUPUI shifts --->
		<cfcase value="CS-CW">
			<cfset shiftSpan='CW'>
		</cfcase>
		<cfcase value="LEAD_CW">
			<cfset shiftSpan='LEAD'>
		</cfcase>
		<cfcase value="CSS-GY">
			<cfset shiftSpan='GY'>
		</cfcase>
		<cfcase value="CS-HUB">
			<cfset shiftSpan='HUB'>
		</cfcase>

		<!--- Anything else, show nothing --->
		<cfdefaultcase>
			<cfset shiftSpan=''>
		</cfdefaultcase>
	</cfswitch>
	<cfreturn shiftSpan>
</cffunction>
