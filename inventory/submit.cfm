<cfmodule template="#application.appPath#/header.cfm" title='Inventory' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Consultant">

<cfsetting showdebugoutput="false">

<!---this form has been replaced with a modular-ized version.--->
<cfmodule template="mod_inventory_form.cfm">

<cfmodule template="#application.appPath#/footer.cfm">