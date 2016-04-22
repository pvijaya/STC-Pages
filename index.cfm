<cfparam name="instance" type="integer" default="0">

<cfif instance EQ 0>
	<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">
</cfif>

<cfsetting showdebugoutput="false">

<!---If they are arriving from pie, instance will be set to the correct value. So, we want to set that as their default.--->
<!---This is primarily for chat to figure out which chat they want to view first--->
<cfset newInstance = 0>
<cfset instanceName = "Instance">
<cfif instance EQ 1> <!---If they only have one mask, we can easily point them to the right chat--->
	<cfif hasmasks('IUB')>
		<cfset newInstance = 1>
		<cfset instanceName = "IUB">
		<cfset setDefaultInstance(newInstance)>
	<cfelseif hasmasks('IUPUI')>
		<cfset newInstance = 2>
		<cfset instanceName = "IUPUI">
		<cfset setDefaultInstance(newInstance)>
	</cfif>

<cfelseif instance EQ 2>
	<cfif hasmasks('IUPUI')>
		<cfset newInstance = 2>
		<cfset instanceName = "IUPUI">
		<cfset setDefaultInstance(newInstance)>
	<cfelseif hasmasks('IUB')>
		<cfset newInstance = 1>
		<cfset instanceName = "IUB">
		<cfset setDefaultInstance(newInstance)>
	</cfif>

<cfelse>
	<!---This is the attempt to guess the instance. If they have both masks, we sadly have to default to IUB--->
	<cfif hasmasks('IUB') AND Session.primary_instance EQ 0>
		<cfset newInstance = 1>
		<cfset instanceName = "IUB">
		<cfset setDefaultInstance(newInstance)>
	<cfelseif hasmasks('IUPUI')  AND Session.primary_instance EQ 0>
		<cfset newInstance = 2>
		<cfset instanceName = "IUPUI">
		<cfset setDefaultInstance(newInstance)>
	<cfelseif Session.primary_instance NEQ 0>
		<cfset newInstance = Session.primary_instance>
	</cfif>
</cfif>

<cfmodule template="#application.appPath#/header.cfm" title='TETRA' drawCustom=false noText=false>
	<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<!---
<script type="text/javascript">
	var instance_name = #serializeJSON(instanceName)#;
	$("#instance_name").html(instance_name);
</script>
--->

<div class="row">
	<div class="col-sm-7">
		<div class="panel panel-default">
			<div id="chat-heading" class="panel-heading red-heading">
				<cfif newInstance EQ 1>IUB Chat<cfelseif newInstance EQ 2>IUPUI Chat</cfif>
				<span style="float:right;font-weight:500;" id="chatUpdateDate"></small>
			</div>
			<div class="panel-body">
				<cfif newInstance EQ 1 OR newInstance EQ 2>

					<cfinclude template="#application.appPath#/chat/inc_chat.cfm">
				<cfelse>
					Unknown Chat User<span style="float:right;font-weight:500;" id="chatUpdateDate"></span>
					<p>You are not allowed to view or post in chat. Please contact an admin team or the webmaster if you believe that you should be able to see chat.</p>
				</cfif>
			</div>
		</div>
	</div>

	<div class="col-sm-5">

		<!---show active users outside the chat when the screen is big enough.--->
		<div class="panel panel-default hidden-xs">
	    	<div class="panel-heading red-heading">
				<h4 class="panel-title chat-activetitle">Active Users</h4>
		    </div>
			<div class="panel-body chat-activecons">
				<div class="text-center"><i class="fa fa-spinner fa-spin" style="vertical-align:baseline;"></i> Loading active users</div>
			</div>
		</div>
		<div class="panel panel-default">
			<cfmodule template="#application.appPath#/inventory/mod_inventory_form.cfm">
		</div>
		<div class="panel panel-default">
			<cfmodule template="#application.appPath#/modules/mod_rss_it_notices.cfm" url="https://#cgi.server_name##application.appPath#/chat/itnotice_proxy.cfm" title="Status.IU">
		</div>

		<cfif session.primary_instance eq 1>
		<div class="panel panel-default">
			<div class="panel-heading red-heading">IUB TWITTER</div>
			<div class="panel-body">
				<div class="content" id="iubTwitter" style='margin-top:5px;'>
				<a class="twitter-timeline" href="https://twitter.com/uits_tcc_iub" data-widget-id="299607919618564096" data-chrome="nofooter transparent"  data-tweet-limit="2">Tweets by @uits_tcc_iub</a>
				<script>
					!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");
				</script>


				</div>
			</div>
		</div>
		<cfelseif session.primary_instance eq 2>
		<div class="panel panel-default">
			<div class="panel-heading red-heading">IUPUI TWITTER</div>
			<div class="panel-body">
				<div class="content" id="iupuiTwitter" style='margin-top:5px;'>
				<a class="twitter-timeline" href="https://twitter.com/uits_tcc_iupui" data-widget-id="347809339567906816"  data-chrome="nofooter transparent"  data-tweet-limit="2">Tweets by @uits_tcc_iupui</a>
				<script>
					!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+"://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");
				</script>
				</div>
			</div>
		</div>
		</cfif>
	</div>
</div>
	<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>
