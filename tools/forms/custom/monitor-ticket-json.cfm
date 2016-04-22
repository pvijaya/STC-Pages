<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">

<cfif not hasMasks("consultant", session.cas_uid)>
	<cfheader statuscode="403" statustext="Access Level too low">
	<cfabort>
</cfif>

<cfheader name="Content-Type" value="application/json">

<!---fetch all actors for the current date, then build-up actorsArray with a value for each top-level parent.--->
<cfquery datasource="iu-tickets-dev" name="getActors">
	SELECT actor_id, actor_name, instance_id, actor_parent_id
	FROM dbo.get_actors( GETDATE() )

	WHERE is_center = 1
	AND display = 1

	ORDER BY actor_name
</cfquery>

<cfset actorsArray = arrayNew(1)>

<cfloop query="getActors">
	<cfif actor_parent_id eq "">
		<cfset actorObj = {
			"actor_id": actor_id,
			"actor_name": actor_name,
			"children": getChildActors(actor_id, getActors),
			"tickets": []
		}>

		<cfset arrayAppend(actorsArray, actorObj)>
	</cfif>
</cfloop>

<!---fetching all open tickets--->
<cfquery datasource="iu-tickets-dev" name="getOpenTickets">
	SELECT t.ticket_uid, t.ticket_id, t.opened, t.lname, t.fname, t.nid, t.lastModified, t.summary, t.actor_id, a.actor_name, b.building_name, t.room_number
	FROM tbl_tkt_tickets t
	INNER JOIN dbo.get_actors( GETDATE() ) a ON a.actor_id = t.actor_id
	LEFT OUTER JOIN tbl_tkt_rps_buildings b ON b.building_code = t.building_code

	WHERE t.status_id = 1

	ORDER BY a.actor_name, t.opened
</cfquery>

<!---now loop over all the tickets and file them away in the correct actor.--->
<cfloop query="getOpenTickets">
	<!---find the actor object this ticket belongs to.--->
	<cfloop array="#actorsArray#" index="actorObj">
		<cfif listFind(actorObj.children, getOpenTickets.actor_id)>
			<cfset ticketObj = structNew()>

			<cfset ticketObj['ticket_uid'] = ticket_uid>
			<cfset ticketObj['ticket_id'] = ticket_id>
			<cfset ticketObj['opened'] = opened>
			<cfset ticketObj['lastModified'] = lastModified>
			<cfset ticketObj['lname'] = lname>
			<cfset ticketObj['fname'] = fname>
			<cfset ticketObj['nid'] = nid>
			<cfset ticketObj['summary'] = summary>
			<cfset ticketObj['actor_id'] = actor_id>
			<cfset ticketObj['actor_name'] = actor_name>
			<cfset ticketObj['building_name'] = building_name>
			<cfset ticketObj['room_number'] = room_number>

			<cfset arrayAppend(actorObj.tickets, ticketObj)>
		</cfif>
	</cfloop>
</cfloop>

<cfoutput>#serializeJSON(actorsArray)#</cfoutput>


<cffunction name="getChildActors">
	<cfargument name="parent_id" type="numeric" required="true">
	<cfargument name="getActorsQuery" type="query" required="true">

	<cfset var childList = "#parent_id#">

	<!---find any child actors and append them to childList.--->
	<cfloop query="getActorsQuery">
		<cfif actor_parent_id eq parent_id>
			<cfset childList = childList & "," & getChildActors(actor_id, getActorsQuery)>
		</cfif>
	</cfloop>

	<cfreturn childList>
</cffunction>