<cfsetting showdebugoutput="false" enableCFoutputOnly="yes">
<cfcontent type="text/css">
<cfoutput>
	<!---TODO probably want to change this to more often--->
	<cfcache action="cache" name="cssCache" timespan="#createTimeSpan(0,0,0,5)#" stripWhiteSpace ="true"> 
		<cfsavecontent variable="cssText">
			<!---Include CSS files here--->
			<cfinclude template="#application.appPath#/css/main.cfm">
		</cfsavecontent>
		<!---We only have the style tags in for the editors--->
		<cfset cssText = Replace(cssText, "<style>", "")>
		<cfset cssText = Replace(cssText, "</style>", "")>
		<cfoutput>#cssText#</cfoutput>
	</cfcache>
</cfoutput>