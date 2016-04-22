<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant" showMaskPermissions="False">
<cfinclude template="chat_functions.cfm">

<cfparam name="instanceSelected" type="integer" default="1">

<!--- set defaults --->
<cfset chatDir = "\\bl-uits-slwc1\pie$\Development\uploads\hash-#instanceSelected#.txt"><!---due to file permission issues use the old chat's hash.txt--->
<!---cfset chatDir = expandPath(chatDir)--->

<cfparam name="txt_chatter" default="">
<cfset txt_chatter = replace("#txt_chatter#", "&", "&amp;", 'all')>
<cfset txt_chatter = trim(stripTags(txt_chatter))>
<cfif txt_chatter EQ 'qaz'>
	<cfset txt_chatter = ''>
</cfif>
<cfif LCase(#txt_chatter#) EQ ''>
	<cfheader statuscode="400" statustext="You must type a message.">
	<cfabort>
</cfif>

<cfif NOT REFind('^/', #txt_chatter#)> <!--- Insert message if no /command given --->
	<cfquery name="updateUser" datasource="#application.applicationDatasource#">
 		INSERT INTO 	tbl_chat_messages ( user_id, Message, From_IP, instance)
 		VALUES			(<cfqueryparam value="#session.cas_uid#" cfsqltype="cf_sql_int">,
 						<cfqueryparam value="#txt_chatter#" cfsqltype="cf_sql_char" maxlength="1000">,
 						<cfqueryparam value="#HTTP.REMOTE_ADDR#" cfsqltype="cf_sql_char">, 
						<cfqueryparam value="#instanceSelected#" cfsqltype="cf_sql_int">)
	</cfquery>
	

	<!---update the hash.txt with a new random value--->
	<cfset r = randomize(datePart("s", now()))>
	<cflock name="iubHash" throwontimeout="false" timeout="20" type="exclusive">
		<cffile action="write" file="#chatDir#" output="#randRange(1, 1000000)#">
	</cflock>
</cfif>