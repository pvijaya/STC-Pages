<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">
<cfinclude template="chat_functions.cfm">

<cfparam name="instanceSelected" type="integer" default="1">

<cfset chatDir = "\\bl-uits-slwc1\pie$\Development\uploads\hash-#instanceSelected#.txt"><!---due to file permission issues use the old chat's hash.txt--->
<!---cfset chatDir = expandPath(chatDir)--->

<cfif isDefined('url.msgid')>
	<cfscript>hideMessage(url.msgid);</cfscript>
<cfelseif isDefined('url.hideall')>
	<cfscript>hideAllMessages();</cfscript>
</cfif>

<cfset random = Rand() * 1000000000000>

<cflock name="iubHash" throwontimeout="false" timeout="20" type="exclusive">
	<cffile action="write" file="#chatdir#" output="#random#">
</cflock>

<cflocation url="#application.appPath#/index.cfm" addToken="no">