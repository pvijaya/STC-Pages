<cfmodule template="#application.appPath#/header.cfm" title='Incident Report'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="requestType" type="string" default="">
<cfparam name="dateSelected" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">
<cfparam name="hoursSelected" default="#TimeFormat(Now(),'hh')#" type="string">
<cfparam name="minutesSelected" default="#TimeFormat(Now(),'mm')#" type="string">
<cfparam name="timeModifier" default="#TimeFormat(Now(), 'tt')#" type="string">
<cfparam name="locationSelected" default="i0l0" type="string">
<cfparam name="prNumber" default="" type="string">
<cfparam name="situation" type="string" default="">
<cfparam name="description" type="string" default="">
<cfparam name="person" type="string" default="">
<cfparam name="position" type="string" default="">
<cfparam name="action" type="string" default="">

<!--- STYLE / CSS --->
<style type="text/css">

	h3 {
		margin-bottom:0px;
	}

	.row {
		width:100%;
		min-height:20%;
		clear:both;
	}

	.left {
		float:left;
		clear:left;
	}

	.right {
		min-width:300px;
		max-width: 40%;
		float:right;
		clear:right;
	}

	.block-card {
		text-align:left;
		margin-top:0px;
		margin-right:5px;
		margin-bottom:0px;
		padding-top:0px;
		padding-bottom:0px;
	}

</style>

<!--- HEADER / NAVIGATION --->
<h1>Incident Report</h1>
<cfoutput>
	<cfif hasMasks('CS')>
		<a href="#application.appPath#/tools/incident-report/incident-report-viewer.cfm">Incident Report Viewer </a>
	</cfif>
	<cfif hasMasks('Admin')>
		| <a href="#application.appPath#/tools/incident-report/incident-situation-manager.cfm">Situations Manager</a>
	</cfif>
	<br/>

</cfoutput>

<cfset myInstance = getInstanceById(session.primary_instance)>

<!---use the provided location to get a lab object--->
<cfset myLab = parseLabName(locationSelected)>

<!--- Merges the 4 string lists into 1 array ---->
<cfset peopleArray = arrayNew(1)>
<cfloop from="1" to="#listLen(person)#" index="n">
	<cfset peopleArray[n] = structNew()>
	<cfset peopleArray[n].name = ListGetAt(person, n)>
	<cfif listLen(position) GTE n>
		<cfset peopleArray[n].position = ListGetAt(position,n)>
	<cfelse>
		<cfset peopleArray[n].position = "Unknown"> <!--- if they blank position for some reason --->
	</cfif>
</cfloop>

<!--- the default email recipients for both IUB and IUPUI --->
<cfset mailList = "tccwm@iu.edu">

<!--- based on session id, add individual email recipients --->
<cfif myInstance.instance_mask EQ "IUB">
	<cfset mailList = listAppend(mailList, "tcc-admin-l@indiana.edu")>
	<cfset mailList = listAppend(mailList, "tcciub@indiana.edu")>
<cfelseif myInstance.instance_mask EQ "IUPUI">
	<cfset mailList = listAppend(mailList, "tcc-admin-l@iupui.edu")>
</cfif>

<!--- fetch the user's email address --->
<cfquery datasource="#application.applicationdatasource#" name="getUserEmail">
	SELECT email
	FROM tbl_users
	WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
</cfquery>

<cfif action EQ "Send Report">

	<cftry>

		<cfoutput>

			<cfif trim(description) EQ "">
				<cfthrow message="Missing Input" detail="You must include a description.">
			</cfif>

			<cfif myLab.instance eq 0 OR myLab.lab eq 0>
				<cfthrow type="custom" message="Missing Input" detail="You must provide a location for this incident.">
			</cfif>

			<cfset situationTime = dateSelected & ' ' & hoursSelected & ':' & minutesSelected & ':00 ' & timeModifier>

			<cfquery datasource="#application.applicationdatasource#" name="insertIncident">
				INSERT INTO tbl_incident_reports(reporter_uid, situation_time, instance_id, lab_id, description, pr_number)
				OUTPUT INSERTED.incident_id [newID]
				VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					   <cfqueryparam cfsqltype="cf_sql_timestamp" value="#situationTime#">,
					   <cfqueryparam cfsqltype="cf_sql_integer" value="#myLab.instance#">,
					   <cfqueryparam cfsqltype="cf_sql_integer" value="#myLab.lab#">,
					   <cfqueryparam cfsqltype="cf_sql_varchar" value="#description#">,
					   <cfqueryparam cfsqltype="cf_sql_varchar" value="#prNumber#">
					)
			</cfquery>

			<cfset incidentId = insertIncident.NEWID>

			<cfloop from="1" to="#arrayLen(peopleArray)#" index="i">
				<cfif NOT (peopleArray[i].name EQ "Unknown")>
					<cfquery datasource="#application.applicationdatasource#" name="insertIncidentPeople">
						INSERT INTO tbl_incident_people(name, person_position, incident_id)
						VALUES(
							 <cfqueryparam cfsqltype="cf_sql_varchar" value="#peopleArray[i].name#">,
							 <cfqueryparam cfsqltype="cf_sql_varchar" value="#peopleArray[i].position#">,
							 <cfqueryparam cfsqltype="cf_sql_varchar" value=" #incidentId#">
							)
					</cfquery>
				</cfif>
			</cfloop>

			<cfif listLen(situation)>
				<cfquery datasource="#application.applicationdatasource#" name="insertIncidentSituations">
					INSERT INTO tbl_incident_situation_match (incident_id, incident_situation_id)
					VALUES
					<cfloop from="1" to="#listLen(situation)#" index="i">
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#incidentId#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#listGetAt(situation, i)#">)<cfif i lt listLen(situation)>,</cfif>
					</cfloop>
				</cfquery>
			</cfif>

			<!--->
			<cfmail to="#mailList#"
					from="#getUserEmail.email#"
					bcc="#getUserEmail.email#"
					subject="New Incident Report from #session.cas_username#"
					type="text/html">
				<h2>An incident report has been filed</h2>
				<p>For more details about the incident please visit the <a href="https://#cgi.server_name#/#application.appPath#/tools/incident-report/incident-report-viewer.cfm?frmAction=View&incidentId=#incidentId#">Incident Report System</a>.

				<p>Have a wonderful day!</p>
				</p>
			</cfmail>
			--->

			<!--- reset form values --->
			<cfset description = "">
			<cfset person = "">
			<cfset position = "">
			<cfset dateSelected = "#DateFormat(Now(),'yyyy-mm-dd')#">
			<cfset hoursSelected = "#TimeFormat(Now(),'hh')#">
			<cfset minutesSelected = "#TimeFormat(Now(),'mm')#">
			<cfset timeModifier = "#TimeFormat(Now(),'tt')#">
			<cfset locationSelected = "i0l0">
			<cfset prNumber = "">

			<p class="ok">
				Incident documented successfully.
			</p>

		</cfoutput>

		<cfcatch>
			<p class="warning">
				<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
			</p>
		</cfcatch>

	</cftry>

</cfif>

<!---HTML--->
<p/>
<p>
	The incident Report is a method used to inform the Admin Team via email about any issues related TCC Operations.
</p>

<cfquery datasource="#application.applicationdatasource#" name="getSituations">
	SELECT s.incident_situation_id, s.situation AS situation_name
	FROM tbl_incident_situations s
	WHERE s.active = 1
	ORDER BY s.sort_order, s.situation
</cfquery>

<cfoutput>
	<form action="#cgi.script_name#" method="post" id="form1Id">

		<input type="hidden" name="action" value="Send Report">

		<fieldset>

			<div class="row">

				<div class="left">

					<label for="dateSelectorId">Date of incident: </label>
					<input type="text" name="dateSelected" id="dateSelectorId" value="#dateSelected#"/>
					<br /><br />

					<script type="text/javascript">
						$("##dateSelectorId").datepicker({dateFormat: "mm/dd/yy"});
					</script>

					<label for="hoursSelected">Time of incident: </label>
					<select id="hoursSelected"  type="text" name="hoursSelected"/>
						#shiftHours()#
					</select>
					<select  type="text" name="minutesSelected"/>
						#shiftMinutes()#
					</select>
					<select type="text" name="timeModifier">
						#shiftModifier()#
					</select>

					<br /><br />

					<label for="locationSelected">Location: </label>
					#drawLabsSelector('locationSelected',locationSelected)#

					<br /><br />

					<label>Footprint Number (if applicable):
						<input type="text" name="prNumber" value="#prNumber#">
					</label>
					<br />

				</div>

				<div class="block-card right">

					<h3>Related Resources</h3>

					<ul>
						<li><a href="http://www.indiana.edu/~iupd" target="_new">IUPD Contact Information</a></li>
						<li><a href="http://www.iu.edu/~code/" target="_new">Code Of Student Rights, Responsibilities, and Conduct</a></li>
					</ul>

				</div>

			</div>

		</fieldset>

		<br/>

		<div class="row">
			<fieldset>
				<legend>Check all that apply to the situation</legend>

				<cfloop query="#getSituations#">
					<label>
						<input type="checkbox" name="situation" value="#incident_situation_id#" <cfif listFind(situation, incident_situation_id)>checked="true"</cfif>> #situation_name#
					</label><br/>
				</cfloop>
			</fieldset>
		</div>
		<br/>

		<fieldset>
			<label for="descriptionId" style="font-size:120%;">Description of the Incident:</label>
			<textarea id="descriptionId" name="description" style="width:100%;height:200px;">#description#</textarea>
		</fieldset>
		<br/>

		<fieldset>
			<legend>UITS Employees Around Situation</legend>
			<cfset found = 0>
			<cfloop from="1" to="#listLen(person)#" index="n">
				<cfif listLen(position) GTE n>
					<cfif listGetAt(person, n) NEQ "Unknown" AND listGetAt(position, n) EQ "UITS">
						<div id="uitsPeople">
							<label for="uitsPerson1">Name </label>
							<input id="uitsPerson1" type="text" name="person" value="#listGetAt(person, n)#"/>
							<input type="hidden" name="position" value="UITS" />
						</div>
						<cfset found = 1>
					</cfif>
				</cfif>
			</cfloop>
			<cfif found EQ 0>
				<div id="uitsPeople">
					<label for="uitsPerson1">Name </label>
					<input id="uitsPerson1" type="text" name="person"/>
					<input type="hidden" name="position" value="UITS" />
				</div>
			</cfif>
			<a id="addUITS" href="##" onclick="return false;">Add More</a>
		</fieldset>
		<br/>

		<fieldset>
			<legend>Other Persons Involved in Situation</legend>
			<cfset found = 0>
			<cfloop from="1" to="#listLen(person)#" index="n">
				<cfif listLen(position) GTE n>
					<cfif listGetAt(person, n) NEQ "Unknown" AND listGetAt(position, n) NEQ "UITS">
						<div id="otherPeople">
							<label for="iPerson1">Name </label><input id="iPerson1" type="text" name="person" value="#listGetAt(person, n)#" />
							<label for="iPosition1">Position </label><input id="iPosition1" type="text" name="position" value="#listGetAt(position, n)#" />
						</div>
						<cfset found = 1>
					</cfif>
				</cfif>
			</cfloop>

			<cfif found EQ 0>
				<div id="otherPeople">
					<label for="iPerson1">Name </label><input id="iPerson1" type="text" name="person" />
					<label for="iPosition1">Position </label><input id="iPosition1" type="text" name="position" value="Unknown" />
				</div>
			</cfif>

			<a id="addPeople" href="##"onclick="return false;">Add More</a>

		</fieldset>

		<p>This page will be sent to the TCC Admin team.</p>

		<input id="submitIncident" onclick="return false;" type="submit"  name="action" value="Send Report">

	</form>

	<script type="text/javascript">
		var uitsCount = 1;
		var elementCount = 2;
		$('##addUITS').click(function() {
			uitsCount++;
			var newUITS = '<br/><label for="uitsPerson'+uitsCount+'">Name </label><input id="uitsPerson'+uitsCount+'" type="text" name="person" /><input id="uitsPosition'+uitsCount+'" type="hidden" name="position" value="UITS" />';
			$('##uitsPeople').append(newUITS);

		});
		var peopleCount = 1;
		$('##addPeople').click(function() {
			peopleCount++;
			var newPerson = '<br/><label for="iPerson'+peopleCount+'">Name </label><input id="iPerson'+peopleCount+'" type="text" name="person" />	<label for="iPosition'+peopleCount+'">Position </label><input id="iPosition'+peopleCount+'" type="text" name="position" value="Unknown"/>';
			$('##otherPeople').append(newPerson);

		});
		$('##submitIncident').click(function() {
			console.log('a');
			utisError = 0;
			for (var a = 1; a <= uitsCount; a++) {
				if($('##uitsPerson'+a).val() == "" || $('##uitsPosition'+a).val() == "") {
					$('##uitsPerson'+a).val("Unknown");
					$('##uitsPosition'+a).val("Unknown");
				}
			}
			peopleError = 0;
			for (var a = 1; a <= peopleCount; a++) {
				if($('##iPerson'+a).val() == "" || $('##iPerson'+a).val() == "") {
					$('##iPerson'+a).val("Unknown");
					$('##iPerson'+a).val("Unknown");
				}
			}
			$('##form1Id').submit();
		});
	</script>

</cfoutput>

<!--- FUNCTIONS --->
<!--- draws a select box for hours --->
<cffunction name="shiftHours">

	<cfoutput>

		<option value="---">---</option>
		<cfloop from="0" to="12" index="i" step="1">
			<cfif i LTE 9>
				<option value="0#i#" <cfif hoursSelected EQ "0#i#">selected="selected"</cfif>>0#i#</option>
			<cfelse>
			<option value="#i#" <cfif hoursSelected EQ #i#>selected="selected"</cfif>>#i#</option>
			</cfif>
		</cfloop>

	</cfoutput>

</cffunction>

<!--- draws a select box for minutes --->
<cffunction name="shiftMinutes">

	<cfoutput>
		<option value="---">---</option>

		<cfloop from="0" to="60" index="i" step="1">
			<cfif i LTE 9>
				<option value="0#i#" <cfif minutesSelected EQ "0#i#">selected="selected"</cfif>>0#i#</option>
			<cfelse>
				<option value="#i#" <cfif minutesSelected EQ "0#i#">selected="selected"</cfif>>#i#</option>
			</cfif>
		</cfloop>

	</cfoutput>

</cffunction>

<!--- draw an am / pm selector --->
<cffunction name="shiftModifier">

	<cfoutput>
		<option value="---">---</option>

		<option value="AM" <cfif timeModifier EQ "AM">selected="selected"</cfif>>AM</option>
		<option value="PM" <cfif timeModifier EQ "PM">selected="selected"</cfif>>PM</option>

	</cfoutput>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
