<cfsetting showdebugoutput="false" enableCFoutputOnly="yes">

<!---Variables--->
<cfset colors = {}>
<!---cfset colors.crimson = "##7D110C"--->
<cfset colors.crimson = "##54544C"><!---on dev we want more of a charcoal color so we know we're not on prod..--->
<cfset colors.cream = "##E1D8B7">
<cfset colors.mahogany = "##4A3C31">
<cfset colors.white = "##ffffff">
<cfset colors.offwhite = "##EBEBEB"><!---##f5f5f5--->
<cfset colors.mint = "##9ADCC6">
<cfset colors.info = "##44697D">
<cfset colors.hoverBlue = "##2a6496">

<cfset colors.red = "##990000">
<cfset colors.black = "##000">
<cfset colors.lightBlack = "##555">
<cfset colors.lightestBlack = "##ccc">

<cfset font = {}>
<cfset font.normalSize = "12px">


<cfset width.maxScreen = "1300px">
<!--->
colors.crimson:#7D110C
colors.cream:#E1D8B7
colors.mahogany:#4A3C31

Responsive Design Elements for bootstrap
http://getbootstrap.com/css/#responsive-utilities




--->
<cftry>
	<cfoutput>
	<style>
		/* here is some anti-css for our existing stylesheets that we should attempt to resolve so that we no longer need these*/
			.page-header h1	{
				border-bottom:none;
			}


		/* stop anti-css */





		/* Default HTML Elements */
			html {
				position: relative;
				min-height: 100%;
				font-family: "BentonSansCondensedRegular", "Arial Narrow", Arial, Helvetica, sans-serif;
				font-size: #font.normalSize#;
			}
			body {
				margin-bottom: 6em;
				background-color:#colors.white#;
			}
			a, a:link, a:visited, a:hover, a:active, a:focus {
				text-decoration:none;
				color:#colors.crimson#;
			}

			<!---a:hover, a:focus { color:#colors.hoverBlue# !important;	}--->

			p { line-height:150%; }

			textarea { max-width:100%; }

			/* Headings */
			h1 {
				font-size: 225%;
				color:#colors.crimson#;
				border-bottom:1px solid #colors.lightestBlack#;
				margin-bottom:5px;
			}
			h2 { font-size: 200%; }
			h3 { font-size: 175%; }
			h4 { font-size: 150%; }
			h5 {
				font-size: 125%;
				margin:0px;
			}
			h6 { font-size: 100%; }



		/* Header */
			##header {
				background-color:#colors.white#;
			}
			##iu-header {
				border-top: .5em solid #colors.red#;
				background-color: #colors.crimson#;
				padding:0 .5em;
			}
			##header div.iu {
				font-size: 1.4em;
				line-height:2em;
				text-transform: uppercase;
				max-width:#width.maxScreen#;
				margin:0 auto;
			}
			##header img{
				position:absolute;
				margin-left:1em;
				height:2em;
			}

			##header .iu span{
				color:#colors.white#;
			}
			.navbar {
				margin-bottom:0em;
			}

			/* Header Navigation */
				##header-navigation {
					font-size: 1.2em;
				}
				.navbar-default .navbar-nav>li>a, .navbar-default .navbar-brand, .navbar-default .navbar-nav .open .dropdown-menu>li>a, .dropdown-menu>li>a {
					color:#colors.crimson#;
				}
				.navbar-default {
					background-color:#colors.white#;
				}
				.navbar .container-fluid {
					max-width:#width.maxScreen#;
					margin:0 auto;
				}




		/* Footer */
		##footer {
			border-top: 1px solid #colors.offwhite#;
			position: absolute;
			bottom: 0;
			width: 100%;
			height: 6em;
			background-color: #colors.white#;
			color:#colors.lightBlack#;
			padding:1em;
			text-align:center;
		}
		##footer a:link, ##footer a:visited{
			color:#colors.crimson#;
		}


		div.content-block {
			background-color:#colors.white#;
			padding:2em .5em 2em 0;
			max-width:#width.maxScreen#;
			margin:0px auto;

		}




		/* Custom Standard Classes */
			/* headings */
				div.panel-default div.red-heading {
					background-color:#colors.crimson#;
					color:#colors.white#;
					font-weight:bold;
				}

			/* Alignment */
				div.clear {
					clear:both;
				}
			/* Statuses and Warnings */
				div.error { /* you can use the class "fa fa-times-circle" to give you a warning icon */
					padding:1em;
					background-color:#colors.crimson#;
					color:#colors.white#;
					margin-bottom: 1em;
				}
				div.success { /* you can use the class "fa fa-check-circle" to give you a warning icon */
					padding:1em;
					background-color:#colors.mint#;
					color:#colors.black#;
					margin-bottom: 1em;
				}
				div.warning { /* you can use the class "fa fa-exclamation-circle" to give you a warning icon */
					padding:1em;
					background-color:#colors.info#;
					color:#colors.white#;
					margin-bottom: 1em;
				}
			/*make warnings and errors uniform throughout*/
				.warning {
					color: ##fff;
					background-color: ##AB1A1A;
					padding: 0.5em;
					border: double gray 3px;
				}
			/*make success messages uniform throughout*/
				.ok {
					color: black;
					background-color: ##8CFFAB;
					padding: 0.5em;
					border: double gray 3px;
				}


		/* Custom Form Inputs */

			/*multi-select */
				div.multiselect-container input[type="string"], div.multiselect-container select {
					width:85%;
					display:inline-block;
				}
				div.multiselect-container div.add-button-container {
					width:10%;
					display:inline-block;
				}
				div.multiselect-container div.add-button-container > a {
					font-size:240%;
					vertical-align: middle;
				}
				.bootstrap-fieldset {
					border:none;
					box-shadow: 0 0 0px rgba(0, 0, 0, 0.0);
					-webkit-background-clip: padding-box;
				}
				.bootstrap-fieldset legend {
					text-align: right;
					font-weight: 700;
					margin-top:0px;
					box-shadow: 0 0 0px rgba(0, 0, 0, 0.0);
					-webkit-background-clip: padding-box;
					font-size: 14px;
					margin: 0em;
					padding: 0em 1.4em 0em 0em;
				}
				@media (max-width: 768px) {
					.bootstrap-fieldset legend {
						text-align: left;
						padding-left: 1em;
					}
				}






	/*Popovers*/
		.popover-content {
			font-size:#font.normalSize#;

		}

	/*font awesome extensions*/
		i.fa-faintest {
			opacity:0.5;
		}
		i.fa {
			font-size:#font.normalSize#;
		}



























/*
########################################################################################
NOTE: The following styles below are deprecated and will be removed on the next version
########################################################################################
*/



legend {
	width: auto;
	padding:0px 5px;
	#createBoxShadow()#
	background-color:##fff;
	font-size:120%;
	margin-top:-10px;
}
fieldset {
	margin: 1em 5px 5px 5px;
	padding:0em 1em 1em 1em;
	#createBoxShadow()#
}


select
{
	border-radius:2px;
	padding:3px;
	max-width: 98%;
	margin: 0px;
}
input[type="button"], input[type="submit"],  input[type="file"], input[type="reset"]
{
	border-radius:2px;
	/*padding:2px 10px;*/
	font-weight:500;
	line-height: 1.4;
	margin-right: .1em;
	text-decoration: none !important;
	cursor: pointer;
	text-align: center;
	overflow: visible;
}
input[type="button"]:hover, input[type="submit"]:hover, input[type="file"]:hover, input[type="reset"]:hover
{
	background-color:##888888;
	color:##fff;
}
input[type="button"]:active,input[type="submit"]:active,input[type="file"]:active, input[type="reset"]:active
{
	background-color:##111111;
	color:##fff;
}
input[type="text"]
{
	color: ##000 !important;
	padding:2px 5px;
}
textarea
{
	height:100px;
	min-width:300px;
	padding:2px 5px;
}





.red-light{	color:##7d120c; }
.tinytext {	font-size: smaller;}
.light-line {border:thin ##eee groove;}
.text-center { text-align:center;}
.text-right { text-align: right;}
.text-top { vertical-align: top;}

div.heading
{
	background:##555;
	background-size:contain;
	color:##fff;
	padding:7px;
	font-weight:700;
	text-transform: uppercase;
}

div.content
{
	padding:5px;
}










/* inputs */
/*a common function generates site selectors with this class*/
select.siteSelector {
	display: inline-block;
	vertical-align: top;
}

/*a zebra striped table and its helper classes*/
table.stripe, ##articleId table {
	line-height:150%;
	background-color: ##FCF9E6;
	border: thin outset Navy;
	text-align: left;
	<cfoutput>#createBoxShadow()#</cfoutput>
}
/*we don't want any clever table highjinx in the article editor.  This'll put the kibosh on it.*/
##articleId table {
	width:100%;
}

table.stripe th, ##articleId table th {
	font-weight: bold;
	text-align: center;
}

table.stripe tr:nth-child(odd), ##articleId table tr:nth-child(odd){
	background-color: ##F8F3D2;
}
table.stripe tr:nth-child(even), ##articleId table tr:nth-child(even) {
	background-color: ##e1e0d9;
}

table.stripe tr.titlerow {
	background-color:##7D110C !important;
	background-size:contain;
	font-weight: bold;
	color:##fff;
	font-size:110%;
}
table.stripe tr.titlerow a:active {
	color:##fff;
	text-decoration:underline;
}
table.stripe tr.titlerow a:visited {
	color:##fff;
	text-decoration:underline;
}
table.stripe tr.titlerow a:hover {
	color:##fff;
	text-decoration:underline;
}
table.stripe tr.titlerow a:focus {
	color:##fff;
	text-decoration:underline;
}

table.stripe tr.titlerow2 {
	background-color: ##D0C476;
	font-weight: bold;
}
table.stripe td, table.stripe th {
	padding:5px;
	vertical-align: top;
}
/*end of striped table*/

/*.trigger and .triggerexpand are special classes used in a javascript function in /js/common.js */
.trigger, .triggerexpanded {
		white-space: nowrap;
		cursor: pointer;
		font-weight: bold;
}
span.trigger:hover, span.triggerexpanded:hover {
	background-color: ##cccccc;
}



/* special casing */
##articleId {
	width:71%;
	margin:0px auto;
	padding:5px;
}
 ##articleId img {
 	max-width:100%;
 }

 ##articleId a:link, ##articleId a:hover, ##articleId a:focus, ##articleId a:visited,  ##articleId a:active {
 	text-decoration: underline;
 }
.left-side {
	width:63%;
	float:left;
	background-color:##fff;
}
.right-side {
	width:33%;
	float:right;
	background-color:##fff;
}
.block-card {
	text-align:center;
	line-height:150%;
	padding:10px;
	margin:15px;
	#createBoxShadow()#
}

.block-card-tight {
	text-align:center;
	line-height:150%;
	padding:10px 0px;
	margin:15px 0px;
	#createBoxShadow()#
}

/*Shadow border is for inactive boxes*/
.shadow-border
{
	#createBoxShadow()#
}
/*hover box active boxes with a link */
.hover-box {
	border: 1px solid ##FFF;
	color:##000;
}
.hover-box:hover {
	color:##000;
	#createBoxShadow()#
	border: 1px solid ##900;
}
a.hover-box {
	text-decoration:none;
	color:##000;

}


/*draw our mask selector as an inline object.*/
div.maskSelectorForm {
	display: inline-block;
	vertical-align: text-top;
}


ul.inventory {
	font-size: small;
	padding: 0px;
	margin-left: 1em;
}
ul.inventory ul, ul.inventory li {
	list-style:none;
}
ul.inventory li:hover {
	background-color: ##FCF9E6;/*iu light cream*/
}

/*levels at, or beneath, warning level get a yellow box*/
ul.inventory li .normal {
	font-weight: bold;
	padding-left: 2px;
	padding-right: 2px;
}

ul.inventory .warn {
	background-color: yellow;
	opacity:0.9;
	padding-left: 2px;
	padding-right: 2px;

}

/*levels at, or beneath, critical level get a red box*/
ul.inventory li.crit {
	background-color: ##AB1A1A;
	opacity:0.9;
	color:##fff;
	padding-left: 2px;
	padding-right: 2px;
}

/* a special hover for red boxes, to main legibility */
ul.inventory li.crit:hover {
	opacity:0.7;
}

/*override a few jQuery-UI classes so they render more cleanly.*/
.ui-icon {
	display: inline-block;
	vertical-align: text-bottom;
}
.ui-state-default {
	cursor:default;
}

.report-lab {
	display: inline-block;
	min-width: 20em;
	vertical-align: top;
}

/*override a few bootstrap classes that don't render as desired.*/
.form-control {
	display: inline-block;
}

	</style>
	</cfoutput>
	<cffunction name="createBoxShadow">
		<cfoutput>
		border: 1px solid transparent;
		-webkit-box-shadow: 0 0 6px rgba(0, 0, 0, 0.3);
		-moz-box-shadow: 0 0 6px rgba(0,0,0,0.3);
		box-shadow: 0 0 6px rgba(0, 0, 0, 0.3);
		-webkit-background-clip: padding-box;
		-moz-background-clip: padding-box;
		background-clip: content;
		</cfoutput>
	</cffunction>
<cfcatch>
	<cfoutput>#cfcatch#" --- Make sure you are only using coldfusion variables as colors. Nothing in CSS should require a ## unless it is a coldfusion variable. If you are trying to use a ## as an id, use 2 ##"</cfoutput>
</cfcatch>
</cftry>