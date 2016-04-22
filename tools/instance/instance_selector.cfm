<cfmodule template="#application.appPath#/header.cfm" title="Select Instance">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmInstance" type="integer" default="#Session.primary_instance#">
<cfparam name="referrer" type="string" default="#cgi.HTTP_REFERER#">


<h1>Select Instance</h1>

<!--- if the user doesn't have a primary instance, fetch the instances they can legally
	  use and allow him or her the option to choose --->
<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
	SELECT i.instance_id, i.instance_name
	FROM tbl_instances i
	INNER JOIN tbl_user_masks um ON um.mask_name = i.instance_mask
	INNER JOIN tbl_users_masks_match umm ON umm.mask_id = um.mask_id
	WHERE umm.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">
</cfquery>

<!--- if the user has only one valid instance, there is no reason to show them the form --->
<!--- just set the instance and send them back to where they came from --->
<cfif getUserInstances.recordCount EQ 1>
	<cfset setNewInstance(getUserInstances.instance_id)>
</cfif>

<!--- handle user input --->
<cfif frmAction EQ "Go">

	<cftry>

		<!--- this is a little redundant, but having frmInstance as a cfparam allows users to input whatever
			  instance they like as a url argument. instead of blindly updating the instance, make sure he or she
			  is allowed to use it. --->
		<cfquery datasource="#application.applicationDataSource#" name="checkUserInstance">
			SELECT i.instance_id, i.instance_name
			FROM tbl_instances i
			INNER JOIN tbl_user_masks um ON um.mask_name = i.instance_mask
			INNER JOIN vi_all_masks_users amu ON amu.mask_id = um.mask_id
			WHERE amu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.cas_uid#">
				  AND i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstance#">
		</cfquery>

		<!--- if the instance is valid, set it; otherwise, return an error --->
		<cfif checkUserInstance.recordCount GT 0>
			<cfset setNewInstance(frmInstance)>
		<cfelse>
			<cfthrow message="Permission" detail="You are not permitted to use this instance.">
		</cfif>

		<p class="ok">
			Instance updated successfully.
		</p>

	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

</cfif>

<!--- draw forms --->
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
	<fieldset>
		<legend>Choose</legend>

		<cfoutput>
			<input type="hidden" name="referrer" value="#referrer#">
		</cfoutput>

		<label>
			Select your instance:
			<select name="frmInstance">
				<option value="0"></option>
				<cfoutput query="getUserInstances">
					<option value="#instance_id#"
							<cfif instance_id EQ frmInstance>selected="true"</cfif>>
						#instance_name#
					</option>
				</cfoutput>
			</select>
		</label>

		<input name="frmAction" type="submit" value="Go">

	</fieldset>
</form>

<!--- functions --->
<!--- given the new instanceId, sets it and whisks the user back to their referrer link --->
<cffunction name="setNewInstance">
	<cfargument name="instanceId" type="numeric">

	<!--- the cflock is to prevent multiple requests from writing to the Session variables at the same time --->
	<cflock scope="Session" timeout="30" type="Exclusive">
		<cfset Session.primary_instance = instanceId>
	</cflock>

	<!---first build the form for the URL--->
	<cfset firstPass = 1>
	<cfset tempUrl = structNew()><!---a place to store URL data from the referrer--->

	<cfif trim(referrer) neq "">
		<!---in the case of a referrer link we need to rebuild the URL scope so we can clean-out any problem items.--->
		<cfset newLocation = listGetAt(referrer, 1, "?")>

		<!---now add any URL data that came along with referrer.--->
		<cfloop list="#listRest(referrer, "?")#" delimiters="&" index="i">
			<cfset splitSpot = find("=", i)>

			<cfif splitSpot gt 0>
				<cfset key = left(i, splitSpot - 1)>
				<cfset value = mid(i, splitSpot + 1, len(i))>
			<cfelse>
				<cfset key = i>
				<cfset value = "">
			</cfif>

			<cfset tempUrl[URLDecode(key)] = URLDecode(value)>
		</cfloop>
	<cfelse>
		<!---if the user didn't provide any referrer, just send them back to the main page.--->
		<cfset newLocation = "#application.appPath#">
	</cfif>

	<cfloop collection="#tempUrl#" item="key">
		<!--- since castickets are one-time-use, make sure we don't pass any along.  Also, we don't want to clobber the instance we just set, so strip that out, too. --->
		<cfif key NEQ 'casticket' AND key NEQ 'instance'>
			<cfif firstPass>
				<cfset newLocation = newLocation & "?">
			<cfelse>
				<cfset newLocation = newLocation & "&">
			</cfif>

			<cfset newLocation = newLocation & key & "=" & urlEncodedFormat(tempUrl[key])>
			<cfset firstPass = 0>

		</cfif>

	</cfloop>

	<cfoutput>
		<form method="post" action="#newLocation#" id="redirForm">

			<!---now generate a form for and posted items--->
			<cfloop collection="#form#" item="key">
				<input type="hidden" name="#htmleditFormat(key)#" value="#htmlEditFormat(form[key])#">
			</cfloop>

			You should be automatically redirected to your requested page, but if you are not click this button.<br/>
			<input type="submit" value="Proceed">

		</form>
	</cfoutput>

	<script type="text/javascript">
		//automatically submit the form for the user.
		document.forms["redirForm"].submit();
	</script>

	<cfabort>


</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">