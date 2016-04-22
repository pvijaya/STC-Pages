<cfmodule template="#application.appPath#/header.cfm" title='Printer Intervention Report'>
<!---we cannot simply use check-access.cfm here, because we want both folks with the CS OR Logistics masks to be able to use this page.--->
<cfif not hasMasks('Logistics') AND not hasMasks('CS')>
	<p>
		You do not have the masks required to view this page.
	</p>
	<cfabort>
</cfif>

<h1>Printer Intervention Report</h1>
<a href="printervention.cfm">Printer Intervention Form</a>


<cfset resultsPerPage = 50>
<cfparam name="frmPage" type="integer" default="0">
<cfset rangeStart = abs(frmPage * resultsPerPage) + abs(frmPage)>
<cfset rangeEnd = rangeStart + resultsPerPage>
<cfif rangeStart eq 0><cfset rangeStart = 1></cfif>


<cfparam name="frmUsername" type="string" default="">
<cfparam name="frmLabId" type="string" default="i0l0">
<cfset myLabs = arrayNew(1)>
<cfloop list="#frmLabId#" index="labName">
	<cfset arrayAppend(myLabs, parseLabName(labName))>
</cfloop>
<cfparam name="frmTypeIds" type="string" default="">
<cfparam name="frmPaperIds" type="string" default="">
<cfparam name="frmStatusIds" type="string" default="">
<cfparam name="frmStartDate" type="date" default="#dateAdd("m", -1, NOW())#">
<cfparam name="frmEndDate" type="date" default="#now()#">

<!---trim off dangling date parts from start and end dates--->
<cfset frmStartDate = dateFormat(frmStartDate, "mmm d, yyyy")>
<cfset frmEndDate = dateFormat(frmEndDate, "mmm d, yyyy")>

<!---here that we have all the search parameters we can build up a url string version of it for use with pagination and resolution links.--->
<cfset searchString = "frmUsername=#urlEncodedFormat(frmUsername)#&frmLabId=#urlEncodedFormat(frmLabId)#&frmTypeIds=#urlEncodedFormat(frmTypeIds)#&frmPaperIds=#urlEncodedFormat(frmPaperIds)#&frmStatusIds=#urlEncodedFormat(frmStatusIds)#&frmStartDate=#urlEncodedFormat(frmStartDate)#&frmEndDate=#urlEncodedFormat(frmEndDate)#">

<!---handle user input for marking interventions as resolved.--->
<cfparam name="frmInterventionId" type="integer" default="0">
<cfparam name="frmMarkResolved" type="boolean" default="false">
<cfif frmInterventionId gt 0 and frmMarkResolved>
	<cfquery datasource="#application.applicationDataSource#" name="resolveIntervention">
		UPDATE tbl_printerventions
		SET resolved = 1,
			resolved_by = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
			resolved_date = GETDATE()
		WHERE intervention_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInterventionId#">
	</cfquery>
	
	<p class="ok">
		Intervention <cfoutput>###frmInterventionId#</cfoutput> has been marked resolved.
	</p>
</cfif>


<!---draw the form to limit search results--->
<h2>Report Parameters</h2>

<form method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
<fieldset>
	<legend>Limit Results</legend>
	<cfoutput>
		<p>
			<label>
				Customer:
				<input type="text" name="frmUsername" placeholder="any" value="#htmlEditFormat(frmUsername)#">
			</label>
		</p>
		
		<p>
			<label>
				Lab(s):
				<cfset drawLabsSelector("frmLabId", frmLabId, 1)>
			</label>
		</p>
	</cfoutput>	
	<!---now we need to fetch all the active types of categories, and draw them as checkboxes.--->
	<cfquery datasource="#application.applicationDataSource#" name="getTypes">
		SELECT pt.type_id, pt.category_id, ptc.category_name, pt.type_name
		FROM tbl_printerventions_types pt
		INNER JOIN tbl_printerventions_types_categories ptc ON ptc.category_id = pt.category_id
		WHERE pt.retired = 0
		ORDER BY ptc.category_name, pt.require_comment ASC, pt.type_name
	</cfquery>
	
	<fieldset>
		<legend>Release Type</legend>
		<cfoutput query="getTypes" group="category_id">
			<div class="shadow-border">
				<b>#category_name#</b><br/>
				<cfoutput>
					<label>
						<input type="checkbox" name="frmTypeIds" value="#type_id#" <cfif listFind(frmTypeIds, type_id) OR listLen(frmTypeIds) eq 0>checked="true"</cfif> />
						#type_name#
					</label>
				</cfoutput>
			</div>
		</cfoutput>
	</fieldset>
	
	<!---now do the same for the print type.--->
	<cfquery datasource="#application.applicationDataSource#" name="getPrintType">
		SELECT paper_id, paper_type
		FROM tbl_printerventions_papers
		WHERE retired = 0
		ORDER BY paper_type
	</cfquery>
	
	<fieldset>
		<legend>Print Type</legend>
		
		<cfoutput query="getPrintType">
			<label>
				<input type="checkbox" name="frmPaperIds" value="#paper_id#" <cfif listContains(frmPaperIds, paper_id) OR listLen(frmPaperIds) eq 0>checked="true"</cfif> />
				#paper_type#
			</label>
		</cfoutput>
	</fieldset>
	
	<fieldset>
		<legend>Status</legend>
		<label>
			<input type="checkbox" name="frmStatusIds" value="0" <cfif listFind(frmStatusIds, 0) OR listLen(frmStatusIds) eq 0>checked="true"</cfif> />
			Open
		</label>
		<label>
			<input type="checkbox" name="frmStatusIds" value="1" <cfif listFind(frmStatusIds, 1) OR listLen(frmStatusIds) eq 0>checked="true"</cfif> />
			Resolved
		</label>
	</fieldset>
	
	<cfoutput>
		<fieldset>
			<legend>Submitted Between</legend>
			
			<label>
				Start:
				<input type="text" class="calendar" name="frmStartDate" value="#dateFormat(frmStartDate, "mmm d, yyyy")#">
			</label>
			<label>
				End:
				<input type="text" class="calendar" name="frmEndDate" value="#dateFormat(frmEndDate, "mmm d, yyyy")#">
			</label>
		</fieldset>
	</cfoutput>
	<input type="submit" value="Run Report">
</fieldset>
</form>

<!---turn our date inputs into jquery calendars.--->
<script type="text/javascript">
	$(document).ready(function(){
		$("input.calendar").datepicker({
			dateFormat: 'M d, yy',
			changeMonth: true,
			changeYear: true,
			minDate: "Feb 19, 2008",
			maxDate: "<cfoutput>#dateFormat(now(), 'mmm d, yyyy')#</cfoutput>"
		});
	});
</script>

<!---the query to fetch search results--->
<cfquery datasource="#application.applicationDataSource#" name="getInterventions">
	SELECT x.*
	FROM (
		SELECT ROW_NUMBER() OVER(ORDER BY p.submitted_date DESC) AS cnt_id, 
			p.intervention_id, p.username, i.instance_name, l.lab_name, p.page_count, p.printed, ptc.category_name, pt.type_name, pap.paper_type, u.username AS submitted_by, p.comments, p.resolved, r.username AS resolved_by, p.resolved_date, p.submitted_date
		FROM tbl_printerventions p
		INNER JOIN tbl_users u ON u.user_id = p.user_id
		INNER JOIN tbl_instances i ON i.instance_id = p.instance_id
		INNER JOIN vi_labs l
			ON l.instance_id = p.instance_id
			AND l.lab_id = p.lab_id
		INNER JOIN tbl_printerventions_types pt ON pt.type_id = p.type_id
		INNER JOIN tbl_printerventions_types_categories ptc ON ptc.category_id = pt.category_id
		INNER JOIN tbl_printerventions_papers pap ON pap.paper_id = p.paper_id
		LEFT OUTER JOIN tbl_users r ON r.user_id = p.resolved_by
		
		WHERE p.submitted_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate# 00:00"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate# 23:59:59.999"> 
		
		<cfif trim(frmUsername) neq "">
			AND p.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmusername#">
		</cfif>
		
		<cfif frmLabId neq "i0l0"><!---a value was actually submitted, that's just our default value.--->
			<cfset cnt = 1>
			AND (
			<cfloop array="#myLabs#" index="lab">
				<cfif cnt gt 1>OR </cfif>(p.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#lab.instance#"> AND p.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#lab.lab#">)
				<cfset cnt = cnt + 1>
			</cfloop>
			)
		</cfif>
		
		<cfif listLen(frmTypeIds) gt 0>
			AND p.type_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmTypeIds#" list="true">)
		</cfif>
		
		<cfif listLen(frmPaperIds) gt 0>
			AND p.paper_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmPaperIds#" list="true">)
		</cfif>
		
		<cfif listLen(frmStatusIds) gt 0>
			AND resolved IN (<cfqueryparam cfsqltype="cf_sql_bit" value="#frmStatusIds#" list="true">)
		</cfif>
		
	) x
	WHERE x.cnt_id BETWEEN <cfqueryparam cfsqltype="cf_sql_integer" value="#rangeStart#"> AND <cfqueryparam cfsqltype="cf_sql_integer" value="#rangeEnd#">
</cfquery>

<!---for pagination we need to know how many total results there are based on the report criteria.--->
<cfquery datasource="#application.applicationDataSource#" name="getTotalInterventions">
	SELECT COUNT(DISTINCT p.intervention_id) AS intervention_total
		FROM tbl_printerventions p
		INNER JOIN tbl_users u ON u.user_id = p.user_id
		INNER JOIN tbl_instances i ON i.instance_id = p.instance_id
		INNER JOIN vi_labs l
			ON l.instance_id = p.instance_id
			AND l.lab_id = p.lab_id
		INNER JOIN tbl_printerventions_types pt ON pt.type_id = p.type_id
		INNER JOIN tbl_printerventions_types_categories ptc ON ptc.category_id = pt.category_id
		INNER JOIN tbl_printerventions_papers pap ON pap.paper_id = p.paper_id
		LEFT OUTER JOIN tbl_users r ON r.user_id = p.resolved_by
		
		WHERE p.submitted_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate# 00:00"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate# 23:59:59.999"> 
		
		<cfif trim(frmUsername) neq "">
			AND p.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmusername#">
		</cfif>
		
		<cfif frmLabId neq "i0l0"><!---a value was actually submitted, that's just our default value.--->
			<cfset cnt = 1>
			AND (
			<cfloop array="#myLabs#" index="lab">
				<cfif cnt gt 1>OR </cfif>(p.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#lab.instance#"> AND p.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#lab.lab#">)
				<cfset cnt = cnt + 1>
			</cfloop>
			)
		</cfif>
		
		<cfif listLen(frmTypeIds) gt 0>
			AND p.type_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmTypeIds#" list="true">)
		</cfif>
		
		<cfif listLen(frmPaperIds) gt 0>
			AND p.paper_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#frmPaperIds#" list="true">)
		</cfif>
		
		<cfif listLen(frmStatusIds) gt 0>
			AND resolved IN (<cfqueryparam cfsqltype="cf_sql_bit" value="#frmStatusIds#" list="true">)
		</cfif>
</cfquery>

<cfset interventionsTotal = 0>
<cfloop query="getTotalInterventions">
	<cfset interventionsTotal = intervention_total>
</cfloop>


<!---draw the results--->
<h2>Interventions</h2>

<!---draw our pagination links--->
<cfset drawPage()>

<table class="stripe">
	<tr class="titlerow">
		<td colspan="6">Printer Interventions</td>
	</tr>
	
	<tr class="titlerow2">
		<th>Customer</th>
		<th>Lab</th>
		<th>Release Type</th>
		<th>Print Type</th>
		<th>Submitted</th>
		<th>Resolved</th>
	</tr>
	
	<cfoutput query="getInterventions">
		<tr>
			<td>
				#username#
			</td>
			<td>
				#instance_name# #lab_name#
			</td>
			<td>
				#category_name#: #type_name#
			</td>
			<td>
				#paper_type#<br/>
				<span class="tinytext">
					<em>#numberFormat(page_count, ",")# pages</em>
					<cfif not printed>
						<b>Did not print</b>
					</cfif>
				</span>
			</td>
			<td>
				#dateTimeFormat(submitted_date, "mmm d, yyyy h:nn aa")#<br/>
				by <em>#submitted_by#</em>
			</td>
			<td>
				<cfif resolved>
					#dateTimeFormat(resolved_date, "mmm d, yyyy h:nn aa")#<br/>
					by <em><cfif resolved_by neq "">#resolved_by#<cfelse>Unknown</cfif></em>
				<cfelse>
					[<a href="#cgi.script_name#?frmInterventionId=#intervention_id#&frmMarkResolved=1&#searchString#" onClick="return confirm('Are you sure you wish to mark this intervention as resolved?');">Resolve</a>]
				</cfif>
			</td>
		</tr>
	</cfoutput>
</table>

<!---draw our pagination links--->
<cfset drawPage()>

<cfmodule template="#application.appPath#/footer.cfm">


<!---draw the links for navigating between pages --->
<cffunction name="drawPage">
	<!---figure out the maximum number of pages based on our resultsPerPage--->
	<cfset var maxPage = iif(interventionsTotal mod resultsPerpage gt interventionsTotal\resultsPerpage, interventionsTotal\resultsPerpage + 1, interventionsTotal\resultsPerpage)>
	
	<cfoutput>Displaying records #rangeStart# to #iif(rangeEnd gt interventionsTotal, interventionsTotal, rangeEnd)# of #numberFormat(interventionsTotal,",")#<br/></cfoutput>
	
	<cfif interventionsTotal gt resultsPerPage>
		<cfif frmPage gt 0>
			<cfoutput><a href="#cgi.script_name#?frmPage=0&#searchString#">&lt;&lt;</a> <a href="#cgi.script_name#?frmPage=#frmPage-1#&#searchString#">&lt;</a></cfoutput>
		</cfif>
		
		<cfoutput>Page #frmPage+1# of #maxPage#</cfoutput>
		
		<cfif rangeEnd lt interventionsTotal>
			<cfoutput><a href="#cgi.script_name#?frmPage=#frmPage+1#&#searchString#">&gt;</a> <a href="#cgi.script_name#?frmPage=#maxPage-1#&#searchString#">&gt;&gt;</a></cfoutput>
		</cfif>
	</cfif>
</cffunction>