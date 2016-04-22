	<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant" showMaskPermissions="False">
	<cfsetting showdebugoutput="true">

	<!---this include is intended such that it can be easily used on any page in the stcpages without causing too much interference.--->

	<!---this ensures us a unique name for our chat's container.--->
	<cfset chatId = "chat" & createUUID()>

	<style type="text/css">

		input#chatbox {
			width:38%;
			height:26px;
			padding-left:10px;
		    background: #f3f3f3;
		    border: solid 1px #dcdcdc;
		    border-radius: 2px;
		}

		.iconbox{
			max-height: 3em;
			float:left;
			margin-right:10px;
			margin-bottom:10px;
			-webkit-box-shadow: 0 0 6px rgba(0, 0, 0, 0.3);
			-moz-box-shadow: 0 0 6px rgba(0,0,0,0.3);
			box-shadow: 0 0 6px rgba(0, 0, 0, 0.3);
			-webkit-background-clip: padding-box;
			-moz-background-clip: padding-box;
			background-clip: content;
		}

		div.buttons {
			float: left;
			clear: both;
			margin:3px 0px 0px 0px;
		}

		.chatmess span.msg_hide_btn{ cursor: pointer;}/*our hide message "X"*/
		.chatmess .user { cursor: pointer; }/*make the clickable parts looks like links.*/
		.chatmess.highlight{ background-color:#0CF;}
		.chatmess.announce{ background:#FF6; }
		.chatmess img.emoticon { max-height: 3em; width: auto;}
		.chatmess {padding:2px 5px 2px 5px; margin:0px;border: 1px solid #FFF;}
		.scroll-pane{ width: 100%; height: 435px; overflow: auto; padding-top:5px;}
		#chatarea p {font-size:12px; overflow:auto; margin:2px;}
		div#chatarea {
			background-color: white;
			display: block;
			padding-left: 0px;
			padding-right: 0px;
			padding-bottom:20px;
			overflow-y: hidden;
			overflow-x: hidden;
		}

		img.user{ max-width:40px;  float:left; margin-right:5px; }/*width and height are controlled by js, but this should restrain in failures.*/

		.slider {
			display: none;/*initially do not display, jQuery will render it*/
			width:100%;

		}

		/*status indicators*/
		.c_admin{width:10px; height:10px; margin-right:5px; float:left;  background:#a172a3;}
		.c_out_zero{width:10px; height:10px; margin-right:5px; float:left;  background:#900;}
		.c_in_one{width:10px; height:10px; margin-right:5px; float:left; background:#090;}
		.c_step_two{width:10px; height:10px; margin-right:5px; float:left; background:#ffe100;}
		.c_break_three{width:10px; height:10px; margin-right:5px; float:left; background:#ffe100;}
		.boxshad{ -moz-box-shadow: 0px 0px 2px rgba(0,0,0,0.55);
		  -khtml-box-shadow: 0px 0px 2px rgba(0,0,0,0.55);
		  -webkit-box-shadow: 0px 0px 2px rgba(0,0,0,0.95);
		}



		/*ANNOUNCEMENTS*/
		#anncbutton
		{
			/*color:#900;*/
		}
		#anncdiv .adminlvl a {color:purple;}
		#anncdiv .cslvl a {color:blue;}
		#anncdiv .conslvl a {color:green;}
		#anncdiv .logsLevel { color:#E38D4B; }
		a.more-messages {
			position:fixed;
			top:0px;
			font-size:125%;
			width:655px;
			min-width:300px;
			padding:3px;
			z-index:1001;
		}

		a.more-messages:active, a.more-messages:link, a.more-messages:visited,a.more-messages, a.more-messages:focus  {
			color:#fff;
		}
		ul.chat-feature-list {
			list-style:none;
		}
		ul.chat-feature-list li {
			margin:10px;
		}
		.post-form {
		overflow:auto;
		padding:7px;
		}
		.adminColor {color:#800080;}
		.csColor {color:blue;}
		.logisticsColor {color:orange;}
		.techColor {color:#148aa5;}
		.conColor {color:#090;}
		#progressHeader{
			font-family: "sans-serif";
		}

	</style>
<!---The customer contact progress bar--->
<cfquery datasource="#application.applicationDataSource#" result= "info" name="getGoal">
	DECLARE @now datetime = GETDATE(),
	        @curStart datetime,
	        @curCode int,
	        @weeksIn int,
	        @prevStart datetime,
	        @prevWeek datetime,
	        @contactDate datetime;

	DECLARE @curWeekday int = DATEPART(weekday, @now),
	        @dayTotal int = 0,
	        @total int = 0;


	SELECT @curStart = start_date, @curCode = semester_code_id, @weeksIn = DATEDIFF(week, start_date, @now)
	FROM vi_semesters
	WHERE @now BETWEEN start_date AND end_date
	AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">

	DECLARE sems CURSOR FOR
	SELECT TOP 5 start_date
	FROM vi_semesters
	WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
	AND semester_code_id = @curCode
	AND start_date < @curStart
	ORDER BY start_date DESC

	OPEN sems
	FETCH NEXT FROM sems INTO @prevStart
	WHILE @@FETCH_STATUS = 0
	BEGIN

	    SET @prevWeek = DATEADD(week, @weeksIn, @prevStart)

	    <!---make sure prevWeek is actually the first day of the week --->
	    WHILE DATEPART(weekday, @prevWeek) > 1
	    BEGIN
	        SET @prevWeek = DATEADD(day, -1, @prevWeek)
	    END

	   <!---now set @contactDate to the same day of the week as @now --->
	    SET @contactDate = DATEADD(day, @curWeekday-1, @prevWeek)


	   <!---now that we have the day for this previous semester tally up the contacts for this day.*/
	    find the count of contacts for @contactDate. --->
	    SELECT @dayTotal = COUNT(c.contact_id)
	    FROM tbl_contacts c
	    LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = c.contact_id
	    WHERE c.created_ts BETWEEN @contactDate AND DATEADD(day, 1, @contactDate)

	    SET @total = @total + @dayTotal

	    <!---update for the next pass --->
	    FETCH NEXT FROM sems INTO @prevStart
	END

	CLOSE sems
	DEALLOCATE sems

	SELECT @total/5 AS avg

</cfquery>


<cfset getGoalValue= "#getGoal.avg#">


<script type="text/javascript">

	$(document).ready(function(){
		initialSetUp();

		function initialSetUp(){

		/* query the completion percentage from the server */
		$(".progress").attr("elem","dailyTotal");

			$.get("data.cfm", function(data){

				<cfoutput>
     				 var #toScript(getGoalValue, "goal")#;
  				 </cfoutput>

				var	myPercentage = data.personal/goal * 100;

				var totalPercentage = ((data.total/goal) * 100) - myPercentage;

				//don't let total be more than 100%, nor total + personal be over 100%.
				if( totalPercentage + myPercentage > 100){
					totalPercentage = 100 - myPercentage;
				}

				myPercentage = myPercentage.toFixed(1);//only one decimal place is desired.
				totalPercentage = totalPercentage.toFixed(1);//Again only one decimal place of precision is wanted.



				//Start by making the bars look active
				$("#total, #personal").addClass("active");

				/* update the progress bars' widths */
				$("#total").css('width',totalPercentage + '%');

				/* and display the numeric value */
				$("#total").html(totalPercentage+ '%');

				/* update the progress bar width */
				$("#personal").css('width',myPercentage + '%');

				/* and display the numeric value */
				$("#personal").html(myPercentage+ '%');

				//if we've hit our goal, the total doesn' need to look active anymore.
				if (parseFloat(totalPercentage) + parseFloat(myPercentage) >= 100){
					$("#total").removeClass("active");
				}


			});


		}

		var progresspump = setInterval(function(){
			initialSetUp();

		}, 15000);


		$('[data-toggle="tooltip"]').tooltip();

		/* div messages for progress bar */

		document.getElementById("total").onclick = function() {
			//$("div.progress").popover({ placement: "bottom" ,title: 'Today\'s Consultants !', content: "Consultants in shift who logged contacts"});
			document.getElementById("progressHeader").innerHTML = "Consultants contributing towards the customer contacts goal for the day!";
			loadContacts()};

/* Loading the individual customer contacts */
		function loadContacts() {

			<cfoutput>
     			var #toScript(getGoalValue, "goal")#;
  			</cfoutput>
			//var goal = 98;
			var conBarArray = new Array();
			var total = 0;

			$("#total").hide();
			$("#personal").hide();
			$(".progress").attr("elem","consultantsTotal");

			$.get("total-consultants.cfm", function(data){
				for(var n in data){
					var uniquePointer = 0;

					var contDiv = $( document.createElement('div') );//We need an outside element to put conbar in, and then dump its HTML.
					var conBar = $( document.createElement('div') );

					conBar
						.addClass("consultant")
						.addClass("progress-bar progress-bar-info progress-bar-striped")
						.attr("role", "progressbar")
						.attr("id", 'q'+n)
						.attr("user_id", data[n].user_id)
						.attr("last_name", data[n].lastName)
						.attr("user_TotalCount", data[n].Total_Count)
						.attr("data-toggle", "tooltip")
						/*.attr("title", data[n].user_id);*/
						.attr("title", data[n].firstName + " " + data[n].lastName);

					contDiv.append(conBar);

					total += data[n].userCount;
					conBarArray.push(contDiv.html());

					}

				//if our total works out to more than our goal, reset goal, since we can't deal with more than 100% contacts.
				if(total > goal) goal = total;

				//having found our total, and populated conBarArray with elements.  Determine the width of each element and render it.
				for(var n in data){
					var contDiv = $( document.createElement('div') );//We need an outside element to put conbar in, and then dump its HTML.
					var myPercentage = data[n].userCount / data[n].Total_Count * 100;

					//read the element into contDiv
					contDiv.html(conBarArray[n]);
					//make a helper to manipulate the conbar
					var conBar = $("div.consultant", contDiv);

					//now set the width and color of the element.
					conBar
						//.css("width: " + myPercentage + "%; background-color: " + data[n].color)
						.attr("style", "width: " + myPercentage + "%; background-color: " + data[n].color)
						//.html(myPercentage.toFixed() + "%");

					//draw the actual element in our progress bar.
					$("div.progress").append( conBar );

				}

				//having drawn our new divs, makesure they have tooltips.
				$('[data-toggle="tooltip"]').tooltip();
			 });

		}


/* We pull lab distribution for each consultant */


	$("div.progress").on("click",".consultant",function(e){
			e.preventDefault();
			document.getElementById("progressHeader").innerHTML =$(this).attr('last_name')+ "'s lab distribution towards the customer contacts goal";
			currentUserID=$(this).attr('user_id');
       		loadLabsThisId(currentUserID)

		});

	function loadLabsThisId(currentUserID){

			$("#total").hide();
			$("#personal").hide();
			$(".consultant").hide();
			$(".progress").attr("elem","labsOtherConsultants");

			<cfoutput>
     				 var #toScript(getGoalValue, "goal")#;
  			</cfoutput>

			var labBarArray = new Array();
			var total = 0;

			$.post("consultantsLabs.cfm",{ id : currentUserID}, function (data,status) {

   					for(var n in data){

					var contDiv = $( document.createElement('div') );//We need an outside element to put conbar in, and then dump its HTML.
					var labBar = $( document.createElement('div') );

					labBar
						.addClass("labsCount")
						.addClass("progress-bar progress-bar-info progress-bar-striped")
						.attr("role", "progressbar")
						.attr("id", "labBar")
						.attr("data-toggle", "tooltip")
						/*.attr("title", data[n].user_id);*/
						.attr("title", data[n].buildingName + " "+data[n].buildShortName + data[n].roomNumber);

					contDiv.append(labBar);

					total += data[n].customerContacts;
					labBarArray.push(contDiv.html());

				}

				//if our total works out to more than our goal, reset goal, since we can't deal with more than 100% contacts.
				if(total > goal) goal = total;

				//having found our total, and populated labBarArray with elements.  Determine the width of each element and render it.
				for(var n in data){
					var contDiv = $( document.createElement('div') );//We need an outside element to put labBar in, and then dump its HTML.
					var myPercentage = data[n].customerContacts / data[n].Total_Count * 100;

					//read the element into contDiv
					contDiv.html(labBarArray[n]);
					//make a helper to manipulate the labBar
					var labBar = $("div.labsCount", contDiv);

					//now set the width and color of the element.
					labBar
						//.css("width: " + myPercentage + "%; background-color: " + data[n].color)
						.attr("style", "width: " + myPercentage + "%; background-color: " + data[n].color)
						//.html(myPercentage.toFixed() + "%");

					//draw the actual element in our progress bar.
					$("div.progress").append( labBar );

				}

				//having drawn our new divs, makesure they have tooltips.
				$('[data-toggle="tooltip"]').tooltip();

				},'json');
		}

/* Loading the labs where consultant have recorded the customer contact */
		document.getElementById("personal").onclick = function() {
			document.getElementById("progressHeader").innerHTML = "My lab distribution towards the customer contacts goal!"
			loadLabsContacts()};
		function loadLabsContacts() {

			<cfoutput>
     			 var #toScript(getGoalValue, "goal")#;
  			</cfoutput>
			//var goal = 98;
			var labBarArray = new Array();
			var total = 0;

			$("#total").hide();
			$("#personal").hide();
			$("#consultant").hide();
			$(".progress").attr("elem","labsTotal");


			$.get("total-labs.cfm", function(data){
				for(var n in data){

					var contDiv = $( document.createElement('div') );//We need an outside element to put conbar in, and then dump its HTML.
					var labBar = $( document.createElement('div') );

					labBar
						.addClass("labsCount")
						.addClass("progress-bar progress-bar-info progress-bar-striped")
						.attr("role", "progressbar")
						.attr("id", "labBar")
						.attr("data-toggle", "tooltip")
						/*.attr("title", data[n].user_id);*/
						.attr("title", data[n].buildingName + " "+data[n].buildShortName + data[n].roomNumber);

					contDiv.append(labBar);

					total += data[n].customerContacts;
					labBarArray.push(contDiv.html());

				}

				//if our total works out to more than our goal, reset goal, since we can't deal with more than 100% contacts.
				if(total > goal) goal = total;

				//having found our total, and populated labBarArray with elements.  Determine the width of each element and render it.
				for(var n in data){
					var contDiv = $( document.createElement('div') );//We need an outside element to put labBar in, and then dump its HTML.
					var myPercentage = data[n].customerContacts / data[n].Total_Count * 100;

					//read the element into contDiv
					contDiv.html(labBarArray[n]);
					//make a helper to manipulate the labBar
					var labBar = $("div.labsCount", contDiv);

					//now set the width and color of the element.
					labBar
						//.css("width: " + myPercentage + "%; background-color: " + data[n].color)
						.attr("style", "width: " + myPercentage + "%; background-color: " + data[n].color)
						//.html(myPercentage.toFixed() + "%");

					//draw the actual element in our progress bar.
					$("div.progress").append( labBar );

				}

				//having drawn our new divs, makesure they have tooltips.
				$('[data-toggle="tooltip"]').tooltip();
			 });

		}


/* flipping the progress bar on clicks */
		$('div.progress').on('click',
                          function(){

	                       		if ($(".progress").attr("elem") == 'dailyTotal' )
	                       		{
									$(".consultant").hide();
									$(".labsCount").hide();
	                       			$("#total").show();
	                       			$("#personal").show();
	                       			document.getElementById("progressHeader").innerHTML = ""

	                       		}
	                       	else if ($(".progress").attr("elem") == 'labsOtherConsultants' )
	                       		{

	                       			$('.consultant').on('click',function(){
		                       		$(".consultant").hide();
		                       		$(".labsCount").hide();
		                       		$("#total").show();
		                       		$("#personal").show(); });
									$(".progress").attr("elem", "dailyTotal")


	                       		}
	                       		else if ($(".progress").attr("elem") == 'labsTotal' )
	                       		{
									$('.labsCount').on('click',function(){
		                       		$(".consultant").hide();
		                       		$(".labsCount").hide();
		                       		$("#total").show();
		                       		$("#personal").show(); });
									$(".progress").attr("elem", "dailyTotal")

	                       		}

                          	});


	})
</script>

<div id="progressHeader"></div>
 <div class="progress">
	<div id="personal" class="progress-bar progress-bar-success progress-bar-striped active" data-toggle="tooltip"  title="My Customer Contacts" role="progressbar" style="width:0%">

	</div>
	<div id="total"  class="progress-bar progress-bar-info progress-bar-striped active" role="progressbar" data-toggle="tooltip"  title="TCC Customer Contacts" rel="popover" style="width:0%">

	</div>
</div>
<!---end of progress bar code--->

	<div class="content" id="<cfoutput>#chatId#</cfoutput>">
	<cfinclude template="idle_message.cfm">
		<center>
			<a id="chatbutton" class="btn btn-default button">Chat</a>
			<a id="anncbutton" class="btn btn-default button" >Announcements</a>
			<a id="contactbutton" class="btn btn-default button">Contacts <span class="open-contact-counter"></span></a>
			<a id="showicons" class="btn btn-default button">Reference</a>
		</center>
		<cfquery datasource="#application.applicationDatasource#" name="getYourPic">
			SELECT picture_source
			FROM tbl_users
			WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		</cfquery>

		<div class="post-form">
			<center>
				<cfoutput query="getYourPic">
					<img src="#picture_source#" class="shadow-border user"/>
				</cfoutput>

				<cfoutput>
					<form id="chatform" action="chat_store.cfm" method="post" style="display: inline;margin:5px;">
						<input id='instanceId' type="hidden" name="instanceSelected" value="#Session.primary_instance#"/>
						<input name="txt_chatter" class="form-element" style="width: 65%;height:28px;" type="text" id="chatbox" placeholder="Type Message Here...">
						<a class="btn btn-default button" id="postbutton">Post</a>
					</form>
				</cfoutput>

			</center>
		</div>
		<!---show active users in the chat when the screen is small.--->
		<div class="visible-xs">
			<div class="panel-group" id="accordion">
				<div class="panel panel-default">
			    	<div class="panel-heading" style="cursor:pointer;" data-toggle="collapse" data-parent="#accordion" href="#activeUserCollapse">
						<h4 class="panel-title chat-activetitle">Active Users</h4>
				    </div>
				    <div id="activeUserCollapse" class="panel-collapse collapse">
						<div class="panel-body chat-activecons">
							<div class="text-center"><i class="fa fa-spinner fa-spin" style="vertical-align:baseline;"></i> Loading active users</div>
						</div>
					</div>
				</div>
			</div>
		</div>
		<div id="chatarea" class="slider">
			Please <a href='index.cfm'>Click Here</a> to launch the chat.
		</div><!--end chatarea-->
		<div class="slider" id="contactsdiv" style="overflow:visible !important">
			<!---iframe src="load_contacts.cfm"></iframe--->
			<cfinclude template="#application.appPath#/views/contacts/contacts.cfm">
		</div>

		<div class="slider" id="anncdiv">
			<cfinclude template="#application.appPath#/chat/displayannounce.cfm">
		</div>


		<!---fetch icons to draw--->
		<cfquery datasource="#application.applicationDatasource#" name="getEmoticons">
			SELECT match, replacement, file_id
			FROM tbl_chat_replace
			ORDER BY match
		</cfquery>

		<div class="slider" id="iconsdiv">
			<h2 style="margin-bottom:0px;">Add an image to chat:</h2>
			<p style="margin-left:50px;">Click an image to append it to the chat box.</p>
			<div style="margin-left:50px;">
			<cfoutput query="getEmoticons">
				<!---our onclick is in single quotes, so escape any single quotes.--->
				<cfset jsMatch = jsStringFormat(match)>

				<div style="display: inline-block;cursor:pointer;" onclick="putInTextbox('#htmlEditFormat(jsMatch)#')">
					<span class="username" style="display: none;">#match#</span>
					<img src="#application.appPath#/tools/filemanager/get_file.cfm?fileId=#file_id#" class="iconbox" alt="#htmlEditFormat(match)#" title="#htmlEditFormat(match)#" >
				</div>
			</cfoutput>
			</div>
			<div class="clr"></div>
			<cfif hasMasks('Admin')>
				<p style="margin-left:50px;">
				<a href="<cfoutput>#application.appPath#/chat/chat_edit_icons.cfm</cfoutput>" target="_top">Add/Remove Icons</a>
				</p>
			</cfif>
			<h2 style="margin-bottom:0px;">Chat Features</h2>
			<ul class="chat-feature-list">
				<li>Clicking a username in the Active User's list or clicking someone's message in chat will automatically inform that user that you are talking to them.</li>
				<li>If a message contains your username, it will be highlighted. Use this to help grab someone's attention.</li>
				<li>Links to Problem Reports can be quickly created in the form PR#nnnnn. <br/>Example: PR#21086 becomes PR#21086</li>
				<li>A <span style="width:20px;height:10px; background-color:#900;display:inline;border-radius:2px;">&nbsp;&nbsp;&nbsp;&nbsp;</span> block to the right of your icon means you're clocked out.</li>
				<li>A <span style="width:20px;height:10px; background-color:#090;display:inline;border-radius:2px;">&nbsp;&nbsp;&nbsp;&nbsp;</span> block to the right of your icon means you're clocked in.</li>
				<li>A <span style="width:20px;height:10px; background-color:#FF8308;display:inline;border-radius:2px;">&nbsp;&nbsp;&nbsp;&nbsp;</span> block to the right of your icon means you're stepped out.</li>
				<li>A <span style="width:20px;height:10px; background-color:#ffe100;display:inline;border-radius:2px;">&nbsp;&nbsp;&nbsp;&nbsp;</span> block to the right of your icon means you're on break.</li>
				<cfif hasMasks('CS')>
					</ul>
					<h3>Consultant Supervisors only:</h3>
					<ul class="chat-feature-list">

					<li>Click the 'x' after each message to hide it.</li>
					<li>Type 'qaz' anywhere in your message and it will highlight yellow for everyone.</li>
				</cfif>
			</ul>
		</div><!--end iconsdiv-->
	</div>



	<script type="text/javascript">
	firstLoad = 1;
	myHash = 0;
	messageStartCount = 1;
	messageEndCount = 20;
	scrollPosition = 0;
	scrollThreshold = 1000;
	scrollBottomlock = false;
	scrollTopLock = true;


	// Sliding Icons
	$(document).ready(function(){

		$("a#postbutton", "div#<cfoutput>#chatId#</cfoutput>").button().click(function(e){
			//clicking this button submits the form.
			$("#chatform", "div#<cfoutput>#chatId#</cfoutput>").submit();
		})

		$("a#chatbutton", "div#<cfoutput>#chatId#</cfoutput>").button().click(function(e){
			displaySlide("div#chatarea", e.currentTarget);
		});
		$("a#chatbutton", "div#<cfoutput>#chatId#</cfoutput>").addClass("ui-state-focus");//by default chat is selected.

		//when a button, other than post, is clicked, give it focus.
		$("a.button", "div#<cfoutput>#chatId#</cfoutput>").not("#postbutton").click(function(e){
			//remove focus from other buttons.
			$("a.button", "div#<cfoutput>#chatId#</cfoutput>").removeClass("ui-state-focus");
			//focus on this one.
			if(this.id != "#switchButton") {
				$(this).addClass("ui-state-focus");
			}
		});

		$("a#contactbutton", "div#<cfoutput>#chatId#</cfoutput>").button().click(function(e){
			displaySlide("div#contactsdiv", e.currentTarget);
		});

		$('a#showicons', "div#<cfoutput>#chatId#</cfoutput>").button().click(function(e){
			displaySlide("div#iconsdiv", e.currentTarget);
		});
		//clicking an emoticon returns you to the chat.
		$('div#iconsdiv .iconbox', "div#<cfoutput>#chatId#</cfoutput>").click(function(e){
			displaySlide("div#chatarea");
			//highlight the chat button
			$("a.button", "div#<cfoutput>#chatId#</cfoutput>").removeClass("ui-state-focus");
			$("a#chatbutton", "div#<cfoutput>#chatId#</cfoutput>").addClass("ui-state-focus");
		});

		$('a#anncbutton', "div#<cfoutput>#chatId#</cfoutput>").button().click(function(e){
			displaySlide("div#anncdiv", e.currentTarget);
		});

		/*handle hovering over a user's name in the Active Users section.*/
		$(document).on("click", ".chat-activecons a.con", function(e){
			$('#activeUserModal').modal('show');

			$('div#userhover').html("<p>" + $(this).attr('original-title') + "</p>");
			//add a little style to the provided image.
			$('div#userhover img').css({"max-width": "150px", "border": "solid 1px #555"});
		});

		//handle submitting the form.
		$("#chatform", "div#<cfoutput>#chatId#</cfoutput>").submit(function(evt){
			postMessage(evt, $('#instanceId', "div#<cfoutput>#chatId#</cfoutput>").val());
			//if someone submits a message, of course take them back to the chat.
			displaySlide("div#chatarea");
			//highlight the chat button
			$("a.button", "div#<cfoutput>#chatId#</cfoutput>").removeClass("ui-state-focus");
			$("a#chatbutton", "div#<cfoutput>#chatId#</cfoutput>").addClass("ui-state-focus");
		});

		//Load the chat.
		getHash();
		//get active users.
		activeReloader();
		//get announcements.
		getAnnouncements();
		//give chatbox focus
		$('#chatbox').focus();

	});


	function displaySlide(selector, button) {
		if(selector != 'div#switcharea' ) {
			if($(selector).css("display") != "none") selector = "div#chatarea";
		}

		//hide current sliders
		$.when( $(".slider").not(selector).slideUp("slow") ).done(function(){
			if(selector == 'div#switcharea' ) {
				selector = "div#chatarea"
			}
			//with them hidden display the clicked button
			$(selector).slideDown("slow");

			//now handle button highlighting if the button isn't highlighted add the highlighting if it is remove it and highlight the chat button.
			$("a.button").removeClass("ui-state-focus");
			if(selector == "div#chatarea"){
				$("a#chatbutton").addClass("ui-state-focus");
			} else {
				$(button, "div#footer").addClass("ui-state-focus");
			}

		});
	}

	function getHash(doRefresh){
		if(typeof(doRefresh) === 'undefined') doRefresh = 1;//should we run the refresh timer part?

		//before we make the call make sure we know what session we need.
		var instanceId = $('#instanceId', "div#<cfoutput>#chatId#</cfoutput>").val();
		if (instanceId === undefined) instanceId = <cfoutput>#Session.primary_instance#</cfoutput>;//if we didn't get an instanceId from the DOM, provide a default.

		$.ajax({
			type: 'POST',
			url: '<cfoutput>#application.appPath#</cfoutput>/chat/hash.cfm',
			data: { 'instanceSelected': instanceId },
			cache: false,
			success: function(data){
				var tempHash = parseInt(data);
				if(myHash != tempHash){
					if(scrollPosition >= 400) {
						$('#main-content-id').append("<a href='#' class='more-messages header shadow-border'>New Chat Message!</a>")
					} else {
						updateChat();
					}
					myHash = tempHash;
				}
				//update the timestamp to show refresh has been checked.
				var ts = new Date();
				$("#chatUpdateDate").html(ts.toLocaleString());

				//check for updates every 12 seconds.
				if(doRefresh != 0){
					window.setTimeout("getHash();", 12000);
				}
			},
			dataType: 'html',
			error: function(){
				$("#chatarea", "div#<cfoutput>#chatId#</cfoutput>").html("An error occurred, please <a href='index.cfm'>refresh</a> this page.");
			}
		});
	}
	//reach out and grab the most recent itteration of the chat, but you can send a messageStartCount and messageEndCount to pick the range of messages you want
	function updateChat(moreMessage){
		var lastMessage = 0;//our last message says where we should start looking for more chat records.

		if (moreMessage != undefined) {
			messageStartCount = messageStartCount + moreMessage;
			messageEndCount = messageEndCount + moreMessage;

			//if we know how many records we want we're not starting from scratch find our earliest message.
			$("div.chatmess", "div#<cfoutput>#chatId#</cfoutput>").each(function(n){
				lastMessage = $(this).attr("messageId");
			});

		} else {
			messageStartCount = 1;
			messageEndCount = 20;
		}

		//before we blank the chat, stash the active users list so we can re-draw it.


		$.ajax({
			type: 'POST',
			url: '<cfoutput>#application.appPath#</cfoutput>/chat/ajax_chat.cfm',
			 data: {
	        	   		'rowsToFetch': moreMessage,
	        	   		'lastMessage': lastMessage,
	        	   		'instanceSelected': $('#instanceId', "div#<cfoutput>#chatId#</cfoutput>").val()
	        	   },
			cache: false,
			success: function(data){

				//if they just want to see more, append to the current chat
				if (moreMessage != undefined) {
					$(".see-more-button").remove();
					$("#chatarea", "div#<cfoutput>#chatId#</cfoutput>").append(data);
				} else { //redraw the updated chat

					//now redraw the chat.
					$("#chatarea", "div#<cfoutput>#chatId#</cfoutput>").html(data);
				}
				moreMessage = 0;
				// Fade in latest message.
				if(!firstLoad){
					$("#chatarea div.chatmess:first-child", "div#<cfoutput>#chatId#</cfoutput>").hide();
					$("#chatarea div.chatmess:first-child", "div#<cfoutput>#chatId#</cfoutput>").fadeIn(2000);
				}

				//once images load resize them.
				$(".chatmess img.user, .con img", "div#<cfoutput>#chatId#</cfoutput>").each(function(index, ele){
					resizeImage(this, 40,'auto');
				});

				/*what is this doing?
				$(".chatmess img, .con img", "div#<cfoutput>#chatId#</cfoutput>").show();
				*/

				//we've loaded it for future loads fade-in the most recent entry.
				firstLoad = 0;

				if (navigator.appName == "Microsoft Internet Explorer") {
						getActive(<cfoutput>#Session.primary_instance#</cfoutput>); //ridiculous internet explorer bug that doesn't save the active users div
				}

			},
			dataType: 'html',
			error: function(){
				$("#chatarea", "div#<cfoutput>#chatId#</cfoutput>").html("An error occurred, please <a href='index.cfm'>refresh</a> this page.");
			}
		});
	}



	function getAnnouncements(){
		$.ajax({
			type: 'POST',
			url: '<cfoutput>#application.appPath#</cfoutput>/chat/displayannounce.cfm',
			cache: false,
			dataType: 'html',
			success: function(data){
				//redraw our announcements slider.
				$("div#anncdiv", "div#<cfoutput>#chatId#</cfoutput>").html(data);

				anncCnt = $("#announcementCount").html();
				$("a#anncbutton").html("Announcements");
				if(anncCnt > 0){
					$("a#anncbutton").append(" (" + anncCnt + ")");
					$("a#anncbutton").css('color',"#a01410");
				} else {
					$("a#anncbutton").css('color',"#000000");
				}

				//refresh this periodically.
				window.setTimeout("getAnnouncements();", 120000);
			},
			error: function(){
				$("div#anncdiv", "div#<cfoutput>#chatId#</cfoutput>").html("An error occurred fetching announcements, please <a href='index.cfm'>refresh</a> this page.");
			}
		});
	}


	function postMessage(e, instanceSelected){//e is a jQuery event.
		e.preventDefault();//prevents form from submitting.

		//check if our message is valid
		if($.trim($("input[name='txt_chatter']", "div#<cfoutput>#chatId#</cfoutput>").val()) == ""){
			alert("Message cannot be blank.");
		} else {
			var tempHolder = $("input[name='txt_chatter']", "div#<cfoutput>#chatId#</cfoutput>").val();
			<cfoutput>
			$("##chatform").html('<img src="#application.appPath#/images/loading.gif" height="20"  style="margin-left:25%;" alt="loading"/>');
			</cfoutput>
			//submit our users message
			$.ajax({
				type: 'POST',
				url: '<cfoutput>#application.appPath#</cfoutput>/chat/chat_store.cfm',
				data: { 'instanceSelected': instanceSelected },
				cache: false,
				data: {txt_chatter: tempHolder, "instanceSelected": instanceSelected},
				complete: function(){
				$("#chatform").html('<input id="instanceId" type="hidden" name="instanceSelected" value="'+ instanceSelected + '"/><input name="txt_chatter" style="width: 65%;height:28px;" type="text" id="chatbox" placeholder="Type Message Here..."> <a class="button" style="margin:2px 0px 0px 10px" id="postbutton">Post</a>'
					);
					$("a#postbutton", "div#<cfoutput>#chatId#</cfoutput>").button().click(function(e){
						//clicking this button submits the form.
						$("#chatform", "div#<cfoutput>#chatId#</cfoutput>").submit();
					})
				},
				success: function(){
					//if our post worked, redraw the messages pane.
					//using getHash() caused the user to hammer hash.cfm too often.
					getHash(0);//Do NOT reset the timer.

					//remove what we typed
					$("input[name='txt_chatter']", "div#<cfoutput>#chatId#</cfoutput>").val("");
				},
				error: function(){
					alert('Error, could not submit your message.');
				},
				dataType: 'html'
			});
		}
	}

	//hide a particular chat message.
	function hide_msg_confirm(msg_id) {
		//before we make the call make sure we know what session we need.
		var instanceId = $('#instanceId', "div#<cfoutput>#chatId#</cfoutput>").val();
		if (instanceId === undefined) instanceId = <cfoutput>#Session.primary_instance#</cfoutput>;//if we didn't get an instanceId from the DOM, provide a default.

		if (window.confirm('Are you sure you want to hide this message?')) {
			window.location = '<cfoutput>#application.appPath#</cfoutput>/chat/chat_hide.cfm?msgid=' + msg_id + '&instanceSelected=' + instanceId;
		}
	}



	// function hide_all_msg_confirm(){
	//	if (window.confirm('Are you sure you want to ALL messages?')) {
	//		window.location = '<cfoutput>#application.appPath#</cfoutput>/chat/chat_hide.cfm?hideall=1&instanceSelected=' + instanceId;
	//	}
	//}

	function putInTextbox(value) {
		var currentText = $('#chatbox').val();
		$('#chatbox').val(currentText + " " + value + " ");
		$('#chatbox').focus();
	}

	function resizeImage(orig_pic, max_width, max_height){
		var pic = $(orig_pic);

		if(pic.width() < max_width && pic.height() >= max_height){
			pic.height(max_height);
			pic.css("width", "auto");
		}
		if(pic.width() >= max_width && pic.height() < max_height){
			pic.css("height", "auto");
			pic.width(max_width);
		}
		if(pic.width() >= max_width && pic.height() > max_height){
			if(pic.width() / pic.height() > max_width/max_height){
				pic.css("height", "auto");
				pic.width(max_width);
			} else {
				pic.height(max_height);
				pic.css("width", "auto");
			}
		}

	}

	function activeReloader(){
		var instanceId = $('#instanceId', "div#<cfoutput>#chatId#</cfoutput>").val();
		if (instanceId === undefined) instanceId = <cfoutput>#Session.primary_instance#</cfoutput>;//if we didn't get an instanceId from the DOM, provide a default.

		getActive(instanceId);
		window.setTimeout("activeReloader()", 45000);
	}

	function getActive(instanceSelected){

		$.ajax({
			dataType: 'json',
			type: 'POST',
			url: '<cfoutput>#application.appPath#</cfoutput>/chat/displayactive.cfm?instanceSelected='+ instanceSelected,
			async: true,
			cache: false,
			beforeSend: function(){
				//if the div we want to display active users in doesn't exist yet, create it with a loading message.
				//if($("div#activecons", "div#<cfoutput>#chatId#</cfoutput>").length == 0) {
					//$("div#chatarea", "div#<cfoutput>#chatId#</cfoutput>").prepend("<div id='activecons'><center>Loading Active Users<br/><img src='<cfoutput>#application.appPath#/images/loading.gif</cfoutput>'></center></div>");
				//}
			},
			success: function(data){

				$(".panel .chat-activetitle").html( data.length + " Active Users");

				//clear the active users.
				$(".panel .chat-activecons").html("");

				$(data).each(function(n){
					var output = "";

					var profile = "";

					/*if this item has error data draw the error*/
					if(typeof this.error !== 'undefined'){
						output += '<div class="alert alert-danger">ERROR: ' + this.error + '</div>';
						$(".panel .chat-activecons").prepend(output);
						return(1);//we're done with this pass.
					}

					//draw HTML for displaying their short profile first, so we can use it with our general output.
					profile += "<img src='" + this.image +"'/> <br>";
					profile += this.name + " <br> " + this.username;
					//if they've got a profile link, use it.
					if(this.profileLink != "")
						profile += " <br/> <a href='" + this.profileLink + "' target='_blank'>Profile</a>";

					//now a fieldset for every badge they've earned.
					$(this.badges).each(function(i){
						profile += "<fieldset style='padding:0px;display:inline-block;vertical-align:top;width:30px;' title='"+ this.name +"'>";
							profile += "<legend style='float:right;margin:-5px -5px 0px 0px;font-size:50%;line-height:25%;padding:2px;'><strong>"+ this.count +"</strong></legend>";
							profile += "<div style='margin:4px 0px 0px 0px;text-align:center;'><img src='"+ this.imageUrl +"' style='width:30px;vertical-align:top;' /></div>";
						profile += "</fieldset>";
					});


					output += '<div class="list-group-item">';
						output += '<span class="glyphicon glyphicon-comment" style="cursor:context-menu" onclick="putInTextbox(\'' + this.username + '\')" title="Copy username to chat message"></span> ';
						output += '<a class="con" style="cursor:pointer;" data="' + this.username + '" original-title="">';
							//draw their status roundel
							output += '<div style="width:20px;height:10px; background-color:' + this.statusColor + ';display:inline;border-radius:2px;">&nbsp;&nbsp;&nbsp;&nbsp;</div> ';
							//draw their details
							output += '<div class="' + this.userClass + '" style="display:inline;max-width:200px;">';
								output += this.name + ' (' + this.username + ') ';

								//display consultant of semester/month awards.
								if(this.CoS) {
									output += '<span class="tinytext">CoS</span> ';
								}else if(this.CoM){
									output += '<span class="tinytext">CoM</span> ';
								}
							output += '</div>';

							//draw their location
							output += '<div style="display:inline;">' + this.currentShift + ' ' + this.location + '</div>';

						output += '</a>';
					output += '</div>';

					var output = $(output);//make our output into jQuery object we can manipulate.
					$("a.con", output).attr("original-title", profile);

					$(".panel .chat-activecons").append(output);
				});
				<!---
				//hide while redrawing.
				$(".chat-activecons").hide();

				//draw currently active users.
				$(".chat-activecons").html(data);

				//once images load resize them.
				$(".chat-activecons .con img").load(function(index, ele){
					resizeImage(this, 20, 200);
				});

				//with the redraw done, display it.
				$(".chat-activecons").show();
				--->
			}
	});
	}
	</script>


<div class="modal fade bs-example-modal-sm" id="activeUserModal">
     <div class="modal-dialog modal-sm" style="width: 300px;margin: 30px auto;">
         <div class="modal-content" >
             <div class="modal-body" id="">
				<div id="userhover" class="text-center"></div>
             </div>
         </div><!-- /.modal-content -->
     </div><!-- /.modal-dialog -->
 </div><!-- /.modal -->