<cfmodule template="#application.appPath#/header.cfm" title='Cleaning Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmLab" type="string" default="">
<cfparam name="frmCleaningId" type="integer" default="0">
<cfparam name="frmLabId" type="integer" default="0">
<cfparam name="frmInstanceId" type="integer" default="0">
<cfparam name="frmRetired" type="boolean" default="0">
<cfparam name="submitted" type="boolean" default="0">
<cfparam name="frmRetiredSections" type="string" default="">
<cfparam name="frmActiveSections" type="string" default="">

<!--- Header / Navigation --->
<h1>Cleaning Manager</h1>
<cfif frmCleaningId GT 0 OR frmAction EQ "NewLab">
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_manager.cfm</cfoutput>">Go Back</a>]
</cfif>
[<a href="<cfoutput>#application.appPath#/tools/cleaning/lab_cleaning.cfm</cfoutput>">Submit Cleaning</a>]
<cfif hasMasks('cs')>
	[<a href="<cfoutput>#application.appPath#/tools/cleaning/cleaning_report.cfm</cfoutput>">Cleaning Submissions</a>]
</cfif>

<br/>

<cfquery datasource="#application.applicationDataSource#" name="getInstances">
	SELECT a.instance_id, a.instance_name, a.instance_mask
	FROM tbl_instances a
	INNER JOIN tbl_user_masks b ON b.mask_name = a.instance_mask
	WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, a.instance_mask)
</cfquery>

<!--- Handle user input. --->
<cfif frmAction EQ "Submit">

	<cftry>
		
		<cfset labStruct = parseLabName(frmLab)>
		<cfset frmLabId = labStruct.lab>
		<cfset frmInstanceId= labStruct.instance>
		
		<cfquery datasource="#application.applicationDataSource#" name="checkLabs">
			SELECT a.cleaning_id
			FROM tbl_cleaning_labs a
			WHERE a.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLabId#">
			      AND a.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#">
			      AND a.cleaning_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
		</cfquery>
		
		<cfif checkLabs.recordCount GT 0>
			<cfthrow message="Invalid Lab Selection" 
					 detail="That lab already has a cleaning associated with it.">
		</cfif>
		
		<!--- Preserve user input from this point forward. --->
		<cfset submitted = 1>
		
		<cfif frmCleaningId EQ 0>	
					
			<!--- Create new lab record. --->
			<cfquery datasource="#application.applicationDataSource#" name="addLab">
				INSERT INTO tbl_cleaning_labs (lab_id, instance_id)
				OUTPUT inserted.cleaning_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmLabId#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#">
				)
			</cfquery>	
				
			<cfset frmLabId = "0">
					
			<p class="ok"> Lab successfully created. </p>	
				
		<cfelseif frmCleaningId GT 0>
				
			<!--- Update existing lab record. --->
			<cfquery datasource="#application.applicationDataSource#" name="editTask">
				UPDATE tbl_cleaning_labs
				SET lab_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmLabId#">,
					instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
				WHERE cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
			</cfquery>
			
			<!--- Update the new active and sort values. --->			
			<cfquery datasource="#application.applicationDataSource#" name="getSections">
				SELECT a.section_id, a.sort_order
				FROM tbl_cleaning_labs_sections a
				WHERE a.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
				ORDER BY a.sort_order
			</cfquery>
			
			<cfloop query="getSections">
				
				<cfparam name="frmSortOrder#section_id#" type="integer" default="#sort_order#">
				
				<!--- Each section id should belong in either frmActiveSections or frmRetiredSections. --->
				<!--- This is how we sort out the new values. --->
				<cfset section_retired = 0>
				<cfif listFindNoCase(frmActiveSections, section_id)>
					<cfset section_retired = 0>
				<cfelseif listFindNoCase(frmRetiredSections, section_id)>
					<cfset section_retired = 1>
				</cfif>
					
				<!--- Fetch the user-entered sort values. --->
				<cfset userVal = evaluate("frmSortOrder#section_id#")>
								
				<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
					UPDATE tbl_cleaning_labs_sections
					SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#userVal#">,
					 	retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#section_retired#">
					WHERE section_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#section_id#">
				</cfquery>				
				
			</cfloop>
						
			<p class="ok"> Lab successfully updated. </p>	
				
		</cfif>
		
		<!--- Reset the form action. --->
		<cfset frmAction = "">
		
	<cfcatch>
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>	
	</cftry>

</cfif>

<!--- Draw forms. --->

<!--- Editing or Creating. --->
<cfif frmCleaningId GT 0 OR frmAction EQ "NewLab">

	<cfif frmCleaningId GT 0>
		
		<h2>Edit Cleaning Form</h2>
		
		<!--- If the user is editing and hasn't submitted this form, use the existing values. --->
		<cfif not submitted>
			<cfquery datasource="#application.applicationDataSource#" name="getLab">
				SELECT a.lab_id, a.instance_id
				FROM tbl_cleaning_labs a
				WHERE a.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
			</cfquery>
			
			<cfset frmLabId = getLab.lab_id>
			<cfset frmInstanceId = getLab.instance_id>
			<cfset frmLab = "i#frmInstanceId#l#frmLabId#">
			
			<!--- If editing, fetch the existing record for this lab. --->
			<cfquery datasource="#application.applicationDataSource#" name="getLabInfo">
				SELECT a.retired
				FROM tbl_cleaning_labs a
				WHERE a.lab_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmLabId#">
					  AND a.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#">
			</cfquery>
			
			<cfset frmRetired = getLabInfo.retired>
			
		</cfif>
		
	<cfelse>
	
		<h2>Create Cleaning Form</h2>	
	
	</cfif>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<!--- Track our non-form values. --->
		<cfoutput>
			<input type="hidden" name="submitted" value="#submitted#">
			<input type="hidden" name="frmCleaningId" value="#frmCleaningId#">
		</cfoutput>
		
		<table>
			<tr>
				<td><label for="frmLab">Base Lab:</label></td>
				<td><cfset drawLabsSelector("frmLab", "#frmLab#")></td>
			</tr>
			<cfif frmCleaningId GT 0>
				<tr>
					<td>Active?</td>
					<td>
						<label><input type="radio" name="frmRetired" value="0" <cfif NOT frmRetired>checked</cfif>>Yes</label>
						<label><input type="radio" name="frmRetired" value="1" <cfif frmRetired>checked</cfif>>No</label>	
					</td>
				</tr>
				<tr>
					<td>Sections:</td>
				</tr>
			</cfif>
		</table>
		
		<!--- Draw the sections of this lab, for easy re-ordering / retiring. --->
		<cfif frmLabId GT 0>	
			<cfset drawSections(0)>	
			[<a href="<cfoutput>#application.appPath#/tools/cleaning/section_manager.cfm?cleaningId=#frmCleaningId#</cfoutput>">New Section</a>]<br/>	
			</br>
			<cfset drawSections(1)>		
		</cfif>
		
		<br/>
		
		<input type="submit" value="Submit" name="frmAction">
		
	</form>	

<!--- Select a lab. --->
<cfelse>

	<!--- Fetch existing labs with cleaning forms. --->
	<cfquery datasource="#application.applicationDataSource#" name="getLabs">
		SELECT a.cleaning_id, a.lab_id, a.retired, b.lab_name
		FROM tbl_cleaning_labs a
		INNER JOIN vi_labs b ON b.lab_id = a.lab_id AND b.instance_id = a.instance_id
		INNER JOIN tbl_instances c ON c.instance_id = a.instance_id
		WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, c.instance_mask)
		ORDER BY a.retired, a.lab_id
	</cfquery>

	<br/>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<fieldset>
			
			<legend>Choose</legend>
			
			<label>
				Select a Lab:
				<select name="frmCleaningId">
					<cfoutput query="getLabs">
						<option value="#cleaning_id#">
							#lab_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			<input type="submit" value="Go" name="frmAction">
			
			<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
						
			<a href="<cfoutput>#cgi.script_name#?frmAction=NewLab</cfoutput>">Add New Lab</a>	 
			
		</fieldset>		
		
	</form>

</cfif>

<!--- javascript. --->
<script type="text/javascript">
	
	$(document).ready(function(){
		
		$("ul.sections").sortable({
			items: "li.item",
			axis: "y",
			placeholder: "ui-state-highlight"
		});		
		
		/* Style up our draggable items to make it clear they are draggable. */
		$("ul.sections li.item")
			.addClass("ui-state-default")
			.css({'cursor': 'n-resize','padding': '0.25em'});
		
		/* When items are dragged update all the sort_orders in that group. */
		$("ul.sections").bind("sortupdate", function(e, i){
			//fetch the new order of the items, this uses the li's id value.
			
			/*Loop over the new order and update the form.*/
			$("ul.sections").each(function(n){
				$("li.item", this).each(function(i){
					$("input.sortOrder", this).val(i+1);
				});
			});
		});	
		
		/* Set up our X buttons so that they retire / reinstate the sections in real time. */	
		$(document).on("click", '#retireSection', (function (e) {
			var li = $(this).closest('li');
			var new_li = li.clone(); 
			new_li.find('.retire').remove();
			var a = '<span class="reinstate pull-right"><a id="reinstateSection" href="##" onclick="return false;">';
			a += '<span class="glyphicon glyphicon-remove"></span></a></span>';
			new_li.find('input.state').attr('name', "frmRetiredSections"); // Switch the parameter that this li is connected to.
			new_li.append(a); 
			li.fadeOut('slow', function() { li.remove(); });
			$("#retiredSections").append($(new_li).hide().fadeIn('slow'));
		}));
		$(document).on("click", '#reinstateSection', (function (e) {
			var li = $(this).closest('li');
			var new_li = li.clone();
			var sort = $("#sections li").last('li').find('input.sortOrder').attr('value');
			sort = parseInt(sort, 10);
			sort += 1;
			new_li.find('.reinstate').remove();
			/* Manually set the sort order to be the last active item sort value plus 1. */
			/* If the order isn't manipulated after reinstating, this keeps thing as they look. */
			new_li.find('input.sortOrder').attr('value', sort);
			new_li.find('input.state').attr('name', "frmActiveSections"); // Switch the parameter that this li is connected to.
			var a = '<span class="retire pull-right"><a id="retireSection" href="##" onclick="return false;">';
			a += '<span class="glyphicon glyphicon-remove"></span></a></span>';
			new_li.append(a);
			li.fadeOut('slow', function() { li.remove(); });
			$("#sections").append($(new_li).hide().fadeIn('slow'));
		}));
		
	});
</script>

<cffunction name="getLabSections">
	<cfargument name="retired" type="boolean" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getSections">
		SELECT cls.section_id, cls.sort_order, cls.section_description, l.lab_name
		FROM tbl_cleaning_labs_sections cls
		INNER JOIN vi_labs l ON l.lab_id = cls.lab_id 
				             AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmInstanceId#">
		INNER JOIN tbl_instances i ON i.instance_id = l.instance_id
		WHERE cls.cleaning_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCleaningId#">
		      AND cls.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#retired#">
		ORDER BY cls.sort_order
	</cfquery>

	<cfreturn getSections>
	
</cffunction>

<cffunction name="drawSections">
	<cfargument name="retired" type="boolean" default="0">
	
	<cfset var firstPass = 1> <!---have we drawn the surrounding ul tags yet?--->
	
	<cfset getSections = getLabSections(retired)>

	<cfif retired>
		<span class="trigger">Retired Sections</span>	
		<div>
	</cfif>

	<ul class="sections" <cfif not retired>id="sections"<cfelse>id="retiredSections"</cfif>>

	<cfloop query="getSections">
		
		<cfoutput>
			<li class="item" id="item#section_id#">
				<!---this gets changed when we drag the list using jquery's .sortable() feature.--->
				<input type="hidden" name="frmSortOrder#section_id#" 
					   value="#sort_order#" class="sortOrder">
				<cfif not retired>
					<input type="hidden" name="frmActiveSections" value="#section_id#" class="state">
				<cfelse>
					<input type="hidden" name="frmRetiredSections" value="#section_id#" class="state">
				</cfif>
				#lab_name# <cfif section_description NEQ "">- #section_description#</cfif> [<a href="<cfoutput>#application.appPath#/tools/cleaning/section_manager.cfm?cleaningId=#frmCleaningId#&sectionId=#section_id#</cfoutput>">Edit</a>]				
				<span <cfif not retired>class="retire pull-right"<cfelse>class="reinstate"</cfif>>
					<a <cfif not retired>id="retireSection"<cfelse>id="reinstateSection"</cfif>
					   href="##" onclick="return false;"><span class="glyphicon glyphicon-remove"></span></a>
				</span>

			</li>
		</cfoutput>
		
		<cfset firstPass = 0>
		
	</cfloop>
		
	</ul>
	
	<cfif retired></div><br/></cfif>
	
</cffunction>

<cfinclude template="#application.appPath#/footer.cfm">