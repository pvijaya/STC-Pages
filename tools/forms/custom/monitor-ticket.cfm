<cfmodule template="#application.appPath#/header.cfm" title='Monitor the tickets'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<h1>Open Tickets</h1>

<!---we need some information about the user's instance so we can present the correct links to the tickets in PIE.--->
<cfset piePath = "/apps/tcc/">
<cfquery datasource="#application.applicationDataSource#" name="getInstance">
	SELECT pie_path
	FROM tbl_instances
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
</cfquery>
<cfloop query="getInstance">
	<cfset piePath = pie_path>
</cfloop>

<script type="text/javascript">
	var status = 2;// 1 - paused, 2 - waiting to refresh, 3 - refreshing.
	var interval = 30;
	var curTicks = 0;

	$(document).ready(function(e){
		//setup the modal, but don't show it.
		$('#actorModal').modal({show:false});


		//event handler for catching button presses.
		$(document).on("click", ".actor-btn", function(e){
			e.preventDefault();

			var actorId = $(this).data("actor_id");
			var actorName = $(this).data("actor_name");
			var tickets = $(this).data("tickets");

			var loading = new LoadingElement('#actorModal .modal-body', "Drawing tickets...");
			$('#actorModal .modal-title').html(actorName);

			//update which id the modal believes it is showing
			$("#actorModal").data("actor_id", actorId);

			//show the modal.
			$('#actorModal').modal({show:true});

			//loop over the tickets and draw each of them.
			for(var n in tickets){
				var ticket = tickets[n];//a quick shorthand.
				var cont = $(document.createElement('div'));

				var opened = new Date( Date.parse(ticket.opened) ).dateFormat("mmm d, yyyy h:nn aa");

				var panel = $(document.createElement('div'))
					.addClass('panel')
					.addClass('panel-default');

				var title = $(document.createElement('h4'))
					.html("<a href='#' target='_blank'>" + ticket.ticket_id + "</a>")
					.addClass("panel-title");

				$("a", title).attr("href", "<cfoutput>#piePath#</cfoutput>/tickets/index.cfm?fuseaction=tkt&subfuse=edit&ticket_uid=" + ticket.ticket_uid);

				var panelBody = $(document.createElement('div'))
					.addClass("panel-body")
					.html("<p>" + ticket.fname + " " + ticket.lname + "(" + ticket.nid + ")</p>")
					.append("<p>" + opened + "</p>")
					.append("<p>" + ticket.building_name + " " + ticket.room_number + "</p>")
					.append("<p>" + ticket.summary + "</p>");

				panel.append(title).append(panelBody);

				cont.html(panel);

				if(n == 0){
					$('#actorModal .modal-body').html(cont);
				} else {
					$('#actorModal .modal-body').append(cont);
				}
			}



		});

		//event handler for the pause button.
		$(document).on("click", "button#pause", function(e){
			e.preventDefault();

			if( $(this).hasClass("btn-default") ){
				status = 1;
				$(this).removeClass("btn-default").addClass("btn-primary");
			} else {
				status = 2;
				$(this).removeClass("btn-primary").addClass("btn-default");
			}
		});

		updateTickets();

		setInterval(
			function(){

				if(status == 3){
					var x = new LoadingElement("span#status", "Refreshing...");
				} else if(status == 2) {
					curTicks++;

					if(curTicks >= interval){
						updateTickets();
						curTicks = 0;
					}

					$("span#status").html( interval - curTicks + " seconds until next refresh.");
				}
		 	},
		  1000);

	});



	function updateTickets() {
		$.ajax({
			type: 'GET',
			async: true,
			url: '<cfoutput>#application.appPath#/tools/forms/custom/monitor-ticket-json.cfm</cfoutput>',
			beforeSend: function(){
				//show that our status is refreshing
				status = 3;
			},
			success: function(data){
				//console.log(data);

				var x = new LoadingElement("div#ticketCanvas", "Redrawing Actors/Tickets.");

				var cont = $(document.createElement('div'));
				for( var n in data ){

					var btnCont = $(document.createElement('div'));
					btnCont.addClass('col-sm-2');

					var btn = $(document.createElement('a'));
					btn.addClass('btn')
						.addClass('btn-default')
						.addClass('actor-btn')
						.attr("href", "#")
						.data("actor_id", data[n].actor_id)
						.data("actor_name", data[n].actor_name)
						.data("tickets", data[n].tickets)
						.html( data[n].actor_name + " <span class='badge'>" + data[n].tickets.length + "</span>");

					btnCont.append(btn);
					cont.append(btnCont);
				}

				$("div#ticketCanvas").html(cont);

				//If the modal is currently open we need to redraw it.
				if( $('#actorModal').data('bs.modal').isShown ){
					var actorId = $('#actorModal').data('actor_id');

					//find the button that has that actor_id and click it.
					$('.actor-btn').each(function(n){
						if( $(this).data('actor_id') == actorId){
							$(this).click();
							return;
						}
					});
				}


				status = 2;
			},
			error: function(error){
				alert("An error was encountered refreshing the list of tickets.  Please reload this page.");
			}
		});
	}
</script>

<div>
	<button class="btn btn-default" id="pause">
		<span aria-hidden="true" class="glyphicon glyphicon-pause" style="cursor:default;"></span>
	</button>
	<span id="status"></span>
</div>
<hr/>

<div id="ticketCanvas"></div>

<div class="modal fade" id="actorModal" role="dialog">
	<div class="modal-dialog">
		<!-- Modal content-->
		<div class="modal-content">
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


<cfmodule template="#application.appPath#/footer.cfm">


