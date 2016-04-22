<cfsetting enablecfoutputonly="true"><!---thanks to the recursive functions we can get a TON of whiltespace.  This should help.--->
<cfif not isDefined("attributes")>
	<cfoutput>
		<h1>Error</h1>
		<p>
			This page is to be exclusively used as a module, and cannot be browsed to.
		</p>
	</cfoutput>
	<cfabort>
</cfif>

<!---since this is a module we may need to bring in our common functions.--->
<cfif not isDefined("getAllCategoriesQuery")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfparam name="attributes.width" type="string" default="30em"><!---the width, in em that the content should be displayed at--->
<cfparam name="attributes.catId" type="integer" default="0"><!---the category_id we want to have open by default when rendering.--->
<cfparam name="attributes.articleSelected" type="integer" default="0">
<cfparam name="attributes.sortable" type="boolean" default="0">
<cfparam name="attributes.useRetired" type="boolean" default="0">
<cfparam name="attributes.hideOptions" type="boolean" default="0">


<!---only admins can sort items, if they're not an admin reset it to false.--->
<cfif attributes.sortable AND not hasMasks("Article Editor")>
	<cfset attributes.sortable = 0>
</cfif>

<cfset myId = "content" & createUUID()><!---myId is a unique ID so we don't clobber other CSS and javascript classes.--->


<cfset getAllCats = getAllCategoriesQuery(attributes.useRetired)><!---if we're including retired articles, we'll want retired categories, too.--->

<!---first fetch all the articles, along with the masks required to view them.--->
<cfquery datasource="#application.applicationDataSource#" name="getUserArticlesMasks">
	SELECT a.article_id, a.category_id, a.retired, ar.title, a.sort_order,um.mask_name
	FROM tbl_articles a
	INNER JOIN tbl_articles_revisions ar
		ON ar.article_id = a.article_id
		AND ar.use_revision = 1
		AND ar.approved = 1
	LEFT OUTER JOIN tbl_articles_masks am ON a.article_id = am.article_id
	LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
	WHERE a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#attributes.useRetired#">
	AND 0 NOT IN (
		SELECT
			CASE
				WHEN mu.mask_id IS NULL THEN 0
				ELSE 1
			END AS has_mask
		FROM tbl_articles_masks am
		LEFT OUTER JOIN vi_all_masks_users mu
			ON mu.mask_id = am.mask_id
			AND mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		WHERE am.article_id = a.article_id
	)
	ORDER BY a.sort_order, a.article_id DESC
</cfquery>

<!---now build, from scratch a query that mirrors our old getUserArticles, and include a column of mask_list--->
<cfset getuserArticles = queryNew("article_id,category_id,retired,title,sort_order,mask_list", "integer,integer,bit,varchar,integer,varchar")>
<cfloop query="getUserArticlesMasks" group="article_id">
	<cfset maskList = "">
	<cfloop>
		<!----this is a little weird, but stashing the masks as pre-formatted HTML should save some time when we're rendering later.--->
		<cfset formattedString = '<span class="ui-state-default ui-corner-all">' & #mask_name# & '</span> '>
		<cfset maskList = maskList & formattedString>
	</cfloop>

	<!---now we can add a row to getUserArticles.--->
	<cfset queryAddRow(getuserArticles)>
	<cfset querysetCell(getuserArticles, "article_id", article_id)>
	<cfset querysetCell(getuserArticles, "category_id", category_id)>
	<cfset querysetCell(getuserArticles, "retired", retired)>
	<cfset querysetCell(getuserArticles, "title", title)>
	<cfset querysetCell(getuserArticles, "sort_order", sort_order)>
	<cfset querysetCell(getuserArticles, "mask_list", maskList)>
</cfloop>


<!---if we don't have any articles we cannot continue.--->
<cfif getUserArticles.recordCount eq 0>
	<cfoutput>
		<p class="alert">
			You do not appear to have the masks required to view any of the existing articles.
		</p>
	</cfoutput>
<cfelse>
	<!---weed out empty categories--->
	<cfset filledCats = "">
	<cfloop query="getAllCats">
		<cfif catHasContent(category_id)>
			<cfset filledCats = listAppend(filledCats, category_id)>
		</cfif>
	</cfloop>

	<cfquery dbtype="query" name="filledCats">
		SELECT *
		FROM getAllCats
		WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#filledCats#" list="true">)
		ORDER BY sort_order
	</cfquery>

	<!---there's one last thing we need to know, which categories should be expanded.--->
	<cfset expandedList = getCategoryParentList(attributes.catId, filledCats)>


	<!---here we are, down to about 1 second to reach just categories we want to draw.--->

	<!---
		BEGIN DRAWING
	--->

	<cfoutput>
	<style type="text/css">
		div###myId# {
			width: #htmlEditFormat(attributes.width)#;
		}
		div###myId# div.category {
			margin-left: 1em;
		}

		div###myId# div.category ul {
			padding: 0px;
			margin: 0px;
			/*margin-left: 1em;*/
			list-style-type: none;
		}
		div###myId# div.category ul li {
			border: 1px solid ##FFF;
		}
		div###myId# div.category ul li:hover {
			border: dotted 1px gray;
		}

		div###myId# p {
			padding: 0px;
			margin-top: 0.5em;
			margin-bottom: 0em;
		}

		/*override some of our triggerexpand css so it works more cleanly.*/
		div###myId# span.trigger{
			display: inline-block;
			width: 100%;
			margin: 0;
			padding:2px 0;
			background-color: ##eee !important;
			border-bottom:1px solid ##fff;

		}

		div###myId# span.trigger:hover{
			background-color: ##888 !important;
			color:##fff !important;
		}
		div###myId# span.triggerexpanded{
			display: inline-block;
			width: 100%;
			margin-bottom: 1px;
			background-color: ##888 !important;
			padding:2px 0;
			color:##fff;
		}
		div###myId# span.trigger {

		}
		.trigger, .triggerexpanded {
			overflow: hidden;
		}
	</style>

	<!---this is a bit odd, but it'll make creating new articles a bit easier. Listen for clicks on trigger spans, find if they have an associated category id, and seed that in the "Create a new article" link.--->
	<script type="text/javascript">
		$(document).ready(function(){
			$("div###myId#").on("click", "span.trigger", function(e){
				var catId = 0;
				var getCatId = $(this).attr("categoryid");

				if(!isNaN(getCatId)){
					catId = getCatId;
				}

				//update the Create Article link to use our catId.
				$("a##articleLink", "div###myId#").attr("href", "#application.appPath#/documents/article_editor.cfm?frmCatId=" + catId);
			});

			//when closing a category reset it.
			$("div###myId#").on("click", "span.triggerexpanded", function(e){
				$("a##articleLink", "div###myId#").attr("href", "#application.appPath#/documents/article_editor.cfm?frmCatId=0");
			});

			//Also prevent clicks on the "Sort Articles" links from bubbling up the dom tree and fiddling with our trigger/triggerexpandeds.
			$("div###myId#").on("click", "span span.tinytext a", function(e){
				e.stopPropagation();
			});
		});
	</script>

	</cfoutput>

	<cfset drawCat(0, expandedList)>
</cfif>
<!---
	END DRAWING
--->

<cffunction name="drawCat">
	<cfargument name="catId" type="numeric" default="0">
	<cfargument name="expandedList" type="string" default="">

	<cfset var i = "">
	<cfset var triggerClass = "trigger"><!---trigger or triggerexpanded?--->
	<cfif listFind(expandedList, catId)>
		<cfset triggerClass = "triggerexpanded">
	</cfif>

	<!---if this is our first pass open a containing div.--->
	<cfif catId eq 0>
		<cfoutput>
			<div class="panel-heading red-heading">TCC Content</div>
			<div id="#myId#" class="panel-body">
		</cfoutput>
	</cfif>
	<cfloop query="filledCats">
		<cfif category_id eq catId>
			<cfoutput>
				<span class="#triggerClass#" categoryId="#catId#">
					#category_name#
					<cfif attributes.sortable>
						&nbsp;&nbsp;
						<span class="tinytext">
							[<a href="#application.appPath#/documents/sort_articles.cfm?frmCatId=#catId#">Sort Articles</a>]
						</span>
					</cfif>
				</span>
				<div class="category">
			</cfoutput>
			<cfbreak>
		</cfif>
	</cfloop>

	<!---now draw any articles for this level.--->
	<cfset drawCatArticles(catId)>

	<!---now draw the child categories under it.--->
	<cfloop query="filledCats">
		<cfif parent_cat_id eq catId>
			<cfset drawCat(category_id, expandedList)>
		</cfif>
	</cfloop>

	<!---now close that dangling div tag.--->
	<cfoutput>
			<cfif attributes.hideOptions EQ 0>
				<!---if we're at level 0, draw a link to create new articles.--->
				<cfif catId eq 0>
					<p>
						<cfif hasMasks("Article Editor")><a href="#application.appPath#/documents/article_editor.cfm?frmCatId=#attributes.catId#" id="articleLink">Create a New Article</a></cfif>
						<cfif hasMasks("Admin")><br/><a href="#application.appPath#/documents/category_editor.cfm">Manage Categories</a></cfif><br/>
						<cfif hasMasks("Article Editor")><a href="#application.appPath#/documents/sort-articles-selection.cfm?">Sort Articles</a></cfif>
					</p>
				</cfif>
			</cfif>
		</div>
	</cfoutput>

</cffunction>

<cffunction name="drawCatArticles">
	<cfargument name="catId" type="numeric" required="true">

	<cfset var i = "">
	<cfset var mask = "">

	<cfoutput><ul></cfoutput>

	<cfloop query="getUserArticles">
		<cfif category_id eq catId>
			<cfoutput>
				<li>
					<cfif article_id EQ attributes.articleSelected>
						<span title="#trim(stripTags(title))#"><strong>#stripTags(title)#</strong></span>
					<cfelse>
						<a title="#stripTags(title)#" href="#application.appPath#/documents/article.cfm?articleId=#article_id#">#stripTags(title)#</a>
					</cfif>
					<cfif len(mask_list) gt 0>
						<br/>
						<span class="tinytext">
							#mask_list#
						</span>
					</cfif>
				</li>
			</cfoutput>
		</cfif>
	</cfloop>

	<cfoutput></ul></cfoutput>
</cffunction>

<cffunction name="catHasContent" output="false">
	<cfargument name="catId" type="numeric" default="0">

	<cfset var hasContent = 0>

	<!---does this category have articles?--->
	<cfloop query="getUserArticles">
		<cfif category_id eq catId>
			<cfreturn 1><!---this category has content, we're done.--->
		</cfif>
	</cfloop>

	<!---if it doesn't have content, does its children?--->
	<cfloop query="getAllCats">
		<cfif parent_cat_id eq catId>
			<cfset hasContent = catHasContent(category_id)>

			<cfif hasContent>
				<cfbreak>
			</cfif>
		</cfif>
	</cfloop>

	<!--At this point hasContent is the truth of the matter on where this category has content under it.--->
	<cfreturn hasContent>
</cffunction>

<!---having reached the end of the module re-enable output--->
<cfsetting enablecfoutputonly="false">