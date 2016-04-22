<cfmodule template="#application.appPath#/header.cfm" title='View Contact' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/views/contacts/view-contacts.cfm">

<!--- CFPARAMS --->
<cfparam name="contactId" type="integer" default="0">

<!---the div where we'll output our contact's info.--->
<div id="drawSpace"></div>

<script type="text/javascript">
	contactViewer("div#drawSpace", {"contact_id": <cfoutput>#contactId#</cfoutput>});
	
</script>

<p>
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm">