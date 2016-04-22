<cfmodule template="#application.appPath#/header.cfm" title='Sub Plea' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- bring in exterior functions --->
<cfinclude template="#application.appPath#/tools/sub-plea/sub-plea-functions.cfm">

<!--- header / navigation --->
<h1>Sub Plea Report</h1>
<cfoutput>
	<a href="#application.appPath#/tools/sub-plea/sub-plea.cfm">Sub Plea Request</a>
</cfoutput>

<h2>Existing Sub Pleas</h2>

<!--- unlike the individual sub plea page, we want to see sub pleas for all users --->
<cfset postSubs = #getPostSubsFunc(session.primary_instance, "")#>
<cfset date = "">
<cfset subPleaExists = 0>
	
<cfif postSubs.recordCount GT 0>	
	
	<cfloop query="postSubs">
		
		<!---Also, check if the user has sent pleas for this sub before--->
		<cfquery name='countPleaRequests' datasource="#application.applicationDataSource#">
			SELECT *
			FROM tbl_sub_plea_requests
			WHERE post_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#post_id#">
		</cfquery>
		
		<cfif countPleaRequests.recordCount GT 0>
		
			<cfset subPleaExists = 1>
		
			<cfoutput>
		
				<!--- this bit controls the date headers --->
				<!--- the headers help split the pleas up into a more organized fashion --->
				<cfset tempDate = dateFormat(start_time, 'mmmm yyyy')>
				
				<cfif tempDate NEQ date>
					<h3>#tempDate#</h3>
					<cfset date = tempDate>
				</cfif>
			
				<!--- draw each sub just like the sub plea request page, without the 'send plea' button --->
				<div class="block-card" style="width:220px; display:inline-block;">
					
					<!---If they are show their current subs--->
					<strong>#first_name# #last_name# (#username#)</strong><br/> 
					<strong>#site_name#, #dateFormat(Start_Time, 'mmmm dd, yyyy')#</strong><br/> 
					#timeFormat(Start_Time, 'hh:nn tt')# - #timeFormat(End_Time, 'hh:nn tt')#<br/>
					
					<!--- when there are comments, they are hidden by default --->
					<!--- jquery links allow the comments to be expanded and hidden --->
					<!--- this keeps the initial grid looking cleaner and less uneven --->
					<cfif trim(comments) NEQ "">
						<span style="display:none;" class="comments">
							#htmlEditFormat(comments)#<br/>
							<a id="hideComments" href="##" onclick="return false;">[Hide Comments]</a>
						</span>
						<span class="noComments">
							<a id="showComments" href="##" onclick="return false;">[Show Comments]</a>
						</span>
					<cfelse>
						[No comments]
					</cfif>
					
					<!--- draw the plea dates and times here --->
					<cfloop query="countPleaRequests">
						<p class="tinytext">
							Plea Sent: #dateTimeFormat(sent_date, "mmmm dd, yyyy hh:nn tt")#
						</p>
					</cfloop>
					
				</div>
				
			</cfoutput>
			
		</cfif>
		
	</cfloop>

</cfif>

<cfif NOT subPleaExists>
	
	<p>There are no active sub pleas.</p>
	
</cfif>
		
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>