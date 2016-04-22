<cfmodule template="#application.appPath#/header.cfm" title='Shift Report'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/contacts/contact-functions.cfm">
<cfinclude template="#application.appPath#/views/contacts/view-contacts.cfm"><!---bring in the viewer for the new contacts.--->
<cfinclude template="#application.apppath#/inventory/inventory-functions.cfm">

<!--- CFPARAMS --->
<cfparam name="frmRouteId" type="string" default="i0r0"> <!--- in the form of i1r2 --->

<cfset myInstance = getInstanceById(session.primary_instance)>

<cfset routeStruct = parseRoute(frmRouteId)>
<cfset instanceId = routeStruct.instance>
<cfset routeId = routeStruct.route>

<!--- STYLE --->
<style type="text/css">

	.modal-dialog {
 	 	width: 90%;
	}

	div.sel-con input.username, div.sel-con input#dayDateId {
		width: 120px;
	}

	h3, span {
		margin:0px 5px 0px 5px;
	}

	div.sidebar {
		width:25%;
		float:left;
		padding:5px;
	}

	div.sidebar div {
		padding:5px;
	}

	div.main {
		width:70%;
		float:right;
		padding:5px;
	}

	div.main div {
		padding:5px;
	}

	a.consultant-on-route {
		width:200px;
		display:inline-block;
		margin:5px;
		cursor:pointer;
	}

	img.consultant-image {
		max-width:75px;
		max-height:75px;
		float:left;
	}

</style>

<script type="text/javascript">
	$(document).ready(function(){

		//Add an event handler to open up our bootrap modal with the contact clicked by the user.
		$(document).on("click", "a.contactLink", function(e){
			//if the user was holding he ctrl or shift keys don't show our pop-in use the browser's behavior
			if(e.ctrlKey || e.shiftKey)
				return (0);

			e.preventDefault();//don't let clicking links whisk them off to another page.

			var cId = $(this).attr("contactId");

			//use the new contact viewer and a bootstrap modal to display the contact.
			contactViewer("#contactModal .modal-body", {"contact_id": cId});
			$('#contactModal').modal({show:true});
		});

		$('.consultant-on-route').click(function(e){
			e.preventDefault();

			var myUrl = $(this).attr('href');

			var username = $(this).attr('username');
			$.ajax({
				type: 'GET',
				async: true,
				url: myUrl,
				data: {
					'drawheader': 0,
					'drawnextShift' : 0,
					'drawpreviousShift' : 0,
					'drawdialog' : 0,
					'drawbackToShift' : 0,
					'drawContactModal': 0,
					'drawfooter' : 0
				},
				beforeSend: function(){
					//Update the content of our modal, and its header before showing it to our user.
					$('#myModal .modal-body').html('loading..');
					$('#myModal .modal-title').html(username);
					$('#myModal .modal-title').append("'s Mentee Report");

					$('#myModal').modal({show:true});
				},
				success: function(data){
					$('#myModal .modal-body').html(data);
				},
				error: function(error){
					$('#myModal .modal-body').html("<div class='alert alert-danger' role='alert'>An issue was encountered feching the Mentee Report, please try again.</div>");
				}
			});

		});

		/*This is a hack from http://miles-by-motorcycle.com/static/bootstrap-modal/index.html that should let us have more than one bootstrap modal at a time.*/
		$('.modal').on('hidden.bs.modal', function( event ) {
			$(this).removeClass( 'fv-modal-stack' );
			$('body').data( 'fv_open_modals', $('body').data( 'fv_open_modals' ) - 1 );


			//if any modals are still open and the body has lost its modal-open class forcefully re-apply it.
			if( $('body').data( 'fv_open_modals' ) > 0 && !$('body').hasClass('modal-open') ){
				$('body').addClass('modal-open');
			}

		});


		$( '.modal' ).on( 'shown.bs.modal', function ( event ) {
			// keep track of the number of open modals

			if ( typeof( $('body').data( 'fv_open_modals' ) ) == 'undefined' ){
				$('body').data( 'fv_open_modals', 0 );
			}

			// if the z-index of this modal has been set, ignore.
			if ( $(this).hasClass( 'fv-modal-stack' ) ) {
				return;
			}

			$(this).addClass( 'fv-modal-stack' );

			$('body').data( 'fv_open_modals', $('body').data( 'fv_open_modals' ) + 1 );

			$(this).css('z-index', 1040 + (10 * $('body').data( 'fv_open_modals' )));

			$( '.modal-backdrop' ).not( '.fv-modal-stack' )
				.css( 'z-index', 1039 + (10 * $('body').data( 'fv_open_modals' )));


			$( '.modal-backdrop' ).not( 'fv-modal-stack' )
				.addClass( 'fv-modal-stack' );

		});
		/*end of modal hack*/

	});
</script>

<h1>Shift Report</h1>

<!--- if the user currently has a shift on a route, select that one by default --->
<cfif instanceId eq 0 OR routeId eq 0>

	<!--- fetch the rich info for the instances that the user has access to, --->
	<!--- in particular we need the instance_id and datasource to pull info from the correct PIE. --->
	<!--- use the primary instance only to coincide with the rest of tetra --->
	<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
		SELECT i.instance_id, i.instance_name, i.instance_mask, i.datasource
		FROM tbl_instances i
		WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	</cfquery>

	<!--- 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask) --->

	<cfloop query="getUserInstances">
		<!--- reach into this instance's PIE and look for a current shift for our user.  --->
		<!--- Specifically a shift that has a route, all others will be ignored. --->
		<cfquery datasource="#application.applicationDataSource#" name="getShift">
			SELECT TOP 1 sb.site_id, si.site_name, r.route_id, r.retired
			FROM [#datasource#].dbo.shift_blocks sb
			/*this could restrict us to folks who are currently checked in.
			INNER JOIN tbl_checkins ci ON ci.checkin_id = sb.checkin_id
			*/
			INNER JOIN [#datasource#].dbo.tbl_consultants c ON c.ssn = sb.ssn
			INNER JOIN [#datasource#].dbo.tbl_sites si ON si.site_id = sb.site_id
			INNER JOIN [#datasource#].dbo.tbl_routes r ON r.mentor_site_id = sb.site_id
			WHERE LOWER(c.username) = LOWER(<cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">)
			AND GETDATE() BETWEEN sb.shift_time AND DATEADD(hour, 1, sb.shift_time)
		</cfquery>

		<cfloop query="getShift">
			<!---we've hit a shift on a route, set the global values and bust out of these loops.--->
			<cfset instanceId = getUserInstances.instance_id>
			<cfif not retired><!---don't try to work with sites on retired routes--->
				<cfset routeId = route_id>
			<cfelse>
				<cfset routeId = 0>
			</cfif>
		</cfloop>

		<cfif instanceId neq 0 AND routeId neq 0>
			<!---we've got legit values, break out of the loop.--->
			<cfbreak>
		</cfif>

	</cfloop>
</cfif>

<!--- draw route select --->

<cfquery datasource="#application.applicationDataSource#" name="getRoutes">
	SELECT r.route_name, r.color, r.route_id, r.instance_id, i.instance_name, i.datasource,
		   i.instance_mask, m.site_name AS mentor_site
	FROM vi_routes r
	INNER JOIN tbl_instances i ON i.instance_id = r.instance_id
	/*now find the route's mentor*/
	INNER JOIN vi_sites m
		ON m.instance_id = r.instance_id
		AND m.site_id = r.mentor_site_id
	WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
	       AND r.access_level >= 3
</cfquery>

<!--- if at this point we still don't have a route for our user default to the first one available --->
<!--- if user is IUB admin AND in IUB instance, default to Supervisor Route --->
<cfif instanceId eq 0 AND routeId eq 0 AND hasMasks('ADMIN') AND hasMasks('IUB')
	  AND session.primary_instance eq 1>
		<cfset instanceId = 1>
		<cfset routeId = 7>
<cfelseif instanceId eq 0 AND routeId eq 0>
	<cfloop query="getRoutes">
		<cfset instanceId = instance_id>
		<cfset routeId = route_id>
		<cfbreak> <!---leave the loop, we're done.--->
	</cfloop>
</cfif>

<!--- DRAW FORMS --->

<!--- draw route selector --->
<form>
	<label>Select a Route:
		<select  name="frmRouteId">
			<cfoutput query="getRoutes" group="instance_id">
				<optgroup label="#htmlEditFormat(instance_name)#">
					<cfoutput group="route_id">
						<option value="i#instance_id#r#route_id#" style="color: #color#;"
							<cfif instanceId eq instance_id AND routeId eq route_id>selected="selected"</cfif>>
								#route_name#
						</option>
					</cfoutput>
				</optgroup>
			</cfoutput>
		</select>
	</label>
	<input type="submit"  value="Go">
</form>

<cfif getRoutes.recordCount eq 0>
	<p class="warning">You do not have access to any Routes to Review</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>

<!---if the user has provided a route they'd like to view make sure they have access to view it.--->
<cfif session.primary_instance NEQ instanceId>
	<p class="warning">The route you selected either does not exist or is not available to you.</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>

<!---if at this point we still don't have a route selected default to the first one available--->
<cfif instanceId eq 0 OR routeId eq 0>
	<cfset instanceId = getRoutes.instance_id[1]>
	<cfset routeId = getRoutes.route_id[1]>
</cfif>

<!--- Route Selection Ends.  We now have a valid instanceId and routeId to use. --->

<cfquery datasource="#application.applicationDataSource#" name="getRouteLabs">
	SELECT i.instance_id, i.instance_mask, r.route_id, r.route_name, r.color, s.site_id, s.site_name,
		   s.site_long_name, s.staffed, i.datasource, i.instance_name, b.building_id, b.building_name,
		   l.lab_name, l.lab_id
	FROM tbl_instances i
	INNER JOIN vi_routes r
		ON r.instance_id = i.instance_id
	INNER JOIN vi_routes_sites rs
		ON rs.instance_id = r.instance_id
		AND rs.route_id = r.route_id
	INNER JOIN vi_sites s
		ON s.instance_id = rs.instance_id
		AND s.site_id = rs.site_id
	INNER JOIN vi_labs_sites ls
		ON ls.instance_id = s.instance_id
		AND ls.site_id = s.site_id
	INNER JOIN vi_labs l
		ON l.instance_id = ls.instance_id
		AND l.lab_id = ls.lab_id
	INNER JOIN vi_buildings b
		ON b.instance_id = l.instance_id
		AND b.building_id = l.building_id
	WHERE r.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
	AND r.route_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#routeId#">
	AND s.retired = 0
	AND l.active = 1
	AND r.access_level = 3

	ORDER BY r.sort_order, r.route_name, r.route_id, s.staffed DESC, s.site_name ASC
</cfquery>

<!--- Query to get all contact information--->
<cfquery datasource="#application.applicationdatasource#" name="getContacts">
	SELECT DISTINCT c.contact_id, c.last_opened, l.lab_id, l.lab_name, u.username, cc.customer_username, cm.category_id, ct.category_name
	FROM vi_routes r
	/*get the sites on our route*/
	INNER JOIN vi_routes_sites rs
		ON rs.instance_id = r.instance_id
		AND rs.route_id = r.route_id
	/*match the sites to labs(contacts use building_id and room_number, which we have for labs(not sites)*/
	INNER JOIN vi_labs_sites ls
		ON ls.instance_id = rs.instance_id
		AND ls.site_id = rs.site_id
	/*fetch the building_id and room_number about our labs*/
	INNER JOIN vi_labs l
		ON l.instance_id = ls.instance_id
		AND l.lab_id = ls.lab_id

	/*now that we have the information about labs on our route we can start getting the details of open contacts in those labs*/
	INNER JOIN tbl_contacts c
		ON c.instance_id = l.instance_id
		AND c.building_id = l.building_id
		AND c.room_number = l.room_number
		AND c.status_id = 1 /*only open contacts*/
	/*get the details of the user who created the contact*/
	INNER JOIN tbl_users u ON u.user_id = c.user_id
	/*find the customers for the contact, doing a left join because a contact could get all its customers removed*/
	LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = c.contact_id
	/*find the categories for the contact, left join since contacts can be opened without a category*/
	LEFT OUTER JOIN tbl_contacts_categories_match cm ON cm.contact_id = c.contact_id
	LEFT OUTER JOIN tbl_contacts_categories ct ON ct.category_id = cm.category_id

	WHERE r.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
	AND r.route_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#routeId#">

	/*carefully sort our contacts so we can group them by their lab_id, then the age of the contact, and then by customers, leaving categories for last*/
	ORDER BY l.lab_name, c.last_opened, c.contact_id, cc.customer_username, ct.category_name, cm.category_id
</cfquery>

<cfset routeName = "">
<cfset mentorSite = "">
<cfset myPieDsn = "">

<!---we included the datasource in the getRoutes query above, we need that datasource to pull
information about the route and who's on it from the correct PIE.--->
<cfloop query="getRoutes">
	<cfif instanceId eq instance_id AND routeId eq route_id>
		<cfset routeName = "#instance_mask# #route_name#">
		<cfset mentorSite = "#mentor_site#">
		<cfset myPieDsn = datasource>
		<cfbreak>
	</cfif>
</cfloop>

<cfset frmRouteId = "i#instanceId#r#routeId#">

<!--- If the user comes in with some routeId that PIE doesn't recognize, (such as XLEAD) --->
<!--- show only the route selector initially. --->

<cfif frmRouteId EQ "i0r0">
	<p>Please select a route.</p>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
	<cfabort>
</cfif>

<h2 style="margin-bottom:0em;"><cfoutput>#routeName#</cfoutput></h2>
Supervisor: <cfoutput><strong>#mentorSite#</strong></cfoutput>
<br/><br/>

<!---PIE doesn't store shift information in a freindly(or particularly useful) way.  We're going to fetch all the shifts for the days surrounding today so we don't hammer the database looking for the info we want.--->
<!---used with the getShiftBySite() function --->
<cfquery datasource="#application.applicationDataSource#" name="getAllShifts">
	SELECT #instanceId# AS instance_id, sb.site_id, sb.shift_time, u.user_id,  picture_source, preferred_name, c.username,
		 ci.checkin_id, ci.start_time, ci.end_time, ci.checkin_time, ci.checkout_time
	FROM [#myPieDsn#].dbo.shift_blocks sb
	INNER JOIN [#myPieDsn#].dbo.tbl_consultants c ON c.ssn = sb.ssn
	INNER JOIN tbl_users u ON LOWER(u.username) = LOWER(c.username)
	LEFT OUTER JOIN [#myPieDsn#].dbo.tbl_checkins ci ON ci.checkin_id = sb.checkin_id
	WHERE sb.shift_date BETWEEN '#dateFormat(dateAdd("d", -1, now()), "yyyy-mm-dd")#' AND '#dateFormat(dateAdd("d", 1, now()), "yyyy-mm-dd")#'
	ORDER BY sb.shift_date ASC, sb.time_id ASC, sb.site_id
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getMyMentees">
	SELECT u.user_id, c.username, u.picture_source, u.preferred_name
	FROM [#myPieDsn#].dbo.tbl_obs_mentors m
	INNER JOIN [#myPieDsn#].dbo.tbl_consultants cs ON cs.ssn = m.mentor_id
	INNER JOIN [#myPieDsn#].dbo.tbl_consultants c ON c.ssn = m.mentee_id
	LEFT OUTER JOIN tbl_users u ON LOWER(u.username) = LOWER(c.username)
	WHERE GETDATE() BETWEEN m.start_date AND m.end_date
	AND cs.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.cas_username#">
	ORDER BY c.username ASC
</cfquery>

<!---HTML--->

<!--- left sidebar --->
<div class="sidebar">

	<cfoutput>

		<!--- mentees --->
		<div class="shadow-border">

			<h3>Mentees</h3>

			<cfif getMymentees.recordCount eq 0>
				<p style="padding:5px;">None.</p>
			<cfelse>

				<cfloop query="getMyMentees">
					<a class="block-card  hover-box" style="display:block;width:85%;display:inline-block;margin:1%;"
					   href="#application.AppPath#/tools/shift-report/mentee-report.cfm?currentUserId=#getMyMentees.user_id#">
						<img src="#picture_source#" style="width:75px;float:left;"/>
						<span class="display:block;">
							<br/>#username#
							<br/>
						</span>
						<br/>
						<div style="clear:both;"></div>
					</a>
				</cfloop>

			</cfif>

		</div>

		<br/>

		<!--- consultant selector --->
		<div class="shadow-border">

			<h3 style="margin:0px 5px 0px 5px;">Select a Consultant</h3>

			<div class="sel-con" style="text-align: center;">

				<form action="#application.appPath#/tools/shift-report/mentee-report.cfm" method='get' style="margin-bottom:0px;">

					<cfquery datasource="#application.applicationDataSource#" name="getBlacklist">
						SELECT i.instance_mask
						FROM tbl_instances i
						WHERE i.instance_mask != <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
					</cfquery>

					<cfset blackList = "Admin, Logistics"> <!--- never display admins or logistics members --->
					<cfif not hasMasks("Admin")>
						<cfset blackList= listAppend(blackList, "CS")> <!--- blacklist CS for non-admin users --->
					</cfif>

					<!--- add all non-primary instance masks to the blacklist --->
					<cfloop query="getBlacklist">
						<cfset blackList = ListAppend(blackList,getBlacklist.instance_mask)>
					</cfloop>

					#drawConsultantSelector('consultant', blackList, 0)#

					<br/>

					<label for="dayDayId">Date:</label>
					<input id="dayDateId" type="text" name="dayDate" value="#DateFormat(now(),'mm/dd/yyyy')#">

					<!--- replace text field with datepicker --->
					<script type="text/javascript">
						$("##dayDateId").datepicker({dateFormat: "mm/dd/yy"});
					</script>

					<br/>

					<input type='submit' name='action' value='View'/>

				</form>

			</div>

		</div>

	</cfoutput>

	<br/>

	<!--- staffed and unstaffed labs --->
	<cfoutput query="getRouteLabs" group="route_id">

		<div class="shadow-border">

			<cfoutput group="staffed">

				<cfif staffed>
					<h3>Staffed Labs</h3>
				<cfelse>
					<br/>
					<h3>Unstaffed Labs</h3>
				</cfif>

				<cfoutput group="site_id">
					<span style="float:left;">#site_long_name#</span>
					<span style="float:right;">#site_name#</span> <br/>
				</cfoutput>

			</cfoutput>

		</div>

	</cfoutput>

</div>
<!--- end sidebar --->

<!--- main information box --->
<div class="main">

	<!--- consultants on route --->
	<div class="shadow-border">

		<h3>Consultants on Route</h3>

		<cfoutput query="getRouteLabs" group="route_id">

			<cfoutput group="site_id">

				<cfset shift = getShiftBySite(instance_id, site_id)>

				<cfif shift.user_id NEQ -1>
		<!---	<a class="block-card hover-box consultant-on-route"
					   href="#application.AppPath#/tools/shift-report/mentee-report.cfm?currentUserId=#shift.user_id#"> --->
			    <a class="block-card hover-box consultant-on-route"
					   href="#application.AppPath#/tools/shift-report/mentee-report.cfm?currentUserId=#shift.user_id#" userName=#shift.username#>
						<img src="#shift.picture_source#" class="consultant-image" />

						<span class="display:block;">
							<br/>#shift.username#
							<br/>#site_name#
							<br/>
							#TimeFormat(shift.start_time, "hh:mm")# - #TimeFormat(shift.end_time, "hh:mm")#
							<br/>
						</span>

					</a>

				</cfif>

			</cfoutput>

		</cfoutput>
		</div>

<cfset drawContact = 0>
	<br/>

	<div class="shadow-border">
		<h3>Open Contacts on Route</h3>
		<span class="triggerexpanded">Show/Hide</span>
		<div>
			<cfoutput query="getContacts" group="contact_id">
				<div style="opacity: 1; display: inline-block; width: 20em; border: 1px solid gray;">
					#trim(lab_name)# <span class="tinytext">(#username#)</span> - <a href="#application.appPath#/tools/contacts/view-contact.cfm?contactId=#contact_id#" class="contactLink" contactId="#contact_id#">#contact_id#</a><br/>

					<!---rather than output customers and categories all at once build a list of each.--->
					<cfset custList = "">
					<cfset catList = "">
					<cfoutput group="customer_username">
						<cfif customer_username neq "">
							<cfset custList = listAppend(custList, customer_username)>
						<cfelse>
							<cfset custList = listAppend(custList, "<em>none</em>")>
						</cfif>

						<!---reset catList from our last pass--->
						<cfset catList = "">
						<cfoutput>
							<cfset catList = listAppend(catList, category_name)>
						</cfoutput>

					</cfoutput>


					<!---having built-up custList and catList we can now display them.--->
					<span class="tinytext">
						<br/>
						Customers: #custList#
						<br/>
						Categories: #catList#
					</span>
				</div>
			</cfoutput>

			<cfif getContacts.recordCount eq 0>
				<em>None</em>
			</cfif>
		</div>
	</div>

	</br>

	<div class="shadow-border">

		<cfoutput>

			<h3><a href="#application.appPath#/tools/lab-distribution/lab-distribution.cfm">Lab Distribution</a></h2>

			<!---bring in our lab dist functions--->
			<cfinclude template="#application.appPath#/tools/lab-distribution/lab-distribution-module.cfm">
			<cfset tickets = getTicketsByRoute("i#instanceId#r#routeId#")>

			<span class="triggerexpanded">Show/Hide</span>

			<div>
				<cfloop query='tickets'>

					<cfset ticketLabs = getLabsForTicket(ticket_id)>

					<cfif ticketLabs.recordCount NEQ 0 >
						<a class='block-card hover-box'
						   href='#application.appPath#/tools/lab-distribution/complete-item.cfm?action=Edit%20Ticket&ticketId=#ticket_id#' style='display:block;'>
							<div style='width:150px; float:left;'>
									<strong>#item_name#</strong>
									<br/>
									Comment: #stripTags(comment)#
									<br/>
								</div>
								<div style='width:60%; float:right;' >
									<cfloop query='ticketLabs'>
										<div style='width:125px; display:inline-block;'>
										<center>
											#lab_name#
										</center>
										<br/>
										</div>
									</cfloop>
								</div>
							<div style='clear:both;'></div>
						</a>

					</cfif>

				</cfloop>

				<cfif tickets.recordCount EQ 0>None.</cfif>
			</div>

		</cfoutput>

	</div>

	<br/>

	<!--- supply reports --->
	<div class="shadow-border">
		<cfoutput>
			<h3>Supply Reports</h3>
			<span class="triggerexpanded">Show/Hide</span>
			<div>
				#drawSiteInventoriesByRoute(instanceId,routeId)#
			</div>
		</cfoutput>
	</div>

</div>

<div class="modal fade" id="myModal" role="dialog">
	<div class="modal-dialog">
		<!-- Modal content-->
		<div class="modal-content" id="content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal">&times;</button>
				<h3 class="modal-title"></h3>
			</div>
			<div class="modal-body"></div>

			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Dismiss</button>
			</div>
		</div>
	</div>
</div>

<div class="modal fade" id="contactModal" role="dialog">
	<div class="modal-dialog">
		<!-- Modal content-->
		<div class="modal-content" id="content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal">&times;</button>
				<h3 class="modal-title">View Contact</h3>
			</div>

			<div class="modal-body"></div>

			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Dismiss</button>
			</div>
		</div>
	</div>
</div>


<!--- FUNCTIONS --->
<!--- sadly PIE doesn't sort shifts in a very human friendly way, this function works with the cumbersome getAllShifts query to spit out human readable information about the current shift for a given site. --->
<cffunction name="getShiftBySite" output="true">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="siteId" type="numeric" required="true">

	<cfset var shiftObj = structNew()>
	<cfset var curTime = dateTimeFormat(now(), "yyyy-mm-dd HH:00")>
	<cfset var getShift = ""><!---find who's working and if they've checked in/out.--->
	<cfset var tempTime = ""><!---a placeholder for various checks.--->
	<cfset var getStart = ""><!---find the time the shift started--->
	<cfset var getEnd = ""><!---find the time the shift should end--->
	<cfset var getPrev = ""><!---find the last time the site was staffed.--->
	<cfset var getNext = ""><!---find the next time the shift will be staffed.--->


	<cfset shiftObj.username = "">
	<cfset shiftObj.user_id = -1>
	<cfset shiftObj.picture_source = "">
	<cfset shiftObj.preferred_name = "">
	<cfset shiftObj.start_time = "">
	<cfset shiftObj.end_time = "">
	<cfset shiftObj.checkin_time = "">
	<cfset shiftObj.checkout_time = "">
	<cfset shiftObj.last_staffed = "">
	<cfset shiftObj.next_staffed = "">


	<cfquery dbtype="query" name="getShift">
		SELECT user_id, username,  picture_source, preferred_name, start_time, end_time, checkin_time, checkout_time
		FROM getAllShifts
		WHERE instance_id = #instanceId#
		AND site_id = #siteId#
		AND shift_time  = '#curTime#'
	</cfquery>

	<cfloop query="getShift">
		<cfset shiftObj.username = username>
		<cfset shiftObj.user_id = user_id>
		<cfset shiftObj.picture_source = picture_source>
		<cfset shiftObj.preferred_name = preferred_name>
		<cfset shiftObj.checkin_time = checkin_time>
		<cfset shiftObj.checkout_time = checkout_time>
		<!---if we have a checkin we can cheat a little bit and use the start_time and end time from it.--->
		<cfset shiftObj.start_time = start_time>
		<cfset shiftObj.end_time = end_time>
	</cfloop>

	<!---if we didn't luck into a shift that's been checked into we need to figure out when the shift started--->
	<cfif not isDate(shiftObj.start_time) AND shiftObj.username neq "">
		<!---fetch the shifts for this user at or before the current shift so we can find the earliest contigous shift.--->
		<cfquery dbtype="query" name="getStart">
			SELECT shift_time
			FROM getAllShifts
			WHERE instance_id = #instanceId#
			AND site_id = #siteId#
			AND username = '#shiftObj.username#'
			AND shift_time < '#curTime#'
			ORDER BY shift_time DESC
		</cfquery>

		<!---someone could work a non-contigous shift in this site, if we reach one we now know when the shift started.--->
		<cfset tempTime = curTime>
		<cfloop query="getStart">
			<cfif dateCompare(shift_time, dateAdd("h", -1, tempTime)) neq 0>
				<!---we reached a non-contigous shift portion, the last pass was the start of the curent shift.--->
				<cfbreak>
			</cfif>
			<!---update for our next pass.--->
			<cfset tempTime = shift_time>
		</cfloop>
		<cfset shiftObj.start_time = tempTime>
	</cfif>

	<!---now do the same for end_time.--->
	<cfif not isDate(shiftObj.end_time) AND shiftObj.username neq "">
		<!---fetch the shifts in this site for our user following the current hour.--->
		<cfquery dbtype="query" name="getEnd">
			SELECT shift_time
			FROM getAllShifts
			WHERE instance_id = #instanceId#
			AND site_id = #siteId#
			AND username = '#shiftObj.username#'
			AND shift_time > '#curTime#'
			ORDER BY shift_time ASC
		</cfquery>

		<!---someone could work a non-contigous shift in this site, if we reach one we now know when the shift started.--->
		<cfset tempTime = curTime>

		<cfloop query="getEnd">
			<cfif dateCompare(shift_time, dateAdd("h", 1, tempTime)) neq 0>
				<!---we reached a non-contigous shift portion, the last pass was the start of the curent shift.--->
				<cfbreak>
			</cfif>
			<!---update for our next pass.--->
			<cfset tempTime = shift_time>
		</cfloop>
		<cfset shiftObj.end_time = dateAdd("h", 1, tempTime)><!---the actual ending time, not the start of the 1-hour shift block--->
	</cfif>

	<!---before this shift when was this site last staffed?--->
	<cfset tempTime = iif(isDate(shiftObj.start_time), de(shiftObj.start_time), de(curTime))>
	<cfquery dbtype="query" name="getPrev" maxrows="1">
		SELECT shift_time
		FROM getAllShifts
		WHERE instance_id = #instanceId#
		AND site_id = #siteId#
		AND shift_time < '#dateFormat(tempTime, "yyyy-mm-dd HH:00")#'
		AND checkin_id IS NOT NULL
		ORDER BY shift_time DESC
	</cfquery>

	<cfloop query="getPrev">
		<cfset shiftObj.last_staffed = dateAdd("h", 1, shift_time)>
	</cfloop>

	<!---after this shift when is the lab next staffed?--->
	<cfset tempTime = iif(isDate(shiftObj.end_time), de(shiftObj.end_time), de(curTime))>
	<cfquery dbtype="query" name="getNext" maxrows="1">
		SELECT shift_time
		FROM getAllShifts
		WHERE instance_id = #instanceId#
		AND site_id = #siteId#
		AND shift_time > '#dateFormat(tempTime, "yyyy-mm-dd HH:00")#'
		ORDER BY shift_time ASC
	</cfquery>

	<cfloop query="getNext">
		<cfset shiftObj.next_staffed = shift_time>
	</cfloop>

	<cfreturn shiftObj>
</cffunction>

<!---this function takes a route, and draws all the sites that have inventory items in that route.--->
<cffunction name="drawSiteInventoriesByRoute">
	<cfargument name="instanceId" type="numeric" required="true">
	<cfargument name="routeId" type="numeric" required="true">
	<cfset var labItemList = "">
	<cfset var siteTypeList = "">
	<cfset var allItems = getAllItems()>
	<cfset var allItemTypes = getAllItemTypes()>
	<cfset var labList = "0">
	<cfset var getInvLabs = "">

	<!---build a list of labs on this route so we can check if any of them have inventories--->
	<cfloop query="getRouteLabs">
		<cfif not listFind(labList, lab_id)>
			<cfset labList = listAppend(labList, lab_id)>
		</cfif>
	</cfloop>

	<cfquery datasource="#application.applicationDataSource#" name="getInvLabs">
		SELECT DISTINCT i.instance_id, b.building_id, b.building_name, i.lab_id, l.lab_name, l.staffed
		FROM tbl_inventory_site_items i
		INNER JOIN vi_labs l
			ON l.instance_id = i.instance_id
			AND l.lab_id = i.lab_id
		INNER JOIN vi_buildings b
			ON b.instance_id = l.instance_id
			AND b.building_id = l.building_id
		WHERE i.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
		AND i.lab_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#labList#" list="true">)
		ORDER BY b.building_name, l.lab_name
	</cfquery>

	<cfif getInvLabs.recordCount eq 0>
		<em>No labs with inventory for this route.</em>
	</cfif>


	<!---armed with our siteId we can fetch the valid items, types, and current levels for this site.--->
	<cfoutput query="getInvLabs">
		<fieldset class="report-lab" style="display:inline-block;width:45%;margin-top:2em;">

			<legend>#building_name# #lab_name#</legend>
			<span class="tinytext">
				<a href="#application.appPath#/inventory/report_site_graph.cfm?frmInstanceId=#instance_id#&frmLabId=#lab_id#" target="_blank">Supply Graph</a>
			</span>
			<cfset drawLabInventory(lab_id, 0, "", allItems, allItemTypes)>

		</fieldset>
	</cfoutput>

</cffunction>


<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>