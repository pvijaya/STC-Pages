<cfsetting requesttimeout="400"><!---this can take a good while to run.--->
<cfparam name="badgeId" type="integer" default="0">
<cftry>
	<cfinclude template="#application.appPath#/tools/badges/badge-rules.cfm">
	<cfif badgeId EQ 0>
		<cfloop from="1" to="4" step="1" index="loopCount">
			<cfset hourOfDay = hour(now())>
				<!---run badge automation query where badgeId is based on the hour of the day--->
				<cfif loopCount EQ 1>
					<cfswitch expression="#hourOfDay#">
						<cfcase value="0">
							<cfset badgeId = 3>
						</cfcase>
						<cfcase value="1">
							<cfset badgeId = 4>
						</cfcase>
						<cfcase value="2">
							<cfset badgeId = 7>
						</cfcase>
						<cfcase value="3">
							<cfset badgeId = 13>
						</cfcase>
						<cfcase value="4">
							<cfset badgeId = 14>
						</cfcase>
						<cfcase value="5">
							<cfset badgeId = 15>
						</cfcase>
						<cfcase value="6">
							<cfset badgeId = 16>
						</cfcase>
						<cfcase value="7">
							<cfset badgeId = 17>
						</cfcase>
						<cfcase value="8">
							<cfset badgeId = 18>
						</cfcase>		
						
						
						<!---prime time--->
						
						<cfcase value="15">
							<cfset badgeId = 24>
						</cfcase>
						<cfcase value="16">
							<cfset badgeId = 25>
						</cfcase>		
						<cfcase value="17">
							<cfset badgeId = 28>
						</cfcase>
						<cfcase value="18">
							<cfset badgeId = 34>
						</cfcase>
						<cfcase value="19">
							<cfset badgeId = 35>
						</cfcase>
						<cfcase value="20">
							<cfset badgeId = 36>
						</cfcase>
						<cfcase value="21">
							<cfset badgeId = 37>
						</cfcase>
						<cfcase value="22">
							<cfset badgeId = 38>
						</cfcase>
						<cfcase value="23">
							<cfset badgeId = 39>
						</cfcase>
						<cfdefaultcase>
							<cfset badgeId = 0>
						</cfdefaultcase>
					</cfswitch>
				<cfelseif loopCount EQ 2>
						<cfswitch expression="#hourOfDay#">
						<cfcase value="0">
							<cfset badgeId = 44>
						</cfcase>
						<cfcase value="1">
							<cfset badgeId = 56>
						</cfcase>
						<cfcase value="2">
							<cfset badgeId = 57>
						</cfcase>
						<cfcase value="3">
							<cfset badgeId = 58>
						</cfcase>
						<cfcase value="4">
							<cfset badgeId = 59>
						</cfcase>
						<cfcase value="5">
							<cfset badgeId = 60>
						</cfcase>
						<cfcase value="6">
							<cfset badgeId = 61>
						</cfcase>
						<cfcase value="7">
							<cfset badgeId = 73>
						</cfcase>
						<cfcase value="8">
							<cfset badgeId = 76>
						</cfcase>		
						
						
						<!---prime time--->
						
						<cfcase value="15">
							<cfset badgeId = 77>
						</cfcase>
						<cfcase value="16">
							<cfset badgeId = 78>
						</cfcase>		
						<cfcase value="17">
							<cfset badgeId = 79>
						</cfcase>
						<cfcase value="18">
							<cfset badgeId = 84>
						</cfcase>
						<cfcase value="19">
							<cfset badgeId = 86>
						</cfcase>
						<cfcase value="20">
							<cfset badgeId = 87>
						</cfcase>
						<cfcase value="21">
							<cfset badgeId = 97>
						</cfcase>
						<cfcase value="22">
							<cfset badgeId = 98>
						</cfcase>
						<cfcase value="23">
							<cfset badgeId = 100>
						</cfcase>
						<cfdefaultcase>
							<cfset badgeId = 0>
						</cfdefaultcase>
					</cfswitch>
				<cfelseif loopCount EQ 3>
					<cfswitch expression="#hourOfDay#">
						<cfcase value="0">
							<cfset badgeId = 109>
						</cfcase>
						<cfcase value="1">
							<cfset badgeId = 110>
						</cfcase>
						<cfcase value="2">
							<cfset badgeId = 117>
						</cfcase>
						<cfcase value="3">
							<cfset badgeId = 118>
						</cfcase>
						<cfcase value="4">
							<cfset badgeId = 120>
						</cfcase>
						<cfcase value="5">
							<cfset badgeId = 125>
						</cfcase>
						<cfcase value="6">
							<cfset badgeId = 126>
						</cfcase>
						<cfcase value="7">
							<cfset badgeId = 127>
						</cfcase>
						<cfcase value="8">
							<cfset badgeId = 128>
						</cfcase>		
						
						
						<!---prime time--->
						
						<cfcase value="15">
							<cfset badgeId = 129>
						</cfcase>
						<cfcase value="16">
							<cfset badgeId = 140>
						</cfcase>		
						<cfcase value="17">
							<cfset badgeId = 141>
						</cfcase>
						<cfcase value="18">
							<cfset badgeId = 143>
						</cfcase>
						<cfcase value="19">
							<cfset badgeId = 145>
						</cfcase>
						<cfcase value="20">
							<cfset badgeId = 150>
						</cfcase>
						<cfcase value="21">
							<cfset badgeId = 152>
						</cfcase>
						<cfcase value="22">
							<cfset badgeId = 161>
						</cfcase>
						<cfcase value="23">
							<cfset badgeId = 163>
						</cfcase>
						<cfdefaultcase>
							<cfset badgeId = 0>
						</cfdefaultcase>
					</cfswitch>
					<cfelseif loopCount EQ 4>
						<cfswitch expression="#hourOfDay#">
							<cfcase value="0">
								<cfset badgeId = 169>
							</cfcase>
							<cfcase value="1">
								<cfset badgeId = 170>
							</cfcase>
							<cfcase value="2">
								<cfset badgeId = 171>
							</cfcase>
							<cfcase value="3">
								<cfset badgeId = 173>
							</cfcase>
							<cfcase value="4">
								<cfset badgeId = 176>
							</cfcase>
							<cfcase value="5">
								<cfset badgeId = 177>
							</cfcase>
							<cfcase value="6">
								<cfset badgeId = 43>
							</cfcase>
							<cfcase value="7">
								<cfset badgeId = 108>
							</cfcase>
							
							<cfcase value="8">
								<cfset badgeId = 113>
							</cfcase>		
							
							
							<!---prime time--->
							
							<cfcase value="15">
								<cfset badgeId = 124>
							</cfcase>
							<cfcase value="16">
								<cfset badgeId = 46>
							</cfcase>		
							<cfcase value="17">
								<cfset badgeId = 47>
							</cfcase>
							<cfdefaultcase>
								<cfset badgeId = 0>
							</cfdefaultcase>
						</cfswitch>
				</cfif>
			<cfif badgeId NEQ 0>		
				<cfset assignBadge(badgeId)>
			</cfif>
		</cfloop>
	<cfelse>
		<cfset assignBadge(badgeId)>
	</cfif>
	<cfcatch type="any">
		<cfoutput>
			<p>#cfcatch.Message# - #cfcatch.detail#</p>
		</cfoutput>

		<!--- Get the current timeout settings, if this was a timeout issue we need to allow our selves enough time to generate output!--->
		<cfset currentTimeout = CreateObject("java", "coldfusion.runtime.RequestMonitor").GetRequestTimeout() />
		
		<!--- Increase it a little bit --->
		<cfsetting requesttimeout="#(currentTimeout + 10)#"/>
		<cfoutput>
			<h3>Aw, Snap!</h3>
			<p>#cfcatch.Message# - #cfcatch.detail#</p>
		</cfoutput>
		<!--->
		<cfmail to="tccpie@indiana.edu" from="pie@indiana.edu" subject="Badge Update Failed" type="html">
			<h1>Badge Update Failed</h1>
			<p>#cfcatch.Message# - #cfcatch.detail#</p>
			
			<p>Please investigate.</p>
		</cfmail>
		--->
	</cfcatch>
</cftry>

<cffunction name="assignBadge">
	<cfargument name="badgeId" type="numeric">
	<!---Get the users for this badge automation--->
	<cfset newUsersBadgeMatchQuery = getNewBadgesUsersByBadgeRule(badgeId,dateFormat(dateAdd("d", -1, now()), "yyyy-mm-dd") & " 23:59:59")>
	<cfif newUsersBadgeMatchQuery.recordCount GT 0>
	    <cfquery datasource="#application.applicationDatasource#" name="insertBadgeQuery">
	        INSERT INTO tbl_badges_users_matches (badge_id, assigner_id, user_id, time_assigned)
			OUTPUT Inserted.match_id
	        VALUES 
	        <cfset counter = 1>
	        <cfloop query="newUsersBadgeMatchQuery">
	            (
	                <cfqueryparam cfsqltype="cf_sql_integer" value="#newUsersBadgeMatchQuery.badge_id#">,
					2,
	                <cfqueryparam cfsqltype="cf_sql_integer" value="#newUsersBadgeMatchQuery.user_id#">,
	                <cfqueryparam cfsqltype="cf_sql_timestamp" value="#newUsersBadgeMatchQuery.time_assigned#">
	            )<cfif counter lt newUsersBadgeMatchQuery.recordCount>,</cfif>
	            <cfset counter = counter + 1>
	        </cfloop>
	    </cfquery>
		<cfquery datasource="#application.applicationDatasource#" name="insertBadgeAuditQuery">
	        INSERT INTO tbl_badges_users_matches_audit (match_id, modifier_id, audit_text)
			OUTPUT Inserted.match_id
	        VALUES 
		    <cfset counter = 1>
	        <cfloop query="insertBadgeQuery">
	            (
	                <cfqueryparam cfsqltype="cf_sql_integer" value="#insertBadgeQuery.match_id#">,
					2,
	                <cfqueryparam cfsqltype="cf_sql_varchar" value="Added Badge">
	            )<cfif counter lt insertBadgeQuery.recordCount>,</cfif>
	            <cfset counter = counter + 1>
	        </cfloop>
	    </cfquery>
	</cfif>
</cffunction>