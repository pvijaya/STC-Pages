<cfmodule template="#application.appPath#/header.cfm" title='Weekly Contact Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">

<cfinclude template="#application.appPath#/tools/contacts/contact-functions.cfm">

<h1>Weekly Contact Report</h1>


<cfparam name="frmStartDate" type="date" default="#dateAdd("m", -1, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">

<!---cfparam name="instanceList" type="string" default="#session.primary_instance#"--->
<!---cfparam name="categoriesList" type="string" default="14,20,32,30,31,47,45,21,46,44"---><!---default to all printing categories--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="instanceList" default="[#session.primary_instance#]">
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="categoriesList" default="[]">

<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT instance_id, instance_name
	FROM tbl_instances
	ORDER BY instance_name
</cfquery>
<cfset instancesArray = arrayNew(1)>
<cfloop query="getInstances">
	<cfset iObj = structNew()>

	<cfset iObj['name'] = instance_name>
	<cfset iObj['value'] = instance_id>

	<cfset arrayAppend(instancesArray, iObj)>
</cfloop>

<form method="post">

<fieldset>
	<legend>Report Criteria</legend>

	<div id="instance">
	</div>

	<div id="category">
	</div>

	<fieldset>
		<legend>Date Opened</legend>

		<label>
			<strong>Starting:</strong><br/>
			<input type="text" name="frmStartDate" value="<cfoutput>#DateFormat(frmStartDate, "mmm d, yyyy")#</cfoutput>" class="date">
		</label>
		<br/>
		<label>
			<strong>Ending:</strong><br/>
			<input type="text" name="frmEndDate" value="<cfoutput>#DateFormat(frmEndDate, "mmm d, yyyy")#</cfoutput>" class="date">
		</label>
	</fieldset>

	<input type="Submit" value="Search">
</fieldset>
</form>

<script type="text/javascript">
	contactViewer = "";//this just sets up our viewer for later use.

	$(document).ready(function(){
		//make our date fields into jQuery-ui date pickers.
		$("input.date")
			.datepicker({dateFormat: "M d, yy"})
			.css("width", "8em");


		/*now use MultiChoiceSelectElement() from common.js to handle multip-option inputs*/
		multiCatObject = new MultiChoiceSelectElement("div#category", "categoriesList", '', <cfoutput>#serializeJSON( getCatsObject() )#</cfoutput>);
		multiCatObject.setLabel("Category");
		multiCatObject.setValue(<cfoutput>#serializeJSON(categoriesList)#</cfoutput>);

		multiLabObject = new MultiChoiceSelectElement("div#instance", "instanceList", '', <cfoutput>#serializeJSON(instancesArray)#</cfoutput>);
		multiLabObject.setLabel("Instances")
		multiLabObject.setValue(<cfoutput>#serializeJSON(instanceList)#</cfoutput>);


		/*also setup a contact viewer and a jQuery-UI dialog to display it with*/
		//first the jQuery-UI dialog space.
		contactWidget = $("div#contactCanvas").dialog({
			autoOpen: false,
			title: "View Contact",
			minWidth: "840",
			height: "600",
			open: function(){
				//We don't actually need to do anything fancy here, the click handler that opens this should update our canvas.
			}
		});

		//now setup a viewer that writes its details to the contactWidget
		contactViewer = new ContactDisplay(contactWidget);

		//and an event handler to open up our jquery-ui dialog, and fill it with the correct data.
		$("a.contactLink").click(function(e){
			//if the user was holding he ctrl or shift keys don't show our pop-in use the browser's behavior
			if(e.ctrlKey || e.shiftKey)
				return (0);

			e.preventDefault();//don't let clicking links whisk them off to another page.

			var cId = $(this).attr("contactId");

			//now use our viewer to update the contents of our dialog
			contactViewer.drawContact(cId);
			//having done that we can open our dialog
			$(contactWidget).dialog("open");
		});

	});
</script>

<h2>Report</h2>

<!---fetch the matching contacts--->
<cfquery datasource="#application.applicationDataSource#" name="getContacts">
	SELECT DISTINCT c.contact_id, u.username, /*l.lab_name,*/ c.status_id, s.status, c.minutes_spent, c.created_ts
	FROM tbl_contacts c
	INNER JOIN tbl_users u ON u.user_id = c.user_id
	/*INNER JOIN vi_labs l
		ON l.instance_id = c.instance_id
		AND l.building_id = c.building_id
		AND l.room_number = c.room_number*/
	INNER JOIN tbl_contacts_statuses s ON s.status_id = c.status_id
	INNER JOIN tbl_contacts_categories_match cm ON cm.contact_id = c.contact_id
	INNER JOIN tbl_contacts_categories cc
		ON cc.category_id = cm.category_id
		<cfif arrayLen(categoriesList)>
			AND cc.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#arrayToList(categoriesList)#" list="true">)
		</cfif>
	WHERE c.created_ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
	<cfif arrayLen(instanceList)>
		AND c.instance_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#arrayToList(instanceList)#" list="true">)
	</cfif>
	ORDER BY c.created_ts
</cfquery>


<!---loop over our dates, drawing contacts split-up by week--->
<cfset totalCnt = 0>
<cfloop from="0" to="#dateDiff('d', frmStartDate, frmEndDate)#" step="7" index="i"><!---adding one week at a time.--->
	<cfset curDate = dateAdd("d", i, frmStartDate)>
	<cfset curCnt = 0>


	<cfset curStart = dateAdd("d", 1 - datePart("w", curDate), curDate)>
	<cfset curEnd = dateAdd("d", 7 - datePart("w", curDate), curDate)>

	<!---restrict to frmStartDate and frmEndDate--->
	<cfif frmStartDate gt curStart>
		<cfset curStart = frmStartDate>
	</cfif>
	<cfif frmEndDate lt curEnd>
		<cfset curEnd = frmEndDate>
	</cfif>

	<cfoutput>
		<span class="triggerexpanded">
			#dateFormat(curStart, "ddd MMM d, yyyy")# to #dateFormat(curEnd, "ddd MMM d, yyyy")#
			<cfif datePart("w", curStart) neq 1 OR datePart("w", curEnd) neq 7>
				(Partial Week)
			</cfif>
		</span>
	</cfoutput>
	<!--- now get ready to draw the actual table of contacts for this week--->
		<!---
		<div>
			<table class="stripe">
				<tr class="titlerow">
					<th>Created</th>
					<th>Location</th>
					<th>Status</th>
					<th>Time</th>
					<th>Creator</th>
					<th>Link</th>
				</tr>
		--->
			<cfloop query="getContacts">
				<cfif created_ts gte curStart AND created_ts lte curEnd>
					<cfset curCnt = curCnt + 1>
					<!---cfoutput>

						<tr>
							<td>#dateFormat(created_ts, "MMM d, yyyy")# #timeFormat(created_ts, "short")#</td>
							<td>#lab_name#</td>
							<td>#status#</td>
							<td>
								<cfif minutes_spent gt 1440><!---return days--->
									#numberFormat(minutes_spent/1440.0, "9,999.9")# Days
								<cfelseif minutes_spent gt 60>
									#numberFormat(minutes_spent/60.0, "9,999.9")# Hours
								<cfelse>
									#minutes_spent# Minutes
								</cfif>
							</td>
							<td>#username#</td>
							<td>Link</td>
						</tr>
					</cfoutput--->

				<cfelseif created_ts gt curEnd><!---results are sorted by created_ts ASC, so if we hit a later contact we can break out.--->
					<cfbreak>
				</cfif>
			</cfloop>
		<!---</table>
		</div>--->
		<cfoutput>
			<p>#numberFormat(curCnt, "9,999")# Contacts</p>
		</cfoutput>
		<hr/>

	<cfset totalCnt = totalCnt + curCnt>
</cfloop>

<cfoutput>
	<p><strong>#numberFormat(totalCnt, "9,999")# Total Contacts</strong></p>
</cfoutput>


<cfinclude template="#application.appPath#/footer.cfm">
