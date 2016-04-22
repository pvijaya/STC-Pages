<cfmodule template="#application.appPath#/header.cfm" title='IC Cleaning Form' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">
<!---handle user input--->
<cftry>
	<cfparam name="frmSectionId" type="integer" default="0">
	<cfparam name="frmSectionName" type="string" default="">
	<cfparam name="frmImage" type="string" default="">
	<cfparam name="frmActive" type="boolean" default="1">
	<cfparam name="frmSubmit" type="string" default="">
	
	<cfif frmSubmit neq "" AND frmSubmit neq "Edit">
		<cfif len(trim(frmSectionName)) eq 0>
			<cfthrow type="custom" message="Section Name" detail="You must provide a name for the Section.">
		</cfif>
	</cfif>
	
	<!---the user's data is legit, stash it in the database.--->
	<cfif frmSubmit eq "Update">
		<!---update--->
		<cfquery datasource="#application.applicationDataSource#" name="updateSection">
			UPDATE tbl_ic_cleaning_sections
			SET section_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmSectionName#">,
				image = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmImage#">,
				active = <cfqueryparam cfsqltype="cf_sql_bit" value="#iif(frmActive, 1, 0)#">
			WHERE section_id = #frmSectionId#
		</cfquery>
	<cfelseif frmSubmit eq "Add">
		<!---insert--->
		<cfquery datasource="#application.applicationDataSource#" name="addSection">
			INSERT INTO tbl_ic_cleaning_sections (section_name, image, active)
			VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmSectionName#">, <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmImage#">, <cfqueryparam cfsqltype="cf_sql_bit" value="#frmActive#">)
		</cfquery>
	</cfif>
	
	<cfif frmSubmit eq "Update" OR frmSubmit eq "Add">
		<h3>Data Stored</h3>
		<!---blank the user input--->
		<cfset frmSectionId = 0>
		<cfset frmSectionName = "">
		<cfset frmImage = "">
		<cfset frmActive = 1>
		<cfset frmSubmit = "">
	</cfif>
	
<cfcatch type="any">
	<h2>Error</h2>
	<cfoutput>
		<p><b>#cfcatch.Message#</b> - #cfcatch.detail#</p>
	</cfoutput>
	<!---if this was an update, redraw that form--->
	<cfif frmSubmit eq "Update">
		<cfset frmSubmit = "Edit">
	</cfif>
</cfcatch>
</cftry>

<!---fetch the existing info form the database--->
<cfif frmSubmit eq "Edit">
	<cfquery datasource="#application.applicationDataSource#" name="getSection">
		SELECT section_name, image, active
		FROM tbl_ic_cleaning_sections
		WHERE section_id = #frmSectionId#
	</cfquery>
	
	<cfloop query="getSection">
		<cfif not isDefined("form.frmSectionName")>
			<cfset frmSectionName = section_name>
		</cfif>
		<cfif not isDefined("form.frmImage")>
			<cfset frmImage = image>
		</cfif>
		<cfif not isDefined("form.frmActive")>
			<cfset frmActive = active>
		</cfif>
	</cfloop>
</cfif>



<!---select a section to edit.--->
<h1>Edit Cleaning Sections</h1>
<a href="ic-cleaning.cfm">Cleaning Map</a>
<br/><br/>
<cfquery datasource="#application.applicationDatasource#" name="getSections">
	SELECT section_id, section_name, active
	FROM tbl_ic_cleaning_sections
	ORDER BY active DESC, section_name ASC
</cfquery>
<form accept="edit_sections.cfm" method="post">
<select name="frmSectionId">
<cfoutput query="getSections">
	<option value="#section_id#" <cfif section_id eq frmSectionId>selected</cfif>>#htmlEditFormat(section_name)#<cfif not active>(Retired)</cfif></option>
</cfoutput>
</select>

<input type="submit"  name="frmSubmit" value="Edit">
</form>

<h3><cfif frmSubmit eq "Edit">Edit<cfelse>Add A</cfif> Section</h3>
<form accept="edit_sections.cfm" method="post">
<input type="hidden" name="frmSectionId" value="<cfoutput>#frmSectionId#</cfoutput>">
<table>
	<tr>
		<th>Name:</th>
		<td><input type="text" name="frmSectionName" size="80" value="<cfoutput>#htmlEditFormat(frmSectionName)#</cfoutput>"></td>
	</tr>
	<tr>
		<th>Image URL:</th>
		<td><input type="text" name="frmImage" size="80" value="<cfoutput>#htmlEditFormat(frmImage)#</cfoutput>"></td>
	</tr>
	<tr>
		<th>Active:</th>
		<td>
			 <input type="radio" name="frmActive" value="1" <cfif frmActive>checked</cfif> id="active-yes"><label for="active-yes">Yes</label> <input type="radio" name="frmActive" value="0" <cfif not frmActive>checked</cfif> id="active-no"><label for="active-no">No</label>
		</td>
	</tr>
	<tr>
		<th colspan="2" align="center">
			<cfif frmSubmit eq "Edit">
				<input type="submit"  name="frmSubmit" value="Update">
			<cfelse>
				<input type="submit"  name="frmSubmit" value="Add">
			</cfif>
		</th>
	</tr>
</table>
</form>


<cfinclude template="#application.appPath#/footer.cfm">