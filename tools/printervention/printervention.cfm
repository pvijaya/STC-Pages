<cfmodule template="#application.appPath#/header.cfm" title="Printer Intervention Form">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="iupui,consultant">

<h1>Printer Intervention Form</h1>
<cfif hasMasks("admin") OR hasMasks("logistics")>
	<a href="report.cfm">Printer Intervention Report</a>
</cfif>

<cfparam name="frmLabId" type="string" default="i0l0">
<cfparam name="frmTypeId" type="integer" default="0">
<cfparam name="frmPages" type="integer" default="0">
<cfparam name="frmPaperId" type="integer" default="1">
<cfparam name="frmPrinted" type="boolean" default="1">
<cfparam name="frmusername" type="string" default="">
<cfparam name="frmComments" type="string" default="">
<cfparam name="frmSubmit" type="string" default="">

<cfset myLab = parseLabName(frmLabId)><!---this breaks out our instance and lab id's from frmLabId.--->

<!---
	We need to fetch a good deal of data about each type, carefully sorted so we can group by categories.
	We'll use this to validate user input and later draw the selection of types.
--->
<cfquery datasource="#application.applicationDataSource#" name="getTypes">
	SELECT ptc.category_id, ptc.category_name, pt.type_id, pt.type_name, pt.require_comment, pt.retired
	FROM tbl_printerventions_types pt
	INNER JOIN tbl_printerventions_types_categories ptc ON ptc.category_id = pt.category_id
	WHERE pt.retired = 0
	ORDER BY ptc.category_name, pt.require_comment ASC, pt.type_name
</cfquery>

<!---the same goes for paper types--->
<cfquery datasource="#application.applicationDataSource#" name="getPaperTypes">
	SELECT paper_id, paper_type
	FROM tbl_printerventions_papers
	WHERE retired = 0
	ORDER BY paper_type
</cfquery>

<h2>Directions</h2>
<p>
	<a href="<cfoutput>#application.appPath#</cfoutput>/documents/article.cfm?articleId=974" target="_blank">Policies and Print Management</a>
</p>

<h2>Submit Details</h2>

<!---handle any user input that's been submitted.--->
<cfif frmSubmit eq "subForm">
	<cftry>
		<!---make sure we have all the required input--->
		<cfif myLab.instance eq 0 OR myLab.lab eq 0>
			<cfthrow message="Invalid Lab" detail="You must select a Lab from the drop-down menu.">
		</cfif>
		
		<!---make sure we have a real username, using LDAP, and pull some useful information about the user while we're at it.--->
		<cfset frmUsername = replace(frmUsername, "*", "", "all")><!---first strip any wildcards out of our username before talking to the LDAP server.--->
		<cfif trim(frmUsername) eq "">
			<cfthrow message="Invalid Username" detail="You must enter the username for the customer this printer intervention was for.">
		</cfif>
		
		<cfldap name="user_info" 
			username="#application.ldap_user#" 
			password="#application.ldap_password#" 
			action="query" 
			server="ads.iu.edu"
			start="ou=accounts,dc=ads,dc=iu,dc=edu"
			filter="cn=#frmUsername#"
			attributes="mail,givenName,displayName"
			port="389"
			timeout="5000"
		>
		
		<!---if we didn't get any matches we don't have a real ADS username. We may need to remove this throw if dealing with non-ads accounts, but there aren't many left.--->
		<cfif user_info.recordCount eq 0>
			<cfthrow message="Invalid Username" detail="The username <i>#htmlEditFormat(frmUsername)#</i> was not found in an LDAP lookup, please verify you have the correct username.">
		</cfif>
		
		<cfif frmPages lte 0>
			<cfthrow message="Invalid Number of Pages" detail="The Number of Pages must be a positive integer.">
		</cfif>
		
		<!---checking release types--->
		<cfset requireComment = 0>
		<cfset foundType = 0>
		<cfloop query="getTypes">
			<cfif type_id eq frmTypeId>
				<cfset foundType = 1>
				<cfset requireComment = require_comment>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---if at this point we haven't found the type_id we've got a bad one.--->
		<cfif foundType eq 0>
			<cfthrow message="Invalid Release Type" detail="You must select a Release Type from the form.">
		</cfif>
		
		<!---if comments are required, and we don't have any throw an error.--->
		<cfif requireComment AND trim(frmComments) eq "">
			<cfthrow message="Comment Required" detail="You must provide a Comment for the Release Type you have selected.">
		</cfif>
		
		<!---now make sure we have a valid paper Id--->
		<cfset foundType = 0>
		<cfloop query="getPaperTypes">
			<cfif paper_id eq frmPaperId>
				<cfset foundType = 1>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<cfif not foundType>
			<cfthrow message="Invalid Print Type" detail="You mus select a Print Type from the form.">
		</cfif>
		
		<!---If we got this far all of our input looks good, store it in the database.--->
		<cfquery datasource="#application.applicationDataSource#" name="addPrintervention">
			INSERT INTO tbl_printerventions (instance_id, lab_id, user_id, type_id, paper_id, page_count, printed, username, comments)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#myLab.instance#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#myLab.lab#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmTypeId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmPaperId#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#frmPages#">,
				<cfqueryparam cfsqltype="cf_sql_bit" value="#frmPrinted#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">,
				<cfqueryparam cfsqltype="comments" value="#frmComments#">
			)
		</cfquery>
		
		
		<p class="ok">
			Record created for <i><cfoutput>#frmUsername#</cfoutput></i>.
		</p>
		<!---reset the provided values--->
		<cfset frmLabId = "i0l0">
		<cfset frmTypeId = 0>
		<cfset frmPages = 0>
		<cfset frmprinted = 1>
		<cfset frmUsername = "">
		<cfset frmPaperId = 1>
		<cfset frmComments = "">
	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
</cfif>

<!---(re)draw the form.--->

<form method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
<input type="hidden" name="frmSubmit" value="subForm">
<table class="stripe">
	<tr class="titlerow">
		<td colspan="2">Printer Intervention</td>
	</tr>
	<tr>
		<td class="text-right">
			<label for="frmLabId">Lab:</label>
		</td>
		<td>
			<cfset drawLabsSelector("frmLabId", frmLabId, 0)>
		</td>
	</tr>
	
	<tr>
		<td class="text-right text-top">
			<label for="frmUsername">
				Customer:
			</label>
		</td>
		<td>
			<input type="text" size="10" id="frmUsername" name="frmUsername" placeholder="username" value="<cfoutput>#htmlEditFormat(frmUsername)#</cfoutput>">
		</td>
	</tr>
	
	<tr>
		<td class="text-right text-top">
			<label for="frmPages">
				Number of Pages:
			</label>
		</td>
		<td>
			<input type="text" name="frmPages" id="frmPages" size="2" value="<cfoutput>#frmPages#</cfoutput>">
		</td>
	</tr>
	
	<tr>
		<td></td>
		<td>
			<fieldset>
				<legend>Did pages print?</legend>
				
				<label>
					<input type="radio" name="frmPrinted" value="1" <cfif frmPrinted>checked="true"</cfif>>
					Yes
				</label>
				<label>
					<input type="radio" name="frmPrinted" value="0" <cfif not frmPrinted>checked="true"</cfif>>
					No
				</label>
			</fieldset>
		</td>
	</tr>
	
	
	<tr>
		<td></td>
		<td>
			
			<fieldset>
				<legend>Release Type:</legend>
				
				<cfoutput query="getTypes" group="category_id">
					<fieldset>
						<legend>#category_name#</legend>
						<cfoutput>
							<label>
								<input type="radio" name="frmTypeId" value="#type_id#" <cfif frmTypeId eq type_id>checked="true"</cfif>>
								#type_name#
							</label>
							<cfif require_comment>
								<span class="tinytext">*Comments required</span>
							</cfif>
							<br/>
						</cfoutput>
					</fieldset>
				</cfoutput>
			</fieldset>
		</td>
	</tr>
	

	
	<tr>
		<td></td>
		<td>
			
			<fieldset>
				<legend>Print Type:</legend>
				
				<cfoutput query="getPaperTypes">
					<label>
						<input type="radio" name="frmPaperId" value="#paper_id#" <cfif paper_id eq frmPaperId>checked="true"</cfif> >
						#paper_type#
					</label>
					<br/>
				</cfoutput>
			</fieldset>
		</td>
	</tr>
	
	
	
	<tr>
		<td class="text-right text-top">
			<label for="frmComments">
				Comments:
			</label>
		</td>
		<td>
			<textarea name="frmComments" id="frmComments"><cfoutput>#htmlEditFormat(frmComments)#</cfoutput></textarea>
			<br/>
			<span class="tinytext">
				Include reason for release, details of problem, simplex vs. duplex, and document name.
			</span>
		</td>
	</tr>
	
	<tr class="titlerow2">
		<td colspan="2" class="text-center">
			<input type="submit" value="Submit">
		</td>
	</tr>
</table>
</form>



<cfmodule template="#application.appPath#/footer.cfm">