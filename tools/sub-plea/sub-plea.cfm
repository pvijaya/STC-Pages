<cfmodule template="#application.appPath#/header.cfm" title='Sub Plea' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- bring in exterior functions --->
<cfinclude template="#application.appPath#/tools/sub-plea/sub-plea-functions.cfm">

<!--- cfparams --->
<cfparam name="action" type="string" default="">
<cfparam name="subId" type="integer" default=0>

<!--- sort out some information before we start --->
<cfset postSubLink = 'main/view_subs.cfm'>

<cfset myInstance = getInstanceById(session.primary_instance)>

<!---get the path to pie--->
<cfquery name='getPiePath' datasource="#application.applicationDataSource#">
	SELECT pie_path, instance_name
	FROM tbl_instances
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
</cfquery>

<!--- header / navigation --->
<h1>Sub Plea Request</h1>
<cfoutput>
	<cfif subId GT 0>
		<a href='<cfoutput>#cgi.script_name#</cfoutput>'>Go Back</a>
	</cfif>
	<cfloop query="getPiePath">
		<cfoutput>
			<cfif subId GT 0>|</cfif>
			<a href='#pie_path##postSubLink#' target='_blank'>Post #instance_name# subs here</a>
		</cfoutput>
	</cfloop>
	<cfif hasMasks('admin')>
		| <a href="#application.appPath#/tools/sub-plea/sub-plea-report.cfm">Sub Plea Report</a>
	</cfif>
</cfoutput>

<br/>

<!--- the page itself will contain many small forms, corresponding to shifts the user can sub plea --->
<!--- this bit of code happens when one of those forms is submitted to, giving us a subId --->
<!--- it looks up the particular sub and grabs all of its info --->
<cfif subId NEQ 0>

	<cfquery name="getPieDatabase" datasource="#application.applicationDatasource#">
		SELECT datasource
		FROM tbl_instances
		WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	</cfquery>

	<cfloop query ="getPieDatabase">
		<cfset pieDatabase= getPieDatabase.datasource>
	</cfloop>

	<cfquery name='getPostInfo' datasource="#pieDatabase#">
		SELECT c.username, si.site_long_name, si.site_name, ps.comments, ps.post_id,
			/*human readable shift start and end times*/
			convert(char(10), ps.shift_start_date, 121)+' '+convert(char(5), st.start_time, 114) "Start_Time",
			convert(char(10), ps.shift_end_date, 121)+' '+convert(char(5), et.start_time, 114) "End_Time"
		FROM tbl_post_subs ps
		INNER JOIN tbl_consultants c ON c.ssn = ps.owner_ssn
		INNER JOIN tbl_sites si ON si.site_id = ps.site_name_id
		INNER JOIN tbl_times st ON ps.start_time_id = st.time_id
		INNER JOIN tbl_times et ON ps.end_time_id = et.time_id
		WHERE c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">
			  AND ps.approved = 0
			  AND ps.deleted = 0
			  AND ps.post_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#subId#">
	</cfquery>

</cfif>

<!--- sub plea emails appear to come from the user, so grab that --->
<cfquery name='getUserEmail' datasource="#application.applicationDataSource#">
	SELECT email
	FROM tbl_users
	WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
</cfquery>

<!--- handle user actions --->
<cfif action EQ 'Join List'>
	<cfquery name='joinSubPleaList' datasource="#application.applicationDataSource#">
		INSERT INTO tbl_users_masks_match(mask_id, user_id, value)
		VALUES((SELECT mask_id FROM tbl_user_masks WHERE mask_name = 'Sub Plea'),
			<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,1)
	</cfquery>

	<!---ok, we want to run the nightly update to get them on the mailing list immediately, but for sure we don't want them seeing any of the output that might result.--->
	<cfsavecontent variable="hideOutput">
		<cfinclude template="#application.appPath#/tools/crons/update-access.cfm">
	</cfsavecontent>

<cfelseif action EQ 'Leave List'>
	<cfquery name='leaveSubPleaList' datasource="#application.applicationDataSource#">
		DELETE
		FROM tbl_users_masks_match
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		AND mask_id = (SELECT mask_id FROM tbl_user_masks WHERE mask_name = 'Sub Plea')
	</cfquery>

	<!---ok, we want to run the nightly update to get them on the mailing list immediately, but for sure we don't want them seeing any of the output that might result.--->
	<cfsavecontent variable="hideOutput">
		<cfinclude template="#application.appPath#/tools/crons/update-access.cfm">
	</cfsavecontent>

<cfelseif action EQ 'Send Request'>

	<!--- retrieve the existing please for this sub --->
	<cfquery name='countPleaRequests' datasource="#application.applicationDataSource#">
		SELECT *
		FROM tbl_sub_plea_requests
		WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		AND post_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#subId#">
	</cfquery>

	<!--- only go forward if the user has zero or one active pleas - the limit is two --->
	<cfif countPleaRequests.recordCount LTE 1>

		<cftry>

			<!---get the path to pie--->
			<cfquery name='getPiePath' datasource="#application.applicationDataSource#">
				SELECT pie_path
				FROM tbl_instances
				WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			</cfquery>
			<cfloop query="getPiePath">
				<cfset piePath = pie_path>
			</cfloop>

			<!--- build up the list of emails that the sub plea will go out to --->
			<!--- generally this is tcc-subplea-l@campus.edu, but sometimes a particular admin asks for emails --->
			<!--- admins cannot join the subplea list the normal way, due to mask blacklisting --->
			<cfset listserv = "">
			<cfset contactEmail = "">
			<cfif myInstance.instance_name EQ "TCC IUB">
				<cfset listserv = listAppend(listserv, "tcc-subplea-l@indiana.edu")>
				<cfset listserv = listAppend(listserv, "tcchr@indiana.edu")>
				<cfset contactEmail = "tcciub@indiana.edu">
			<cfelseif myInstance.instance_name EQ "TCC IUPUI">
				<cfset listserv = listAppend(listserv, "tcc-subplea-l@iupui.edu")>
				<cfset contactEmail = "timetcc@iupui.edu">
			<cfelse>
				<!--- default to IUB if we can't find an instance, so that some email is presented --->
				<cfset contactEmail = "tcciub@indiana.edu">
			</cfif>
			<cfset listserv = listAppend(listserv, "tccwm@iu.edu")>
			<cfset linkPost = "https://#cgi.server_name##piePath#main/view_sub_new.cfm?postId=#getPostInfo.post_id#">
			<cfset linkSubs = "https://#cgi.server_name##piePath#main/view_subs.cfm">
			<cfset linkSchedule = "https://#cgi.server_name##piePath#schedules/schedule.cfm">

			<!--- create the email that will be sent out --->
			<!--- in production replace tccwm@iu.edu with #listserv# --->
			<cfmail from="#getUserEmail.email#" to="#listserv#"
			        subject="Sub Available #getPostInfo.Start_Time# - #getPostInfo.End_Time#"
			        type="text/html">
				<html>
					<body>
						<center>
							#getPostInfo.site_long_name#
							 <br/>
							(#getPostInfo.site_name#)
							<br/><br/>
							Starting at: #getPostInfo.Start_Time#
							<br/>
							Ending at: #getPostInfo.End_Time#
							<br/><br/>
							#getPostInfo.comments#
							<br/><br/>
							<a href='#linkPost#' target='_new'>View the sub</a> |
							<a href='#linkSubs#' target='_new'>View all subs</a> |
							<a href='#linkSchedule#'>View your schedule</a>
							<br/><br/>
							<hr/>
							NOTICE: This message was generated by a user-submitted form.  To report abuse, please contact #contactEmail#.
						</center>
					</body>
				</html>
			</cfmail>

			<!--- finally, if everything else succeeded, insert the request record --->
			<cfquery name='insertPleaRequest' datasource="#application.applicationDataSource#">
				INSERT INTO tbl_sub_plea_requests(post_id, instance_id, user_id)
				VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#subId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">)
			</cfquery>

			<p class="ok">Your sub plea request has been sent to everyone on the sub plea list.</p>

			<cfcatch type="any">
				<p class="warning"><cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput></p>
			</cfcatch>

		</cftry>

	<cfelse>

		<!--- if they've already sent two subpleas and somehow manage to get here, this message will kick up --->
		<p class="warning"><cfoutput>You have already sent this sub plea twice. You are not allowed to send it for this shift again.</cfoutput></p>

	</cfif>

</cfif>

<!---HTML--->

<cfoutput>

	<!--- if subId is zero, we aren't dealing with any user action; just draw the subs --->
	<cfif subId EQ 0 >

		<!--- check to see if they are on the sub plea list --->
		<cfif hasMasks('Sub Plea') EQ 1>

			<!--- option to remove themself from the list --->
			<p>You can always leave the list if you don't want to receive sub plea requests from others.</p>

			<form action="#cgi.script_name#" method='post'>
				<input  type='submit' name='action' value='Leave List'>
				<span class="tinytext">
					<sup>*</sup>It may take several seconds for this form to run, as it removes you to the IU List system.<sup>*</sup>
				</span>
			</form>

			<cfset postSubs = #getPostSubsFunc(session.primary_instance, session.cas_username)#>

			<h2>Existing Subs</h2>

			<!--- either draw the set of subs that the user can sub plea, or write a message --->
			<cfif postSubs.recordCount GT 0>

				<cfloop query="postSubs">

					<!--- look for previous pleas to this sub --->
					<cfquery name='countPleaRequests' datasource="#application.applicationDataSource#">
						SELECT *
						FROM tbl_sub_plea_requests
						WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
						AND post_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#post_id#">
					</cfquery>

					<div class="block-card" style="width:220px; display:inline-block;">

						<!--- draw each sub in its own div and form --->
						<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
							<strong>#site_name#, #dateFormat(Start_Time, 'mmmm dd, yyyy')#</strong><br/>
							#timeFormat(Start_Time, 'hh:nn tt')# - #timeFormat(End_Time, 'hh:nn tt')#<br/>

							<!--- this tells the logic above which sub has been acted upon --->
							<input type='hidden' name='subId' value='#post_id#'>

							<p>
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
							</p>

							<!--- don't draw the submit button if they've hit their plea limit --->
							<cfif countPleaRequests.recordCount lt 2>
								<input  type='submit' name='action' value='Send Request'>
								<br/>
							</cfif>

							<!--- draw the dates and times of their existing pleas --->
							<cfloop query="countPleaRequests">
								<p class="tinytext">
									Plea Sent: #dateTimeFormat(sent_date, "mmmm dd, yyyy hh:nn tt")#
								</p>
							</cfloop>

						</form>

					</div>

				</cfloop>

			<cfelse>

				<!---If they have no subs explain that they must sub them out before sending a sub plea--->
				<p>You have no available subs. In order to use the sub plea system, you must have posted subs that take place within forty-eight hours.</p>
				<p>Please see the <a href="https://pie.iu.edu/apps/tetra/documents/article.cfm?articleId=1203">Subbing Guidelines</a> article for more information.</p>

			</cfif>

		<cfelse>

			<!---If not, allow them to sign up--->
			<p>You cannot send to the sub plea list unless you are on the list.</p>
			<form action="#cgi.script_name#" method='post'>
				<input  type='submit' name='action' value='Join List'>
				<span class="tinytext">
					<sup>*</sup>It may take several seconds for this form to run, as it adds you to the IU List system.<sup>*</sup>
				</span>
			</form>

		</cfif>
	</cfif>
</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>