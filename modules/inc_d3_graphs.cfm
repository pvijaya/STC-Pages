<!---
	This script is used inside a cfinclude to:
	* Include the D3JS library
	* Add a script tag filled with constructors for building several types of charts/graphs
	* a style tag to skin the graphs to our liking.
--->

<!---bring in the D3 library--->
<script src="<cfoutput>#application.appPath#</cfoutput>/js/d3.v3.min.js"></script>

<!---Style for elements of our graphs.--->
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

	svg.d3line {
		height: 100%;
		width: 100%;
	}

	svg.d3line .xaxis{
	    fill:none;
	    stroke:gray;
	    font-size: 0.75em;
	}

	svg.d3line path.line {
		stroke: black;
		stroke-width: 1.5px;
		stroke-opacity: 0.8;
		fill: none;
	}

	svg.d3line circle.line {
		stroke: black;
		fill-opacity: 0.8;
	}

	svg.d3line .tip {
		font-size: 10px;
		font-family: monospace;
	}

	svg.d3line .yaxis{
	    fill:none;
	    stroke:gray;
	    font-size: 0.75em;
	}

</style>

<script type="text/javascript">

	/* interactive force layout */
	d3Force = function() {

		/* assumes dataset is a structure containing two arrays:
		*  nodes: an array of structures with attribute 'id'
		*  edges: an array of structures with attributes 'source' and 'target'
		*         corresponding to indices of 'nodes' */

		var rcg = new randomColorGenerator();

		this.container = "";
		this.svg = "";
		this.dataset = [];

		this.url = "<cfoutput>#application.appPath#</cfoutput>/tools/contacts/view-contact.cfm";

		this.w = 800;
		this.h = 500;
		this.charge = -200;
		this.linkDistance = 75;
		this.r = 20;

		this.init = function(container, d) {

			this.container = container;
			this.dataset = d;

			/* ensure our container is big enough for the graph */
			$(this.container)
				.css('width', this.w)
				.css('height', this.h);

			/* create the svg within the specified container */
			this.svg = d3.select(container)
						  	.append('svg')
						 	.attr('class', 'd3force')
						 	.attr('width', this.w)
						  	.attr('height', this.h);

		}

		this.draw = function() {

			/* local variables */
			var dataset = this.dataset;
			w = this.w;
			h = this.h;
			svg = this.svg;
			url = this.url;
			charge = this.charge;
			linkDistance = this.linkDistance;
			r = this.r;

			/* create a force object */
			var force = d3.layout.force()
				.nodes(dataset.nodes)
				.links(dataset.edges)
				.size([w, h])
				.linkDistance([linkDistance]) /* increases line length */
				.charge([charge]) /* circles repel each other more strongly */
				.start();

			/* create edges */
			var edges = svg.selectAll("line")
				.data(dataset.edges)
				.enter()
				.append("line")
				.style("stroke", "#ccc")
				.style("stroke-width", 1);

			/* create nodes - contain circles */
			var nodes = svg.selectAll(".node")
				.data(dataset.nodes)
				.enter().append("svg:g")
					.attr("class", "node")
					.attr("id", function(d) { return d.id; })
					.call(force.drag);

			/* create circles */
			var circles = nodes.append("circle")
				.attr("r", r)
				.style("fill", function(d) { return rcg.getColor(); });

			/* create tooltips - contain rectangles and text links */
			/* **the rect shape and text have to be made seperately** */
			/* tooltips are appended after nodes so that the tooltip can't get covered up
			 *   by circles when it is made visible*/
			var tooltips = svg.selectAll(".d3Tooltip")
				.data(dataset.nodes) // shares data and location with nodes
				.enter().append("svg:g")
					.attr("class", "d3Tooltip")
					.attr("id", function(d) { return d.id; })
					.style("display", "none"); // prevent invisible rects from blocking circle clicks

			/* create rectangles */
			tooltips.append("svg:rect")
				.attr("width", "100px")
				.attr("height", "2em")
				.attr("stroke", "black")
				.attr("fill", "white");

			/* create svg a tags */
			tooltips.append("svg:a")
				.attr("class", "contactLink")
				.attr("xlink:href", function(d) {
					return url + "?contactId=" + d.id; // build url
				})
				.attr("contactId", function(d) { return d.id; });

			var text = svg.selectAll(".contactLink");

			/* create text */
			text.append("text")
				.attr("x", "20px") // offset right a bit
				.attr("y", "20px") // offset down (otherwise text appears above rectangle)
				.attr("width", "80px")
				.attr("height", "2em")
				.text(function(d) { return d.id })
				.style("text-align", "center");

			/* add mouseover events to draw titles for our points */
			d3.selectAll("circle")
				.on('click', function(d) {

					if(d3.event.defaultPrevented) return; // ignore drag clicks

					// hide all rectangles //
					svg.selectAll(".d3Tooltip")
						.style("display", "none");

					var myNode = d3.select(this.parentNode);

					// find the tooltip with the same id as the clicked node
					var myTooltip = d3.selectAll(".d3Tooltip")
						.filter(function(d) { return d.id == myNode.attr("id") });

					myTooltip.style("display", "initial");

					d3.event.stopPropagation(); // stop this click from triggering other click events

				})
				// this bit darkens the bubbles when they are hovered over
				.on("mouseover", function() {
					if((r = $(this).css("fill").match(/(\d+),\s*(\d+),\s*(\d+)/i))) {
				        for(var i = 1; i < 4; i++) {
				            r[i] = Math.round(r[i] * .5);
				        }
				        $(this).attr("fill-old", $(this).css("fill"));
				        $(this).css("fill", 'rgb('+r[1]+','+r[2]+','+r[3]+')');
				    }
				})
				.on("mouseout", function() {
					if($(this).attr("fill-old")) $(this).css("fill", $(this).attr("fill-old"));
				});

			d3.select(".d3force")
				.on('click', function(d) {

					if(d3.event.defaultPrevented) return; // ignore drag clicks

					// clicking anywhere other than a circle hides all tooltips
					svg.selectAll(".d3Tooltip")
						.style("display", "none");

				});

			/* adjust element positions over time */
			force.on("tick", function() {
				edges.attr("x1", function(d) { return d.source.x; })
					 .attr("y1", function(d) { return d.source.y; })
					 .attr("x2", function(d) { return d.target.x; })
					 .attr("y2", function(d) { return d.target.y; });
				nodes.attr("transform", function(d) {
					return "translate(" + d.x  + "," + d.y + ")";
				});
				tooltips.attr("transform", function(d) {
					return "translate(" + d.x  + "," + d.y + ")";
				});

			});

		}

	}

	/* horizontal bar graph */
	d3BarGraph = function() {

		/* assumes dataset is an array containing structures where:
		 * item : string item name
		 * quantity: integer item value */

		var rcg = new randomColorGenerator();

		/* variable defaults */
		this.bar_padding = 5;
		this.max_bar_h = 20;
		this.padding = 20;
		this.font_size = 12;
		this.min_bar_x = 0;
		this.bar_color = function(d) { return rcg.getColor() };
		this.w = 800;
		this.h = 500;
		this.dataset = [];
		this.scale = "";
		this.xAxis = "";
		this.svg = "";
		this.bars = "";
		this.container = "";
		this.number_padding = "";

		/* since providing a custom color function is optional, it has its own function */
		/* color should be a function with argument d */
		this.setColor = function(color) {
			this.bar_color = color;
		}

		/* initialization function */
		this.init = function(container, w, d) {

			/* set variables based on inputs */
			this.container = container;
			this.dataset = d;
			this.w = w;
			/* when drawing labels, we retrieve the max string length and estimate the pixel count */
			this.min_bar_x = d3.max(this.dataset, function(d) { return d['item'].length });
			this.min_bar_x = (this.min_bar_x * (this.font_size / 1.5));
			this.number_padding = d3.max(this.dataset, function(d) { return d['quantity'].toString().length });
			this.number_padding = (this.number_padding * this.font_size);
			this.h = this.dataset.length * (this.max_bar_h + this.bar_padding) + (this.padding * 2);

			/* if bar_height exceeds a certain value, cap it */
			/* this lets us space out the bars evenly within the desire height,
			*  but keeps them from getting too large */
			this.bar_height = this.h / this.dataset.length;
			if (this.bar_height > this.max_bar_h)
				this.bar_height = this.max_bar_h;

			/* ensure our container is big enough for the graph */
			$(this.container)
				.css('width', this.w)
				.css('height', this.h)

			/* create the svg within the specified container */
			this.svg = d3.select(this.container)
						  	.append('svg')
						 	.attr('class', 'd3bar')
						 	.attr('width', w)
						  	.attr('height', this.h);

			/* establish our bars based on this.dataset */
			this.bars = this.svg.selectAll('rect')
					      	.data(this.dataset)
					      	.enter().append('rect');

			/* set scale and xAxis */
			this.scale = d3.scale.linear()
		      				.domain([0, d3.max(this.dataset, function(d) { return d['quantity']; })])
		    				.range([0, w - this.min_bar_x - this.number_padding]);

			this.xAxis = d3.svg.axis()
							.scale(this.scale)
							.orient('bottom');

		}

		/* draw function */
		this.draw = function() {

			/* local variables - within functions, d3 gets confused by 'this' variables */
			scale = this.scale;
			bar_height = this.bar_height;
			bar_padding = this.bar_padding;
			min_bar_x = this.min_bar_x;
			dataset = this.dataset;

			/* draw the bars */
			this.bars.attr('y', function(d, i) {
					return ((bar_height + bar_padding) * i) + 1;
			    })
				.attr('x', this.min_bar_x)
				.attr('height', this.bar_height)
				.attr('width', function(d) {
					return scale(d['quantity']) + 'px';
				})
				.attr('fill', this.bar_color)
				.attr('stroke', 'black');

			/* draw the numbers that appear to the right of each bar */
			var numbers = this.svg.selectAll('text.number')
				.data(this.dataset)
				.enter().append('text')
				.attr('class', 'number')
				.text(function(d) {
					return d['quantity'];
				})
				.attr('y', function(d, i) {
					return ((bar_height + bar_padding) * i) + (bar_height + bar_padding) - (bar_height / 2) + 1;
				})
				.attr('x', function(d) {
					return scale(d['quantity']) + bar_padding + min_bar_x;
				})
				.attr('fill', 'black')
				.attr('font-family', 'sans-serif')
				.attr('font-size', '12px');

			/* draw the labels that appear on y-axis */
			var labels = this.svg.selectAll('text.label')
				.data(this.dataset)
				.enter().append('text')
				.attr('class', 'label')
				.text(function(d) {
					return d['item'];
				})
				.attr('y', function(d, i) {
					return ((bar_height + bar_padding) * i) + (bar_height + 4) - (bar_height / 2) + 1;
				})
				.attr('x', 0)
				.attr('fill', 'black')
				.attr('font-size', '12px');

			/* draw the axis */
			this.svg.append('g')
				 .attr('class', 'axis')
				 .attr('transform', 'translate('+ this.min_bar_x + ',' + (this.dataset.length * (this.bar_height + this.bar_padding) + this.padding) + ')')
			     .call(this.xAxis);

		}

	}

	/*a constructor for making D3js line charts*/
	d3LineChart = function() {
		/*first set defaults for our variables*/
		this.container = "#chart";
		this.canvasWidth = 100;
		this.canvasHeight = 100;
		this.data = [];
		this.lines = [];/*the names variables in the data that represent the numbers we want to graph*/

		this.svg = "";
		//this.time_scale = "";
		//this.y_scale = "";
		this.xAxis = "";
		this.yAxis = "";

		this.legendPadding = 0;

		/*our init method simply sets the initial values for our line graph.*/
		this.init = function(cont, w, h, d, l) {
			this.container = cont;
			this.canvasWidth = w;
			this.canvasHeight = h;
			this.data = d;

			/*lines is a little special, it's an array of the variable names we want to graph.  If it's an empty array we graph everything that isn't the date in the objects we got from data*/
			if(l instanceof Array){
				this.updateLines(l)

			} else {
				this.updateLines([])
			}


			/* make sure our containing div is large enough for what we're going to draw*/
			$(this.container)
				.css("width", this.canvasWidth)
				.css("height", this.canvasHeight);

			/*create the svg we're going to draw in. give it the class d3line for use with our css.*/
			this.svg = d3.select(this.container).append("svg").attr("class", "d3line");

			/*make sure our svg is the right size
			this.svg
				.style("width", this.canvasWidth)
				.style("height", this.canvasHeight);
			*/
			/*having initiated these values invoke the draw() method*/
			//this.draw();
		},

		this.updateLines = function(useLines){
			var newLines = new Array();
			var rcg = new randomColorGenerator();/*used for generating colors of graph elements*/

			for(var n in useLines) {
				newLines.push({"name": useLines[n], "color": rcg.getColor()});
			}

			/*if they didn't provide any particular items to be graphed, graph everything that isn't the date*/
			if(newLines.length == 0 && this.data.length > 0){
				for(var k in this.data[0]){
					if(k != 'Date')	newLines.push({name: k, color: rcg.getColor()});
				}
			}

			//now that we've built-up newLines replace our this.lines with it.
			this.lines = newLines;
		}


		/*Sanitize the data before trying to draw it, add missing zero levels if we need to.*/
		this.sanitizeData = function(){
			//for any lines that don't show up in a data entry add it as a zero.
			for(var x in this.data){
				for(var l in this.lines){
					var line = this.lines[l]

					if(typeof this.data[x][line.name] === 'undefined'){
						this.data[x][line.name] = 0;
					}
				}
			}
		}

		/*this method will draw the intital svg canvas, and attempt to set everything up.*/
		this.draw = function(){

			//before we can even consider drawing we must know that our data is complete.
			this.sanitizeData();

			var localSvg = this.svg;

			//if this isn't our first time through clear out existing circles and lines.
			this.svg.selectAll("circle.line").remove();
			this.svg.selectAll("path.line").remove();

			//Start by drawing our legend, so we know how much we need to pad the y axis.
			this.drawLegend();

			/*before we can really do anything terribly useful we need to determine our "scales" for drawing stuff to the correct size.*/
			var time_scale = d3.time.scale()
				.domain([
					new Date(d3.min(this.data, function(d){return d.Date})),
					new Date(d3.max(this.data, function(d){return d.Date}))
				])
				.range([45,(this.canvasWidth - 45)]);/*this range leaves room for our axes*/

			/*building the y axis scale is a little harder, we need to find the max(and min) value out of all our this.lines items we want to graph*/
			var curMin = 0;
			var curMax = 1;

			for(var n in this.lines) {
				var myMax = this.max(this.lines[n].name);

				if(myMax > curMax) curMax = myMax;
			}

			var y_scale = d3.scale.linear()
				.domain([0, curMax])
				.range([this.canvasHeight - 20, this.legendPadding]);/*this looks a little backwards, but max to min works best for the y axis - this is where the 0 of the y axis starts, remove the same amount when drawing the x axis below*/


			/*using the scales we just create, we can also generate axes to label the graph with*/
			this.xAxis = d3.svg.axis().scale(time_scale);
			this.yAxis = d3.svg.axis().scale(y_scale).orient("left");


			/*now, loop over all the lines we want to draw*/
			for(var n in this.lines){
				var lineName = this.lines[n].name;

				//add a group to keep all our line's data together
				if(typeof this.lines[n].group === 'undefined')
					this.lines[n].group = this.svg.append("svg:g").attr("transform", "translate(0,0)");

				/*now have d3 plot the location of our number as circles, this accentuates things.*/
				this.lines[n].circles = this.lines[n].group.selectAll("circle")
					.data(this.data)


				//remove logic
				this.lines[n].circles.exit()
					.remove()

				//enter logic
				this.lines[n].circles.enter()
					.append("circle")
					.attr("class", "line")
					.attr("line-name", lineName)
					.attr("cx", function(d){return time_scale( new Date(d["Date"]));})
					.attr("cy", function(d){return y_scale(0)})
					.attr("r", 3.5)
					.style("fill", this.lines[n].color)
					.style("opacity", 0)
					.transition().duration(1000)//some animations to transition in with
						.attr("cy", function(d){return y_scale(d[lineName])})
						.style("opacity", 0.8)


				//now draw the line that connects our dots add a line for our contacts so it's easier to read
				var cLine = d3.svg.line()
					.x( function(d) { return time_scale( new Date(d["Date"]) ) })
					.y( function(d) { return y_scale(d[lineName]) } )

				this.lines[n].line = this.lines[n].group.append("path")
					.attr("class", "line")
					.attr("id", lineName)
					//.attr("d", "M45," + (this.canvasHeight - 20) + "," + (this.canvasWidth) + "," + (this.canvasHeight - 20)  )
					.attr("d", cLine(this.data))
					.style("opacity", 0)

				this.lines[n].line
					.transition().duration(2000)
					.style("opacity", 1)



			}/*end of drawing lines and circles*/

			/*add mouseover events to draw titles for out points*/
			d3.selectAll("circle.line")
				.on('mouseover', function(d){

					var myX = parseFloat($(this).attr("cx"));
					var myY = parseFloat($(this).attr("cy"));
					var myType = $(this).attr("line-name");

					var tGroup = localSvg.append("svg:g")
						.attr("transform", "translate("+ (myX + 8) +", " + (myY) + ")")
						.attr("class", "tip")

					var hoverText = (d[myType] + " " + myType );
					var theDate = new Date(d["Date"]);

					var dateText = theDate.getFullYear() + "/" + (theDate.getMonth() + 1) + "/" + theDate.getDate() + " " + ((theDate.getHours() > 10) ? "" : "0") + theDate.getHours() + ":" + ((theDate.getMinutes() > 9) ? "" : "0") + theDate.getMinutes();

					tGroup.append("svg:rect")
						.attr("x", 0)
						.attr("y", 0)
						.attr("width", (((hoverText.length > dateText.length) ? hoverText.length : dateText.length) * 7) + "px")
						.attr("height", "2.5em")
						.style("stroke", "black")
						.style("fill", "white")

					tGroup.append("text")
						.attr("x", 0)
						.attr("y", 0)
						.attr("dx", 5)
						.attr("dy", "1em")
						.text(hoverText)

					tGroup.append("text")
						.attr("x", 0)
						.attr("y", 0)
						.attr("dx", 5)
						.attr("dy", "2em")
						.text(dateText)
				})
				.on('mouseout', function(d){
					d3.selectAll(".tip").remove()
				})


			/*remove any existing axis so we can draw fresh ones*/
			var selX = this.svg.select("g.xaxis").remove();
			var selY = this.svg.select("g.yaxis").remove();

			/*now draw the groups for out axes*/
			this.svg.append("g")
				.attr("class", "xaxis")
				.attr("transform", "translate(0," + (this.canvasHeight - 20) + ")")//that's the same 20px we shaved off when setup up the y axis' range.
				.call(this.xAxis)

			this.svg.append("g")
				.attr("class", "yaxis")
				.attr("transform", "translate(45,0)")//This is the same 45px we left off when setting up the time_scale range.
				.call(this.yAxis)

		}

		/*finds the maximum value in our data for a given line*/
		this.max = function(lineName){
			var curMax = 1;

			for(var d in this.data){
				if(this.data[d][lineName] > curMax) curMax = this.data[d][lineName];
			}

			return curMax;
		}

		/*finds the minimum value in our data for a given line*/
		this.min = function(lineName, max){
			var curMin = max;

			for(var d in this.data){
				if(this.data[d][lineName] < curMin) curMin = this.data[d][lineName];
			}

			return curMin;
		}

		this.drawLegend = function(){
			/*for line charts we want our legend at the top of the page*/

			//first remove any existing legends.
			this.svg.selectAll("g.legend").remove();

			var lGroup = this.svg.append("svg:g")
				.attr("class", "legend")
				.attr("transform", "translate(45,0)");//this is space for the y-axis, and then drawing from the top

			var legendItemWidth = 150;
			var legendItemHeight = 12;//determines the height and default font size for all legend items
			var legendSpacing = 5;

			//curX and curY help us keep track of where we last drew, and if we need to start a new line.
			var curX = legendSpacing;
			var curY = legendSpacing;

			/*loop over all our lines and figure out to draw them*/
			for(var n in this.lines){
				lGroup.append("rect")
					.attr("x", curX)
					.attr("y", curY)
					.attr("width", legendItemHeight)
					.attr("height", legendItemHeight)
					.style("fill", this.lines[n].color);

				//to draw legend items correctly we need a few things.  We have to use a monospaced font so we can calculate the maximum font-size we can use.
				//by default we'll want to use one matching legendItemHeight, but if the item has too many characters to fit in the remaining space we need to use a lower one.
				var fSize = legendItemHeight;
				var charRatio = 0.625;//this is funky but font-sizes in CSS specify height, so we need to use a monospace font and find the ratio of how wide those fonts are vs. their height.
				var remainingSpace = legendItemWidth - legendItemHeight - legendSpacing;

				//console.log(remainingSpace + " vs. " + (this.lines[n].name.length * (legendItemHeight * charRatio)) + " vs. " + (remainingSpace/this.lines[n].name.length) + " : " + (legendItemHeight * charRatio));

				if(this.lines[n].name.length * (legendItemHeight * charRatio) > remainingSpace){
					fSize = (remainingSpace/this.lines[n].name.length) / charRatio;
				}

				//console.log(fSize);

				lGroup.append("text")
					.attr("x", curX + legendItemHeight + legendSpacing)//this takes into account what we've already drawn and the space we should allow
					.attr("y", curY)
					.attr("dx", 0)
					.attr("dy", legendItemHeight)//draw the text in-line with our rect.
					.style("font-family", "monospace")
					.style("font-size", fSize + 'px')
					.text(this.lines[n].name)

				//now get curX and CurY ready for their next pass.
				curX = curX + legendItemWidth + legendSpacing;
				//if our new value of curX would result in drawing off the canvas, start a new line.
				if(curX > this.canvasWidth - legendItemWidth) {
					curX = legendSpacing;
					curY = curY + legendItemHeight + legendSpacing;
				}
			}

			//now that we've drawn all that we need to update this.legendPadding so we don't let our y axis reach that high.
			this.legendPadding = curY + legendItemHeight;
		}

		/*a method for spitting out what we know about our work.*/
		this.debug = function(){
			console.log(this.container);
			console.log(this.canvasWidth);
			console.log(this.canvasHeight);
			console.log(this.lines);
			//console.log(this.data);

		}
	}/*end of line chart object*/

	d3SunBurst = function() {
		/*first set defaults for our variables*/
		this.container = "#chart";
		this.canvasWidth = 100;
		this.canvasHeight = 100;
		this.data = [];
		this.selectedItem = null;

		this.svg = "";
		//this.time_scale = "";
		//this.y_scale = "";
		this.xAxis = "";
		this.yAxis = "";

		this.legendPadding = 0;

		this.rcg = new randomColorGenerator();/*used for generating colors of graph elements*/

		/*our init method simply sets the initial values for our line graph.*/
		this.init = function(cont, w, h, d) {
			this.container = cont;
			this.canvasWidth = w;
			this.canvasHeight = h;
			this.data = d;
			/*having initiated these values invoke the draw() method*/
			this.draw();
		},


		 /*this method will draw the intital svg canvas, and attempt to set everything up.*/
		this.draw = function(){
			var classObject = this;
			$(classObject.container)
				.css("width", this.canvasWidth)
				.css("height", this.canvasHeight);

	 		var height = this.canvasHeight;
	 		var width = this.canvasWidth;

			function getPercentValue(d) {
				var percentage = (100 * d.value /d.parent.value).toPrecision(4);
				var percentageString = percentage + "%";
				if (percentage < 0.1) {
				  percentageString = "< 0.1%";
				}
				return percentageString;
			}

			function mouseOver(d) {
				d3.select(this)
					.style("cursor", "pointer")
				//update middle text
				percentageString = getPercentValue(d);
				d3.select("#middleText").text(percentageString);

				//make everything more transparent
				d3.selectAll("path")
					.style("opacity", 0.2);

				//show our "path"
				var breadcrumbs = [];
				var path = [];
				var current = d;
				while (current.parent) {
					path.unshift(current);
					current.percent = d.value /d.parent.value;
					breadcrumbs.push(current);
					current = current.parent;
				}
				var sequenceArray = path;

				classObject.svg.selectAll("path")
				.filter(function(node) {
					return (sequenceArray.indexOf(node) >= 0);
				})
				.style("opacity", 1);

				//and draw update the breadcrumbs
				var offset = 0;
				var blockWidth = 0;
				var blockHeight = classObject.canvasHeight *.1;
				var arrowWidth = 8;
				var fontSize = 16;
				var fontWidth = fontSize * .6;
				d3.select("#breadcrumbs").selectAll("path").remove();
				//draw each breadcrumb label
				for(var a = breadcrumbs.length - 1; a >= 0; a--) {
					offset = offset + blockWidth + (arrowWidth) ;
					blockWidth = breadcrumbs[a].name.length * fontWidth + fontSize;
					var points = [
						[offset, 0],
						[offset + blockWidth, 0],
						[offset + blockWidth + arrowWidth, blockHeight *.5],
						[offset+ blockWidth,blockHeight],
						[offset, blockHeight],
						[offset + arrowWidth, blockHeight *.5],
						[offset, 0],
					];

				    classObject.breadcrumbs = classObject.breadcrumbContainer.selectAll("path.area")
				        .data([points])
				        .enter().append("path")
				        .style("fill", breadcrumbs[a].color)
				        .attr("d", d3.svg.area());
		        	classObject.breadcrumbsText = classObject.breadcrumbContainer.append("text")
				        .text(breadcrumbs[a].name)
						.attr('stroke', 'white')
						.attr("font-family", "Lucida Console, Monaco, monospace")
						.attr("x", offset + arrowWidth + (blockWidth / 2))
						.attr("y", (blockHeight) / 2 + 5)
						.style({ "font-size" : fontSize + "px", 'stroke': 'White', 'fill': 'none', 'stroke-width': '1px', "text-anchor" : "middle", 'font-weight': 400})
		        }
			}

			function onMouseLeave(d) {
				//remove breadcrumbs and make everything visible
				d3.select("#breadcrumbs").selectAll("path").remove();
				d3.selectAll("path")
					.style("opacity", 1);
				console.log("leaving");
			}

			function onMouseClick(d) {
				if(d.children !== undefined) {
					$(classObject.container).html("");
					classObject.selectedItem = d;
					render();
				}
			}
			function backButtonClick() {
				$(classObject.container).html("");
				classObject.selectedItem = null;
				render();
			}


			var width = width;
			var height = height * .8
			var radius = Math.min(width, height) / 2;

			render();

			//this actually draws the svg to the container, but we can call it again and again to redraw it
			function render() {
				var workingDataset = classObject.data;
				//this little guy finds the selected item and modifies our data to only include it and its parents
				if(classObject.selectedItem) {
					getJsonObjectFromObject(classObject.data, classObject.selectedItem.name)
					function getJsonObjectFromObject(json, objectName) {
						if(json.children) {
							for(var a = 0; a < json.children.length; a++) {
								if(json.children[a].name == objectName ) {
									//if we found a match
									workingDataset = json.children[a];
									d3.select("#backButton").text('Back');
								} else {
									getJsonObjectFromObject(json.children[a], objectName)
								}
							}
						}
					}
				}

				classObject.breadcrumbContainer = d3.select(classObject.container) //create container
			        .append("svg")
			        .attr('id', 'breadcrumbs')
			        .attr("width", classObject.canvasWidth)
			        .attr("height", classObject.canvasHeight/8);


				classObject.svg = d3.select(classObject.container)
					.append("svg")
				    .on("mouseleave", onMouseLeave)
				    .attr("width", width)
				    .attr("height", height)
				  		.append("g")
				  		.attr("id", "container")
				   		.attr("transform", "translate(" + width / 2 + "," + height / 2  + ")")

				var partition = d3.layout.partition()
				    .sort(null)
				    .size([2 * Math.PI, radius * radius])
				    .value(function(d) { return d.contacts; });

				var arc = d3.svg.arc()
				    .startAngle(function(d) { return d.x; })
				    .endAngle(function(d) { return d.x + d.dx; })
				    .innerRadius(function(d) { return Math.sqrt(d.y); })
				    .outerRadius(function(d) { return Math.sqrt(d.y + d.dy); });

				var path = classObject.svg.datum(workingDataset)
					.selectAll("path")
					.data(partition.nodes)
					.enter()
						.append("path")
						.attr("display", function(d) {
							//this is its ring level from center
							return d.depth ? null : "none";
						}) // hide inner ring
						.attr("d", arc)
						.style("stroke", "#fff")
						.attr("color" , function(d) {
							if(typeof(d.color) === "undefined") {
								if(typeof(d.parent) !== "undefined") { //if not wrapper object
									if(typeof(d.parent.parent) !== "undefined") {
										//a child of a real group
										var color = classObject.rcg.getColorObjectFromString(d.parent.color);
										var decay = 0.9
										color.red = parseInt(color.red * decay);
										color.green = parseInt(color.green * decay);
										color.blue = parseInt(color.blue * decay);
										var random = Math.random();
										switch(Math.ceil(random*3)) {
											case 1: color.red = parseInt(color.red + color.red/3 * random);
												break;
											case 2: color.green = parseInt(color.green + color.green/3 * random);
												break;
											case 3: color.blue = parseInt(color.blue + color.blue/3 * random);
												break;
										}
										d.color = classObject.rcg.getColorString(color);
									} else {
										//its the first real group
										d.color = classObject.rcg.getColor()
									}
								}
							}
							return d.color;
						})
						.style("fill", function(d) {
							return d.color;
						})
						.style("fill-rule", "evenodd")
						.on("click", onMouseClick)
						.on("mouseover", mouseOver)

				//create middle text label
				var text = classObject.svg.append("text")
					.attr("id", "middleText")
					.text("100%")
					.attr('stroke', 'black')
					.style("text-anchor", "middle");
                if(classObject.selectedItem != null) {
                	if(typeof(classObject.selectedItem) !== "undefined") {
						var backButton = classObject.svg.append("text")
							.attr("id", "backButton")
							.text("Back")
							.attr('stroke', 'black')
							.attr("x", (width / 2) * -1 + 20)
							.attr("y", height / 2 - 20)
							.style({"stroke" : "black", "font-size" : "20px", "cursor" : "pointer"})
							.on("click", backButtonClick)
							.on("mouseover", function() {
								d3.select(this)
									.style("cursor", "pointer")
							});
					}
				}
			}
		}

		/*a method for spitting out what we know about our work.*/
		this.debug = function(){
			console.log(this.container);
			console.log(this.canvasWidth);
			console.log(this.canvasHeight);
			console.log(this.lines);
		}
	}





	//creates a sortable table based on json content
	d3Table = function (data,columns,drawElement) {
		var sortObject = {};

		columns.map( function(item) {//set up our sortObject based on columns
			sortObject[item] = "";
		});
		$(drawElement).html("");//clear out existing content.

		var table = d3.select(drawElement)
				.append("table")
				.attr("class", "stripe");
		var thead = table.append("thead");
		var tbody = table.append("tbody");

		/*a method for handling colum names as more viewable*/
		camelCaseToProperCase = function (string) {
		    var strings = string.split(/(?=[A-Z])/).join(" "); //break camelCase into words
		    return strings.replace(/(\b)([a-zA-Z])/g, function(letter){ //capitalize first letter of each word
		        return letter.toUpperCase();
		    });
		}

		thead.append("tr")
				.attr("class", "titlerow")
				.selectAll("th")
				.data(columns)
				.enter()
				.append("th")
				.attr("style", "cursor:pointer")
				//.text(function(column) { return camelCaseToProperCase(column)})
				.text(function(column) { return column})
				.on("click", function (d) {
					//this sorts the records based on one column and
					var rows = tbody.selectAll("tr")
							.sort(function(a, b) {
								return (sortObject[d] == "descending") ? d3.descending(a[d], b[d]) : d3.ascending(a[d], b[d]);
							});
					sortObject[d]  = (sortObject[d] == "descending") ? "ascending" : "descending";
					columns.map( function(item) {
						if(d != item) {
							sortObject[item] = "ascending";
						}
					})
				});

		var rows = tbody.selectAll("tr")
				.data(data)
				.enter()
				.append("tr")
				.sort(function(a,b) {
					return d3.ascending(a[columns[0]], b[columns[0]]);
				});

		var cells = rows.selectAll("td")
				.data(function(row) {
					return columns.map(function(column) {
						return {column: column, value: row[column]};
					});
				})
				.enter()
				.append("td")
				.html(function(d) { return d.value; });

		return table;
	}













	/*a function we'll use in a few places to set colors for graph elements*/
	function randomColorGenerator () {
		var previousArray = [];
   	    var presetColors = [ //setting our preset colors
	  						{"red": 153, "green" : 191, "blue": 132,},
	  						{"red": 188, "green" : 140, "blue": 100},
	  						{"red": 177, "green" : 106, "blue": 151},
	  						{"red": 147, "green" : 191, "blue": 185},
	  						{"red": 107, "green" : 125, "blue": 200},
	  						{"red": 144, "green" : 141, "blue": 170},
	  						{"red": 188, "green" : 184, "blue": 189},
	  						{"red": 155, "green" : 102, "blue": 121}
	  					];

	  	this.getColor = function(){
	  		/*if we haven't burned up our preset colors, use those first*/
	  		if (previousArray.length < presetColors.length) {
	  			var myColor = presetColors[previousArray.length];
	  		} else {
	  			/*otherwise we need to get a new system generated color*/
	  			var myColor = this.getRandomColorObject();
	  		}

	  		/*tack our color onto previous array, and return it as a string the user can consume*/
	  		previousArray.push(myColor);

	  		return this.getColorString(myColor);
	  	}

	    this.getRandomColorObject = function(){
		    var maxSimilarity = 2;/*allow only two of the RGB elements to be within similarityRange of an already used color.*/
		    var similarityRange = 20;/*how much must each rgb element be from eachother*/
		    var similarity = 0;
		    var passes = 0;/*to prevent ourselves from going into an infinite loop allow only maxPasses attempts*/
		    var maxPasses = 20;

		    var color = this.generateRandomColorObject();

		    /*if the color we got is too similar generate a new color and check again until we get an acceptable color*/
		    while(passes < maxPasses){
		    	/*check how similar our current color is to already used colors*/
		    	for( var n in this.previousArray){
		    		var testColor = this.previousArray[n];

		    		if(abs(testColor.red - color.red) > similarityRange) similarity++;
		    		if(abs(testColor.green - color.green) > similarityRange) similarity++;
		    		if(abs(testColor.blue - color.blue) > similarityRange) similarity++;

		    		/*if we aren't too similar to an existing color, break out of the loop*/
		    		if(similarity <= maxSimilarity) break;
		    	}

		    	passes++;//get ready for our next pass
		    }

		    return color;
	    }

	    this.generateRandomColorObject = function () {
	    	var color = {};
	    	color.red = Math.round(Math.random() * 125 + 75);
	    	color.green = Math.round(Math.random() * 125 + 75);
	    	color.blue = Math.round(Math.random() * 125 + 75);
	    	return color
	    }

	    this.getColorString = function(colorObject) {
	    	return "rgb("+ colorObject.red + "," + colorObject.green  + "," + colorObject.blue + ")";
	    }
	    this.getColorObjectFromString = function(colorString) {
	    	var rgb = colorString.substring(4, colorString.length-1)
		         .replace(/ /g, '')
		         .split(',');
		    var color = {};
	    	color.red = rgb[0];
	    	color.green = rgb[1];
	    	color.blue = rgb[2];
	    	return color
	    }

	}/*end of d3LineChart*/

</script>
