<cfmodule template="#application.appPath#/header.cfm" title='Cleaning Submissions' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmCleaningId" type="integer" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d",-1,now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<cfparam name="frmUser" type="integer" default="0">

<!--- Header / Navigation --->
<h1>Cleaning Submissions</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 1em;">
	<cfif hasMasks("Admin")>
		[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_manager.cfm</cfoutput>">Manage Labs</a>]
	</cfif>
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_cleaning.cfm</cfoutput>">Submit a Cleaning</a>]
</p>	

<!--- sanitize our dates for searching --->
<cfset frmStartDate = dateFormat(frmStartDate, "mmm d, yyyy ") & "00:00">
<cfset frmEndDate = dateFormat(frmEndDate, "mmm d, yyyy ") & "23:59:59.9">

<cfif frmAction EQ "Clear">
	<cfset frmAction = "">
	<cfset frmCleaningId = "0">
	<cfset frmUser = "0">
	<cfset frmStartDate = "#dateAdd("d", -1, now())#">
	<cfset frmEndDate = "#now()#">
</cfif>

<!--- draw forms --->

<!--- when showing search results, collapse our form --->
<cfif frmAction EQ "Search">
	<span class="trigger">Search Parameters</span>
<cfelse>
	<span class="triggerexpanded">Search Parameters</span>
</cfif>

<div>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	
		<!--- get existing labs --->
		<cfquery datasource="#application.applicationDataSource#" name="getLabs">
			SELECT cl.cleaning_id, l.lab_name, cl.retired, cl.instance_id
			FROM tbl_cleaning_labs cl
			INNER JOIN vi_labs l ON l.lab_id = cl.lab_id AND l.instance_id = cl.instance_id
			ORDER BY cl.retired, l.lab_name
		</cfquery>
		
		<!--- get users who have submitted cleanings --->	
		<cfquery datasource="#application.applicationDataSource#" name="getUsers">
			SELECT DISTINCT a.user_id, b.username, b.last_name, b.first_name
			FROM tbl_cleaning_submissions a
			INNER JOIN tbl_users b ON a.user_id = b.user_id
			ORDER BY b.last_name, b.first_name, b.username
		</cfquery>	
		
		<fieldset>
			
			<legend>Choose Search Parameters</legend>
			
			<label for="frmFormId">Lab:</label>
				<select name="frmCleaningId">
					<option value = "0">
					<cfoutput query="getLabs">
						<option value="#cleaning_id#"
								<cfif frmCleaningId EQ cleaning_id>selected="selected"</cfif>>
							#lab_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>	
			
			<br/><br/>
					
			<cfoutput>
				<label>From: <input class="date" name="frmStartDate" value="#dateFormat(frmStartDate,  "MMM d, yyyy")#"></label>
				<label>To: <input class="date" name="frmEndDate" value="#dateFormat(frmEndDate,  "MMM d, yyyy")#"></label>
			</cfoutput>
			
			<script type="text/javascript">
				$(document).ready(function() {
				// make the dates calendars.
				$("input.date").datepicker({dateFormat: 'M d, yy'});
				});
			</script>
			
			<br/><br/>
			
			<label for="frmUserFor">Submitted By:</label>
				<select name="frmUser">
					<option value = "0">
					<cfoutput query="getUsers">
						<option value="#user_id#"
								<cfif frmUser EQ user_id>selected="selected"</cfif>>
							#last_name#, #first_name# (#username#)
						</option>
					</cfoutput>
				</select>
			</label>	
			
		</fieldset>
		
		<p class="submit">
			<input type="submit" value="Search" name="frmAction">
			<input type="submit" value="Clear" name="frmAction">
		</p>	
			
	</form>
	
</div>

<!--- search --->

<cfif frmAction EQ "Search">

	<cfquery datasource="#application.applicationDataSource#" name="getSearchResults">
		SELECT DISTINCT TOP 100 a.submission_id, a.cleaning_id, a.section_id, a.user_id, a.comments, a.date_cleaned,
								b.instance_id, c.section_image, c.section_description, d.username
		FROM tbl_cleaning_submissions a
		INNER JOIN tbl_cleaning_labs b ON b.cleaning_id = a.cleaning_id
		INNER JOIN tbl_cleaning_labs_sections c ON c.section_id = a.section_id
		INNER JOIN tbl_users d ON d.user_id = a.user_id
		WHERE a.date_cleaned BETWEEN <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmStartDate#"> AND
								        <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmEndDate#">
		<cfif frmCleaningId GT 0> AND a.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#"></cfif>
		<cfif frmUser GT 0> AND a.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUser#"></cfif>
		ORDER BY a.date_cleaned DESC
	</cfquery>

	<h1>Search Results</h1>
	<table class="stripe" style="padding:0px;">
		<tr class="titlerow" style="padding:5px;">
			<th>Image</th>
			<th>Lab</th>
			<th>Section</th>
			<th>Cleaned By</th>
			<th>Date</th>
			<th>Comments</th>
		</tr>
		<cfloop query="getSearchResults">
			
			<cfquery datasource="#application.applicationDataSource#" name="getLab">
				SELECT l.lab_name
				FROM tbl_cleaning_labs cl
				INNER JOIN vi_labs l ON l.lab_id = cl.lab_id AND l.instance_id = cl.instance_id
				WHERE cl.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#cleaning_id#">
			</cfquery>
			
			<cfquery datasource="#application.applicationDataSource#" name="getSection">
				SELECT l.lab_name
				FROM tbl_cleaning_labs_sections cls
				INNER JOIN tbl_cleaning_labs cl ON cl.cleaning_id = cls.cleaning_id
				INNER JOIN vi_labs l ON l.lab_id = cls.lab_id AND l.instance_id = cl.instance_id
				WHERE cls.section_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#section_id#">
			</cfquery>
			
			<cfoutput>
				<tr>
					<td><cfif section_image NEQ "">
							<a href="#section_image#">Link</a>
						<cfelse>
							None
						</cfif>
					</td>
					<td>#getLab.lab_name#</td>
					<td>#getSection.lab_name#
						<cfif section_description NEQ "">
						- #section_description#
						</cfif>	
					</td>
					<td>#username#</td>
					<td class="tinytext">#dateFormat(date_cleaned, "MMM d, yyyy")# 
						                 #timeFormat(date_cleaned, "h:mm tt")#</td>
					<td><cfif comments EQ "">None<cfelse>#comments#</cfif></td>
				</tr>	
			</cfoutput>	
		</cfloop>
	</table>

</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>