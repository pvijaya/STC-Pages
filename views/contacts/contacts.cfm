<cfoutput>
<cfinclude template="#application.appPath#/views/contacts/view-contacts.cfm">
<div class="page-header">
	<h1>Manage Contacts</h1>
</div>

<div class="row">
	<div class="col-sm-12">
	    <ul id="contact-tabs" class="nav nav-tabs" data-tabs="tabs">
	        <li class="active"><a href="##create-contact-container" data-toggle="tab">New Contact</a></li>
	        <li><a href="##open-contacts-container" data-toggle="tab">Open Contacts <span class="open-contact-counter"></span></a></li>
	        <li><a href="##contacts-myInfo-container" data-toggle="tab" id="stats">Statistics</a></li>
			<script type="text/javascript">
			    $(document).ready(function ($) {
			        $('##contact-tabs').tab();
			    });
			</script>  
	    </ul>
    	<div class="tab-content">
        	<div class="tab-pane active" id="create-contact-container">
				<h2>Create A Contact</h2>
				<br/>
				<cfset viewId = CreateUUID()>
				<cfoutput><div id="#viewId#"></div></cfoutput>
				<script>contactViewer("###viewId#", {"contact_id": 0}, true);</script>
 				</div>
    		<div class="tab-pane" id="open-contacts-container" >
				<h2>Open Contacts</h2>
				<br/>
				<cfset viewId = CreateUUID()>
				<cfoutput><div id="#viewId#"></div></cfoutput>
				<script>contactViewer("###viewId#", {"status_id": 1, "user_id": #session.cas_uid#}, false);</script>
			</div>
			<div class="tab-pane" id="contacts-myInfo-container">
				<h2>My Statistics</h2>
				
				<div id="statsDiv"></div>
				
				<p>
					<a href="#application.appPath#/tools/contacts/contacts.cfm" target="_blank">Customer Contacts Reporting</a>
				</p>
			</div>
		</div>
	</div>
</div>

<br/><br/>
</cfoutput>

<!---override the dd margin in bootstrap--->
<style type="text/css">
	dd {
		margin-left: 1em;
	}
</style>

<script type="text/javascript">
	/*event handler for drawing up-to-date statistics info when the Statistics tab is clicked*/
	$("a#stats").on("click", function(e){
		var container = $(this).parents("div.row");
		
		var drawSpace = $("div#statsDiv", container);
		
		new LoadingElement(drawSpace, "Loading Statistics");
		
		//actually grab our user's statistics and draw them.
		$.ajax({
			type: 'GET',
			url: '<cfoutput>#application.appPath#</cfoutput>/views/contacts/statistics.cfm',
			dataType: 'html',
			data: {},
			cache: false,
			success: function(data){
				$(drawSpace).html(data);
			},
			error: function(error){
				$(drawSpace).html("An error was encountered fetching your statistics, please try again.");
			}
		});
		
	});
</script>
