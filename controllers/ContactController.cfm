<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">
<cfset response = {}>
<cfset response["errors"] = ArrayNew(1)>
<cftry>
	<cfparam name="object" type="string" default="">
	<cfparam name="method" type="string" default="">
	<cfset object = DeserializeJSON(object)>
	<cfset response["status"] = "Success">

	<!--- GET and set contact metadata based on contact model--->
	<cfobject component="#application.model_qualified_path#.Contact" name="contactInstance">
	<cfset response["metadata"] = contactInstance.getMetadata()>
	<cfset response["metadata"]["properties"]["labId"]["options"] = Arraynew(1)>
	<cfset response["metadata"]["properties"]["categories"]["options"] = Arraynew(1)>
	<!---pack in the info for how we want our editor to look here.  We'd rather do it on the model, but it doesn't work there.'--->
	<cfset response["metadata"]["properties"]["note"]["editorOptions"] = {"toolbar" = "Custom", "toolbar_Custom"=[["Bold","Italic","Strike","-","RemoveFormat"],["NumberedList","BulletedList","-","Blockquote"],["Link","Unlink"]],"height"="8em"}>

	<cfset nonGroupingMetadata = {}>
	<cfset nonGroupingMetadata["labs"] = ArrayNew(1)>
	<cfset nonGroupingMetadata["categories"] = ArrayNew(1)>

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
	<cfloop query="getLabsQuery">
		<cfset labObject = {}>
		<cfset labObject["name"] = getLabsQuery.lab_name>
		<cfset labObject["value"] = getLabsQuery.lab_id>
		<cfset ArrayAppend(nonGroupingMetadata["labs"], labObject)>
	</cfloop>

	<cfquery datasource="#application.applicationDataSource#" name="getContactCategoriesQuery">
		SELECT cc.category_id, cc.category_name, cc.parent_category_id, cc.active
		FROM tbl_contacts_categories cc
		WHERE active != 0
		ORDER BY cc.category_name
	</cfquery>

	<cfloop query="getContactCategoriesQuery">
		<cfset categoryObject = {}>
		<cfset categoryObject["name"] = getContactCategoriesQuery.category_name>
		<cfset categoryObject["value"] = getContactCategoriesQuery.category_id>
		<cfset ArrayAppend(nonGroupingMetadata["categories"], categoryObject)>
	</cfloop>


	<!---Jason wants to rush this into production, so this is a bit hackish, ideally this would be client driven retrieval functions--->
	<cfif method EQ "GET">
			<!---build-up an object of nicely formatted labs for the user's current instance--->
			<!---start with a blank row so the user has to select a lab.--->
			<cfset arrayAppend(response["metadata"]["properties"]["labId"]["options"], {"name": "", "value":""})>
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

				<cfset arrayAppend(response["metadata"]["properties"]["labId"]["options"], instanceGroup)>
			</cfloop>

			<!---fetch our categories, grouped by parent-child relationships.--->
			<cfset response["metadata"]["properties"]["categories"]["options"] = getCategoryMetadataStruct(getContactCategoriesQuery)>

		<cfif StructIsEmpty(object)>
			<cfthrow message="You must specify some search parameters.">
		</cfif>
		<cffunction name="getContacts">
			<cfset var getContactsQuery = ''>
			<cfquery datasource="#application.applicationDataSource#" name="getContactsQuery">
				SELECT c.*
				FROM tbl_contacts c
				WHERE 1 = 1
				<cfif structKeyExists(object, "status_id")>
					AND  c.status_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#object['status_id']#">
				</cfif>
				<cfif structKeyExists(object, "user_id")>
					AND  c.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#object['user_id']#">
				</cfif>
				<cfif structKeyExists(object, "contact_id")>
					AND  c.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#object['contact_id']#">
				</cfif>
				ORDER BY c.created_ts DESC
			</cfquery>

			<cfset results = ArrayNew(1)>
			<cfset contact_results = queryToArray(getContactsQuery)>
			<cfloop array="#contact_results#" index="contact">
				<cfset ArrayAppend(results, getDetailedContactInfo(contact))>
			</cfloop>
			<cfreturn results>
		</cffunction>
		<cfset response["result"] = getContacts()>

	<cfelseif method EQ "POST">
		<cfset validateModel(object)>

		<cfif object.statusId EQ 2 AND trim(object.note) EQ "">
			<cfthrow message="Please enter a note for this contact" type="BadRequest">
		</cfif>
		<cfset contactId = insertContact()>
		<cfset updateContactRelationships(contactId)>
		<cfset addNote(contactId, object.note)>


	<cfelseif method EQ "PUT">
		<cfset validateModel(object)>
		<cfset existingContact = getContact(object.contactId)>
		<cfif object.statusId EQ 2 AND ArrayLen(existingContact.notes) EQ 0 AND trim(object.note) EQ "">
			<cfthrow message="Please enter a note for this contact" type="BadRequest">
		</cfif>
		<cfset updateContact(object,existingContact)>
		<cfset updateContactRelationships(object.contactId)>
		<cfset differences = compareObjects(existingContact, object)>
		<cfset addNote(object.contactId, differences & object.note)>
	</cfif>


	<cffunction name="validateModel">
		<cfargument name="object">

		<cfif !isStruct(object["labId"]) AND object["labId"] EQ "">
			<cfthrow message="Please select a lab for this contact" type="BadRequest">
		</cfif>

		<cfif arrayLen(object.customers) EQ 0><!---Add #unknown if user provided no users--->
			<cfset object.customers = ArrayNew(1)>
			<cfset ArrayAppend(object.customers, '##unknown')>
		<cfelse>
			<cfset customerArray = ArrayNew(1)><!---Change all "unknown" usernames to "#unknown" --->
			<cfloop array="#object.customers#" index="customer">
				<cfif customer EQ "unknown">
					<cfset customer = "##unknown">
				</cfif>
				<cfset arrayAppend(customerArray,customer)>
			</cfloop>
			<cfset object.customers = customerArray>
		</cfif>

		<cfif object.statusId EQ 2 AND arrayLen(object.categories) EQ 0>
			<cfthrow message="Please select at least one category for this contact" type="BadRequest">
		</cfif>

		<cfif isArray(object.links) >
			<cfloop array=#object.links# index="link">
				<cfif !isNumeric(link)>
					<cfthrow message="Link IDs must be integers" type="BadRequest">
				</cfif>
			</cfloop>
		</cfif>
	</cffunction>

	<!--- draws the options for the category select box --->
	<cffunction name="getCategoryMetadataStruct">
		<cfargument name="getCats" type="query">
		<cfargument name="parentCat" type="numeric" default="0">
		<cfargument name="level" type="numeric" default="0">

		<cfset var indentString = "&nbsp;&nbsp;">
		<cfset var catObj = arrayNew(1)>
		<cfset var myCat = structNew()>
		<cfset var myChildren = arrayNew(1)>
		<cfset var i = 0>

		<cfloop query="getCats">
			<cfif parent_category_id EQ parentCat>
				<cfset myCat = structNew()><!---reset myCat to avoid disaster--->

				<cfset myCat["name"] = htmlEditFormat(category_name)>
				<cfset myCat["value"] = htmlEditFormat(category_id)>

				<!---pad out the name with the apropriate level of indentation.--->
				<cfloop from="1" to="#level#" index="i">
					<cfset myCat["name"] = indentString & myCat["name"]>
				</cfloop>

				<!---add our category to our array.--->
				<cfset arrayAppend(catObj, myCat)>

				<!---now fetch any child categories--->
				<cfset myChildren = getCategoryMetadataStruct(getCats, category_id, level + 1)>

				<cfloop from="1" to="#arrayLen(myChildren)#" index="i">
					<cfset arrayAppend(catObj, myChildren[i])>
				</cfloop>

			</cfif>
		</cfloop>

		<cfreturn catObj>
	</cffunction>

	<cffunction name="updateContactRelationships">
		<cfargument name="contactId">
		<cfset updateCustomers(contactId, object.customers)>
		<cfset updateCategories(contactId, object.categories)>
		<cfset updateLinks(contactId, object.links)>
	</cffunction>

	<cffunction name="getBuildingInfo">
		<cfargument name="labId" type="numeric">
		<cfargument name="instanceId" type="numeric">
		<cfset var getBuildingInfoQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getBuildingInfoQuery">
			SELECT TOP 1 l.building_id, l.room_number, l.lab_name, l.lab_id, l.instance_id
			FROM vi_labs l
			WHERE l.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labId#">
				  AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		</cfquery>

		<cfif getBuildingInfoQuery.recordCount EQ 0>
			<cfthrow message="Please select the lab for this contact" type="BadRequest">
		</cfif>
		<cfreturn getBuildingInfoQuery>
	</cffunction>

	<cffunction name="getContact">
		<cfargument name="contactId" type="numeric">
		<cfset var getContactQuery = ''>
		<cfquery datasource="#application.applicationDatasource#" name="getContactQuery">
			SELECT TOP (1) *
			FROM tbl_contacts
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">
		</cfquery>
		<cfset contact = queryToArray(getContactQuery)[1]>
		<cfreturn getDetailedContactInfo(contact)>
	</cffunction>

	<cffunction name="getLabId">
		<cfargument name="buildingId" type="numeric">
		<cfargument name="roomNumber" type="string">
		<cfset var getLabIdQuery = ''>
		<cfquery datasource="#application.applicationDatasource#" name="getLabIdQuery">
			SELECT TOP (1) *
			FROM vi_labs
			WHERE building_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#buildingId#">
			AND room_number = <cfqueryparam cfsqltype="cf_sql_varchar" value="#roomNumber#">
		</cfquery>
		<cfreturn getLabIdQuery.lab_id>
	</cffunction>

	<cffunction name="insertContact">
		<cfset buildingInfo = getBuildingInfo(object.labId.labId,object.labId.instanceId)>
		<cfset var insertContactQuery = ''>
 		<cfquery datasource="#application.applicationDatasource#" name="insertContactQuery">
			INSERT INTO tbl_contacts (instance_id, building_id,room_number,user_id,status_id,ip_address,created_ts,last_opened,minutes_spent)
			OUTPUT inserted.contact_id
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#buildingInfo.instance_id#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#buildingInfo.building_id#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#buildingInfo.room_number#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#object.statusId#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#HTTP.REMOTE_ADDR#">,
				<cfqueryparam cfsqltype="cf_sql_timestamp" value="#Now()#">,
				<cfqueryparam cfsqltype="cf_sql_timestamp" value="#Now()#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="0">

			)
		</cfquery>

		<cfreturn insertContactQuery.contact_id>
	</cffunction>

	<cffunction name="updateContact">
		<cfargument name="newContact" type="struct">
		<cfargument name="existingContact" type="struct">

		<cfset minutesSpent = existingContact.minutesSpent>
		<cfset lastOpened = existingContact.lastOpened>

		<cfset closingAContact = existingContact.statusId EQ 1 && newContact.statusId EQ 2>
		<cfset reopeningAContact = existingContact.statusId EQ 2 && newContact.statusId EQ 1>

		<cfset buildingInfo = getBuildingInfo(newContact.labId.labId,newContact.labId.instanceId)>
		<cfset var updateContactQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="updateContactQuery">
			UPDATE tbl_contacts
			SET instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#buildingInfo.instance_id#">,
				building_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#buildingInfo.building_id#">,
				room_number = <cfqueryparam cfsqltype="cf_sql_varchar" value="#buildingInfo.room_number#">,
				status_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#newContact.statusId#">,

				<cfif closingAContact>
					<cfset minutesSpent = existingContact.minutesSpent + DateDiff("n", existingContact.lastOpened, NOW())>
				<cfelseif reopeningAContact>
					<cfset lastOpened = NOW()>
				</cfif>
				last_opened = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#lastOpened#">,
				minutes_spent = <cfqueryparam cfsqltype="cf_sql_integer" value="#minutesSpent#">
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#existingContact.contactId#">
		</cfquery>
		<cfreturn existingContact.contactId>
	</cffunction>

	<cffunction name="updateCustomers">
		<cfargument name="contactId" type="numeric">
		<cfargument name="customers" type="array">
		<cfset var updateCustomers = ''>
		<cfquery datasource="#application.applicationDataSource#" name="updateCustomersQuery">
			DELETE
			FROM tbl_contacts_customers
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">

			<cfif arrayLen(customers) GT 0>
			INSERT INTO tbl_contacts_customers(contact_id, customer_username)
			VALUES
				<cfset counter = 0>
				<cfloop index="customerUsername" array="#customers#">
					<cfset counter = counter + 1>
					<cfoutput>
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#customerUsername#">)
					<cfif counter NEQ ArrayLen(customers)>,</cfif>
					</cfoutput>
				</cfloop>
			</cfif>
		</cfquery>
	</cffunction>


	<cffunction name="updateCategories">
		<cfargument name="contactId" type="numeric">
		<cfargument name="categories" type="array">
		<cfset counter = 0>
		<cfset var updateCategories = ''>

		<cfquery datasource="#application.applicationDataSource#" name="updateCategories">
			DELETE
			FROM tbl_contacts_categories_match
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">

			<cfif arrayLen(categories) GT 0>
				INSERT INTO tbl_contacts_categories_match(contact_id, category_id,category_ts)
				VALUES
				<cfset counter = 0>
				<cfloop index="categoryId" array="#categories#">
					<cfset counter = counter + 1>
					<cfoutput>
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#categoryId#">,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">)
						<cfif counter NEQ ArrayLen(categories)>,</cfif>
					</cfoutput>
				</cfloop>
			</cfif>
		</cfquery>
	</cffunction>

	<cffunction name="updateLinks">
		<cfargument name="contactId" type="numeric">
		<cfargument name="links" type="array">
		<cfset counter = 0>
		<cfset var updateLinks = ''>
		<cfquery datasource="#application.applicationDataSource#" name="updateLinks">
			DELETE
			FROM tbl_contacts_relationships
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">

			<cfif arrayLen(links) GT 0>
				INSERT INTO tbl_contacts_relationships(contact_id, links_to, user_id, link_ts, active)
				VALUES
				<cfset counter = 0>
				<cfloop index="linkId" array="#links#">
					<cfset counter = counter + 1>
					<cfoutput>
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#linkId#">,
						#session.cas_uid#,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,1)
						<cfif counter NEQ ArrayLen(links)>,</cfif>
					</cfoutput>
				</cfloop>
			</cfif>
		</cfquery>
	</cffunction>


	<cffunction name="addNote">
		<cfargument name="contactId" type="numeric">
		<cfargument name="note" type="string">
		<cfset counter = 0>
		<cfset var addNoteQuery = ''>
		<cfif note NEQ ''>
			<cfquery datasource="#application.applicationDataSource#" name="addNoteQuery">
				INSERT INTO tbl_contacts_notes(contact_id, user_id, note_text, note_ts)
				VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#note#">,
						<cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">)
			</cfquery>
		</cfif>
	</cffunction>


	<cffunction name="getDetailedContactInfo">
		<cfargument name="contact" type="struct">
		<cfset result = {} >
		<cfset result['notes'] = ArrayNew(1)>
		<cfset result['instanceId'] = contact.instance_id>
		<cfset result['contactId'] = contact.contact_id>
		<cfset result['statusId'] = contact.status_id>
		<cfset result['lastOpened'] = contact.last_opened>
		<cfset result['minutesSpent'] = contact.minutes_spent>
		<cfset result['userId'] = contact.user_id>

		<cfset var getLabIdQuery = ''>
		<cfquery dbtype="query"  name="getLabIdQuery">
			SELECT *
			FROM getLabsQuery
			WHERE building_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contact.building_id#">
			AND room_number = <cfqueryparam cfsqltype="cf_sql_varchar" value="#contact.room_number#">
		</cfquery>
		<cfset labObj = structNew()>
		<cfset tempObj = structNew()>
		<cfset tempObj['instanceId'] = getLabIdQuery.instance_id>
		<cfset tempObj['buildingId'] = getLabIdQuery.building_id>
		<cfset tempObj['labId'] = getLabIdQuery.lab_id>
		<cfset labObj = serializeJSON(tempObj)>

		<cfset result['labId'] = labObj>

		<cfset result['customers'] = ArrayNew(1)>
		<cfset var getCustomersQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getCustomersQuery">
			SELECT customer_username
			FROM tbl_contacts_customers
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contact.contact_id#">
		</cfquery>
		<cfloop query="getCustomersQuery">
			<cfset ArrayAppend(result['customers'], getCustomersQuery.customer_username)>
		</cfloop>

		<cfset result['categories'] = ArrayNew(1)>
		<cfset var getCategoriesQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getCategoriesQuery">
			SELECT category_id
			FROM tbl_contacts_categories_match
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contact.contact_id#">
		</cfquery>
		<cfloop query="getCategoriesQuery">
			<cfset ArrayAppend(result['categories'], getCategoriesQuery.category_id)>
		</cfloop>

		<cfset result['links'] = ArrayNew(1)>
		<cfset var getLinksQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getLinksQuery">
			SELECT links_to
			FROM tbl_contacts_relationships
			WHERE contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contact.contact_id#">
		</cfquery>
		<cfloop query="getLinksQuery">
			<cfset ArrayAppend(result['links'], getLinksQuery.links_to)>
		</cfloop>


		<cfset result['notes'] = ArrayNew(1)>
		<cfset var getNotesQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getNotesQuery">
			SELECT n.note_text, n.note_ts, u.username
			FROM tbl_contacts_notes n
			INNER JOIN tbl_users u ON u.user_id = n.user_id
			WHERE n.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#contact.contact_id#">
			ORDER BY n.note_ts ASC
		</cfquery>
		<cfloop query="getNotesQuery">
			<cfset var note = {}>
			<cfset note['title'] = dateTimeFormat (getNotesQuery.note_ts, 'mmm dd, yyyy h:nn tt') & ' - ' & getNotesQuery.username>
			<cfset note['body'] =  getNotesQuery.note_text>
			<cfset ArrayAppend(result['notes'], note)>
		</cfloop>
		<cfreturn result>
	</cffunction>
	<!---This allows us to take a query and turn it into an array which is ideal for spitting out json--->
	<cffunction name="queryToArray" output="false">
		<cfargument name="myQuery" type="query">
		<cfargument name="myColumns" type="string" default=""><!---optionally you may narrow the columns you wish to include in each object we create--->

		<cfset var myArray = ArrayNew(1)>
		<cfset var myObj = "">
		<cfset var rowCnt = 0>
		<cfset var cCase = "">

		<!---if they didn't provide a column list we want them all in our objects.--->
		<cfif trim(myColumns) eq "">
			<cfset myColumns = myQuery.ColumnList>
		</cfif>

		<!---because of how we'll be referring to each row in the query, we want to loop over each row manually--->
		<cfloop from="1" to="#myQuery.recordCount#" index="rowCnt">
			<cfset myObj = structNew()>

			<cfloop list="#myColumns#" index="colName">
				<cfset cCase = colName>

				<cfset myObj[cCase] = myQuery[colName][rowCnt]><!---fetch this column from this row in myQuery--->
			</cfloop>

			<!---our object should be complete, add it to our array.--->
			<cfset arrayAppend(myArray, myObj)>
		</cfloop>

		<cfreturn myArray>
	</cffunction>

	<cffunction name="compareObjects">
		<cfargument name="existingObject" type="struct">
		<cfargument name="newObject" type="struct">
		<cfset differencesText = ''>

		<cfif existingObject["statusId"] NEQ newObject["statusId"]>
			<cfset differencesText &= "<li>Set status to " & ((newObject["statusId"] EQ 1) ? "Open" : "Closed")  & "</li>">
		</cfif>

		<cfset existingObject["customers"] = ListSort(ArrayToList(existingObject["customers"]), "Text")>
		<cfset newObject["customers"] = ListSort(ArrayToList(newObject["customers"]), "Text")>
		<cfif existingObject["customers"] NEQ newObject["customers"]>
			<cfset differencesText &= "<li>Changed customers from " & existingObject["customers"] & " to " & newObject["customers"] & "</li>">
		</cfif>

		<cfset existingObject["links"] = ListSort(ArrayToList(existingObject["links"]), "Numeric")>
		<cfset newObject["links"] = ListSort(ArrayToList(newObject["links"]), "Numeric")>
		<cfif existingObject["links"] NEQ newObject["links"]>
			<cfset differencesText &= "<li>Changed related contacts from " & (existingObject["links"] NEQ "" ? existingObject["links"] : "none") & " to " & (newObject["links"] NEQ "" ? newObject["links"] : "none") & "</li>">
		</cfif>
		<cfset labObj = deserializeJSON(existingObject["labId"])>
		<cfif labObj["labId"] NEQ newObject["labId"]["labId"]>
			<cfloop array="#nonGroupingMetadata['labs']#" index="lab">
				<cfif newObject["labId"]["labId"] EQ lab["value"]>
					<cfset differencesText &= "<li>Set lab to " & #lab['name']# & "</li>">
				</cfif>
			</cfloop>
		</cfif>

		<cfset existingObject["categories"] = ListSort(ArrayToList(existingObject["categories"]), "Numeric")>
		<cfset newObject["categories"] = ListSort(ArrayToList(newObject["categories"]), "Numeric")>
		<cfif existingObject["categories"] NEQ newObject["categories"]>
			<cfset categoryList = ''>
			<cfloop array="#nonGroupingMetadata['categories']#" index="category">
				<cfloop list="#newObject["categories"]#" index="submittedCategory">
					<cfif submittedCategory EQ category["value"]>
						<cfset categoryList = listAppend(categoryList, category['name'])>
					</cfif>
				</cfloop>
			</cfloop>
			<cfset differencesText &= "<li>Set categories to " & #categoryList# & "</li>">
		</cfif>

		<cfif differencesText NEQ "">
			<cfset differencesText = "<ul>" & differencesText & "</ul>">
		</cfif>
		<cfreturn differencesText>
	</cffunction>
<cfcatch>
	<cfheader statuscode="403" statustext="#cfcatch.message# #cfcatch.detail#">
</cfcatch>
</cftry>

<!---now we can output our JSON response.--->
	<cfset response["object"] = serializeJSON(object)>
<cfoutput>#serializeJSON(response)#</cfoutput>