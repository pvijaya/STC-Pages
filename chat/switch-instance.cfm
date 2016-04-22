<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="" showMaskPermissions="False">
<cfparam name="instanceSelected" type="integer" default="0">

<!---Check to be sure they actually have the instance mask--->
<cfset instanceList = userHasInstanceList().instanceList>
<cfif ListContains(instanceList,instanceSelected)>
	<cfset setDefaultInstance(instanceSelected)>
</cfif>
<script>console.log('was set');</script>