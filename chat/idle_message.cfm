
<!--- Idle Chat Message--->
<cfif hasMasks('admin') EQ false>
		<script>
		var idleTime = 900000; //Currently 1 sec (15 min = 900000) in milliseconds 
		setInterval("showIdleMessage()",idleTime);
		var active = false;
		//fade in message slowly
		function showIdleMessage()
		{
			if(active == false) {
				$(".doWalkaround").fadeIn('1200');
			} else if(active == true) {
				active = false;	
			}
		}
	
		//restart timer 
		function clearScreen()
		{
			$(".doWalkaround").css("display", "none");	
		}
		//after clicking no send to contacts
		function hadContacts()
		{
			//hide all other sliders
			$("div.slider").not("#contactsdiv").slideUp();
			//show/hide our desired div
			$("#contactsdiv").slideToggle();
			clearScreen();
		}
		
		$('html').click(function() {
			active = true;
		});
		</script>
		<div class="doWalkaround" style="display:none; position:absolute; top:0px; left:0px; z-index:1000; width:100%; height:100%; background-color:#FFFFFF; text-align:center; font-size:18px; color:#7D120C;">
			<br/><br/><br/><br/><br/>
			<cfoutput>
			<img src="#application.appPath#/images/tcc_logo_big.jpg" alt="TCC" width="380" height="212" />
			</cfoutput>
			
			<h2>
			  Please do your 15 minute walkaround.
			</h2>
	        <h2>
	        Did you have any customer contacts?
	        </h2>
			<br/>
			
		  	<input onclick="hadContacts();" style=" width:150px; height:50px; font-size:36px; cursor:pointer;" id="goAwayButton" name="goAway" type="button" value="Yes" />
	      	<input onclick="clearScreen();" style=" width:150px; height:50px; font-size:36px; cursor:pointer;" id="goAwayButton2" name="goAway2" type="button" value="No" />
		</div>
</cfif>
<!--- End Idle Chat Message--->