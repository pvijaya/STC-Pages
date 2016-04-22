<cfmodule template="#application.appPath#/header.cfm" title='Update Contact Minutes Spent' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="CS">

<cfparam name="contactId" type="numeric" default="0">
<cfparam name="minutesSpent" type="numeric" default="0">
<cfparam name="action" type="string" default="">

<cfoutput>
	<h2>Contact ###contactId#</h2>
	<hr/>
</cfoutput>

<cfset existingMinutesSpent = 0>
<cfif action EQ "Update" AND contactId NEQ 0>
	<cfset oldMinutes = 0>
	<cfquery datasource="#application.applicationDataSource#" name="getOldTime">
		SELECT minutes_spent
		FROM tbl_contacts
		WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
	</cfquery>

	<cfloop query="getOldTime">
		<cfset oldMinutes = getOldTime.minutes_spent>
	</cfloop>

	<cfset minutesFrom="Minutes changed from " & "#oldMinutes#">
	<cfquery datasource="#application.applicationDataSource#" name="updateMinuteChange">
		INSERT tbl_contacts_notes(contact_id, user_id, note_text, note_ts)
		VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">,
							<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
							<cfqueryparam cfsqltype="cf_sql_varchar" value="#minutesFrom#">,
							<cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">)
	</cfquery>
	<cfquery datasource="#application.applicationDataSource#" name="getContact">
		UPDATE tbl_contacts
		SET minutes_spent = <cfqueryparam cfsqltype="cf_sql_integer" value="#minutesSpent#">
		WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
	</cfquery>

	<cfoutput>
		<div class="success">
			Contact updated!
		</div>
	</cfoutput>
</cfif>

<cfquery datasource="#application.applicationDataSource#" name="getContact">
		SELECT minutes_spent
		FROM tbl_contacts
		WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
	</cfquery>

<cfloop query="getContact">
	<cfset existingMinutesSpent = getContact.minutes_spent>
</cfloop>

<cfif getContact.RecordCount EQ 0 OR contactId EQ 0>
	<cfoutput>No contact exists with that ID</cfoutput>
</cfif>

<cfoutput>
	<form class="form-horizontal" method="Post">
	    <input id="contactId" type="hidden" name="contactId" value="#contactId#">
	    <div class="form-group">
	    	<label class="col-sm-2 control-label" for="minutesSpent">Minutes Spent</label>
	    <div class="col-sm-10">
		    <input id="minutesSpent" class="form-control" type="text" name="minutesSpent" value="#existingMinutesSpent#">
	    </div>
	  </div>
		<div class="col-sm-offset-2">
			<input class="btn btn-primary" name="action" type="submit" value="Update">
		</div>
	</form>
</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>