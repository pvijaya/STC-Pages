<cfsetting showdebugoutput="false">
<cfmodule template="#application.appPath#/header.cfm" title='Contacts Progress bar'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<style type="text/css">
#progressHeader{
	font-family: "sans-serif","monospace";
}
</style>
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
			currentUserTotalCount = $(this).attr('user_TotalCount');
			console.log("each toal count;"+currentUserTotalCount);
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

			//var goal = 98;
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
<cfmodule template="#application.appPath#/footer.cfm">