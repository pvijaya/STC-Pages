<!--- functions for use with the Photoshop Contest tools --->

<!--- draws the navigation bar for this toolset --->
<cffunction name="drawNavigation">

	<cfoutput>
		<p style="padding: 0px;margin-top: 0em;margin-bottom: 0.5em;">
			<a href="#application.appPath#/tools/photoshop-contest/welcome.cfm">Welcome</a> |
			<a href="#application.appPath#/tools/photoshop-contest/consultant-gallery.cfm">Consultant Gallery</a> |
			<a href="#application.appPath#/tools/photoshop-contest/cs-gallery.cfm">CS Gallery</a> |
			<a href="#application.appPath#/tools/photoshop-contest/source-images.cfm">Source Images</a> |
			<a href="#application.appPath#/tools/photoshop-contest/past-winners.cfm">Past Winners</a>
			<cfif hasMasks('CS')>
				| <a href="#application.appPath#/tools/photoshop-contest/rejected-entries.cfm">Rejected Entries</a>
				| <a href="#application.appPath#/tools/photoshop-contest/submission-report.cfm">Submission Report</a>
			</cfif>
			<cfif hasMasks('Admin')>
				| <a href="#application.appPath#/tools/photoshop-contest/vote-report.cfm">Vote Report</a>	
				| <a href="#application.appPath#/tools/photoshop-contest/manager.cfm">Manager</a>
			</cfif>
		</p>
	</cfoutput>

</cffunction>

<!--- draws a secondary version of the navigation bar for this toolset --->
<!--- this is used when no active contest exists, and closes off some of the links --->
<cffunction name="drawNavigationClosed">

	<cfoutput>
		<p style="padding: 0px;margin-top: 0em;margin-bottom: 0.5em;color:grey;">
			<span style="color:black;"><a href="#application.appPath#/tools/photoshop-contest/welcome.cfm">Welcome</a> |</span>
			Consultant Gallery <span style="color:black;">|</span>
			CS Gallery <span style="color:black;">|</span>
			<span style="color:black;"><a href="#application.appPath#/tools/photoshop-contest/source-images.cfm">Source Images</a> |</span>
			<a href="#application.appPath#/tools/photoshop-contest/past-winners.cfm">Past Winners</a>
			<cfif hasMasks('CS')>
				<span style="color:black;">|</span> Rejected Entries
				<span style="color:black;">|</span> Submission Report
			</cfif>
			<cfif hasMasks('Admin')>
				<span style="color:black;">|</span> Vote Report		
				<span style="color:black;">| <a href="#application.appPath#/tools/photoshop-contest/manager.cfm">Manager</a></span>
			</cfif>
		</p>
	</cfoutput>
	
</cffunction>

<!--- fetch the active contest for this instance, if there is one --->
<cffunction name="getActiveContest">

	<cfquery datasource="#application.applicationDataSource#" name="getContest">
		SELECT TOP 1 pc.contest_name, pc.deadline, pc.folder_id, pc.open_entry, pc.open_vote, pc.welcome_text,
					 pc.contest_id
		FROM tbl_psc_contests pc
		WHERE pc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#myInstance.instance_id#">
			  AND pc.retired = 0
		ORDER BY pc.deadline DESC
	</cfquery>
	
	<cfreturn getContest>
	
</cffunction>
