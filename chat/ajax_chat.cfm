
<cfsetting showdebugoutput="false">
<cfprocessingdirective suppresswhitespace="yes">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="consultant" showMaskPermissions="False">
<cfparam name="rowsToFetch" type="integer" default="20"><!---the number of rows we'd like to retrieve--->
<cfparam name="lastMessage" type="integer" default="0">
<cfparam name="instanceSelected" type="integer" default="0">

<cfif instanceSelected eq 0>
	<p class="warning">
		Error:  Unable to determine which instance of chat to fetch records for.
	</p>
	<cfabort>
</cfif>

<cfinclude template="chat_functions.cfm">

<!---folks could provide out of bounds values for the number of rows to fetch, constrain them.--->
<cfif rowsToFetch lte 0>
	<cfset rowsToFetch = 20>
<cfelseif rowsToFetch gt 1000>
	<cfset rowsToFetch = 1000>
</cfif>

<cfquery name="GetChatInfo" datasource="#application.applicationDatasource#">
	SELECT TOP #rowsToFetch# cm.message_ID, u.user_id, u.preferred_name, u.username, cm.date_time, cm.message, cm.visible, u.picture_source
	FROM tbl_chat_messages cm
	INNER JOIN tbl_users u ON u.user_id = cm.user_id
	WHERE visible = 1
	AND cm.instance = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	<cfif lastMessage gt 0>
		AND message_id < <cfqueryparam cfsqltype="cf_sql_integer" value="#lastMessage#">
	</cfif>
	ORDER BY message_id DESC
</cfquery>

<!---CS and up can remove/edit chat entries.--->
<cfset canEdit = hasMasks("CS")>

<!---to color-code everyone correctly we need to fetch everybody's masks.--->
<cfquery dbtype="query" name="getUsers">
	SELECT DISTINCT username
	FROM getChatInfo
</cfquery>
<cfset userList = "">
<cfloop query="getUsers">
	<cfset userList = listAppend(userList, username)>
</cfloop>

<cfset usersMasks = bulkGetUserMasks(userList)>

<cfset counter = 1>
<cfif GetChatInfo.RecordCount NEQ 0>
	<cfoutput query="GetChatInfo">
	
		<cfset ModMessage=Message>
		<cfset ModMessage=stripTags(ModMessage)>
		<cfset ModMessage=parseLinks(ModMessage)>
		<cfset ModMessage=convertPRLinks(ModMessage)>
		<cfset ModMessage=filterProfanity(ModMessage)>
		<cfset ModMessage=chatIconReplace(ModMessage)>
		
		<cfset Username_Highlight=FindNoCase(Session.CAS_Username, ModMessage)>
	
		<!---
		#convertAccessLevels()#
		#convertPrefixes()#
		--->
		
		<!---now set the display_class for the user, by default assume they are a guest.--->
		<cfset display_class = "logsLevel">
		<cfif bulkHasMasks(usersMasks, username, "Admin")>
			<cfset display_class = "adminColor">
		<cfelseif bulkHasMasks(usersMasks, username, "CS")>
			<cfset display_class = "csColor">
		<cfelseif bulkHasMasks(usersMasks, username, "Logistics")>
			<cfset display_class = "logisticsColor">
		<cfelseif bulkHasMasks(usersMasks, username, "Tech Team")>
			<cfset display_class = "techColor">
		<cfelseif bulkHasMasks(usersMasks, username, "Consultant")>
			<cfset display_class = "conColor">
		</cfif>
		
		<cfset prefix = "">
		
		<!--- See if message needs to be highlighted for all (CS and Admins only) --->
		<cfset announce = false>
		<cfif bulkHasMasks(usersMasks, username, "CS") OR bulkHasMasks(usersMasks, username, "Admin")>
			<cfset announce=FindNoCase("qaz", ModMessage)>
			<cfset ModMessage=ReplaceNoCase(#ModMessage#, "qaz", "", "all")>
		</cfif>
		
		<cfset Formatted_Time=TimeFormat(Date_Time, "short")>
		<!---keep this so chrome doesn't get made.--->
	    <meta http-equiv="Content-Language" content="en" />
	
	    <div id="#counter#" class="hover-box chatmess  <cfif announce>announce</cfif><cfif username_highlight> highlight</cfif>" messageId="#GetChatInfo.message_id#">
			<p>
				<img src="#picture_source#" class="shadow-border user" alt="#username#"/ onclick="putInTextbox('#username#')">
				<span class="#display_class# user" onclick="putInTextbox('#username#')">
					<cfif bulkHasMasks(usersMasks, username, "COS")><span class="tinytext">COS</span></cfif>
					<cfif bulkHasMasks(usersMasks, username, "COM")><span class="tinytext">COM</span></cfif>
					<cfif bulkHasMasks(usersMasks, username, "HM")><span class="tinytext">HM</span></cfif>
					#prefix# #preferred_name# (#username#):
				</span>
				<cfif dateformat(now(), "yyyy-mm-dd") EQ dateformat(Date_Time, "yyyy-mm-dd")>
					#Formatted_Time#
				<cfelse>
					(#dateformat(Date_Time, "yyyy-mm-dd")#) #Formatted_Time# a
				</cfif>
				
				<cfif canEdit>
					&nbsp;<span style="color:##900;" class="msg_hide_btn" title="Hide this message" onClick="hide_msg_confirm(#message_id#)">x</span>
				</cfif>
				<br/>
				#ModMessage#
			</p>
		</div><!---end chatmess--->
		<cfset counter = counter +1>
	</cfoutput> 		

	<cfoutput>
		<div class="see-more-button" style="text-align: center; margin: 0px; padding: 0px;">
			<input type="button" class="btn btn-default"  onClick="updateChat(20);return false;" value="See more" />
		</div>
	</cfoutput>
	</cfif>	


</cfprocessingdirective>