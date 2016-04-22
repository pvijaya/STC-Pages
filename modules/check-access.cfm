<!---this module is to be used by files to restrict access for the whole page.  Simply provide the masks they must have to use the page.--->
<!---Alternatively, for backwards compliance you can provide a "requiredLevel" and it will require masks that closely correspond with that.--->
<!---NOTE:  You cannot mix and match, attributes.masks always trumps attributes.requiredLevel.--->
<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfparam name="attributes.masks" type="string" default="">
<cfparam name="attributes.showMaskPermissions" type="boolean" default="true" >

<cfif not hasMasks(attributes.masks)>
	<cfoutput>
		<h1>Sorry!</h1>
		<p>You are not authorized to view this page for some reason or another.</p>
		<p>
			You are missing one of the following permission masks:
			<cfset loopCnt = 1>
			<cfloop list="#attributes.masks#" index="myMask">
				<cfif loopCnt gt 1 AND loopCnt eq listLen(attributes.masks)> or</cfif>
				#myMask#<cfif loopCnt lt listLen(attributes.masks)>,</cfif>
				<cfset loopCnt = loopCnt + 1>
			</cfloop>
		</p>
		<h2>What should you do?</h2>
		<ul>
			<li>If you know why you aren't allowed here, turn back!</li>
			<li>If you do not know why you cannot access this page, please contact a Consultant Supervisor to discuss the problem.</li>
			<li>If you believe that you have the permission mask(s) required, contact the webmaster.</li>
		</ul>
		
	</cfoutput>
	<cfinclude template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>
<cfif hasMasks('Page Mask Viewer') && attributes.showMaskPermissions EQ true>
	<p>Masks required to view page:
	<cfloop list="#attributes.masks#" index="myMask">
		<cfoutput>
			<span class="ui-state-default ui-corner-all">#myMask#</span>
		</cfoutput>
	</cfloop>
	</p>
</cfif>