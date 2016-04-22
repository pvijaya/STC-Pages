<cfmodule template="#application.appPath#/header.cfm" title='Mask Editor' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="admin">

<cfoutput>
<div id="main-content-id">
	<div class="content">
		<h1>Mask Editor</h1>
		<p>Please select an mask option</p>
		<cfquery datasource="#application.applicationdatasource#" name="getAllMasks">
			SELECT r.relationship_id, m.mask_id AS mask_id, m.mask_name, m.mask_notes
			FROM tbl_user_masks m
			LEFT OUTER JOIN tbl_mask_relationships r ON r.mask_id = m.mask_id
			ORDER BY m.mask_name
		</cfquery>
		
		<!---catch user input, remember checkboxes are picky, so we want a cfparam for all possible masks.--->
		
		<cfparam name="frmSubmit" type="string" default="">
		<cfloop query="getAllMasks">
			<cfparam name="frmMask#mask_id#" type="boolean" default="0">
		</cfloop>
		<form action='<cfoutput>#cgi.script_name#</cfoutput>' method="POST">
			
			<select  name="maskCategory" multiple="true">
				<option value=''></option>
			</select>
			Mask Name: <input type="text" name="maskName" placeholder="Account Checker" value="">
			<br/><br/>
			<input  type="submit" name="subAction" value="Create">
			<input  type="submit" name="subAction" value="Exit">
		</form>
	</div>
	<div style="clear:both;"></div>
</div>
</cfoutput>
<cfinclude template="#application.appPath#/footer.cfm">