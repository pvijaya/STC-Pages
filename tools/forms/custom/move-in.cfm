<cfmodule template="#application.appPath#/header.cfm" title='Move-In IT Issue'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<h1>Move-In IT Issue</h1>
<cfparam name="frmSubmit" type="string" default="">

<cfparam name="frmUsername" type="string" default="">
<cfparam name="frmActor" type="integer" default="0">

<cfparam name="frmFirstName" type="string" default="">
<cfparam name="frmLastName" type="string" default="">
<cfparam name="frmGender" type="string" default="?">
<cfparam name="frmBuildingCode" type="integer" default="0">
<cfparam name="frmRoom" type="string" default="">
<cfparam name="frmPhone" type="string" default="">

<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="frmCategoryId" default='[]' constructor='[{"category_id":"integer","type_id":"integer","description":"string"}]'>
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="frmDevices" default='[""]' constructor='["string"]'>

<cfparam name="frmDescription" type="string" default="">

<cfquery datasource="iu-tickets-dev" name="getActors">
	SELECT actor_id, actor_name
	<!---FROM dbo.get_actors('2015-08-16')--->
	FROM dbo.get_actors(GETDATE())
	WHERE actor_parent_id IS NULL
	AND is_center = 1
	AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	ORDER BY actor_name
</cfquery>

<cfset actorOptions = arrayNew(1)>
<cfloop query="getActors">
	<cfset arrayAppend(actorOptions, {"name": actor_name, "value": actor_id})>
</cfloop>

<!---if we don't have a username, get that first.--->
<cfif trim(frmUsername) eq "">
	<form class="form-horizontal" method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
		<cfset bootstrapCharField("frmUsername", "IU Username", frmUsername, "Your IU username, the part before the @ in your IU email address.", "jqdoe")>
		<cfset bootstrapSelectField("frmActor", actorOptions, "Move-In Table", frmActor, "Which building's Move-In table are you at?", [""])>

		<cfset bootstrapSubmitField("frmSubmit", "Begin")>
	</form>

<cfelse>
	<cfif frmSubmit eq "Submit">
		<!---the user has submitted the form, process their input and create a ticket.--->
		<cftry>
			<!---make sure all the user input is valid--->
			<cfif not listFindNoCase("M,F,?", frmGender)>
				<cfset frmGender = "?">
			</cfif>

			<!---must have a building--->
			<cfif frmBuildingCode eq 0>
				<cfthrow type="custom" message="Residence Hall" detail="Residence Hall is a required field, please select the building you live in.">
			</cfif>

			<!---must have a room number.--->
			<cfif trim(frmRoom) eq "">
				<cfthrow type="custom" message="Room Number" detail="Room Number is a required field.">
			</cfif>

			<!---If they gave a phone number it needs to be a valid phone number, and not too large for our database.--->
			<cfset frmPhone = trim(frmPhone)>
			<cfif len(frmPhone) gt 14 OR not isValid("telephone", frmPhone)>
				<cfthrow type="custom" message="Phone Number" detail="Phone number is a required field, provide a phone number in the format <b>xxx xxx-xxxx</b>">
			</cfif>

			<!---cfthrow type="custom" message="Test Error" detail="a test error with more details."--->

			<cfset note = "<p>Move-In Ticket for #frmUsername#</p>">

			<!---we may encounter several categories and types, just record the last one we hit for use with the query.--->
			<cfset myCatId = 0>
			<cfset myTypeId = 0>
			<cfset note = note & "<p><b>Reported Problems:</b></p> <ul>">
			<cfloop array="#frmCategoryId#" index="cat">
				<cfif cat.category_id gt 0>
					<cfset myCatId = cat.category_id>
					<cfset myTypeId = cat.type_id>
				</cfif>

				<cfset note = note & "<li>#cat.description#</li>">
			</cfloop>
			<cfset note = note & "</ul>">


			<cfset note = note & "<p><b>Devices:</b></p> <ul>">
			<cfloop array="#frmDevices#" index="device">
				<cfset note = note & "<li>#device#</li>">
			</cfloop>
			<cfset note = note & "</ul>">

			<!---for the user entered description remove any HTML and replaces linefeeds with BR tags.--->
			<cfset note = note & "<p><b>Description:</b><br/>#replace( htmlEditFormat(frmDescription), '#chr(10)#', '<br/>', 'all' )#</p>">

			<!---
			ticket_uid	ticket_id	opened	opened_by	closed	closed_by	lastModified	lastModified_by	summary	catagory	type	status_id	priority_id	actor_id	os_id	datajack	nid	fname	lname	building_code	phone	sex	room_number	memo	alt_phone	sweeps	wap_model
			DAB882B5-831D-4F9A-AE26-0003E1D9BF1C	15374	2011-10-18 16:21:57.257	852055064	2011-11-02 18:40:23.000	848018527	2011-11-02 18:40:23.000	848018527	APT: 11/02 - Check Data Jack and if possibile collect hub	3	21	2	3	15	14	A	pgilsonj	Paul William	Gilson	1608		M	8-106		317 366-5119	0	NULL
			--->
			<cfquery datasource="iu-tickets-dev" name="addTicket">
				BEGIN TRANSACTION
					DECLARE @uid uniqueidentifier = NEWID()

					INSERT INTO tbl_tkt_tickets (ticket_uid, opened, opened_by, lastModified, lastModified_by, summary, catagory, type, status_id, priority_id, actor_id, nid, fname, lname, sex, building_code, room_number, alt_phone, sweeps)
					OUTPUT INSERTED.ticket_uid
					VALUES (
						@uid,
						GETDATE(),
						0,
						GETDATE(),
						0,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="Move-In Ticket for #frmUsername#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#myCatId#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#myTypeId#">,
						1,
						2,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#frmActor#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmFirstName#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmLastName#">,
						<cfqueryparam cfsqltype="cf_sql_char" value="#frmGender#">,
						<cfqueryparam cfsqltype="cf_sql_integer" value="#frmBuildingCode#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmRoom#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmPhone#">,
						1
					)

					/*now add the note*/
					INSERT INTO tbl_tkt_ticket_notes (ticket_note_id, ticket_note, entered_by, entered_on)
					VALUES(
						@uid,
						<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#note#">,
						0,
						GETDATE()
					)

				IF @@ERROR <> 0
					ROLLBACK
				ELSE
					COMMIT
			</cfquery>


			<!---If we got this far everything worked, stop executing code.--->
			<div class="alert alert-success" role="alert">We got through to the success case.</div>

			<cfoutput>
				<p>
					<a href="#cgi.script_name#?frmActor=#frmActor#" type="button" class="btn btn-default">Open Another Issue</a>
				</p>
			</cfoutput>

			<cfmodule template="#application.appPath#/footer.cfm">
			<cfabort>

		<cfcatch type="any">
			<div class="alert alert-danger" role="alert">
				<cfoutput><b>#cfcatch.message#</b> - #cfcatch.detail#</cfoutput>
			</div>
		</cfcatch>
		</cftry>


	</cfif>
	<!---we do have a username, see if they have an RPS entry we can seed the default values with.--->
	<!---draw the main form--->
	<cfquery datasource="iu-tickets-dev" name="getRPSUser">
		SELECT lastName, firstName, sex, building_code, room
		FROM tbl_tkt_rps_residents
		WHERE networkId = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">
	</cfquery>

	<cfloop query="getRPSUser">
		<cfset frmFirstName = trim(frmFirstname) eq "" ? firstName:frmFirstName>
		<cfset frmLastName = trim(frmLastname) eq "" ? lastName:frmLastName>
		<cfset frmGender = trim(frmGender) eq "?" ? sex:frmGender>
		<cfset frmBuildingCode = frmBuildingCode eq 0 ? building_code:frmBuildingCode>
		<cfset frmRoom = trim(frmRoom) eq "" ? room:frmRoom>
	</cfloop>

	<!---build-up our options for radio buttons and selects.--->
	<cfset genderOptions = arrayNew(1)>
	<cfset arrayAppend(genderOptions, {"name": "Female", "value": "F"})>
	<cfset arrayAppend(genderOptions, {"name": "Male", "value": "M"})>
	<cfset arrayAppend(genderOptions, {"name": "Prefer not to answer", "value": "?"})>

	<cfset buildingOptions = arrayNew(1)>
	<cfset arrayAppend(buildingOptions, {"name":"", "value": 0})>
	<cfquery datasource="iu-tickets-dev" name="getRPSBuildings">
		SELECT b.building_code, b.building_name, b.actor_id
		FROM tbl_tkt_rps_buildings b
		INNER JOIN tbl_tkt_actors a ON a.actor_id = b.actor_id
		WHERE a.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY b.building_name
	</cfquery>
	<cfloop query="getRPSBuildings">
		<cfset arrayAppend(buildingOptions, {"name":building_name, "value": building_code})>
	</cfloop>

	<!---a basic smattering of ticket categories that may apply to the persons problem--->
	<cfset categoryOptions = arrayNew(1)>
	<cfset arrayAppend(categoryOptions, {"name": "Get Connected", "value": {"category_id": 2, "type_id": 31, "description": "Get Connected"} })>
	<cfset arrayAppend(categoryOptions, {"name": "IU Wireless", "value": {"category_id": 32, "type_id": 39, "description": "IU Wireless"} })>
	<cfset arrayAppend(categoryOptions, {"name": "Wired Network", "value": {"category_id": 2, "type_id": 0, "description": "Wired Network"} })>
	<cfset arrayAppend(categoryOptions, {"name": "Missing Cable", "value": {"category_id": 3, "type_id": 37, "description": "Missing Cable"} })>
	<cfset arrayAppend(categoryOptions, {"name": "Security", "value": {"category_id": 1, "type_id": 0, "description": "Security"} })>
	<cfset arrayAppend(categoryOptions, {"name": "Box", "value": {"category_id": 0, "type_id": -1, "description": "Box"} })>
	<cfset arrayAppend(categoryOptions, {"name": "IU Ware", "value": {"category_id": 0, "type_id": -2, "description": "IU Ware"} })>
	<cfset arrayAppend(categoryOptions, {"name": "IUanyWare", "value": {"category_id": 0, "type_id": -3, "description": "IUanyWare"} })>
	<cfset arrayAppend(categoryOptions, {"name": "IU Email", "value": {"category_id": 0, "type_id": -3, "description": "IU Email"} })>
	<cfset arrayAppend(categoryOptions, {"name": "Printing", "value": {"category_id": 5, "type_id": 0, "description": "Printing"} })>
	<cfset arrayAppend(categoryOptions, {"name": "Other", "value": {"category_id": 0, "type_id": 0, "description": "Other"} })>

	<!---examples of hardware the user might be using--->
	<cfset deviceOptions = arrayNew(1)>
	<cfset arrayAppend(deviceOptions, {"name": "iPhone/iPod/iPad/iOS", "value": "iPhone/iPod/iPad/iOS"})>
	<cfset arrayAppend(deviceOptions, {"name": "Android Phone/Tablet", "value": "Android Phone/Tablet"})>
	<cfset arrayAppend(deviceOptions, {"name": "Windows Laptop", "value": "Windows Laptop"})>
	<cfset arrayAppend(deviceOptions, {"name": "Apple Laptop", "value": "Apple Laptop"})>
	<cfset arrayAppend(deviceOptions, {"name": "Playstation", "value": "Playstation"})>
	<cfset arrayAppend(deviceOptions, {"name": "Xbox", "value": "Xbox"})>
	<cfset arrayAppend(deviceOptions, {"name": "WiiU", "value": "Wiiu"})>
	<cfset arrayAppend(deviceOptions, {"name": "Windows Workstation", "value": "Windows Workstation"})>
	<cfset arrayAppend(deviceOptions, {"name": "Apple Workstation", "value": "Apple Workstation"})>
	<cfset arrayAppend(deviceOptions, {"name": "Other", "value": "Other"})>


	<!---draw the actual form.--->
	<form class="form-horizontal" method="post" action="<cfoutput>#cgi.script_name#</cfoutput>">
		<cfset bootstrapTextDisplay("frmUsername", "IU Username", frmUsername, "Your IU username, the part before the @ in your IU email address.", "jqdoe")>
		<cfset bootstrapHiddenField("frmUsername", frmUsername)>

		<cfset bootstrapSelectField("frmActor", actorOptions, "Move-In Table", frmActor, "Which building's Move-In table are you at?", [""])>

		<cfset bootstrapCharField("frmFirstName", "First Name", frmFirstName, "", "John")>
		<cfset bootstrapCharField("frmLastName", "Last Name", frmLastName, "", "Doe")>
		<cfset bootstrapRadioField("frmGender", genderOptions, "Gender", frmGender, "")>
		<cfset bootstrapSelectField("frmBuildingCode", buildingOptions, "Residence Hall", frmBuildingCode, "The name of the RPS building you live in.")>
		<cfset bootstrapCharField("frmRoom", "Room Number", frmRoom, "", "A-123")>
		<cfset bootstrapCharField("frmPhone", "Phone Number", frmPhone, "A phone number you can be reached at about this issue.", "812 555-1234")>

		<cfset bootstrapCheckField("frmCategoryId", categoryOptions, "Type of Problems", frmCategoryId, "Check all boxes for categories that describe what you would like assistance with.")>

		<cfset bootstrapCheckField("frmDevices", deviceOptions, "Affected Devices", frmDevices, "Check all boxes for devices that are affected by the problem your are experiencing.")>

		<div class="form-group">
			<label class="col-sm-3 control-label" for="frmDescription">Description (optional)</label>
			<div class="col-sm-9">
				<textarea class="form-control" name="frmDescription" id="frmDescription"><cfoutput>#htmlEditFormat(frmDescription)#</cfoutput></textarea>
			</div>
		</div>

		<cfset bootstrapSubmitField("frmSubmit", "Submit")>
	</form>
</cfif>



<cfmodule template="#application.appPath#/footer.cfm">