<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/header.cfm" title='Contacts Thermometer'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">


<cfdump var="#session#">
<cfmodule template="#application.appPath#/footer.cfm">