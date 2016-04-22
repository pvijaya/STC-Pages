<cfmodule template="#application.appPath#/header.cfm" title='Account Check' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="selector" default="{}">
<!--- CFPARAMS --->
<cfparam name="action" type="string" default="">
<cfparam name="frmUsername" type="string" default="">

<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="checkType" default="[]">

<cfset myInstance = getInstanceById(session.primary_instance)>

<!--- HEADER / NAVIGATION --->
<h1>Account Check</h1>
<cfif hasMasks('admin')>
	<a href="account-check-options.cfm">Edit Options</a> |
	<a href="report.cfm">Reports</a>
</cfif>
<br/><br/>

<!--- QUERIES --->
<cfquery datasource="#application.applicationDataSource#" name="getAccountCategories">
	SELECT acc.category_id, acc.category_name, i.instance_id, i.instance_name
	FROM tbl_account_check_categories acc
	INNER JOIN tbl_instances i ON i.instance_id = acc.instance
	WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	ORDER BY i.instance_name, acc.category_name
</cfquery>

<!--- HANDLE USER INPUT --->
<cfif action EQ "Submit">
	<cftry>
		<!---verify we have all the input we need.--->

		<cfif trim(frmUsername) eq "">
			<cfthrow message="Missing Input" detail="You must provide the username for the unattended account.">
		</cfif>
		<cfif selector.lab_id eq 0 OR selector.instance_id eq 0>
			<cfthrow message="Missing Input" detail="You must select the lab where the account was left unattended.">
		</cfif>
		<cfif arrayLen(checkType) eq 0>
			<cfthrow message="Missing Input" detail="You must select at least one account type that was left unattended.">
		</cfif>
		<!---parse our lab to get the instance_id and lab_id.--->
		<cfset instanceLabStruct = parselabname("i#selector.instance_id#l#selector.lab_id#")>
		<cfif instanceLabStruct.lab eq 0>
			<cfthrow message="Bad Input" detail="The lab you selected does not appear to exist in the database.">
		</cfif>

		<!---make sure we have a real username, using LDAP, and pull some useful information about the user while we're at it.--->
		<cfset frmUsername = replace(frmUsername, "*", "", "all")><!---first strip any wildcards out of our username before talking to the LDAP server.--->
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
			<cfthrow message="Bad Username" detail="The username <i>#htmlEditFormat(frmUsername)#</i> was not found in an LDAP lookup, please verify you have the correct username.">
		</cfif>

		<cfset email = frmUsername &"@indiana.edu"><!---a default email address if nothing else works.--->
		<cfset firstName = frmUsername><!---a default name if nothing else works.--->
		<cfset lastName = "">

		<cfloop query="#user_info#">
			<cfset email = mail>
			<cfif listLen(displayname) eq 2>
				<cfset firstName = listGetAt(displayname, 2)>
				<cfset lastName = listGetAt(displayname, 1)>
			<cfelseif listLen(displayName) eq 1>
				<cfset firstName = displayName>
			</cfif>
		</cfloop>


		<!---at this point we've verified our input, fetched our user info, and are ready to start stashing info in the database--->
		<cfquery datasource="#application.applicationDataSource#" name="insertAccountCheck">
			INSERT INTO tbl_account_checks(customer_username, instance_id, lab_id, reporter_id, reporter_ip)
			OUTPUT inserted.check_id
			VALUES(<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#" list="true">,
				   <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceLabStruct.instance#" list="true">,
				   <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceLabStruct.lab#" list="true">,
				   <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#" list="true">,
				   <cfqueryparam cfsqltype="cf_sql_varchar" value="#cgi.REMOTE_ADDR#" list="true">)
		</cfquery>
		<cfloop query="insertAccountCheck">
			<cfset lastInsertCheckId = check_id>
			<cfloop array="#checkType#" index="opt">
					<cfquery datasource="#application.applicationdatasource#" name="insertAccountViolations">
						INSERT INTO tbl_account_check_match(check_id, category_id)
						VALUES(
							 <cfqueryparam cfsqltype="cf_sql_integer" value="#lastInsertCheckId#">,
							 <cfqueryparam cfsqltype="cf_sql_integer" value="#opt#">
							)
					</cfquery>
				</cfloop>
		</cfloop>
		<cfquery datasource="#application.applicationDataSource#" name="getAccountsOpen">
			SELECT category_name
			FROM  tbl_account_checks c
			JOIN tbl_account_check_match m ON c.check_id = m.check_id
			JOIN tbl_account_check_categories cc ON m.category_id = cc.category_id
			WHERE c.check_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#lastInsertCheckId#">
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="getAccountLocation">
			SELECT l.lab_name, b.building_name
			FROM tbl_account_checks c
			INNER JOIN vi_labs l
				ON l.instance_id = c.instance_id
				AND l.lab_id = c.lab_id
			LEFT OUTER JOIN vi_buildings b
				ON b.instance_id = l.instance_id
				AND b.building_id = l.building_id
			WHERE c.check_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#lastInsertCheckId#">
		</cfquery>

		<!---build the name of where the account was left open, by default just the lab's full name, but if we have a building matched to the lab get more specific.--->
		<cfset accountLocation = getAccountLocation.lab_name>
		<cfif getAccountLocation.building_name neq "">
			<cfset accountLocation = "the #getAccountLocation.building_name# lab #getAccountLocation.lab_name#">
		</cfif>

		<cfmail to="#email#" subject="Open Account Warning" from="tccwm@iu.edu" type="text/html">
			<p>WARNING: On #DateFormat(Now(), "mm/dd/yy")#, one or more of your computer accounts listed below was left open in #accountLocation#.</p>

			Accounts Open:
			<ul>
			<cfloop query="getAccountsOpen">
				<li>#category_name#</li>
			</cfloop>
			</ul>
			<p>The consultant on duty closed your accounts. If you are sure you logged off,
			this could mean others have gained access to your IU credentials (username and password). We strongly encourage you to immediately reset your
			password/passphrase. For information on how to reset your passphrase see http://kb.iu.edu/data/atay.html Forgetting to log off not only puts your
			personal data and reputation at risk, but it can also pose a risk to the entire network. You will be held responsible for any activity that happens
			on your account if it is left open and unattended, including printing charges. The IT Policy Office reserves the right to disable any account left
			 in this state, especially if additional incidents occur. For your own protection, always log out of all your computer accounts before
			 leaving any workstation. For more information please refer to http://kb.indiana.edu/data/aivs.html. </p>
			 <p>Have a wonderful day,<br/>
			 Technology Center Consulting</p>
		</cfmail>
		<cfquery datasource="#application.applicationDataSource#" name="getUserIncidents">
			SELECT l.lab_name, c.check_date
			FROM tbl_account_checks c
			JOIN vi_labs l
				ON c.instance_id = l.instance_id
				AND c.lab_id = l.lab_id
			WHERE c.customer_username =  <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">
			AND DATEDIFF(day, c.check_date, GETDATE()) < 30
			ORDER BY c.check_date ASC
		</cfquery>


		<cfif #getUserIncidents.recordcount# gte 3>
			<cfmail to="tccwm@iu.edu" cc="tccwm@iu.edu" from="tccwm@iu.edu" subject="#frmUsername# - Repeat Open Account Incident" type="text/html">
				<p>This e-mail is to inform you that #frmUsername# has left his or her account open #getUserIncidents.recordcount# documented times in the last 30 days.</p>

					These are the documented incidents:
					<ul>
					<cfloop query="getUserIncidents">
					<li>#lab_name# at #check_date#</li>
					</cfloop>
					</ul>

					<p>Have a wonderful day!<br/>
					TCC Webmaster</p>
			</cfmail>
		</cfif>
		<div class="alert alert-success" role="alert">
			Notification sent to <cfoutput>#email#</cfoutput> and the Policy Office.
		</div>

		<cfoutput>
			<p>
				Submit another <a href="#cgi.script_name#">Account Check</a>
			</p>
		</cfoutput>

		<cfinclude template="#application.appPath#/footer.cfm">
		<cfabort>

	<cfcatch type="any">
		<div class="alert alert-danger" role="alert">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</div>
	</cfcatch>
	</cftry>
</cfif>

<cfset labOptions = fetchOptions()>
<cffunction name="fetchOptions" output="false">
	<cfset var getOptions = "">
	<cfset var options = arrayNew(1)>
	<cfset var iStruct = "">
	<cfset var bStruct = "">
	<cfset var lStruct = "">

	<cfquery datasource="#application.applicationDataSource#" name="getOptions">
		SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name
		FROM vi_labs_sites ls /*only labs that we have paired to STC sites*/
		INNER JOIN vi_labs l
			ON l.instance_id = ls.instance_id
			AND l.lab_id = ls.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = ls.instance_id
		WHERE l.active = 1
		<cfif session.primary_instance NEQ 0>
			AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		<cfelse>
			AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		</cfif>
		ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
	</cfquery>

	<cfloop query="getOptions" group="instance_id">
		<cfset iStruct = structNew()>

		<cfset iStruct['name'] = instance_name>
		<cfset iStruct['value'] = arrayNew(1)>
		<!---now group results by the buildings in this instance--->
		<cfloop group="building_id">
			<cfset bStruct = structNew()>

			<cfset bStruct['name'] = building_name>
			<cfset bStruct['value'] = arrayNew(1)>
			<cfloop>
				<cfset lStruct = structNew()>
				<cfset lStruct['name'] = lab_name>
				<cfset lStruct['value'] = {"instance_id": instance_id, "building_id": building_id, "lab_id": lab_id}>

				<cfset arrayAppend(bStruct['value'], lStruct)>
			</cfloop>

			<cfset arrayAppend(iStruct['value'], bStruct)>
		</cfloop>


		<cfset arrayAppend(options, iStruct)>
	</cfloop>

	<cfreturn options>
</cffunction>

<!---build-up the category options--->
<cfset catOptions = arrayNew(1)>

<cfloop query="getAccountCategories">
	<cfset opt = { "name": category_name, "value": category_id }>

	<cfset arrayAppend(catOptions, opt)>
</cfloop>


<!--- DRAW FORMS --->
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	<cfoutput>
		<cfset bootstrapCharField("frmUsername", "Customer Username:", frmUsername, "", "")>
		<cfset bootstrapSelectField("selector", labOptions, "Current Lab:", selector, "", [])>
		<cfset bootstrapCheckField("checkType", catOptions, "Account Type(s)", checkType)>
		<cfset bootstrapSubmitField("action", "Submit")>
	</cfoutput>
</form>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>