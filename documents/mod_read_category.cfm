<!---this module is intented to print out an entire category's articles, along with all its child articles that are viewable for the masks provided.  This is especially for things like the Handbook and Newsletter.--->
<cfif not isDefined("attributes")>
	<h1>Error</h1>
	<p>
		This page is to be exclusively used as a module, and cannot be browsed to.
	</p>
	<cfabort>
</cfif>

<style type="text/css">
	a, a:visited {
		color: #7D110C;
	}
</style>

<cfparam name="attributes.categoryId" type="integer">
<cfparam name="attributes.masks" type="string"><!---I'd really prefer just using the user's ID to fetch their masks, but recall that we want to make things like the Handbook available to the public.  So we have to be super careful to make sure this tool can't be abused to divulge things we don't intend to.--->
<cfparam name="attributes.toc" type="boolean" default="true">
<cfparam name="attributes.tocArticles" type="boolean" default="false">
<!--- these parameters track our topmost category --->
<cfparam name="categoryName" type="string" default="">
<cfparam name="categoryId" type="integer" default="0">
<!---since this is a module we may need to bring in our common functions.--->
<cfif not isDefined("getAllCategoriesQuery")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<!---first things first, fetch all the categories once, so we can reuse this information.--->
<cfset getAllCats = getAllCategoriesQuery(0)>
<!---display the category name as the title--->
<cfloop query="getAllCats">
	<cfif category_id eq attributes.categoryId>	
		<cfif isDate(category_name)>
			<cfset catName = LSDateFormat(parseDateTime(category_name), "mmmm yyyy")>
		<cfelse>
			<cfset catName = category_name>
		</cfif>
		<h1 <cfif attributes.toc EQ false>style="border-bottom:none;"</cfif>><cfoutput>#catName#</cfoutput></h1>
		<cfset categoryName = category_name>
		<cfset categoryId = category_id>
	</cfif>
</cfloop>

<!---get the list of categories under attributes.categoryId so we can narrow the following query--->
<cfset myCats = getCategoryChildrenList(attributes.categoryId, getAllCats)>

<!---next get all the articles the user could view with the provided masks, this lets us know which categories to display.--->
<cfquery datasource="#application.applicationDataSource#" name="getUserArticles">
	SELECT a.article_id, a.category_id, a.sort_order, a.retired, ar.title, ar.revision_content
	FROM tbl_articles a
	INNER JOIN tbl_articles_revisions ar ON ar.revision_id = (
		/*narrow it down to the current revision*/
		SELECT TOP 1 revision_id
		FROM tbl_articles_revisions
		WHERE article_id = a.article_id
		AND use_revision = 1
		AND approved = 1
		ORDER BY revision_date DESC
	)
	/*This where cluase looks tricky, but it limits us to articles that the user has the masks to view.*/
	WHERE 0 NOT IN (
		SELECT 
			CASE 
				WHEN um.mask_id IS NULL THEN 0
				ELSE 1
			END AS has_mask
		FROM tbl_articles_masks am
		LEFT OUTER JOIN (
			SELECT mask_id
			FROM tbl_user_masks
			WHERE mask_name IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#attributes.masks#" list="true">)
		) um ON um.mask_id = am.mask_id
		WHERE article_id = a.article_id
	)
	AND retired = 0
	AND category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#myCats#" list="true">)
</cfquery>

<!---there are a ton of categories to contend with, and we can save A LOT of time by weeding out ones the user can't view at all.--->
<cfset myCats = "">
<cfquery dbtype="query" name="usedCats">
	SELECT DISTINCT category_id
	FROM getUserARticles
</cfquery>


<cfloop query="usedCats">
	<cfset tempList = getCategoryParentList(category_id, getAllCats)>
	
	<cfloop list="#tempList#" index="i">
		<cfif isNumeric(i) AND not listFind(myCats, i)>
			<cfset myCats = listAppend(myCats, i)>
		</cfif>
	</cfloop>
</cfloop>

<cfif listLen(myCats) gt 0>
	<!---now we can really pare-down the number of categories to go over.--->
	<cfquery dbtype="query" name="getAllCats">
		SELECT *
		FROM getAllCats
		WHERE category_id IN (#myCats#)
	</cfquery>
</cfif>

<!---drop some javascript to update readership--->
<script type="text/javascript">
	<!---it might be better to do this with scroll events, but this'll work more uniformly, for now.--->
	function submitReadership(articleId){
		$.ajax({
			url: "<cfoutput>#application.appPath#/documents/ajax_article_read.cfm</cfoutput>",
			type: "POST",
			async: true,
			data: {
				"readId": 0,
				"articleId": articleId
			}
		});
	}
</script>

<cfif attributes.toc EQ true>
	<!---try to draw the table of contents.--->
	<fieldset>
		<legend>Table of Contents</legend>
		<cfset drawCatToc(attributes.categoryId)>
	</fieldset>
</cfif>
<!---draw the actual content.--->
<cfset drawCat(attributes.categoryId)>



<cffunction name="drawCatToc">
	<cfargument name="catId" type="numeric" default="0">
	<cfargument name="level" type="numeric" default="0">
	
	<cfset var getChildCats = getChildCategoriesByParent(catId, getAllCats)>
	<cfset var hasChildren = ""><!---does this category have child categories with articles in them?--->
	<cfset var getCatInfo = ""><!---fetch the current category's information and draw it.--->
	<cfset var catName = "">
	<cfset var childList = getCategoryChildrenList(catId, getAllCats)><!---used to see if the global attributes.catId is in this categories children, if it is it should use the triggerexpanded instead of trigger class.--->
	
	<cfquery dbtype="query" name="getCatInfo">
		SELECT category_name
		FROM getAllCats
		WHERE category_id = #catId#
	</cfquery>
	<cfloop query="getCatInfo">
		<cfset catName = category_name>
	</cfloop>
	
	<!---draw the opening of this categories div tag.--->
	<cfoutput>
		<ul  style="list-style:none;">	
			<li  style="list-style:none;">
				<a href="##cat#catId#">#catName#</a>
			</li>
			<!---draw child articles in the TOC if the attribute says to--->
			<cfif attributes.tocArticles>
				<cfset drawCatArticleToc(catId)>
			</cfif>
			
			<cfloop query="getChildCats">
				<cfset hasChildren = hasChildArticles(category_id, getAllCats)>
				
				<!---we only draw categories that have articles for our users in them.--->
				<cfif hasChildren>
					<cfset drawCatToc(category_id, level + 1)>
				</cfif>
			</cfloop>
		</ul>
	</cfoutput>
</cffunction>

<cffunction name="drawCatArticleToc">
	<cfargument name="catId" type="numeric">
	<cfset var getCatArticles = "">
	
	<cfquery dbtype="query" name="getCatArticles">
		SELECT article_id, title
		FROM getUserArticles
		WHERE category_id = #catId#
		ORDER BY sort_order, title
	</cfquery>
	
	<cfif getCatArticles.recordCount gt 0>
		<ul>
		<cfoutput query="getCatArticles">
			<li><a href="##art#article_id#">#title#</a></li>
		</cfoutput>
		</ul>
	</cfif>
	
</cffunction>

<cffunction name="drawCat">
	<cfargument name="catId" type="numeric" default="0">
	<cfargument name="delay" type="numeric" default="0">
	
	<cfset var getChildCats = getChildCategoriesByParent(catId, getAllCats)>
	<cfset var hasChildren = ""><!---does this category have child categories with articles in them?--->
	<cfset var getCatInfo = ""><!---fetch the current category's information and draw it.--->
	<cfset var catName = "">
	<cfset var childList = getCategoryChildrenList(catId, getAllCats)><!---used to see if the global attributes.catId is in this categories children, if it is it should use the triggerexpanded instead of trigger class.--->
	<cfset var getArticles = ""><!---fetch articles for this category.--->
	<cfset var wordCount = "">
	<cfset var countString = "">
	<cfset var longVisitLength = "">
	
	<cfquery dbtype="query" name="getCatInfo">
		SELECT category_name
		FROM getAllCats
		WHERE category_id = #catId#
	</cfquery>
	<cfloop query="getCatInfo">
		<cfset catName = category_name>
	</cfloop>
	
	<cfquery dbtype="query" name="getArticles">
		SELECT article_id, title, revision_content
		FROM getUserArticles
		WHERE category_id = #catId#
		ORDER BY sort_order, title
	</cfquery>
	
	<!---draw the opening of this categories div tag.--->
	<cfoutput>
		<cfif attributes.toc EQ true>
			<cfif catName NEQ categoryName AND catId NEQ categoryId>
				<h2><a name="cat#catId#">#catName#</a></h2>
			<cfelse>
				<a name="cat#catId#"></a>
			</cfif>
		</cfif>
		<!---draw any articles in this level.--->
		<cfloop query="getArticles">
			<hr/>
			<div>
				<h3><a id="art#article_id#">#title#</a></h3>
				#revision_content#
				<br/>
				<div style="clear: both;">
					<span class="tinytext" style="color:gray; font-style: italic;">End of article "#title#"</span><br/>
					<cfif attributes.tocArticles><span class="tinytext">Return to <a href="##top">Table of Contents</a></span></cfif>
				</div>
			</div>
			
			<!---now calculate the amount of time to delay reporting an article as read.--->
			<!---to set the time-out before an article is considered to have experienced a long view should be based on the word count, and the fact that even excellent speed-readers top-out at about 500wpm.  Let's get our word count.--->
			<cfset wordCount = 0>
			<cfset countString = stripTags(revision_content)><!---remove HTML from the content--->
			<cfset countString = reReplace(countString, "\s+", " ", "all")><!---replace all whitespace with just a single space--->
			<cfset countString = trim(countString)><!---trim leading and ending whitespace--->
			<cfset wordCount = listLen(countString, " ")><!---now we can treat countString like a list deliminated by spaces to find our word count.--->
			
			
			<cfset longVisitLength = (wordCount / 500) * 60 * 1000><!--- word count divided by 500 words per minute, times 60 to give us seconds, times 1000 to give us miliseconds.--->
			<cfset longVisitLength = round(longVisitLength)>
			
			<!---update the delay for the next pass.--->
			<cfset delay = delay + longVisitLength>
			<script type="text/javascript">
				/*setup the AJAX call to record long visits*/
				delaySubmit#article_id# = setTimeout("submitReadership(#article_id#)", #delay#);
			</script>
			
		</cfloop>
		<!---we only draw categories that have articles for our users in them.--->
		<cfloop query="getChildCats">
			<cfset hasChildren = hasChildArticles(category_id, getAllCats)>
			
			<cfif hasChildren>
				<cfset drawCat(category_id, delay)>
			</cfif>
		</cfloop>
		
	</cfoutput>
</cffunction>

<cffunction name="hasChildArticles">
	<cfargument name="catId">
	
	<!---fetch all the child categories for catId--->
	<cfset var childList = getCategoryChildrenList(catId, getAllCats)>
	<cfset var getArticles = "">
	
	<cfquery dbtype="query" name="getArticles">
		SELECT article_id
		FROM getUserArticles
		WHERE category_id IN (#childList#)
	</cfquery>
	
	<cfif getArticles.recordCount gt 0>
		<cfreturn 1>
	<cfelse>
		<cfreturn 0>
	</cfif>
</cffunction>