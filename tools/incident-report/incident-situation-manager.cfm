<cfmodule template="#application.appPath#/header.cfm" title='Incident Report'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
<!--- JAVASCRIPT / JQUERY --->
<script type="text/javascript">
	$(document).ready(function(){
		$("ul.labItems").sortable({
			items: "li.item",/*restrict to just moving items, not types*/
			axis: "y",
			placeholder: "ui-state-highlight"
		});


		/*also style up our draggable items to make it clear they are dragable.*/
		$("ul.labItems li.item")
			.addClass("ui-state-default")
			.css({'cursor': 'n-resize','padding': '0.25em'});

		/*when items are dragged update all the sort_orders in that group*/
		$("ul.labItems").bind("sortupdate", function(e, i){
			//fetch the new order of the items, this uses the li's id value.
			//var result = $("ul.labItems").sortable('toArray');

			//loop over the new order and update the form.
			$("ul.labItems").each(function(n){
				$("li.item", this).each(function(i){
					$("input.sortOrder", this).val(i+1);
				});
			});
		});

		});

</script>
<h1>Situation Manager</h1>
<cfoutput>
	<cfif hasMasks('CS')>
		<a href="#application.appPath#/tools/incident-report/incident-report-viewer.cfm">Incident Report Viewer </a>|
		<a href="#application.appPath#/tools/incident-report/incident-report.cfm">Incident Report</a>
		<br/><br/>
	</cfif>
</cfoutput>
<!---get a list of all the Incident types, in order.--->
<cfset getList = getListQuery()>

<cftry>
	<cfparam name="frmID" type="Integer" default="0">
	<cfparam name="frmSituation" type="String" default="">
	<cfparam name="frmActive" type="Boolean" default="true">
	<cfparam name="frmAction" type="String" default="">

	<cfif frmID gt 0>
		<cfquery datasource="#application.applicationdatasource#" name="getList">
			UPDATE tbl_incident_situations
			SET active=<cfqueryparam cfsqltype="cf_sql_bit" value="#frmActive#">
				WHERE incident_situation_id=<cfqueryparam cfsqltype="cf_sql_integer" value="#frmID#">
		</cfquery>
	<cfelseif frmAction eq "submit">
		<cfquery datasource="#application.applicationdatasource#" name="getList">
			INSERT INTO tbl_incident_situations(situation)
			VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmSituation#">)
		</cfquery>
	<cfelseif frmAction eq "Update Order">
		<cfloop query="getList">
		<cfparam name="frmSortOrder#incident_situation_id#" type="integer" default="1">
			<cfquery datasource="#application.applicationdatasource#" name="getList">
				UPDATE tbl_incident_situations
				SET sort_order=<cfqueryparam cfsqltype="cf_sql_integer" value="#evaluate("frmSortOrder#incident_situation_id#")#">
				WHERE incident_situation_id=<cfqueryparam cfsqltype="cf_sql_integer" value="#incident_situation_id#">
			</cfquery>
		</cfloop>
		<p>Successfully updated</p>
		<!---we've updated the order, so we need to get a new version of getList--->
		<cfset getList = getListQuery()>
		</cfif>
<cfcatch>
	<cfoutput>
		<p class="warning">#cfcatch.Message#-#cfcatch.Detail#</p>
	</cfoutput>
</cfcatch>
</cftry>
<cfquery datasource="#application.applicationdatasource#" name="getList">
SELECT *
FROM tbl_incident_situations order by sort_order,situation
</cfquery>
<form method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
	<ul class="labItems">
		<cfoutput query="getList">
			<li class="item">
				#situation#
				<cfif not active>
				(retired)
				</cfif>
				<input type="hidden" class="sortOrder" value="#sort_order#" name="frmSortOrder#incident_situation_id#">
			<cfif active eq "1">
			<a href="#cgi.script_name#?frmID=#incident_situation_id#&frmActive=0" class="pull-right">retire</a>
			<cfelse>
			<a href="#cgi.script_name#?frmID=#incident_situation_id#&frmActive=1" class="pull-right">reactivate</a>
			</cfif>
			</li>
		</cfoutput>
	</ul>
	<p>
		<input type="submit" name="frmAction" value="Update Order">
	</p>
	</form>

<fieldset>
	<legend>Add a New Situation</legend>
	<form  method="post" action="<cfoutput>#cgi.SCRIPT_NAME#</cfoutput>" >
		<input type="hidden" name="frmAction" value="submit">
		<h2>Enter the new situation</h2>
		<input type="text" name="frmSituation" value="<cfoutput>#htmleditformat(frmSituation)#</cfoutput>">
		<input type="submit">
	</form>
</fieldset>


<cfmodule template="#application.appPath#/footer.cfm">

<cffunction name="getListQuery">
	<cfset var getList = "">

	<cfquery datasource="#application.applicationdatasource#" name="getList">
	SELECT *
	FROM tbl_incident_situations order by sort_order,situation
	</cfquery>

	<cfreturn getList>
</cffunction>