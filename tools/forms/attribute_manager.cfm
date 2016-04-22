<cfmodule template="#application.appPath#/header.cfm" title='Attribute Manager' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<h1>Attribute Manager</h1>

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmAttributeId" type="integer" default="0">
<cfparam name="frmAttributeName" type="string" default="">
<cfparam name="frmAttributeDetails" type="string" default="">
<cfparam name="frmAttributeText" type="string" default="">
<cfparam name="frmAttributeRetired" type="boolean" default="-1">

<cfoutput>
	<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
		<cfif frmAction EQ "CreateNew" OR frmAction EQ "Go">
			<a href="#application.appPath#/tools/forms/attribute_manager.cfm">Go Back</a> |
		</cfif>
		<a href="#application.appPath#/tools/forms/form_manager.cfm">Manage Forms</a>
		<cfif hasMasks('Admin')>
			| <a href="#application.appPath#/tools/forms/form_submission_report.cfm">Form Submissions</a>
			| <a href="#application.appPath#/tools/forms/form_report.cfm">Form Report</a>
		</cfif>
	</p>
</cfoutput>

<!--- handle user input --->
<cfif frmAction EQ "Create" OR frmAction EQ "Edit">

	<cftry>
	 
	 	<!--- we want to make the same input checks for both edit and create --->
		<cfif trim(frmAttributeName) eq "">
			<cfthrow message="Missing Input" detail="Attribute Name is a required field, and cannot be left blank.">
		</cfif>	
		<cfif trim(frmAttributeDetails) eq "">
			<cfthrow message="Missing Input" detail="Attribute Description is a required field, and cannot be left blank.">
		</cfif>	
		<cfif trim(frmAttributeText) eq "">
			<cfthrow message="Missing Input" detail="Attribute Text is a required field, and cannot be left blank.">
		</cfif>
		
		<!--- create or edit the attribute --->
		<cfif frmAttributeId EQ 0>
		
			<cfquery datasource="#application.applicationDataSource#" name="createAttribute">
				INSERT INTO tbl_attributes (attribute_name, attribute_details, attribute_text)
				OUTPUT inserted.attribute_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAttributeName#">,
				    <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAttributeDetails#">,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAttributeText#">
				)			   
			</cfquery>
			
			<cfset frmAttributeId = createAttribute.attribute_id>
			<cfset message = "Attribute created successfully.">
			
		<cfelse>
		
			<cfquery datasource="#application.applicationDataSource#" name="editAttribute">
				UPDATE tbl_attributes
				SET attribute_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAttributeName#">,
					attribute_details = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAttributeDetails#">,
					attribute_text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmAttributeText#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmAttributeRetired#">
				WHERE attribute_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmAttributeId#">
			</cfquery>
			
			
			<cfset message = "Attribute updated successfully.">	
			
		</cfif>
			
		<p class="ok"><cfoutput>#message#</cfoutput></p>
	
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
<cfif frmAction EQ "CreateNew" OR frmAction EQ "Go">

	<cftry>

		<cfif frmAttributeId GT 0>
		
			<!--- fetch the old information to use as default --->
			<cfquery datasource="#application.applicationDataSource#" name="getAttribute">
				SELECT a.attribute_id, a.attribute_name, a.attribute_details, a.attribute_text, a.retired
				FROM tbl_attributes a
				WHERE a.attribute_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmAttributeId#">
			</cfquery>
		
			<cfoutput><h2 style="padding: 0px; margin-top: 0.0em; margin-bottom: 0.0em;">Edit Attribute</h2></cfoutput>
			
			<br/>
			
			<!--- set defaults if the user has not provided new values --->
			<cfif frmAttributeName EQ "">
				<cfset frmAttributeName = #getAttribute.attribute_name#>
			</cfif>
			<cfif frmAttributeText EQ "">
				<cfset frmAttributeText = #getAttribute.attribute_text#>
			</cfif>
			<cfif frmAttributeDetails EQ "">
				<cfset frmAttributeDetails = #getAttribute.attribute_details#>
			</cfif>
			<cfif frmAttributeRetired EQ -1>
				<cfset frmAttributeRetired = #getAttribute.retired#>
			</cfif>
		
		<cfelse>
				
			<cfoutput><h2 style="padding: 0px; margin-top: 0.0em; margin-bottom: 0.0em;">New Attribute</h2></cfoutput>
			
		</cfif>
		
		<!--- Since attributes have to be hard-coded to behave differently, I don't particularly want people to
		      mess with this page unless the webmaster or programmer knows about it. --->
		<blockquote>This form is used to create or edit the attributes that can be assigned to forms. <br/>
		The attributes by themselves are  only markers - if you intend for one to change behavior, please contact the Webmaster or Programmer. <br/>
			<ul>
				<li>The 'Text' field should contain the text that will appear on the form creation page to describe this attribute. </li>
				<li>The 'Description' field can be used to make notes or describe the behavior you'd like the attribute to have.</li>
			</ul>
		</blockquote>
	
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">	
				
			<label>Name:
				<input name="frmAttributeName" value="<cfoutput>#htmlEditFormat(frmAttributeName)#</cfoutput>">
			</label>
			
			<br/> <br/>
	
			<label>Text:
				<input name="frmAttributeText" value="<cfoutput>#htmlEditFormat(frmAttributeText)#</cfoutput>" size="90">
			</label>		
			
			<br/> <br/>
			
			<label>Description:
				<textarea name="frmAttributeDetails"><cfoutput>#htmlEditFormat(frmAttributeDetails)#</cfoutput></textarea>
			</label>
			
			<br/>
			
			<!--- replace the default textarea above with a prettier one --->			
			<script type="text/javascript">
				//a custom configuration for this ckeditor textarea
				var contactNote = CKEDITOR.replace('frmAttributeDetails',{
					toolbar_Basic: [['Bold','Italic','Underline'],['RemoveAttributeat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
					toolbar:  'Basic',
					height: '200px',
					width: '500px',
					removePlugins: 'contextmenu,tabletools'/*the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
				});	
			</script>
			
			<cfif frmAttributeId EQ 0>
			
				<input type="submit"  value="Create" name="frmAction">
				
			<cfelse>
			
				<!--- we can only retire existing articles --->
				<fieldset>
					<legend>Retired?</legend>
					<label>
						Yes
						<input type="radio" name="frmAttributeRetired" value="1" <cfif frmAttributeRetired>checked="true"</cfif>>
					</label>
					<label>
						No
						<input type="radio" name="frmAttributeRetired" value="0" <cfif not frmAttributeRetired>checked="true"</cfif>>
					</label>
				</fieldset>
				
				<br/>
				<input type="submit"  value="Edit" name="frmAction">
			
			</cfif>
			
			<!--- keep track of our Attribute id --->
			<cfoutput>
				<input type="hidden" name="frmAttributeId" value="#frmAttributeId#">
			</cfoutput>
		
		</form>
	
	<cfcatch>

		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>

<cfelse> <!--- main menu: select an attribute --->

	<!--- get existing attributes --->
	<cfquery datasource="#application.applicationDataSource#" name="getAttributes">
		SELECT a.attribute_id, a.attribute_name, a.retired
		FROM tbl_attributes a
		ORDER BY a.retired, a.attribute_name
	</cfquery>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<br/>
		
		<fieldset>
			
			<legend>Choose</legend>
			
			<label>
				Select an Attribute:
				<select name="frmAttributeId">
					<cfoutput query="getAttributes">
						<option value="#attribute_id#">
							#attribute_name# <cfif retired>(retired)</cfif>
						</option>
					</cfoutput>
				</select>
			</label>
			
			<input type="submit" value="Go" name="frmAction">
			
			<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
						
			<a href="<cfoutput>#cgi.script_name#?frmAction=createnew</cfoutput>">Create New Attribute</a>	 
			
		</fieldset>
		
	</form>
		
</cfif>
	
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>