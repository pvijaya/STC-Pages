<cftry>
	<cfparam name="attributes.currentUsername" type="string" default="">
	<cfparam name="attributes.startDate" type="date" default="#DateFormat(dateAdd('d', -7, now
()),'yyyy/mm/dd')#">
	<cfparam name="attributes.endDate" type="date" default="#DateFormat(Now(),'yyyy/mm/dd')#">
	<cfparam name="attributes.shortDateTime" type="integer" default="1">
	<cfquery datasource="#application.applicationDataSource#" name="getChatMessages">
		SELECT u.username, cm.Date_Time, cm.From_IP, cm.Message_ID, cm.Visible, cm.Message 
		FROM tbl_chat_messages cm 
		INNER JOIN tbl_users u ON u.user_id = cm.user_id 
		INNER JOIN tbl_instances i ON i.instance_id = cm.instance 
		WHERE cm.Date_Time BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" 
value="#attributes.startDate# 00:00"> and <cfqueryparam cfsqltype="cf_sql_timestamp" value="#attributes.endDate# 00:00">
		AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" 
value="#session.cas_uid#">, i.instance_mask) 
		<cfif trim(attributes.currentUsername) neq ""> 
			AND u.username = <cfqueryparam cfsqltype="cf_sql_varchar" 
value="#attributes.currentUsername#"> 
		</cfif> 
		ORDER BY cm.Date_Time DESC
	</cfquery>
	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</p>
	</cfcatch>
</cftry>

<!---get all chat users for an auto-completing input.--->
<cfquery datasource="#application.applicationDataSource#" name="getChatUsers">
	SELECT DISTINCT u.user_id, u.last_name, u.first_name, u.username
	FROM tbl_chat_messages cm
	INNER JOIN tbl_users u on cm.user_id = u.user_id
	ORDER BY u.last_name, u.first_name, u.username
</cfquery>


<!---HTML--->
<cfoutput>
<cftry>
	<cfif getChatMessages.recordCount NEQ 0>
		<table class="stripe" style="text-align:center;">
			<cfloop query="getChatMessages">
				<tr>
					<td style="min-width:100px;"><cfif attributes.shortDateTime EQ 1>
						(#dateTimeFormat(Date_Time, "h:nn aa")#) 
					<cfelse>
						(#dateTimeFormat(Date_Time, "mmm d, yyyy h:nn aa")#) 
					</cfif></td>
					<td>#message#</td>
				</tr>
			</cfloop>
		</table>
	</cfif>
	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</p>
	</cfcatch>
</cftry>
</cfoutput>
