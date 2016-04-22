<cfmodule template="#application.appPath#/header.cfm" title='Acount Check Options Editor'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<h1>Acount Check Options Editor</h1>
<a href="account-check-options.cfm">Reset Page</a> | 
<a href="account-check.cfm">Account Check</a> | 
<a href="report.cfm">Reports</a>
<br/><br/>
<cfparam name="instanceSelected" type="integer" default="0">
<cfparam name="optionId" type="integer" default="0">
<cfparam name="categoryName" type="string" default="">
<cfparam name="action" type="string" default="">

<!---Resolves instances--->
<cfset instanceList = userHasInstanceList().instanceList>
<cfset instanceNameList = userHasInstanceList().nameList>
<cfif ListLen(instanceList) GTE 2 AND instanceSelected EQ 0>
	<cfoutput>
	<form action='<cfoutput>#cgi.script_name#</cfoutput>' method='post' enctype="multipart/form-data" >
		<cfif ListLen(instanceList) GTE 2>
			<label for="instanceSelected">Campus:</label> 
			<select  id="instanceSelected" name="instanceSelected">
			<cfloop list="#instanceList#" index="i">
				<option <cfif instanceSelected EQ i>selected="selected"</cfif> value="#i#">#ListGetAt(instanceNameList,i)#</option>
			</cfloop>
			</select>
		</cfif>
		<input type="submit"  name="action" value="Select"/>
	</form>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
	</cfoutput>
<cfelseif ListLen(instanceList) GTE 2 AND instanceSelected NEQ 0>
	<!---do nothing--->
<cfelse>
	<cfset instanceSelected = instanceList>
</cfif>

<!---Once we have the instance--->
<cfif instanceSelected NEQ 0>
	<cfif action EQ "Create">
		<cftry>
			<cfquery name='createAccountCheckOption' datasource="#application.applicationdatasource#" >
				INSERT INTO tbl_account_check_categories(category_name, instance)
				VALUES (<cfqueryparam cfsqltype="cf_sql_string" value="#categoryName#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">)
			</cfquery>
			<p class="ok">
				<b>Success</b>
				Option inserted!
			</p>
			<cfcatch>
				<cfoutput>
				<p class="warning">
				<b>Error</b>
				#cfcatch.message# - #cfcatch.Detail#
				</p>
				</cfoutput>
			</cfcatch>
		</cftry>
	<cfelseif action EQ "Delete">
				<cftry>
			<cfquery name='deleteAccountCheckOption' datasource="#application.applicationdatasource#" >
				DELETE FROM tbl_account_check_categories
				WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#optionId#">
				AND instance = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
			</cfquery>
			<p class="ok">
				<b>Success</b>
				Option deleted!
			</p>
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
	<cfquery name='accountCheckOptions' datasource="#application.applicationdatasource#" >
		SELECT *
		FROM tbl_account_check_categories
		WHERE instance = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceSelected#">
	</cfquery>
	
	<!---HTML--->
	<cfoutput>
	<fieldset style="width:45%;float:left;">
	<legend>Create Account Check Option</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">
		<input type="text"  name="categoryName">
		<input type="submit"  name="action" value="Create">
	</form>
	</fieldset>
	<fieldset style="width:45%;float:right;">
	<legend>Delete Account Check Option</legend>
	<form action="#cgi.script_name#" method="POST">
		<input type="hidden" name="instanceSelected" value="#instanceSelected#">
		
		<select  name="optionId">
		<cfloop query="accountCheckOptions">
			<option value="#category_id#">#category_name#</option>
		</cfloop>
		</select>
		<input type="submit"  name="action" value="Delete">
	</form>
	</fieldset>
	</cfoutput>
	
<cfelse>
	<p class="warning">
		<span>Error</span> - You do not belong to any instance.
	</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>