<cfmodule template="#application.appPath#/header.cfm" title="Readership Styling">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">

<cfparam name="frmWidth" type="string" default="100%">
<cfparam name="frmIndent" type="string" default="2em">

<form>
	<p>
		Width: <input type="text" name="frmWidth" value="<cfoutput>#htmlEditFormat(frmWidth)#</cfoutput>">
	</p>
	<p>
		Indent: <input type="text" name="frmIndent" value="<cfoutput>#htmlEditFormat(frmIndent)#</cfoutput>">
	</p>
	<input type="submit" >
</form>

<cfmodule template="mod_individual_readership.cfm" uid="3" read="0" catId="1" start="2011-01-01" end="#now()#" width="#frmWidth#" indentation="#frmIndent#">