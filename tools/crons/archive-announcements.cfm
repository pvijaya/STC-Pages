<!---
	NOTE NOTE NOTE!
	This file runs as a cron-job, and could be run by just about anyone.
	Make sure that the page does not generate any output.
	This file retires announcements more than 2 years old, and sorts announcements into folders by month and year.
	Ideally you'd want the announcements sorted by semester, but IUB and IUPUI semesters don't always match up.
--->

<!---wrap our work in a cftry tag to catch any problem.--->
<cftry>
	<!---fetch our articles and categories--->
	<cfset getArticles = fetchArticles(3)>
	<cfset getCategories = fetchCategories(3)>
	
	
	<!---Our first task will be to put unsorted articles into the correct category--->
	<!---START OF ORGANIZING--->
	<cfquery dbtype="query" name="unorganizedArticles">
		SELECT *
		FROM getArticles
		WHERE category_id = 3
		ORDER BY created_date
	</cfquery>
	
	<!---Now, loop over unorganizedArticles, placing them in the correct category(year-month)--->
	<cfloop query="unorganizedArticles">
		<cfset myCatName = dateFormat(created_date, "MMMM yyyy")>
		<cfset myCatId = 0><!---0 means we haven't found a matching id and will need to create one--->
		
		<!---try to find a category that matches myCatName--->
		<cfloop query="getCategories">
			<cfif category_name eq myCatName AND parent_cat_id eq 3>
				<cfset myCatId = getCategories.category_id>
				<cfbreak><!---we found a match, break out of the loop.--->
			</cfif>
		</cfloop>
		
		<!---if at this point we still don't have a good myCatId we need to create the category.--->
		<cfif myCatId eq 0>
			<!---create the category--->
			<cfquery datasource="#application.applicationDataSource#" name="addCat">
				INSERT INTO tbl_articles_categories (parent_cat_id, category_name, sort_order)
				OUTPUT inserted.category_id
				VALUES (3, <cfqueryparam cfsqltype="cf_sql_varchar" value="#myCatName#">, 1)
			</cfquery>
			
			<cfset myCatId = addCat.category_id>
			
			<!---audit the category's creation.--->
			<cfset auditString = "<p>Category created by #cgi.script_name#</p>">
			<cfquery datasource="#application.applicationDataSource#" name="addCatAudit">
				INSERT INTO tbl_articles_categories_audit (category_id, user_id, audit_text)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#category_id#">,
					0,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditString#">
				)
			</cfquery>
			
			<!---we've created a new category, and thus need to update our getCategories query.--->
			<cfset getCategories = fetchCategories(3)>
		</cfif>
		
		<cfif myCatId eq 0>
			<cfthrow type="custom" message="myCatId" detail="We do not have a valid category_id for this unsorted article.  #article_id#">
		</cfif>
		
		<!---update the article to use our category.--->
		<cfquery datasource="#application.applicationDataSource#" name="updateArticle">
			UPDATE tbl_articles
			SET category_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myCatId#">
			WHERE article_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#article_id#">
		</cfquery>
		
	</cfloop>
	<!---END OF ORGANIZING--->
	
	
	<!---START SORTING CATEGORIES--->
	<!---loop from the present back to the time of the first announcement, setting the sort-order as we go.--->
	<cfset startDate = dateFormat(now(), "yyyy-mm-01")>
	<cfset endDate = "2004-01-01">
	
	<cfset monthCount = dateDiff("m", endDate, startDate)>
	
	<cfloop from="0" to="#monthCount#" index="i">
		<cfset curDate = dateAdd("m", -i, startDate)>
		<cfset myCatName = dateFormat(curDate, "MMMM yyyy")>
		<cfset myCatId = 0>
		
		<cfloop query="getCategories">
			<cfif category_name eq myCatname AND parent_cat_id eq 3>
				<cfquery datasource="#application.applicationDataSource#" name="setCatOrder">
					UPDATE tbl_articles_categories
					SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#i#">
					WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getCategories.category_id#">
				</cfquery>
			</cfif>
		</cfloop>
	</cfloop>
	
	<!---sort orders have changed, so re-fetch our categories.--->
	<cfset getCategories = fetchCategories(3)>
	<!---END SORTING CATEGORIES--->
	
	<!---START RETIRE OLD ANNOUNCEMENTS--->
	<!---make a list of categories that announcments could be living in.--->
	<cfset catList = "">
	<cfloop query="getCategories">
		<cfset catList = listAppend(catList, category_id)>
	</cfloop>
	
	<!---run an update to retire articles older than 2-years old.--->
	<cfquery datasource="#application.applicationDataSource#" name="retireArticles">
		UPDATE tbl_articles
		SET retired = 1
		OUTPUT inserted.article_id
		WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#catList#" list="true">)
		AND retired = 0
		AND created_date < DATEADD(year, -1, GETDATE())
	</cfquery>
	
	<!---now use those id's in the output cluase to audit the retirement.--->
	<cfloop query="retireArticles">
		<cfset auditString = "<ul><li><b>Retired</b> by #cgi.script_name#</li></ul>">
		<cfquery datasource="#application.applicationDataSource#" name="auditRetirement">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
				0,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditString#">
			)
		</cfquery>
		
		<!---also when we retire an announcment we need to remove it from the search index.--->
		<cfindex collection="v4-search" action="delete" type="custom" key="a#article_id#">
	</cfloop>
	<!---END RETIRE OLD ANNOUNCEMENTS--->
	
	<!---Retire announcement categories that have no active articles in them.--->
	<cfset catList = getCategoryChildrenList(3)>
	
	<!--- the first element will be "3", the announcments category, we certainly don't want to retire that.--->
	<cfset catList = listDeleteAt(catList, 1)>
	
	<cfquery datasource="#application.applicationDataSource#" name="getCatArticleCount">
		SELECT ac.category_id, COUNT(a.article_id) AS article_count
		FROM tbl_articles_categories ac
		LEFT OUTER JOIN tbl_articles a
			ON a.category_id = ac.category_id
			AND a.retired = 0
		WHERE ac.retired = 0
		AND ac.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#catList#" list="true">)
		GROUP BY ac.category_id
	</cfquery>
	
	<cfloop query="getCatArticleCount">
		<cfif article_count eq 0>
			<!---this category has no articles in its top level(which is the only place announcements should end up), so we can retire it.--->
			<cfquery datasource="#application.applicationDataSource#" name="retireCategory">
				UPDATE tbl_articles_categories
				SET retired = 1
				WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#category_id#">
			</cfquery>
			
			<!---now audit our retirement of this category.--->
			<cfset auditString = "<ul><li><b>Retired</b> by #cgi.script_name#</li></ul>">
			<cfquery datasource="#application.applicationDataSource#" name="auditRetirement">
				INSERT INTO tbl_articles_categories_audit (category_id, user_id, audit_text)
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#category_id#">,
					0,
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditString#">
				)
			</cfquery>
		</cfif>
	</cfloop>
	
	<!---one more announcement task.  Make sure announcements are sorted by the date they were posted.---->
	<cfset getArticles = fetchArticles(3)>
	
	<!---sort the articles as we'd like them.--->
	<cfquery dbtype="query" name="sortedArticles">
		SELECT *
		FROM getArticles
		WHERE retired = 0
		ORDER BY category_id, created_date, article_id
	</cfquery>
	
	<cfloop query="sortedArticles" group="category_id">
		<cfset myOrder = 0>
		<cfloop>
			<cfset myOrder = myOrder + 1>
			<!---actually update the articles's sort_order in the DB.--->
			<cfquery datasource="#application.applicationDataSource#" name="updateArticleOrder">
				UPDATE tbl_articles
				SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#myOrder#">
				WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">
			</cfquery>
		</cfloop>
	</cfloop>
	<!---end of sorting announcements.--->
	
	
	<!---NEWSLETTER STUFF--->
	<cfset getCategories = fetchCategories(7)>
	
	<!---our category names are in the format of a year and a month, we can parse that out to a date, and then retire their articles accordingly!--->
	<cfloop query="getCategories">
		<cfif isDate(category_name)>
			<cfset myDate = parseDateTime(category_name)>
			
			<cfif dateDiff("m", myDate, now()) gt 12>
				
				<!---fetch the articles for this category---->
				<cfset nlArticles = fetchArticles(category_id)>
				
				<!---retire those articles---->
				<cfloop query="nlArticles">
					<cfif not retired>
						<cfquery datasource="#application.applicationDataSource#" name="retireNLArticle">
							UPDATE tbl_articles
							SET retired = 1
							WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">
						</cfquery>
						
						<cfset auditString = "<ul><li><b>Retired</b> by #cgi.script_name#</li></ul>">
						<cfquery datasource="#application.applicationDataSource#" name="auditRetirement">
							INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
							VALUES (
								<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
								0,
								<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditString#">
							)
						</cfquery>
						
						<!---also when we retire an article we need to remove it from the search index.--->
						<cfindex collection="v4-search" action="delete" type="custom" key="a#article_id#">
					</cfif>
				</cfloop>
				
				<!---retire this category--->
				<cfif not retired>
					<cfquery datasource="#application.applicationDataSource#" name="retireNLcategory">
						UPDATE tbl_articles_categories
						SET retired = 1
						WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#category_id#">
					</cfquery>
					
					<cfset auditString = "<ul><li><b>Retired</b> by #cgi.script_name#</li></ul>">
					<cfquery datasource="#application.applicationDataSource#" name="auditRetirement">
						INSERT INTO tbl_articles_categories_audit (category_id, user_id, audit_text)
						VALUES (
							<cfqueryparam cfsqltype="cf_sql_integer" value="#category_id#">,
							0,
							<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditString#">
						)
					</cfquery>
				</cfif>
			</cfif>
		</cfif>
	</cfloop>
	
<cfcatch>
	<cfmail to="tccpie@indiana.edu,tccwm@iu.edu" from="pie@indiana.edu" subject="Archive Announcements Failure" type="html">
		<p class="warning">
			#cfcatch.Message# - #cfcatch.Detail#
		</p>
	</cfmail>
</cfcatch>
</cftry>

<cffunction name="fetchCategories" output="false">
	<cfargument name="parent" type="numeric" required="true">
	
	<cfset var catList = getCategoryChildrenList(parent)>
	<cfset var getCategories = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getCategories">
		SELECT category_id, parent_cat_id, category_name, sort_order, retired
		FROM tbl_articles_categories
		WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#catList#" list="true">)
	</cfquery>
	
	<cfreturn getCategories>
</cffunction>

<cffunction name="fetchArticles" output="false">
	<cfargument name="parent" type="numeric" required="true">
	<cfset var catList = getCategoryChildrenList(parent)>
	<cfset var getArticles = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getArticles">
		SELECT article_id, category_id, creator_id, sort_order, created_date, retired
		FROM tbl_articles
		WHERE category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#catList#" list="true">)
	</cfquery>
	
	<cfreturn getArticles>
</cffunction>