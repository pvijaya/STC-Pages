<cfmodule template="#application.appPath#/header.cfm" title='Rehire Request Option Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- HEADER / NAVIGATION --->
<h1>Request Reason Editor</h1>
<a href="rehire-deadlines.cfm">Manage Deadlines</a> |
<a href="rehire-report.cfm">Report</a> |
<a href="rehire-request.cfm">Request</a> |
<br/><br/>

<!--- CFPARAMS --->
<cfparam name="action" type="string" default="">
<cfparam name="reasonName" type="string" default="">
<cfparam name="reasonSelected" type="integer" default="0">

<!---Logical Flow--->
<cfif action EQ "Create">
	<cfquery datasource="#application.applicationdatasource#" name="insertReason">
		INSERT INTO tbl_rehire_options(reason) 
		VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#reasonName#">)
	</cfquery>
	<p class='ok'>
		<b>Success</b>
		Reason created
	</p>
<cfelseif action EQ "Edit">
	<cfquery datasource="#application.applicationdatasource#" name="insertReason">
		UPDATE tbl_rehire_options
		SET reason = <cfqueryparam cfsqltype="cf_sql_varchar" value="#reasonName#">
		WHERE reason_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#reasonSelected#">
	</cfquery>
	<p class='ok'>
		<b>Success</b>
		Reason edited
	</p>
<cfelseif action EQ "Delete">
	<cfquery datasource="#application.applicationdatasource#" name="insertReason">
		DELETE tbl_rehire_options
		WHERE reason_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#reasonSelected#">
	</cfquery>
	<p class='ok'>
		<b>Success</b>
		Reason Deleted
	</p>
</cfif>


<!---Autopopulates request name into textbox---->
<cfquery datasource="#application.applicationdatasource#" name="returnedData">
	SELECT *
	FROM tbl_rehire_options
	WHERE reason_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#reasonSelected#">
</cfquery>
<cfloop query="returnedData">
	<cfset reasonName = reason>
</cfloop>



<cfquery datasource="#application.applicationdatasource#" name="getAllOptions">
	SELECT * 
	FROM tbl_rehire_options
</cfquery>
<cffunction name="reasonSelectbox">
	<cfoutput>
		<select  name="reasonSelected" onchange='this.form.submit();'>
			<option value='0'>--------</option>
		<cfloop query="getAllOptions">
			<cfif reasonSelected EQ getAllOptions.reason_id>
				<option value='#getAllOptions.reason_id#' SELECTED>#getAllOptions.reason#</option>
			<cfelse>
			<option value='#getAllOptions.reason_id#' >#getAllOptions.reason#</option>
			</cfif>
		</cfloop>
		</select>
	</cfoutput>
</cffunction>



<cfoutput>
<!---HTML--->

	<fieldset style='width:30%;display:inline-block;vertical-align:top;'>
	<legend>Create New Reason</legend>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
		<label>Text:
		<input  type="text" name="reasonName" placeholder="Sample Reason" />
		</label>
		<input  type="submit" name="action" value="Create"/> 

		</form>
	</fieldset>
	<fieldset style='width:30%;display:inline-block;vertical-align:top;'>
		<legend>Edit Reason</legend>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
		<label>Select Reason:
		#reasonSelectbox()#
		</label>
		<br/><br/>
		<label>Text:
		<input  type="text" name="reasonName" placeholder="Sample Reason" value="#reasonName#"/>
		<br/><br/>
		<input  type="submit" name="action" value="Edit" /> 	
		</form>
	</fieldset>
	<fieldset style='width:30%;display:inline-block;vertical-align:top;'>
		<legend>Delete Reason</legend>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">

		<label>Select Reason:
		#reasonSelectbox()#
		</label>
		<br/><br/>
		<input  type="submit" name="action" value="Delete" /> 
		</form>
	</fieldset>
</cfoutput>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
