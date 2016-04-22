<cfmodule template="#application.appPath#/header.cfm" title='Gold Star Hall of Fame' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfparam name="frmSemester" default="i0s0" type='string'><!---this will be in the form "i#instance_id#s#semester_id#"--->
<cfparam name="frmInstanceId" default="0" type='integer'><!---the instance_id parsed out from frmSemester--->
<cfparam name="frmSemesterId" default="0" type="integer"><!---the semester_id parsed out from frmSemester--->
<cfparam name="action" default="" type="string">

<!---find the viewer's PIE level for use with RAVE functions.--->
<cfset pieLevel = getPieLevel(session.cas_username)>
<cfset isCs = hasMasks("CS")><!---we only want to show comments to CS and up--->

<h1>Gold Star Hall of Fame</h1>
<cfset instanceList = userHasInstanceList().instanceList>

<!---parse frmSemester to populate frmInstanceId and frmSemesterId--->
<cfloop list="#frmSemester#" index="n">
	<!---find the instanceId--->
	<cfset instanceId = mid(n, find("i", n)+1, (find("s", n) - 1 - find("i", n)))>
	<!---find the semesterId, depending where it is in the list--->
	<cfset semesterId = right(n, len(n) - find("s", n))>
	<cfif isNumeric(instanceId) AND isNumeric(semesterId)>
		<cfset frmInstanceId = instanceId>
		<cfset frmSemesterId = semesterId>
	</cfif>
</cfloop>

<!---queries--->
<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT instance_name, datasource
	FROM tbl_instances
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#">
</cfquery>	

<cfoutput>
<form action="#cgi.script_name#" method="get">
	#drawSemesterSelector("past", 10, frmInstanceId, frmSemesterId)#
	<input type='submit'  value='View' name='action' />
</form>
</cfoutput>

<cfif action EQ "View">
	<cfset semStruct = getSemesterById(frmInstanceId,frmSemesterId)/>
	<cfloop query="getInstances">
		<cfset datasource = datasource>
	</cfloop>
		<cfset gsQuery = getRavesByType(datasource, 1, semStruct['start_date'], semStruct['end_date'], "", 0, 0,0)><!---fetch goldstars, between these dates, for all users, only approved gold stars, and show them without regard of the assignee's level.--->
		<hr/>
		<cfoutput query="gsQuery" group="answer_group">
			<div>
				<cfquery datasource="#application.applicationDataSource#" name='showUser'>
					SELECT preferred_name, picture_source
					FROM tbl_users
					WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#gsQuery.about_username#">
				</cfquery>
				<cfloop query='showUser'>
					<div class="block-card" style='width:20%;float:left;margin:5px;'>
							<h2 style='margin:3px;line-height:110%;'>#gsQuery.about_first_name# #gsQuery.about_last_name#</h2>
							<img src="#picture_Source#" width="120px" style='margin:5px 0px;' /><br/>
						<p style='margin-top:0px;'>(#gsQuery.about_username#)</p>
					</div>
				</cfloop>
				<div style='width:70%;float:right;margin:10px;'>
					<p>#ts#</p>
				<p>
					<cfoutput>
					#question#
					#answer#
					</cfoutput>
				</p>
				<cfif comment_count gt 0 AND isCs>
					<cfset drawRaveComments(datasource, answer_group, pieLevel)>
				</cfif>
				</div>
				<div style='clear:both;'></div>
				
			</div>
			<hr/>
		</cfoutput>
</cfif>



<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>