<cfmodule template="#application.appPath#/header.cfm" title='Search Customer Contacts' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">

<!---bring in the contact specific functions.--->
<cfinclude template="#application.appPath#/tools/contacts/contact-functions.cfm">

<cfparam name="frmStartDate" type="date" default="#dateAdd("m", -1, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">

<!--users, categories and labs are special, we return a complex object via JSON--->
<cfparam name="usernameArray" type="string" default="[]">
<cfset usernameArray = deserializeJSON(usernameArray)>

<cfparam name="consArray" type="string" default="[]">
<cfset consArray = deserializeJSON(consArray)>

<cfparam name="categoriesArray" type="string" default="[]">
<cfset categoriesArray = deserializeJSON(categoriesArray)>

<cfparam name="labsArray" type="string" default="[]">
<cfset labsArray = deserializeJSON(labsArray)>

<!---cfparam name="statusList" type="string" default="1"--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="statusList" default="[1]">
<cfparam name="searchTerms" type="string" default="">

<cfparam name="drawXML" type="boolean" default="0">

<cfparam name="frmSortBy" type="string" default="createdASC"><!--- options are createdASC, createdDESC, locationASC/DESC, statusASC/DESC, minutesASC/DESC, creatorASC/DESC--->
<cfparam name="pageNum" type="integer" default="0">


<h2>Search Criteria</h2>
<form class="form-horizontal" role="form" id="create-contact">
	<input type="hidden" name="frmSortBy" value="<cfoutput>#htmlEditFormat(frmSortBy)#</cfoutput>">

	<div class="form-group contact-usernames"></div>
	<div class="form-group creator-usernames"></div>
	<div class="form-group contact-categories"></div>

	<div class="form-group contact-labs"></div>

	<div class="form-group contact-start-date"></div>
	<div class="form-group contact-end-date"></div>

	<div class="form-group contact-status"></div>
	<div class="form-group contact-terms"></div>
	<div class="form-group contact-xml"></div>

	<p>
		<input class="btn btn-primary col-sm-offset-3" type="submit" name="submit"  value="Search">
	</p>
</form>

<script type="text/javascript">
	$(document).ready(function(){
		//fetch contact categories in a format we can use with MultiChoiceElement.
		activeCategories = <cfoutput>#serializeJSON(getCatsObject(getAllCats()))#</cfoutput>
		//fetch active statuses for contacts in a format we can use with a checkbox selector.
		activeStatuses = <cfoutput>#serializeJSON(getStatusesObject())#</cfoutput>
		//fetch active labs for contacts in a format we can use with MultiChoiceElement.
		activeLabs = <cfoutput>#serializeJSON(getLabsObject())#</cfoutput>

		multiUserObject = new MultiChoiceTextElement('#create-contact div.contact-usernames', 'usernameArray', "One or more customers are connected to a contact. If you do not know the customer's username, simply type #unknown instead.", "", 'Customer Username(s)');
		multiUserObject.setValue(<cfoutput>#serializeJSON(usernameArray)#</cfoutput>);
		multiUserObject.setLabel("Customers");

		multiCreatorObject = new MultiChoiceTextElement('#create-contact div.creator-usernames','consArray', '', '', 'Creators');
		multiCreatorObject.setValue(<cfoutput>#serializeJSON(consArray)#</cfoutput>);
		multiCreatorObject.setLabel("Created By", "Limit the results to contacts created by these users.");

		multiCategoriesObject = new MultiChoiceSelectElement('#create-contact div.contact-categories','categoriesArray', '', activeCategories);
		multiCategoriesObject.setValue(<cfoutput>#serializeJSON(categoriesArray)#</cfoutput>);
		multiCategoriesObject.setLabel("Categories");

		multiLabsObject = new MultiChoiceSelectElement('#create-contact div.contact-labs','labsArray', '', activeLabs);
		multiLabsObject.setValue(<cfoutput>#serializeJSON(labsArray)#</cfoutput>);
		multiLabsObject.setLabel("Labs", 'Select the labs you wish to limit the search results to.');

		startDateObject = new DateElement('#create-contact div.contact-start-date', 'frmStartDate', 'The earliest contacts we want to return.', '<cfoutput>#convertTimeToUtcDate(frmStartDate)#</cfoutput>');
		startDateObject.setLabel("Start Date");


		endDateObject = new DateElement('#create-contact div.contact-end-date', 'frmEndDate', 'The latest contacts we want to return.', '<cfoutput>#convertTimeToUtcDate(frmEndDate)#</cfoutput>');
		endDateObject.setLabel("End Date");

		statusCheckbox = new CheckElement('#create-contact div.contact-status','statusList', activeStatuses, '','nothing');
		statusCheckbox.setValue(<cfoutput>#serializeJSON(statusList)#</cfoutput>);
		statusCheckbox.setLabel("Statuses");

		searchTerms = new TextElement('#create-contact div.contact-terms', "searchTerms", "Keywords or terms to find in contacts.", '');
		searchTerms.setLabel("Search Terms");
		searchTerms.setValue(<cfoutput>#serializeJSON(searchTerms)#</cfoutput>);

		drawXML = new RadioElement('#create-contact div.contact-xml','drawXML', [{'name':'Yes', 'value':1},{'name':'No', 'value':0}], '');
		drawXML.setLabel("Return results as XML", "Export the results as XML for use and analysis in other applications.");
		drawXML.setValue(<cfoutput>#drawXML#</cfoutput>);

		/*Now deal with showing/hiding the viewer*/
		$(document).on("click", 'a.contactLink', function(e) {
			if(e.ctrlKey || e.shiftKey) { //if the user was holding he ctrl or shift keys don't show our pop-in use the browser's behavior
				return (0);
			}
			e.preventDefault();
			var contactId = $(this).attr("contactId");

			//find the td the link was clicked in, and replace its content with the "hide" link
			var myTd = $(this).parents("td");
			var hideLink = "<a href='#' class='hideLink' contactId='"+ contactId +"'>Hide</a>";

			//find the tr the link was clicked in.
			var myTr = $(this).parents("tr");

			myTd.html(hideLink);

			var newRow = "<tr class='contact-placeholder' contactId='"+ contactId +"'></tr><tr class='contact-form' contactId='"+ contactId +"'><td colspan='7'></td></tr>";//You'll notice there are two TR's in here, the first is empty.  This is because the striping directive happens to even/odd rows, we need the empty row so our backgroung-color matches.
			myTr.after(newRow);

			//var x = LoadingElement("tr.contact-form[contactId="+ contactId +"] td", "Whoa, Nelly.");

			contactViewer("tr.contact-form[contactId="+ contactId +"] td", {"contact_id": contactId});
			//$("#contact" + contactId).show();
		});

		$(document).on("click", 'a.hideLink', function(e){
			e.preventDefault();

			var contactId = $(this).attr("contactId");

			//remove the rows displaying this contact.
			$("tr.contact-form[contactId="+ contactId +"]").remove();
			$("tr.contact-placeholder[contactId="+ contactId +"]").remove();

			//now draw the view link again.
			var myTd = $(this).parents("td");
			var showLink = "<a href='<cfoutput>#application.appPath#/tools/contacts/view-contact.cfm?contactId=</cfoutput>"+ contactId +"' class='contactLink' contactId='"+ contactId +"'>View</a>";
			myTd.html(showLink);
		})

	});
</script>

<h2>Search Results</h2>

<!---we also need to create an ORDER BY clause based on the user's frmSortBy.  Naturally we can't just let the user provide an ORDER BY clause, as that would allow SQL injection--->
<cfswitch expression="#frmSortBy#">
	<cfcase value="createdDESC">
		<cfset orderBy = "created_ts DESC">
	</cfcase>
	<cfcase value="locationASC">
		<cfset orderBy = "short_building_name ASC, room_number ASC">
	</cfcase>
	<cfcase value="locationDESC">
		<cfset orderBy = "short_building_name DESC, room_number DESC">
	</cfcase>
	<cfcase value="statusASC">
		<cfset orderBy = "status ASC">
	</cfcase>
	<cfcase value="statusDESC">
		<cfset orderBy = "status DESC">
	</cfcase>
	<cfcase value="minutesASC">
		<cfset orderBy = "minutes_spent ASC">
	</cfcase>
	<cfcase value="minutesDESC">
		<cfset orderBy = "minutes_spent DESC">
	</cfcase>
	<cfcase value="creatorASC">
		<cfset orderBy = "created_by ASC">
	</cfcase>
	<cfcase value="creatorDESC">
		<cfset orderBy = "created_by DESC">
	</cfcase>
	<cfdefaultcase>
		<cfset orderBy = "created_ts ASC">
	</cfdefaultcase>
</cfswitch>

<!---this string is used to help generate URLs used by links to sort data--->
<cfset getVars = "frmStartDate=#urlEncodedFormat(frmStartDate)#&frmEndDate=#urlEncodedFormat(frmEndDate)#&usernameArray=#urlEncodedFormat(serializeJSON(usernameArray))#&consArray=#urlEncodedFormat(serializeJSON(consArray))#&categoriesArray=#urlEncodedFormat(serializeJSON(categoriesArray))#&labsArray=#urlEncodedFormat(serializeJSON(labsArray))#&statusList=#urlEncodedFormat(serializeJSON(statusList))#&searchTerms=#urlEncodedFormat(searchTerms)#">

<style type="text/css">

	table.stripe tr.titlerow a:link {
		color: white;
	}

</style>

<!---and setup a few lists from some of our multi-selectors.--->
<cfset usernameList = "">
<cfloop from="1" to="#arrayLen(usernameArray)#" index="i">
	<cfset usernameList = listAppend(usernameList, usernameArray[i])>
</cfloop>

<cfset consList = "">
<cfloop from="1" to="#arrayLen(consArray)#" index="i">
	<cfset consList = listAppend(consList, consArray[i])>
</cfloop>

<cfset categoriesList = "">
<cfloop from="1" to="#arrayLen(categoriesArray)#" index="i">
	<cfset categoriesList = listAppend(categoriesList, categoriesArray[i])>
</cfloop>

<!---if we're doing XML results just do that before we get into any of the pain of pagination--->
<cfif drawXML>
	<cfquery datasource="#application.applicationDataSource#" name="getContacts">
		SELECT c.contact_id, i.instance_name, c.instance_id, c.building_id, b.short_building_name, c.room_number, cs.status, c.created_ts, minutes_spent, u.username AS created_by, cu.customer_username, cc.category_id, cc.category_name
		FROM tbl_contacts c
		INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
		INNER JOIN vi_buildings b
			ON b.instance_id = c.instance_id
			AND b.building_id = c.building_id
		INNER JOIN tbl_users u ON u.user_id = c.user_id
		INNER JOIN tbl_contacts_statuses cs ON cs.status_id = c.status_id

		<cfif arrayLen(labsArray) gt 0><!---restrict results to selected labs--->
			INNER JOIN vi_labs l
				ON l.instance_id = i.instance_id
				AND l.building_id = c.building_id
				AND l.room_number = c.room_number
				AND (
				<cfloop from="1" to="#arrayLen(labsArray)#" index="i">
					<cfif i gt 1>OR </cfif> (l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labsArray[i].instanceId#"> AND l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labsArray[i].labId#">)
				</cfloop>
				)
		</cfif>

		<cfif trim(searchTerms) neq "">
			INNER JOIN tbl_contacts_notes n
				ON n.contact_id = c.contact_id
				AND n.note_text LIKE <cfqueryparam cfsqltype="cf_sql_varchar" value="%#searchTerms#%">
		</cfif>

		LEFT OUTER JOIN tbl_contacts_customers cu ON cu.contact_id = c.contact_id
		LEFT OUTER JOIN tbl_contacts_categories_match ccm ON ccm.contact_id = c.contact_id
		LEFT OUTER JOIN tbl_contacts_categories cc ON cc.category_id = ccm.category_id

		WHERE c.created_ts BETWEEN '#dateFormat(frmStartDate, "yyyy-mm-dd")#' AND  '#dateFormat(dateAdd("d", 1, frmEndDate), "yyyy-mm-dd")#'
		<cfif listLen(usernameList) gt 0>
			AND c.contact_id IN (SELECT contact_id FROM tbl_contacts_customers WHERE customer_username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#usernameList#" list="true">))
		</cfif>

		<cfif listLen(consList) gt 0>
			AND u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#consList#" list="true">)
		</cfif>

		<cfif listLen(categoriesList) gt 0>
			AND c.contact_id IN (SELECT contact_id FROM tbl_contacts_categories_match WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#categoriesList#" list="true">))
		</cfif>

		<cfif listLen(arrayToList(statusList))>
			AND c.status_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#arrayToList(statusList)#" list="true">)
		</cfif>
		ORDER BY c.contact_id
	</cfquery>


	<cfsetting enablecfoutputonly="true" showdebugoutput="false">
	<cfcontent type = "text/xml" reset="true">
	<cfheader name="Content-Disposition" value="attachment;filename=contacts-#dateTimeFormat(now(), 'yyyymmddHHnnss')#.xml">
	<cfheader name="Content-Description" value="This is a XML file.">

	<cfoutput><?xml version="1.0"?>
		<contacts xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://#cgi.server_name##application.appPath#/tools/contacts/contacts_reports_full_text.xsd" generated="#dateFormat(now(),"YYYY-MM-DD")#T#timeFormat(now(), "HH:mm:ss")#">
	</cfoutput>

	<cfloop query="getContacts" group="contact_id">
		<cfset customerList = "">
		<cfset categoryList = "">

		<cfloop>
			<cfif not listFindNoCase(customerList, customer_username)>
				<cfset customerList = listAppend(customerList, customer_username)>
			</cfif>

			<cfif not listFindNoCase(categoryList, category_name)>
				<cfset categoryList = listAppend(categoryList, category_name)>
			</cfif>
		</cfloop>

		<cfoutput>
			<contact>
				<contact_id>#contact_id#</contact_id>
				<status>#status#</status>
				<customers>
				<cfloop list="#customerList#" index="cust">
					<customer>
						<username>#htmlEditFormat(cust)#</username>
					</customer>
				</cfloop>
				</customers>

				<timestamp>#dateFormat(created_ts, "YYYY-MM-DD")#T#timeFormat(created_ts, "HH:mm:ss")#</timestamp>
				<submitted_by>#htmlEditFormat(created_by)#</submitted_by>
				<minutes_spent>#minutes_spent#</minutes_spent>
				<categories>
				<cfloop list="#categoryList#" index="cat">
					<category>
						<category_name>#htmlEditFormat(cat)#</category_name>
					</category>
				</cfloop>
				</categories>
				<instance>#htmlEditFormat(instance_name)#</instance>
				<lab>#htmlEditFormat(short_building_name & room_number)#</lab>
			</contact>
		</cfoutput>
</cfloop>


	<cfoutput>
		</contacts>
	</cfoutput>

	<cfabort>
</cfif>


<!--pagination is hard, we need to know how many total matching records we've got vs. how many we're willing to display.--->
<cfset maxRows = 100>


<cfquery datasource="#application.applicationDataSource#" name="getContactsCount">
	SELECT COUNT(DISTINCT c.contact_id) AS cnt
	FROM tbl_contacts c
	INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
	INNER JOIN tbl_users u ON u.user_id = c.user_id
	INNER JOIN tbl_contacts_statuses cs ON cs.status_id = c.status_id

	<cfif arrayLen(labsArray) gt 0><!---restrict results to selected labs--->
		INNER JOIN vi_labs l
			ON l.instance_id = i.instance_id
			AND l.building_id = c.building_id
			AND l.room_number = c.room_number
			AND (
			<cfloop from="1" to="#arrayLen(labsArray)#" index="i">
				<cfif i gt 1>OR </cfif> (l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labsArray[i].instanceId#"> AND l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labsArray[i].labId#">)
			</cfloop>
			)
	</cfif>
	<cfif trim(searchTerms) neq "">
		INNER JOIN tbl_contacts_notes cn
			ON cn.contact_id = c.contact_id
			AND cn.note_text LIKE <cfqueryparam cfsqltype="cf_sql_varchar" value="%#searchTerms#%">
	</cfif>

	WHERE c.created_ts BETWEEN '#dateFormat(frmStartDate, "yyyy-mm-dd")#' AND  '#dateFormat(dateAdd("d", 1, frmEndDate), "yyyy-mm-dd")#'
	<cfif listLen(usernameList) gt 0>
		AND c.contact_id IN (SELECT contact_id FROM tbl_contacts_customers WHERE customer_username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#usernameList#" list="true">))
	</cfif>

	<cfif listLen(consList) gt 0>
		AND u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#consList#" list="true">)
	</cfif>

	<cfif listLen(categoriesList) gt 0>
		AND c.contact_id IN (SELECT contact_id FROM tbl_contacts_categories_match WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#categoriesList#" list="true">))
	</cfif>

	<cfif listLen(arrayToList(statusList))>
		AND c.status_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#arrayToList(statusList)#" list="true">)
	</cfif>
</cfquery>

<!---at this point we've got our user's input in order.  Let's run a query to get the results.--->
<cfquery datasource="#application.applicationDataSource#" name="getContacts">
	SELECT x.*, cc.customer_username
	FROM (

		SELECT ROW_NUMBER() OVER(ORDER BY #orderBy#) AS cnt_id, ccs.*
		FROM (
			SELECT DISTINCT c.contact_id, i.instance_name, c.instance_id, c.building_id, c.room_number, cs.status, c.created_ts, minutes_spent, u.username AS created_by
			FROM tbl_contacts c
			INNER JOIN tbl_instances i ON i.instance_id = c.instance_id
			INNER JOIN tbl_users u ON u.user_id = c.user_id
			INNER JOIN tbl_contacts_statuses cs ON cs.status_id = c.status_id

			<cfif arrayLen(labsArray) gt 0><!---restrict results to selected labs--->
				INNER JOIN vi_labs l
					ON l.instance_id = i.instance_id
					AND l.building_id = c.building_id
					AND l.room_number = c.room_number
					AND (
					<cfloop from="1" to="#arrayLen(labsArray)#" index="i">
						<cfif i gt 1>OR </cfif> (l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labsArray[i].instanceId#"> AND l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labsArray[i].labId#">)
					</cfloop>
					)
			</cfif>
			<cfif trim(searchTerms) neq "">
				INNER JOIN tbl_contacts_notes cn
					ON cn.contact_id = c.contact_id
					AND cn.note_text LIKE <cfqueryparam cfsqltype="cf_sql_varchar" value="%#searchTerms#%">
			</cfif>


			WHERE c.created_ts BETWEEN '#dateFormat(frmStartDate, "yyyy-mm-dd")#' AND  '#dateFormat(dateAdd("d", 1, frmEndDate), "yyyy-mm-dd")#'
			<cfif listLen(usernameList) gt 0>
				AND c.contact_id IN (SELECT contact_id FROM tbl_contacts_customers WHERE customer_username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#usernameList#" list="true">))
			</cfif>

			<cfif listLen(consList) gt 0>
				AND u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#consList#" list="true">)
			</cfif>

			<cfif listLen(categoriesList) gt 0>
				AND c.contact_id IN (SELECT contact_id FROM tbl_contacts_categories_match WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#categoriesList#" list="true">))
			</cfif>

			<cfif listLen(arrayToList(statusList))>
				AND c.status_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#arrayToList(statusList)#" list="true">)
			</cfif>
		) ccs
	) x

	/*Now we can apply the customer matches, having limitted ourselves to one page's worth of results.'*/
	LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = x.contact_id

	WHERE x.cnt_id BETWEEN #(pageNum * maxRows) + 1# AND #(pageNum+1) * maxRows#

	ORDER BY x.cnt_id, cc.customer_username
</cfquery>

<!---it turns out joining on vi_buildings is expensive, so offload that work from the query that fetches contacts.--->
<cfquery datasource="#application.applicationDataSource#" name="getBuildings">
	SELECT instance_id, building_id, building_name, short_building_name
	FROM vi_buildings
</cfquery>


<cfoutput>
	<p>#getContactsCount.cnt# records found.</p>
</cfoutput>

<cfset drawPage(pageNum, getContactsCount.cnt, maxRows)>

<!---now we're actually ready to draw our contacts--->
<table class="stripe">
	<tr class="titlerow">
		<th>
			Created
			<span class="tinytext">
				<a clas="sort_link" title="sort ascending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=createdASC</cfoutput>">&#923;</a>
				<a clas="sort_link" title="sort descending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=createdDESC</cfoutput>">V</a>
			</span>
		</th>
		<th>
			Location
			<span class="tinytext">
				<a clas="sort_link" title="sort ascending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=locationASC</cfoutput>">&#923;</a>
				<a clas="sort_link" title="sort descending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=locationDESC</cfoutput>">V</a>
			</span>
		</th>
		<th>
			Status
			<span class="tinytext">
				<a clas="sort_link" title="sort ascending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=statusASC</cfoutput>">&#923;</a>
				<a clas="sort_link" title="sort descending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=statusDESC</cfoutput>">V</a>
			</span>
		</th>
		<th>
			Time
			<span class="tinytext">
				<a clas="sort_link" title="sort ascending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=minutesASC</cfoutput>">&#923;</a>
				<a clas="sort_link" title="sort descending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=minutesDESC</cfoutput>">V</a>
			</span>
		</th>
		<th>
			Creator
			<span class="tinytext">
				<a clas="sort_link" title="sort ascending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=creatorASC</cfoutput>">&#923;</a>
				<a clas="sort_link" title="sort descending" href="<cfoutput>#cgi.script_name#?#getVars#&frmSortBy=creatorDESC</cfoutput>">V</a>
			</span>
		</th>
		<th>Customers</th>
		<th>Link</th>
	</tr>
<cfoutput query="getContacts" group="cnt_id">
	<tr>
		<td>#dateFormat(created_ts, "MMM d, yyyy")# #timeFormat(created_ts, "short")#</td>
		<cfset building = getBuildingObj(instance_id, building_id)>
		<td>
			#building.short_building_name# #room_number#
		</td>
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
		<td>#created_by#</td>
		<td>
		<cfoutput>
			<cfif trim(customer_username) eq "">
				Unknown
			<cfelse>
				#customer_username#
			</cfif>
		</cfoutput>
		</td>
		<td>
			<a href="#application.appPath#/tools/contacts/view-contact.cfm?contactId=#contact_id#" class="contactLink" contactId="#contact_id#">View</a>
		</td>
	</tr>
</cfoutput>

</table>


<!---the modal we'll use for editing time spent.--->
<div class="modal fade minutes-modal" tabindex="-1" role="dialog" aria-labelledby="mySmallModalLabel" aria-hidden="true">
	<div class="modal-dialog modal-md">
		<div class="modal-content">
			<div class="modal-header">
				<button aria-label="Close" data-dismiss="modal" class="close" type="button"><span aria-hidden="true">×</span></button>
				<h5 id="mySmallModalLabel" class="modal-title">Time Spent<a href="#mySmallModalLabel" class="anchorjs-link"><span class="anchorjs-icon"></span></a></h5>
			</div>
			<div id="formMinutesSpent">
				<div class="content-block row">
					<form method="Post" class="form-horizontal" id="minutesForm">
						<input type="hidden" value="2249866" name="contactId" id="contactId">
						<div class="form-group">
							<label for="minutesSpent" class="col-sm-2 control-label">Minutes Spent</label>
							<div class="col-sm-10">
								<input type="text" value="11" name="minutesSpent" class="form-control" id="minutesSpent">
							</div>
						</div>
						<div class="col-sm-offset-2">
							<input type="submit" value="Update" name="action" class="btn btn-primary">
						</div>
					</form>
				</div>
			</div>
		</div>
	</div>
</div>

<!---the javascript to control that modal--->
<script type="text/javascript">
	$(document).ready(function(){
		$(document).on("click", ".minuteLink", function(e){
			e.preventDefault();
			$("div.minutes-modal").modal('show');

			var contactId = $(this).attr("contactId");
			var minutes = $(this).attr("minutes");

			$("div#formMinutesSpent input#contactId").val(contactId);
			$("div#formMinutesSpent input#minutesSpent").val(minutes);
		});

		$("form#minutesForm").on("submit", function(e){
			e.preventDefault();

			var contactId = $("input#contactId", this).val();
			var minutes = $("input#minutesSpent", this).val();

			//Disable the form elements while we're submitting.
			$("input", this).each(function(i){
				$(this).attr("disabled", "disabled");
			});

			$.ajax({
				type: 'POST',
				async: false,
				url: '<cfoutput>#application.appPath#/tools/contacts/update-time-spent.cfm</cfoutput>',
				data: {
					"contactId": contactId,
					"minutesSpent": minutes,
					"action": "update"
				}
			});

			//having submitted re-enable the form.
			$("input", this).each(function(i){
				$(this).removeAttr("disabled");
			});

			//fire click events for the hide then view link for our contact so we "refresh the data.
			$("a.hideLink[contactid='"+ contactId +"']").click();
			$("a.contactLink[contactid='"+ contactId +"']").click();

			//close the modal
			$("div.minutes-modal").modal('hide');
		});
	});
</script>
<!--- end of the minute editing modal stuff.--->

<cfinclude template="#application.appPath#/views/contacts/view-contacts.cfm">


<cfset drawPage(pageNum, getContactsCount.cnt, maxRows)>

<p>
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm">



<cffunction name="getStatusesObject" output="false">
	<cfset var getStatuses = "">
	<cfset var statusArray = arrayNew(1)>
	<cfset var statusStruct = structNew()>

	<cfquery datasource="#application.applicationDataSource#" name="getStatuses">
		SELECT status_id, status
		FROM tbl_contacts_statuses
		WHERE active = 1
		ORDER BY status_id
	</cfquery>

	<cfloop query="getStatuses">
		<cfset statusStruct = structNew()>

		<cfset statusStruct['name'] = status>
		<cfset statusStruct['value'] = status_id>

		<cfset arrayAppend(statusArray, statusStruct)>
	</cfloop>

	<cfreturn statusArray>
</cffunction>

<cffunction name="getLabsObject" output="false">
	<cfset var getLabsQuery = "">
	<cfset var instanceGroup = "">
	<cfset var buildingGroup = "">
	<cfset var labObj = "">
	<cfset var tempObj = "">

	<cfset var myObj = arrayNew(1)>

	<cfquery datasource="#application.applicationDataSource#" name="getLabsQuery">
		SELECT DISTINCT i.instance_id, i.instance_name, b.building_id, b.building_name, l.lab_id, l.lab_name, l.room_number
		FROM vi_labs_sites ls /*only labs that we have paired to STC sites*/
		INNER JOIN vi_labs l
			ON l.instance_id = ls.instance_id
			AND l.lab_id = ls.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		INNER JOIN tbl_instances i ON i.instance_id = ls.instance_id
		WHERE l.active = 1
		AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		ORDER BY i.instance_name, b.building_name, b.building_id, l.lab_name
	</cfquery>

	<!---build-up an object of nicely formatted labs for the user's current instance--->
	<cfloop query="getLabsQuery" group="instance_id">
		<cfset instanceGroup = structNew()>
		<cfset instanceGroup['name'] = instance_name>
		<cfset instanceGroup['value'] = arrayNew(1)>

		<cfloop group="building_id">
			<cfset buildingGroup = structNew()>
			<cfset buildingGroup['name'] = "&nbsp;&nbsp;" & building_name><!---here we add a little extra indentation since we know it'll always be nested under the Instance optgroup.--->
			<cfset buildingGroup['value'] = arrayNew(1)>

			<cfloop>
				<cfset labObj = structNew()>
				<cfset tempObj = structNew()>
				<cfset labObj['name'] = lab_name>
				<cfset tempObj['instanceId'] = instance_id>
				<cfset tempObj['buildingId'] = building_id>
				<cfset tempObj['labId'] = lab_id>
				<cfset labObj['value'] = tempObj>

				<cfset arrayAppend(buildingGroup['value'], labObj)>
			</cfloop>

			<cfset arrayAppend(instanceGroup['value'], buildingGroup)>
		</cfloop>

		<cfset arrayAppend(myObj, instanceGroup)>
	</cfloop>

	<cfreturn myObj>
</cffunction>

<!---draw the links for navigating between pages --->
<cffunction name="drawPage">
	<cfargument name="page" type="numeric" required="true">
	<cfargument name="total" type="numeric" required="true">
	<cfargument name="perPage" type="numeric" default="500">

	<cfset var tempVars = getVars>
	<cfset var getVars = tempVars & "&frmSortBy=#urlEncodedFormat(frmSortBy)#">

	<cfset var maxPage = iif(total mod perPage, total\perPage + 1, total\perPage)>

	<cfoutput>Displaying records #(page * perPage) + 1# to #iif((total lt perPage * (page+1)), total, (page+1) * perPage)#<br/></cfoutput>

	<cfif total gt perPage>
		<cfif page gt 0>
			<cfoutput><a href="#application.appPath#/tools/contacts/search.cfm?#getVars#&pageNum=0">&lt;&lt;</a> <a href="#application.appPath#/tools/contacts/search.cfm?#getVars#&pageNum=#page-1#">&lt;</a></cfoutput>
		</cfif>

		<cfoutput>Page #page+1# of #maxPage#</cfoutput>

		<cfif page lt maxPage-1>
			<cfoutput><a href="#application.appPath#/tools/contacts/search.cfm?#getVars#&pageNum=#page+1#">&gt;</a> <a href="#application.appPath#/tools/contacts/search.cfm?#getVars#&pageNum=#maxPage-1#">&gt;&gt;</a></cfoutput>
		</cfif>
	</cfif>
</cffunction>

<cffunction name="getBuildingObj">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="buildingId" type="numeric" required="true">

	<cfset myObj = structNew()>
	<cfset myObj.building_name = "Unknown">
	<cfset myObj.short_building_name = "??">

	<cfloop query="getBuildings"><!---run right after the query that fetches contacts--->
		<cfif instance_id eq instanceId AND building_id eq buildingId>
			<cfset myObj.building_name = building_name>
			<cfset myObj.short_building_name = short_building_name>
			<cfbreak>
		</cfif>
	</cfloop>

	<cfreturn myObj>
</cffunction>