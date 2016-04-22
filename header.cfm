<cfsetting showdebugoutput="true">
<cfparam name="attributes.title" type="string" default="TETRA">
<cfparam name="attributes.drawCustom" type="boolean" default="false"><!---if drawCustom is set, don't draw the container div--->
<cfparam name="attributes.noText" type="boolean" default="false"><!---If noText is set, don't draw the header links.--->

<cfset appPath = application.appPath>
 	<cfif not isDefined("hasMasks")><!---as a module we may need to include our common-fucntions, if they aren't already available.--->
 		<cfinclude template="#application.appPath#/common-functions.cfm"/>
 	</cfif>
<cfoutput>
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">
    <link rel="icon" href="#application.appPath#/favicon.ico">

	<title>#attributes.title#</title>

	<!--Styles-->
	    <!-- Bootstrap core CSS -->
	    	<link href="#application.appPath#/bootstrap/css/bootstrap.min.css" rel="stylesheet">

		<!-- Font Awesome -->
			<link href="//maxcdn.bootstrapcdn.com/font-awesome/4.1.0/css/font-awesome.min.css" rel="stylesheet">

	    <!-- jQuery UI -->
			<link href="#application.appPath#/js/css/smoothness/jquery-ui-1.10.1.custom.css" rel="stylesheet" type="text/css" media="screen" />

		<!-- Custom styles for this template -->
 			<link href="#application.appPath#/css/print.css" rel="stylesheet" type="text/css" media="print" />
 			<link href="#application.appPath#/css/css.cfm" rel="stylesheet" type="text/css" />


    <!-- JavaScript -->
		<!-- jQuery -->
			<script type="text/javascript" src="#application.appPath#/js/jquery-1.11.1.min.js"></script>
			<!---script src="https://code.jquery.com/jquery-migrate-1.2.1.js"></script--->
			
			<script type="text/javascript" src="#application.appPath#/js/jquery-ui-1.10.1.custom.min.js"></script>

		<!-- Bootstrap -->
 			<script src="#application.appPath#/bootstrap/js/bootstrap.min.js"></script>

		<!--CKeditor, rich text editor-->
			<script type="text/javascript" src="#application.appPath#/js/ckeditor/ckeditor.js"></script>

		<!--Custom Javascript -->
			<script type="text/javascript" src="#application.appPath#/js/common.js"></script>



		<link rel="shortcut icon" href="<cfoutput>#application.appPath#</cfoutput>/images/favicon.ico" type="image/x-icon" />
  </head>

<cfset myInstance = getInstanceById(session.primary_instance)>
<cfset hasMoreThanOneInstanceMask = hasMasks("IUB,IUPUI")>
<cfif not attributes.noText>
	<cfset negMaskList = "">

	<!--- if we have a primary instance, limit header links to that instance --->
	<!--- otherwise show all valid mask ones as normal --->
	<cfif session.primary_instance NEQ 0>
		<!--- first find all instance masks the user has that do not correspond to the primary instance --->
		<cfquery datasource="#application.applicationDataSource#" name="getNegInstanceMasks">
			SELECT um.mask_id
			FROM tbl_instances i
			INNER JOIN tbl_user_masks um ON um.mask_name = i.instance_mask
			WHERE i.instance_mask != <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
		</cfquery>

		<cfloop query="getNegInstanceMasks">
			<cfset negMaskList = listAppend(negMaskList, mask_id)>
		</cfloop>
	</cfif>

	<cfquery datasource="#application.applicationDataSource#" name="getMyMasks">
		SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
		FROM tbl_users u
		INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
		INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
		WHERE u.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	</cfquery>

	<!--- fetch the table of masks' parent->child relationships so we can get all the user's inherited masks --->
	<cfquery datasource="#application.applicationDataSource#" name="getAllMaskRelationships">
		SELECT um.mask_id, um.mask_name,
			CASE
				WHEN mr.mask_id IS NULL THEN 0
				ELSE mr.mask_id
			END AS parent_id
		FROM tbl_user_masks um
		LEFT OUTER JOIN tbl_mask_relationships_members mrm ON mrm.mask_id = um.mask_id
		LEFT OUTER JOIN tbl_mask_relationships mr ON mr.relationship_id = mrm.relationship_id
		ORDER BY um.mask_id
	</cfquery>

	<!--- get all user masks using the info above --->
	<cfset getUserMasks = buildMyMasks(getMyMasks, getAllMaskRelationships)>

	<!--- build our final maskList, leaving out any that are in negMaskList --->
	<cfset maskList = ""><!---a placeholder so we never have a list of length 0--->
	<cfloop query="getUserMasks">
		<cfif NOT listFindNoCase(negMaskList, mask_id)>
			<cfset maskList = listAppend(maskList, mask_id)>
		</cfif>
	</cfloop>

	<!---fetch all the categories for our user--->
	<cfquery datasource="#application.applicationdatasource#" name='getHeaderCats'>
		SELECT category_id, text, link, parent
		FROM tbl_header_categories
		WHERE parent = 0 /*we only want top-level categories for the header*/
		AND retired = 0
		ORDER BY sort_order, text
	</cfquery>

	<!---fetch all the links our user can view in one go, as well--->
	<cfquery datasource="#application.applicationDataSource#" name="getUserLinks">
		SELECT link_id, text, link, parent, new_window
		FROM tbl_header_links l
		/*this clause limits us to links that the user has the masks for*/
		WHERE NOT EXISTS (
			SELECT hlm.mask_id
			FROM tbl_header_links_masks hlm
			WHERE hlm.link_id = l.link_id
			 	  AND hlm.mask_id NOT IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#maskList#" list="true">)
		  )
		AND retired = 0
		ORDER BY l.sort_order, l.text
	</cfquery>




<body>
	<div class="container-fluid">
		<div id="header" class="print-hide">
			<div>
			    <div id="iu-header" class="row">
					<div class="iu">
						<div class="col-sm-12">
							<a href="#application.appPath#/index.cfm"><img alt="IU Trident" src="#application.appPath#/images/trident-tab.png"></a>
							<span style="padding-left:3.5em;" class="hidden-xs hidden-sm"><a href="#application.appPath#/index.cfm" style="color:##ffffff !important;">#myInstance.institution_name#</a></span>
	  						<span style="padding-left:3.5em;" class="visible-xs-inline visible-sm-inline"><a href="#application.appPath#/index.cfm" style="color:##ffffff;">#myInstance.instance_mask#</a></span>
							<cfif hasMoreThanOneInstanceMask>
			 	  				<button id="header-change-instance" type="submit" class="btn btn-default pull-right">Instance</button>
		 	  				</cfif>
			 	  			<script>
				 	  			$('##header-change-instance').click(function() {
				 	  				window.location= "#application.appPath#/tools/instance/instance_selector.cfm";
				 	  			});
			 	  			</script>
			 	  		</div>
					</div>
			    </div>
			</div>
			<div id="header-navigation" class="row">
				<div>
					<nav class="navbar navbar-default" role="navigation">
						<div class="container-fluid">
							<!-- Brand and toggle get grouped for better mobile display -->
							<div class="navbar-header">
								<button type="button" class="navbar-toggle" data-toggle="collapse" data-target="##bs-example-navbar-collapse-1">
								<span class="sr-only">Toggle navigation</span>
								<span class="icon-bar"></span>
								<span class="icon-bar"></span>
								<span class="icon-bar"></span>
								</button>
								<a class="navbar-brand visible-xs" href="#application.appPath#">TCC</a>
							</div>

							<!-- Collect the nav links, forms, and other content for toggling -->
							<div class="collapse navbar-collapse" id="bs-example-navbar-collapse-1">
								<ul class="nav navbar-nav">
									<cfloop query="getHeaderCats">
										<li class="dropdown">
											<!---if the link is a valid url just use that, otherwise make it relative to application.appPath.--->
											<cfset myUrl = link>
											<cfif not isValid('url', link) AND link neq "##">
												<cfset myUrl = application.appPath & '/' & link>
											</cfif>

											<a href="##" class="dropdown-toggle" data-toggle="dropdown">#getHeaderCats.text# <span class="caret"></span></a>
											<ul class="dropdown-menu" role="menu">
											<cfloop query="getUserLinks">
												<cfif parent eq getHeaderCats.category_id>
													<li>
														<!---if link is a valid url just use link, otherwise append application.appPath--->
														<cfset myUrl = link>
														<cfif not isValid('url', link) AND link neq "##">
															<cfset myUrl = application.appPath & '/' & link>
														</cfif>

														<a href="#myUrl#" <cfif new_window>target="_blank"</cfif>>#text#</a>
													</li>
												</cfif>
											</cfloop>
											</ul>
										</li>
									</cfloop>
								</ul>
								<form action="<cfoutput>#application.appPath#/search/index.cfm</cfoutput>" method="get" class="navbar-form navbar-right" role="search">
									<div class="form-group">
										<input type="text" id="header-search" name="searchTerm" class="hidden-sm form-control" placeholder="Search">
									</div>
									<button type="submit" class="btn btn-default">Search</button>
								</form>
								<script type="text/javascript">
									$(document).ready(function(){
										//listen to user input and suggest
										$("##header-search").autocomplete({
											source: "#application.appPath#/search/suggestions.cfm",
											minLength: 2
										});
									});
								</script>
							</div><!-- /.navbar-collapse -->
						</div><!-- /.container-fluid -->
					</nav>
				</div>
			</div>
		</div>
	</div>
	<div class="content-block row">
	<div class="col-sm-12">
</cfif>
<!--->
<div class="error">
	<i class="fa fa-times-circle"></i> Testing Error
</div>
<div class="success">
	<i class="fa fa-check-circle"></i> Testing Success
</div>
<div class="warning">
	<i class="fa fa-exclamation-circle"></i> Testing Warning
</div>
--->
</cfoutput>