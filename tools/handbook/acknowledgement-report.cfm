<cfmodule template="#application.appPath#/header.cfm" title='Handbook Acknowledgment Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfparam name="action" type="string" default="">

<h1>Handbook Acknowledgment Report</h1>
<cfset maskList = "consultant">
<cfif hasMasks("CS")>
	<cfset maskList = "CS">
</cfif>

<cfif action EQ "Reset Consultants">
	<cftry>
		<cfquery name="update" datasource="#application.applicationDataSource#">
		UPDATE tbl_handbook_acknowledgements
		SET active = 0
		WHERE 1=1
		<cfif hasMasks('IUB') AND hasMasks('IUPUI')>
			AND (dbo.userHasMasks(user_id,  'iub') = 1 
			OR dbo.userHasMasks(user_id, 'iupui') = 1) 
		<cfelseif hasMasks('IUB') >
			AND dbo.userHasMasks(user_id,  'iub') = 1 
		<cfelseif hasMasks('IUPUI')>
			AND dbo.userHasMasks(user_id,  'iupui') = 1  
		</cfif>
	</cfquery>
	<cfoutput>
		<p class="ok">
		<b>Success</b>
		All Consultants have been reset
		</p>
	</cfoutput>
	<cfcatch>
		<cfoutput>
			<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
</cfif>

<cfquery name="getSigners" datasource="#application.applicationDataSource#">
	SELECT *
	FROM vi_handbook_acknowledgements ha
	LEFT JOIN tbl_users u ON ha.user_id = u.user_id
	WHERE ha.active = 1
	<cfif hasMasks('IUB') AND hasMasks('IUPUI')>
		AND (dbo.userHasMasks(ha.user_id,  'iub') = 1 
		OR dbo.userHasMasks(ha.user_id, 'iupui') = 1) 
	<cfelseif hasMasks('IUB') >
		AND dbo.userHasMasks(ha.user_id,  'iub') = 1 
	<cfelseif hasMasks('IUPUI')>
		AND dbo.userHasMasks(ha.user_id,  'iupui') = 1  
	</cfif>
</cfquery>
	
<cfquery name="getSlackers" datasource="#application.applicationDataSource#">
	SELECT  *
	FROM tbl_users u 
	LEFT JOIN vi_handbook_acknowledgements ha ON ha.user_id = u.user_id
	WHERE (ha.active <> 1 OR ha.active IS NULL)  
	<cfif hasMasks('IUB') AND hasMasks('IUPUI')>
		AND (dbo.userHasMasks(u.user_id,  'iub') = 1 
		OR dbo.userHasMasks(u.user_id, 'iupui') = 1) 
	<cfelseif hasMasks('IUB') >
		AND dbo.userHasMasks(u.user_id,  'iub') = 1 
	<cfelseif hasMasks('IUPUI')>
		AND dbo.userHasMasks(u.user_id,  'iupui') = 1  
	</cfif>
	ORDER BY username
</cfquery>




<!---HTML--->
<center>
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
		<input  type="submit" name="action" value="Reset Consultants" title='"Reset Consultants" should only be used whenever the handbook experiences large changes that would require consultants to need to acknowledge it again.' onclick="return(confirm('Continuing will delete ALL existing handbook acknowledgements for all users.'))">
	</form>	
	<p></p>
	<br/><br/>
</center>
<div>
	<table align="center" class="stripe">
		<tr class="titlerow">
			<td colspan="3">Did Not Sign Handbook</td>
		</tr>
		<tr class="titlerow2">
			<th>Username</th>
			<th>Name</th>
			<th>Email</th>
		</tr>
	<cfoutput query="getSlackers">
		<tr>
			<td>
				#username#
			</td>
			<td>
				#first_name# #last_name#
			</td>
			<td>
				#email#
			</td>
		</tr>
	</cfoutput>
	</table>
</div>
<br/><br/>
<div>
	<table align="center" class="stripe">
		<tr class="titlerow">
			<td colspan="3">Did Sign Handbook</td>
		</tr>
		<tr class="titlerow2">
			<th>Username</th>
			<th>Name</th>
			<th>Date Signed</th>
		</tr>
	<cfoutput query="getSigners">
		<tr>
			<td>
				#username#
			</td>
			<td>
				#first_name# #last_name#
			</td>
			<td>
				#date_signed#
			</td>
		</tr>
	</cfoutput>
	</table>
</div>


<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>