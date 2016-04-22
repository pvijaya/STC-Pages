<cfmodule template="#application.appPath#/header.cfm" title='Bar Graph' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/modules/inc_d3_graphs.cfm">

<!--- import d3 library --->
<script src="<cfoutput>#application.appPath#</cfoutput>/js/d3.v3.min.js"></script>

<cfset vals = "8,22,30,10,101">
<cfset vals2 = "15,20,23,2,18">

<cfset valueArray = ArrayNew(1)>
<cfset valueArray2 = ArrayNew(1)>

<cfloop list="#vals#" index="n">
	
	<!--- we need to make the structure to append to the array. 
	<cfset inventory = structNew()>
	<cfset inventory['itemName'] = item_name>
	<cfset inventory['quantity'] = quantity>
	--->
	
	<!--->	<cfset inventory = quantity> --->

	<cfset value = StructNew()>
	<cfset value['item'] = "Item#n#">
	<cfset value['quantity'] = n>

	<cfset arrayAppend(valueArray, value)>
	
</cfloop>

<cfloop list="#vals2#" index="n">
	
	<!--- we need to make the structure to append to the array. 
	<cfset inventory = structNew()>
	<cfset inventory['itemName'] = item_name>
	<cfset inventory['quantity'] = quantity>
	--->
	
	<!--->	<cfset inventory = quantity> --->

	<cfset value = StructNew()>
	<cfset value['item'] = "Item#n#">
	<cfset value['quantity'] = n>

	<cfset arrayAppend(valueArray2, value)>
	
</cfloop>

<h2>Example Chart</h2>
<div id="barGraph"></div>

<br/><br/><br/>

<div id="barGraph2"></div>

<script type="text/javascript">

	var data = <cfoutput>#serializeJSON(valueArray)#</cfoutput>;
	var data2 = <cfoutput>#serializeJSON(valueArray2)#</cfoutput>

	var x = new d3BarGraph();
	x.init("div#barGraph", 800, data);
	x.draw();
	
	colorFunction = function(d) {
		if (d['quantity'] < 5)
			return 'red';
		else
			return 'green';
	}
	
	var y = new d3BarGraph();
	y.setColor(colorFunction);
	y.init("div#barGraph2", 800, data2);
	y.draw();

</script>

<!--->
<!--- cfparams --->
<cfparam name="frmLabId" type="string" default="i0l0">
<cfparam name="inventoryId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">

<cfset inventoryArray = ArrayNew(1)>

<h1>Inventory Graphs</h1>

<span class="trigger<cfif frmLabId EQ "i0l0">expanded</cfif>">Lab Selector</span>
<div>
	<fieldset>
		<legend>Choose</legend>
		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
			<cfset drawLabsSelector("frmLabId", frmLabId)>
			<input type="submit" name="frmAction" value="Go">
		</form>
	</fieldset>
</div>

<cfif frmLabId NEQ "i0l0">
	
	<cfset labStruct = parseLabName(frmLabId)>
	
	<cfquery datasource="#application.applicationDataSource#" name="getSubmission">
		SELECT TOP 1 isub.submission_id
		FROM tbl_inventory_submissions isub
		WHERE isub.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['lab']#">
			  AND isub.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labStruct['instance']#">
		ORDER BY isub.submitted_date DESC
	</cfquery>
	
	<cfif getSubmission.recordCount GT 0>
		
		<cfset inventoryId = getSubmission.submission_id>
	
		<cfquery datasource="#application.applicationDataSource#" name="getInventoryData">
			SELECT isi.quantity, ii.item_name, l.lab_name, isub.submitted_date, isti.warn_level, isti.critical_level
			FROM tbl_inventory_submissions isub
			INNER JOIN tbl_inventory_submission_items isi ON isi.submission_id = isub.submission_id
			INNER JOIN tbl_inventory_items ii ON ii.item_id = isi.item_id
			INNER JOIN tbl_inventory_site_items isti ON isti.item_id = isi.item_id 
													    AND isti.lab_id = isub.lab_id 
													    AND isti.instance_id = isub.instance_id
			INNER JOIN vi_labs l ON l.lab_id = isub.lab_id AND l.instance_id = isub.instance_id
			WHERE isub.submission_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#inventoryId#">
				  AND isub.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		</cfquery>
		
		<cfset labName = getInventoryData.lab_name>
		<cfset date = getInventoryData.submitted_date>
		
		<cfloop query="getInventoryData">
			
			<!--- we need to make the structure to append to the array. 
			<cfset inventory = structNew()>
			<cfset inventory['itemName'] = item_name>
			<cfset inventory['quantity'] = quantity>
			--->
			
		<!--->	<cfset inventory = quantity> --->
		
			<cfset inventory = StructNew()>
			<cfset inventory['item'] = item_name>
			<cfset inventory['quantity'] = quantity>
			<cfset inventory['warn'] = warn_level>
			<cfset inventory['crit'] = critical_level>
		
			<cfset arrayAppend(inventoryArray, inventory)>
			
		</cfloop>
		
		<!--- HTML --->
		<h2>Inventory For <cfoutput>#labName# On #dateTimeFormat(date, 'mmm dd yyyy, hh:nn tt')#</cfoutput></h2>
		<svg></svg>
	
	<cfelse>
	
		<br/>
		No inventory data found. :(
		
	</cfif>
	
</cfif>

<style type="text/css">

	.axis path,
	.axis line {
		fill: none;
		stroke: black;
		shape-rendering: crispEdges;
	}
	
	.axis text {
		font-family: sans-serif;
		font-size: 11px;
	}

</style>

<script type="text/javascript">
	
	/* this is the 'long' way of writing the bit at the bottom
	var chart = d3.select('.chart');
	var bar = chart.selectAll('div'); define selection to which we will join data 
	var barUpdate = bar.data(data);   join the data to the selection
	var barEnter = barUpdate.enter().append('div'); /* instantiate missing elements 
	barEnter.style('width', function(d) { return x(d) + 'px'; });
	barEnter.text(function(d) {return d; });
	
	var data = [4, 8, 15, 16, 23, 42];
	
	a function used to make dependencies explicit 
	var x = d3.scale.linear()
		.domain([0, d3.max(data)])
		.range([0, 420]); 420 = desired chart width 
	
	d3.select('.chart')
		.selectAll('div')
	  		.data(data)
		.enter().append('div')
			.style('width', function(d) { return x(d) + 'px'; })
			.text(function(d) { return d; });
	
	*/

	var dataset = <cfoutput>#serializeJSON(inventoryArray)#</cfoutput>;

	console.log(dataset);

	var bar_padding = 2;
	var max_bar_h = 20;
	var padding = 20;
	var font_size = 12;
	var min_bar_x = d3.max(dataset, function(d) { return d['item'].length });
	min_bar_x = min_bar_x * (font_size / 2);
	
	var w = 800;
	var h = dataset.length * (max_bar_h + bar_padding) + (padding * 2);
	
	var bar_height = h / dataset.length;
	if (bar_height > max_bar_h)
		bar_height = max_bar_h;
		
	console.log(bar_height);
	
	var scale = d3.scale.linear()
		      .domain([0, d3.max(dataset, function(d) { return d['quantity']; })])
		      .range([0, w - min_bar_x - 50]);
	
	var xAxis = d3.svg.axis()
				  .scale(scale)
				  .orient('bottom');
	
	var chart = d3.select('svg')
				  .attr('class', 'chart')
				  .attr('width', w)
				  .attr('height', h);
				  
	var bars = chart.selectAll('rect')
			      .data(dataset)
			      .enter().append('rect');
			      
	bars.attr('y', function(d, i) {
			return ((bar_height + bar_padding) * i) + 1;
	    })
		.attr('x', min_bar_x)
		.attr('height', function() {
			return bar_height;
		})
		.attr('width', function(d) { 
			return scale(d['quantity']) + 'px'; 
		})
		.attr('fill', function(d) {
			var q = d['quantity'];
			if(q <= d['crit'])
				return 'red';
			else if(q <= d['warn'])
				return 'yellow';
			else
				return 'green';
		})
		.attr('stroke', 'black');
		
	var numbers = chart.selectAll('text.number')
		.data(dataset)
		.enter().append('text')
		.attr('class', 'number')
		.text(function(d) {
			return d['quantity'];
		})
		.attr('y', function(d, i) {
			return ((bar_height + bar_padding) * i) + (bar_height + 4) - (bar_height / 2) + 1;
		})
		.attr('x', function(d) {
			return scale(d['quantity']) + 10 + min_bar_x;
		})
		.attr('fill', 'black')
		.attr('font-family', 'sans-serif')
		.attr('font-size', '12px');	 

	var labels = chart.selectAll('text.label')
		.data(dataset)
		.enter().append('text')
		.attr('class', 'label')
		.text(function(d) {
			return d['item'];
		})
		.attr('y', function(d, i) {
			return ((bar_height + bar_padding) * i) + (bar_height + 4) - (bar_height / 2) + 1;
		})
		.attr('x', 0)
		.attr('fill', function(d) {
			var q = d['quantity'];
			if(q <= d['crit'])
				return 'red';
			else if(q <= d['warn'])
				return 'yellow';
			else
				return 'black';
		})
		.attr('font-size', '12px');

	chart.append('g')
		 .attr('class', 'axis')
		 .attr('transform', 'translate('+ min_bar_x + ',' + (dataset.length * (bar_height + bar_padding) + padding) + ')')
	     .call(xAxis);
	 
	     
		
	/*
	$.ajax({
		dataType: "json",
		url: "d3-bar-graph-data.cfm",
		async: false,
		success: function(data){
			dataset = data;
		}
	});
	*/	
		
</script>

--->