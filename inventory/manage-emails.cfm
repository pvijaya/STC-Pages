<cfmodule template="#application.appPath#/header.cfm" title='Inventory Email Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!---include common inventory functions--->
<cfinclude template="#application.appPath#/inventory/inventory-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmAction" type="string" default="list">
<cfparam name="frmMailId" type="integer" default="0">
<cfparam name="frmMailName" type="string" default="">
<cfparam name="frmRecipientList" type="string" default="">
<cfparam name="frmTitle" type="string" default="">
<cfparam name="frmActive" type="boolean" default="1">

<!--- HEADER / NAVIGATION --->
<h1>Inventory Email Manager</h1>
<a href="<cfoutput>#application.appPath#/inventory/management.cfm</cfoutput>">Go Back</a> | 
<a href="<cfoutput>#cgi.script_name#</cfoutput>">Edit Existing Emails</a> | 
<a href="<cfoutput>#cgi.script_name#?frmAction=add</cfoutput>">Add a New Email</a>

<!--- HANDLE USER INPUT --->
<cftry>
	
	<cfif frmAction EQ "addSubmit">
	
		<!---verify all input is good.--->
		<cfif trim(frmMailName) eq "">
			<cfthrow type="custom" message="Missing Input" detail="Mail Name is a required field.">
		</cfif>
		
		<cfset cleanList = checkRecipients(frmRecipientList)>
		<cfif listLen(cleanList) neq listLen(frmRecipientLIst)>
			<cfset frmRecipientList = cleanList>
			<cfthrow type="custom" message="Bad Input" detail="Malformed email addresses were found and removed from Recipients.  Please be sure the list is correct.">
		</cfif>
		
		<cfset frmRecipientList = cleanList>
		<cfif frmRecipientList eq "">
			<cfthrow type="custom" message="Missing Input" detail="Recipients is a required field.">
		</cfif>
		
		<cfif frmTitle eq "">
			<cfthrow type="custom" message="Missing Input" detail="Subject is a required field.">
		</cfif>
		
		<!---at this point all the input is good, add the email to the databse--->
		<cfquery datasource="#application.applicationDataSource#" name="addEmail">
			INSERT INTO tbl_inventory_emails (mail_name, recipient_list, title)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMailName#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmRecipientList#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTitle#">
			)
		</cfquery>
		
		<p class="ok">
			Email added successfully.
		</p>
		
		<!---take them back to the list page.--->
		<cfset frmAction = "list">
	
	<cfelseif frmAction EQ "editSubmit">
			
		<!---verify all input is good.--->
		<cfif trim(frmMailName) eq "">
			<cfthrow type="custom" message="Missing Input" detail="Mail Name is a required field.">
		</cfif>
		
		<cfset cleanList = checkRecipients(frmRecipientList)>
		<cfif listLen(cleanList) neq listLen(frmRecipientLIst)>
			<cfset frmRecipientList = cleanList>
			<cfthrow type="custom" message="Bad Input" detail="Malformed email addresses were found and removed from Recipients.  Please be sure the list is correct.">
		</cfif>
		
		<cfset frmRecipientList = cleanList>
		<cfif frmRecipientList eq "">
			<cfthrow type="custom" message="Missing Input" detail="Recipients is a required field.">
		</cfif>
		
		<cfif frmTitle eq "">
			<cfthrow type="custom" message="Missing Input" detail="Subject is a required field.">
		</cfif>
		
		<!---at this point all the input is good, update the email in the databse--->
		<cfquery datasource="#application.applicationDataSource#" name="editEmail">
			UPDATE tbl_inventory_emails
			SET	mail_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmMailName#">,
				recipient_list = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmRecipientList#">,
				title = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmTitle#">,
				active = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmActive#">
			WHERE mail_id = #frmMailId#
		</cfquery>
		
		<p class="ok">
			Email updated successfully.
		</p>
		
		<cfset frmAction = "list">
		
	</cfif>

<cfcatch type="any">
	<cfif frmAction EQ "addSubmit">
		<cfset frmAction = "add"> <!---bounce them back to the add form.--->
	<cfelseif frmAction EQ "editSubmit">
		<cfset frmAction = "edit">
	</cfif>
	<p class="warning">
		<cfoutput>#cfcatch.message# - #cfcatch.Detail#</cfoutput>
	</p>
</cfcatch>

</cftry>

<!--- DRAW FORMS --->
<cfif frmAction EQ "add">

	<h3>New Email</h3>
	
	<cfoutput>
		
		<form action="#cgi.script_name#" method="post">
			<input type="hidden" name="frmAction" value="addSubmit">
			<fieldset>
				<legend>Add Email</legend>
				
				<label>Mail Name: <input type="text" name="frmMailName" size="15" value="#htmlEditFormat(frmMailName)#"></label><br/>
				<label>Recipient(s): <input type="text" name="frmRecipientList" size="128" value="#htmlEditFormat(frmRecipientList)#"></label><br/>
				<span class="tinytext">Recipients should be valid email addresses seperated by commas.</span><br/>
				<label>Subject: <input type="text" name="frmTitle" size="15" value="#htmlEditFormat(frmTitle)#"></label><br/>
				<span class="tinytext">The subject will be in the form "<i>Subject</i> for <i>Lab Name</i>".</span><br/>
				
				<input  type="submit" value="Add">
			</fieldset>
		</form>
		
	</cfoutput>
	
<cfelseif frmAction EQ "edit">

	<h3>Edit Email</h3>
		
	<!---fetch the details of the email from the database--->
	<cfquery datasource="#application.applicationDataSource#" name="getEmail">
		SELECT mail_name, recipient_list, title, active
		FROM tbl_inventory_emails
		WHERE mail_id = #frmMailId#
	</cfquery>
	
	<cfloop query="getEmail">
		<cfif frmMailName eq "">
			<cfset frmMailName = mail_name>
		</cfif>
		<cfif frmRecipientList eq "">
			<cfset frmRecipientList = recipient_list>
		</cfif>
		<cfif frmTitle eq "">
			<cfset frmTitle = title>
		</cfif>
		<cfif not isDefined("form.frmActive") AND not isDefined("url.frmActive")>
			<cfset frmActive = active>
		</cfif>
	</cfloop>
	
	<cfoutput>
		<form action="#cgi.script_name#" method="post">
			<input type="hidden" name="frmAction" value="editSubmit">
			<input type="hidden" name="frmMailId" value="<cfoutput>#frmMailId#</cfoutput>">
			<fieldset>
				<legend>Add Email</legend>
				
				<label>Mail Name: <input type="text" name="frmMailName" size="15" value="#htmlEditFormat(frmMailName)#"></label><br/>
				<label>Recipient(s): <input type="text" name="frmRecipientList" size="128" value="#htmlEditFormat(frmRecipientList)#"></label><br/>
				<span class="tinytext">Recipients should be valid email addresses seperated by commas.</span><br/>
				<label>Subject: <input type="text" name="frmTitle" size="15" value="#htmlEditFormat(frmTitle)#"></label><br/>
				<span class="tinytext">The subject will be in the form "<i>Subject</i> for <i>Lab Name</i>".</span><br/>
				
				<fieldset>
					<legend>Active:</legend>
					<label><input type="radio" name="frmActive" value="1" <cfif frmActive>checked="true"</cfif>>Yes</label>
					<label><input type="radio" name="frmActive" value="0" <cfif not frmActive>checked="true"</cfif>>No</label>
				</fieldset>
				
				<input  type="submit" value="Edit">
			</fieldset>
		</form>
		
	</cfoutput>
		
<cfelseif frmAction EQ "list">
	
	<h3>Edit Email</h3>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllEmails">
		SELECT mail_id, mail_name, active
		FROM tbl_inventory_emails
		ORDER BY active DESC, mail_name
	</cfquery>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<input type="hidden" name="frmAction" value="edit">
		<fieldset>
			<legend>Select Email</legend>
			
			<select  name="frmMailId">
			<cfoutput query="getAllEmails">
				<option value="#mail_id#">#mail_name#<cfif not active>(retired)</cfif></option>
			</cfoutput>
			</select>
			
			<input  type="submit" value="Edit">
		</fieldset>
	</form>
		
</cfif>

<!--- CFFUNCTIONS --->
<!---takes the user provided list of recipients.  Makes sure every item is a valid email addres, removes duplicates, and returns a neatly formatted list.--->
<cffunction name="checkRecipients">
	<cfargument name="userMailList" type="string" required="true">
	
	<cfset var cleanMailList = "">
	<cfset var item = "">
	
	<cfloop list="#userMailList#" index="item">
		<cfset item = trim(item)>
		<cfif isValid("email", item) AND not listFindNoCase(cleanMailList, item)>
			<cfset cleanMailList = listAppend(cleanMailList, item)>
		</cfif>
	</cfloop>
	
	<cfreturn cleanMailList>
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">