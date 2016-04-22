<cfmodule template="#application.appPath#/header.cfm" title='Account Check Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<h1>Account Check Report</h1>
<a href="account-check.cfm">Account Check</a> | 
<a href="account-check-options.cfm">Edit Options</a>
<br/><br/>
<cfparam name="frmUsername" type="string" default="">
<cfparam name="frmlabId" type="string" default="">

<cfparam name="frmStartDate" type="date" default="#dateAdd('d', -7, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">

<!---parse the user provided lab name down to a usable struct.--->
<cfset mylabs = arrayNew(1)>
<cfloop list="#frmlabId#" index="n">
	<cfset arrayAppend(mylabs, parselabname(n))>
</cfloop>

<!---dates should be formatted as we like, and start date must always be earlier than end date--->
<cfset frmStartDate = dateFormat(frmStartDate, "mmm d, yyyy")>
<cfset frmEndDate = dateFormat(frmEndDate, "mmm d, yyyy")>

<cfif dateCompare(frmStartDate, frmEndDate) gt 0>
	<cfset tempStart = frmStartDate>
	<cfset frmStartDate = frmEndDate>
	<cfset frmEndDate = tempStart>
</cfif>
<!---done with our dates.--->

<form method="post">
	<fieldset>
		<legend>Report Parameters</legend>
		<p>
			<label>
				Start:
				<input type="text" class="picker" name="frmStartDate" value="<cfoutput>#frmStartDate#</cfoutput>">
			</label>
			
			<label>
				End:
				<input type="text" class="picker" name="frmEndDate" value="<cfoutput>#frmEndDate#</cfoutput>">
			</label>
		</p>
		
		<p>
			<label>
				Customer:
				<input type="text" name="frmUsername" size="10" value="<cfoutput>#htmlEditFormat(frmUsername)#</cfoutput>">
			</label>
			<span class="tinytext">(optional)</span>
		</p>
		
		<p>
			<label style="vertical-align:top;">
				labs:
				<cfset drawlabsSelector("frmlabId", frmlabId, 1)>
				<span class="tinytext" style="vertical-align:top;">(optional)</span>
			</label>
			
		</p>
		
		<p><input type="submit" value="Submit"></p>
	</fieldset>
</form>

<!---now make our date fields datepickers.--->
<script type="text/javascript">
	$(document).ready(function(){
		$("input.picker").datepicker({dateFormat: "M d, yy"});
	});
</script>

<!---now display the results based on the parameters we have.--->
<cfquery datasource="#application.applicationDataSource#" name="getChecks">
	SELECT c.check_id, c.customer_username, i.instance_id, i.instance_name, l.lab_id, l.lab_name, acc.category_name, u.username AS reporter, c.reporter_ip, c.check_date
	FROM tbl_account_checks c
	INNER JOIN tbl_users u ON u.user_id = c.reporter_id
	INNER JOIN tbl_account_check_match acm ON acm.check_id = c.check_id
	INNER JOIN tbl_account_check_categories acc ON acc.category_id = acm.category_id
	INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
	INNER JOIN vi_labs l 
		ON l.instance_id = i.instance_id
		AND l.lab_id = c.lab_id
	WHERE c.check_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate# 23:59:59.999">
	<!---now, if we have a username restrict to their checks.--->
	<cfif trim(frmUsername) neq "">
		AND LOWER(c.customer_username) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">)
	</cfif>
	<!---if they selected labs limit to just those labs--->
	<cfif arrayLen(mylabs) gt 0>
		<cfset cnt = 1>
		AND (
		<cfloop array="#mylabs#" index="thislab">
			(i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#thislab.instance#"> AND l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#thislab.lab#">)
			<cfif cnt lt arrayLen(mylabs)>OR</cfif>
			<cfset cnt = cnt + 1>
		</cfloop>
		)
	</cfif>
	
	ORDER BY i.instance_name, c.check_date, c.customer_username, c.check_id, acc.category_name
</cfquery>

<cfoutput query="getChecks" group="instance_id">
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="5">#instance_name#</td>
		</tr>
		
		<tr class="titlerow2">
			<th>Customer</th>
			<th>lab</th>
			<th>Accounts</th>
			<th>Reported By</th>
			<th>Date</th>
		</tr>
		
		<cfoutput group="check_id">
			<tr>
				<td>#customer_username#</td>
				<td>#lab_name#</td>
				<td>
					<cfoutput>
						<span class="ui-state-default ui-corner-all">#category_name#</span>
					</cfoutput>
				</td>
				<td>
					#reporter#
					<span class="tinytext" style="color: gray;"><br/>#reporter_ip#</span>
				</td>
				<td>
					#dateTimeFormat(check_date, "mmm d, yyyy h:nn aa")#
				</td>
			</tr>
		</cfoutput>
	</table>
</cfoutput>