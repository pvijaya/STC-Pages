<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">

<!---this page does one thing, it reads the updated hash.txt, and displays its contents, this allows
us to use the POST method avoiding IE's caching issues.--->

<cfparam name="instanceSelected" type="integer" default="1">

<cfset hash = "">
<cfset chatDir = "\\bl-uits-slwc1\pie$\Development\uploads\hash-#instanceSelected#.txt"><!---due to file permission issues use the old chat's hash.txt--->
<!---cfset chatDir = expandPath(chatDir)--->

<cflock name="iubHash" throwontimeout="false" timeout="20" type="readonly">
	<cffile action="read" file="#chatDir#" variable="hash">
</cflock>
<cfoutput>#hash#</cfoutput>