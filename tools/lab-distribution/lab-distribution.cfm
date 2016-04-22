<cfmodule template="#application.appPath#/header.cfm" title='Lab Distribution' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- import functions --->
<cfinclude template="#application.appPath#/tools/lab-distribution/lab-distribution-module.cfm">

<!--- CFPARAMS --->
<cfparam name="frmRouteId" type="string" default='i0r0'>
<cfset routeObj = parseRoute(frmRouteId)><!---create a usable routeObject based on the user provided route_id--->

<!--- HEADER / NAVIGATION --->
<h1>Lab Distribution</h1>
<cfif hasMasks("CS")>
	<cfoutput>
	<a href='ticket-editor.cfm'>Ticket Editor</a> |
	<a href='item-list-editor.cfm'>Item Manager</a> |
	<a href='history.cfm'>History</a>
	<br/><br/>
	</cfoutput>
</cfif>

<!--- QUERIES --->
<cfset tickets = getTicketsByRoute(frmRouteId)>

<!--- DRAW FORMS ---->
<cfoutput>

	<h4 style='margin:0px 0px 5px 0px;'>Filter Options:</h4>

	#showRoutes(frmRouteId)#

	<br/><hr style='margin:0px 0px 5px 0px;'/>

	<cfloop query='tickets'>

		<cfset ticketLabs = getLabsForTicket(ticket_id)>

		<cfif ticketLabs.recordCount NEQ 0 >

			<a href='#application.appPath#/tools/lab-distribution/complete-item.cfm?action=EditTicket&ticketId=#ticket_id#'
				class='block-card hover-box'
				style='display:block; float:left; clear:both; width:96%; text-align:center;'>

				<!--- draw item name and comment --->
				<div style='width:30%; float:left;'>
					<strong>#item_name#</strong>
					<br/>#stripTags(comment)#<br/>
				</div>

				<!--- draw labs that still actively need the item --->
				<div style='width:65%; float:right;' >
					<cfloop query='ticketLabs'>
						<div style='display:inline-block;'>
							#lab_name#<br/>
						</div>
					</cfloop>
				</div>

			</a>

		</cfif>

	</cfloop>

</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>