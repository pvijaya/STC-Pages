<cfmodule template="#application.appPath#/header.cfm" title='Customer Contact Relationships' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- include graph and contact functions --->
<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">
<cfinclude template="#application.appPath#/tools/contacts/contact-functions.cfm">

<!--- import d3 library --->
<script src="<cfoutput>#application.appPath#</cfoutput>/js/d3.v3.min.js"></script>

<!--- CFPARAMS --->
<cfparam name="frmContactId" type="string" default="">
<cfparam name="frmAction" type="string" default="">

<cfset dataset = "">
<cfset frmContactId = val(frmContactId)>

<h1>Contact Relationships</h1>

<!--- the div that will become our jQuery-UI dialog for the viewer --->
<div id="contactCanvas">
	<center>Preparing to load contact...</center>
</div>

<div style="margin:1em;width:800px;height:80%;float:right;text-align:center;border:solid 1px black;">
	<div id="force" style="margin: 0em auto;" ></div>
</div>

<!--- HANDLE USER INPUT --->
<cfif frmContactId NEQ 0>

	<cfset dataset = getRelationshipsById(frmContactId)>

	<cftry>
	
		<cfif NOT isNumeric(frmContactId)>
			<cfthrow message="Invalid Input" detail="You must provide a valid contact ID.">
		</cfif>
	
		<cfquery datasource="#application.applicationDataSource#" name="getContactInfo">
			SELECT c.contact_id, c.created_ts, u.username
			FROM tbl_contacts c
			INNER JOIN tbl_users u ON u.user_id = c.user_id
			WHERE c.contact_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmContactId#">
		</cfquery>
		
		<cfif getContactInfo.recordCount EQ 0>
			<cfthrow message="Error" detail="The contact you specified does not exist.">
		</cfif>
		
		<cfset dataset = getRelationshipsById(frmContactId)>
	<!--->
	<cfset dataset = getDataset(frmContactId)>
		<cfset dataset['edges'] = getEdges(dataset['edges'], dataset['nodes'])>
	--->
	
	<cfcatch>
	    <cfoutput>
	        <p class="warning">
	            #cfcatch.Message# - #cfcatch.Detail#
	        </p>
	    </cfoutput>
	</cfcatch>
	
	</cftry>
	
</cfif>

<!--- DRAW FORMS --->
<fieldset style="width:25%;float:left; margin-bottom: 1em; margin-right:0em;">

	<legend>Report Parameters</legend>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post" id="contactForm">
	
		<br/>
	
		<label>Contact ID:
			<cfoutput>
				<input type="text" name="frmContactId" value="<cfif frmContactId GT 0>#frmContactId#</cfif>">
			</cfoutput>
		</label>
		
		<br/><br/>
		
		<input type="submit" name="frmAction" value="Report">
	
	</form>

</fieldset>

<!---Offer a short table of relationships to view--->
<h2 style="margin-bottom:0em;">Recent Relationships</h2>

<cfquery datasource="#application.applicationDataSource#" name="getRels">
	SELECT TOP 14 links_to, COUNT(contact_id) AS members, MIN(link_ts) AS ts
	FROM tbl_contacts_relationships cr
	WHERE cr.active = 1
	GROUP BY links_to
	ORDER BY ts DESC
</cfquery>

<table class="stripe">
	<tr class="titlerow">
		<th>Parent</th>
		<th>Members</th>
		<th>Last Revised</th>
	</tr>
	<cfoutput query="getRels">
		<tr>
			<td>
				<a href="#cgi.script_name#?frmContactId=#links_to#">#links_to#</a>
			</td>
			<td>#members + 1#</td>
			<td>#dateTimeFormat(ts, "mmm d, yyyy h:nn aa")#</td>
		</tr>
	</cfoutput>
</table>

<!--- FOOTER --->
<p style="clear:both;">
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>

<!--- CFFUNCTIONS --->

<!---given a contact_id find all contacts related to it, returning a struct we'll feed to a D3 graph.--->
<cffunction name="getRelationshipsById" output="false">
	<cfargument name="contactId" type="numeric" required="true">
	<cfargument name="relStruct" type="struct" default="#structNew()#">
	
	<!---if relStruct doesn't have nodes or edges create them--->
	<cfif not structKeyExists(relStruct, "nodes")>
		<cfset relStruct['nodes'] = arrayNew(1)>
	</cfif>
	<cfif not structKeyExists(relStruct, "edges")>
		<cfset relStruct['edges'] = arrayNew(1)>
	</cfif>
	<cfif not structKeyExists(relStruct, "checkedList")>
		<cfset relStruct['checkedList'] = "">
	</cfif>
	
	
	<cfset var getRels = "">
	<cfset var foundMatch = 0>
	<cfset var source = 0>
	<cfset var sourcePos = -1>
	<cfset var target = 0>
	<cfset var targetPos = -1>
	<cfset var n = 0>
	<cfset var nodeStruct = "">
	<cfset var edgeStruct = "">
	<cfset var toCheckList = "">
	
	<!---find all the relationships involving contactId--->
	<cfquery datasource="#application.applicationDataSource#" name="getRels">
		SELECT cr.links_to, cr.contact_id
		FROM tbl_contacts_relationships cr
		WHERE <cfqueryparam cfsqltype="cf_sql_integer" value="#contactId#"> IN (cr.contact_id, cr.links_to)
		AND cr.active = 'True'
	</cfquery>
	
	<!---loop over those relationships, add any nodes we don't already have, and if it isn't a duplicate add an edge to match that relationship.--->
	<cfloop query="getRels">
		<cfset source = contact_id>
		<cfset target = links_to>
		<!---reset our source/target positions to negative values--->
		<cfset sourcePos = -1>
		<cfset targetPos = -1>
		
		<!---Do we already have a node entry for source?--->
		<cfloop from="1" to="#arrayLen(relStruct.nodes)#" index="n">
			<cfif relStruct.nodes[n].id eq source>
				<cfset sourcePos = n - 1><!---subtract one because Coldfusion starts array positions at 1 and javascript at 0--->
				<cfbreak><!---we found our match and can move on.--->
			</cfif>
		</cfloop>
		
		<!---if we didn't find an existing node for source, add it.--->
		<cfif sourcePos lt 0>
			<cfset nodeStruct = structNew()>
			<cfset nodeStruct['id'] = source>
			<cfset arrayAppend(relStruct.nodes, nodeStruct)>
			
			<cfset sourcePos = arrayLen(relStruct.nodes) - 1><!---subtract one because Coldfusion starts array positions at 1 and javascript at 0--->
		</cfif>
		
		<!---do the same tests for our target and targetPos--->
		<cfloop from="1" to="#arrayLen(relStruct.nodes)#" index="n">
			<cfif relStruct.nodes[n].id eq target>
				<cfset targetPos = n - 1><!---subtract one because Coldfusion starts array positions at 1 and javascript at 0--->
				<cfbreak><!---we found our match and can move on.--->
			</cfif>
		</cfloop>
		
		<!---if we didn't find an existing node for target, add it.--->
		<cfif targetPos lt 0>
			<cfset nodeStruct = structNew()>
			<cfset nodeStruct['id'] = target>
			<cfset arrayAppend(relStruct.nodes, nodeStruct)>
			
			<cfset targetPos = arrayLen(relStruct.nodes) - 1><!---subtract one because Coldfusion starts array positions at 1 and javascript at 0--->
		</cfif>
		
		<!---At this point we've got our nodes and we know where they are located in relstruct.nodes.  As long as we're not creating a duplicate, add the relationship to relstruct.edges--->
		<cfset foundMatch = 0>
		<cfloop from="1" to="#arrayLen(relStruct.edges)#" index="n">
			<cfif relStruct.edges[n].source eq sourcePos AND relStruct.edges[n].target eq targetPos>
				<cfset foundMatch = 1>
				<cfbreak>
			<cfelseif relStruct.edges[n].source eq targetPos AND relStruct.edges[n].target eq sourcePos><!---It's still a duplicate if source and target are transposed.--->
				<cfset foundMatch = 1>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<cfif not foundMatch>
			<cfset edgeStruct = structNew()>
			<cfset edgeStruct['source'] = sourcePos>
			<cfset edgeStruct['target'] = targetPos>
			
			<cfset arrayAppend(relStruct.edges, edgeStruct)>
		</cfif>
		
		
		<!---we're not done checking all of contactId's relationship, so add source and target to toCheckList so we can recurse over them when we are done.--->
		<cfif not listFind(toCheckList, source)>
			<cfset toCheckList = listAppend(toCheckList, source)>
		</cfif>
		<cfif not listFind(toCheckList, target)>
			<cfset toCheckList = listAppend(toCheckList, target)>
		</cfif>
	</cfloop>
	
	<!---we're done checking contactId, add it to relStruct.checkedList so we don't double-check it.--->
	<cfset relStruct.checkedList = listAppend(relStruct.checkedList, contactId)>
	
	<!---now, check the relationships of all the source/targets we found earlier.--->
	<cfloop list="#toCheckList#" index="n">
		<cfif not listFind(relStruct.checkedList, n)>
			<cfset relStruct = getRelationshipsById(n, relStruct)>
		</cfif>
	</cfloop>
	
	<cfreturn relStruct>
</cffunction>

<script type="text/javascript">

	$(document).ready(function(){

		var container = "div#force";
		var dataset = <cfoutput>#serializeJSON(dataset)#</cfoutput>; 
		var contact_id = <cfoutput>#frmContactId#</cfoutput>;
	
		if (contact_id != 0) {
			var force = new d3Force();
			force.w = 750;//make the force chart just a little wider than default.
			force.h = 700;
			force.init(container, dataset);
			force.draw();
		}
	
		contactViewer = "";//this just sets up our viewer for later use.
		
		/*also setup a contact viewer and a jQuery-UI dialog to display it with*/
		//first the jQuery-UI dialog space.
		contactWidget = $("div#contactCanvas").dialog({
			autoOpen: false,
			title: "View Contact",
			minWidth: "840",
			height: "600",
			open: function(){
				//We don't actually need to do anything fancy here, the click handler that opens this should update our canvas.
			}
		});
		
		//now setup a viewer that writes its details to the contactWidget
		contactViewer = new ContactDisplay(contactWidget);
		
		/*
		d3.selectAll("a.contactLink")
			.on('click', function(d) {
					
				if(d3.event.defaultPrevented) return; // ignore drag clicks	
				
				d3.event.preventDefault(); //don't let clicking links whisk them off to another page
						
				//if the user was holding he ctrl or shift keys don't show our pop-in use the browser's behavior
				if(d3.event.ctrlKey || d3.event.shiftKey)
					return (0);
				
				// hack circumventing an issue where the contactId attribute is undefined
				var cId = $("text", this).html();
				
				//now use our viewer to update the contents of our dialog
				contactViewer.drawContact(cId);
				//having done that we can open our dialog
				$(contactWidget).dialog("open");
						
				d3.event.stopPropagation(); // stop this click from triggering other click events
				
			});
		*/

		
		//and an event handler to open up our jquery-ui dialog, and fill it with the correct data.
		$(document).on('click', "a.contactLink", function(e) {
			
			if(e.defaultPrevented) return; // ignore drag clicks	
			
			e.preventDefault();//don't let clicking links whisk them off to another page
					
			//if the user was holding he ctrl or shift keys don't show our pop-in use the browser's behavior
			if(e.ctrlKey || e.shiftKey)
				return (0);
			
			// hack circumventing an issue where the contactId attribute is undefined
			//var cId = $("text", this).html();
			
			var cId = this.getAttribute("contactId");
			
			//now use our viewer to update the contents of our dialog
			contactViewer.drawContact(cId);
			//having done that we can open our dialog
			$(contactWidget).dialog("open");
					
			e.stopPropagation(); // stop this click from triggering other click events
			 
		});
		

	});
		
</script>
