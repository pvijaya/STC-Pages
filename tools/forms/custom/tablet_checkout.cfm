<cfparam name="frmTablet" type="string" default="">

<!---a struct where we match tablet names to the value for the which tablet question.--->
<cfset tablets = arrayNew(1)>

<cfquery datasource="#application.applicationDataSource#" name="getTablets">
	SELECT form_item_option_id, option_text
	FROM tbl_forms_items_options
	WHERE form_item_id = 1845
	AND retired = 0
	ORDER BY option_order
</cfquery>

<cfloop query="getTablets">
	<cfset arrayAppend(tablets, {"name": option_text, "id": form_item_option_id})>
</cfloop>


<cfset tabletId = 0>

<cfloop from="1" to="#arrayLen(tablets)#" index="n">
	<cfif tablets[n].name eq frmTablet>
		<cfset tabletId = tablets[n].id>
		<cfbreak>
	</cfif>
</cfloop>


<cfif not tabletId>
	<!---We don't know what tablet they're using, so draw a form for them to pick.--->
	<form method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
		Select a Tablet:
		<select name="frmTablet">
		<cfloop from="1" to="#arrayLen(tablets)#" index="n">
			<cfoutput><option value="#tablets[n].name#">#tablets[n].name#</option></cfoutput>
		</cfloop>
		</select>
		
		<input type="submit" value="Go">
	</form>

<cfelse>
	<!---we do know the tablet, determine its curent status and set the correct default--->
	<cfset checkedout = 0>
	<cfset lastUser = "N/A">
	<cfset lastDate = '1999-01-01'>
	
	<!---fetch the last user of this tablet's response to whether they are checking out or returning.--->
	<cfquery datasource="#application.applicationdatasource#" name="tabletStatus">
		SELECT i.user_answer, u.username, s.submission_date
		FROM tbl_forms_users_items i
		INNER JOIN tbl_forms_submissions s ON s.submission_id = i.submission_id
		INNER JOIN tbl_users u ON u.user_id = s.submitted_by
		WHERE i.submission_id = (
			SELECT TOP 1 fs.submission_id
			FROM tbl_forms_users_items fui
			INNER JOIN tbl_forms_submissions fs ON fs.submission_id = fui.submission_id
			WHERE fui.form_item_id = 1845 /*the which tablet question*/
			AND fui.user_answer = <cfqueryparam cfsqltype="cf_sql_integer" value="#tabletId#"> /*which tablet do we want the status of?*/
			ORDER BY fs.submission_date DESC
		)
		AND i.form_item_id = 1846/*the status question*/
	</cfquery>
	
	<cfif tabletStatus.recordCount gt 0>
		<cfset lastUser = tabletStatus.username>
		<cfset lastDate = tabletStatus.submission_date>
		<cfif tabletStatus.user_answer eq 2377>
			<cfset checkedout = 1>
		</cfif>
	</cfif>
	
	<!---now we know the status of the tablet and the last user who worked with the tablet we can seed the correct form information.--->
	<cfoutput>
		<p>
			#frmTablet# was <cfif checkedout>checked out<cfelse>returned</cfif> by #lastUser# on #dateFormat(lastDate, "mmm d, yyyy")# at #timeFormat(lastDate, "h:nn tt")#.
		</p>
	</cfoutput>
	
	<!---if the user is the user who last checked out the tablet default to returning it.--->
	<cfif lastUser eq session.cas_username AND checkedout>
		<cflocation addtoken="false" url="#application.appPath#/tools/forms/form_viewer.cfm?formId=80&radio1845=#tabletId#&radio1846=2378">
	<cfelse>
		<!---otherwise have it default to checking out the tablet.--->
		<cflocation addtoken="false" url="#application.appPath#/tools/forms/form_viewer.cfm?formId=80&radio1845=#tabletId#&radio1846=2377">
	</cfif>
	
</cfif>