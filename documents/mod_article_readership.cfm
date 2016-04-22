<!---this page fetches the readership of a category, for articles created over a date-range, for a single user.--->
<cfif not isDefined("attributes")>
	<h1>Error</h1>
	<p>
		This page is to be exclusively used as a module, and cannot be browsed to.
	</p>
	<cfabort>
</cfif>

<!---since this is a module we may need to bring in our common functions.--->
<cfif not isDefined("getAllCategoriesQuery")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<!---make sure the viewer has permission to view this module's output--->
<cfif not hasMasks("cs")>

	<p>You do not have permission to use mod_individual_readership.cfm</p>
	<cfabort>
	
</cfif>	

<!---now gather up our parameters--->
<cfparam name="attributes.articleId" type="integer" default="0">
<cfparam name="attributes.read" type="boolean" default="0"><!---are we looking for read or unread articles?--->

<cfparam name="attributes.width" type="string" default="50%"><!---how wide should this item be?--->
<cfparam name="attributes.indentation" type="string" default="2em"><!---how much should each item in a list be indented.--->
<cfparam name="attributes.header" type="integer" default="1"><!---show the username and percent read?.--->

<!---fetch all categories for use with functions later.--->
<cfset allCats = getAllCategoriesQuery(0)><!---don't include retired categories.--->

<!--- get the article's info --->
<cfquery datasource="#application.applicationDataSource#" name="getArticle">
	SELECT a.article_id, ar.revision_id, ar.title, ar.revision_date
	FROM tbl_articles a
	INNER JOIN tbl_articles_revisions ar ON ar.article_id = a.article_id
	WHERE a.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#attributes.articleId#">
		  AND ar.use_revision = 1
		  AND ar.approved = 1
		  AND a.retired = 0
</cfquery>

<cfset revisionId = getArticle.revision_id>
		  
<cftry>
		
	<cfquery datasource="#application.applicationDataSource#" name="getArticleMasks">
		SELECT am.mask_id, um.mask_name
		FROM tbl_articles_masks am
		INNER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
		WHERE am.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#attributes.articleId#">
	</cfquery>
	
	<cfset maskList = "">
	<cfloop query="getArticleMasks">
		<cfset maskList = listAppend(maskList, mask_name)>
	</cfloop>
	
	<cfset users = getUsers(maskList, "Logistics, Admin")>
	
	<cfset userList = "">	
	
	<cfloop query="users">
		<cfset userList = listAppend(userList, user_id)>
	</cfloop>
	
	<cfoutput>
		<cfif attributes.header EQ 1>
			<h2 style="margin-bottom: 0px;">#getArticle.title#</h2>
		</cfif>
	</cfoutput>
	
	<!--- fetch all of the users with readership entries for this article --->
	<cfquery datasource="#application.applicationDataSource#" name="getReadership">
		SELECT r.first_view_date, r.recent_view_date, r.long_view, r.long_view_date,
		       u.first_name, u.last_name, u.username, u.user_id
		FROM tbl_users u
		INNER JOIN tbl_articles a ON a.article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#attributes.articleId#">
		LEFT OUTER JOIN tbl_articles_readership r ON r.user_id = u.user_id AND r.article_id = a.article_id
		WHERE u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" list="yes" value="#userList#">)
		ORDER BY u.last_name ASC, u.username ASC
	</cfquery>
	
	<!---find out how many users have read the article based on userList and getReadership --->
	<cfset readTotal = listLen(userList)> <!--- total number of users --->
	<cfset readCnt = 0> <!--- number of users that have read the article --->
	<cfloop query="getReadership">
		<cfif isDate(first_view_date)>
			<cfset readCnt = readCnt + 1>
		</cfif>
	</cfloop>
	
	<cfif readTotal NEQ 0>
	
		<cfoutput>
			<cfif attributes.header EQ 1>
				<p>
					<span class="tinytext">#readCnt# of #readTotal# users have read the article:  #numberFormat((readCnt/readTotal)*100, 99.9)#% readership.</span>		
				</p>
			</cfif>
		</cfoutput>
		
		<!---now draw the read / not read lists of users --->	
		<h3>Read</h3>
		<cfoutput>
		<table class="stripe">
			<tr class="titlerow">
				<th>User</th>
				<th>First View</th>
				<th>Last View</th>
				<th>Long View?</th> <!--- shows whether the user stayed long enough to read the article --->
			</tr>
			
			<cfloop query="getReadership">		
				
				<cfif isDate(first_view_date)>
				
					<tr>
						<td>#first_name# #last_name# (#username#)</td>
						<td>#dateTimeFormat(first_view_date, "mmm d, yyyy h:nn aa")#</td>
						<td>#dateTimeFormat(recent_view_date, "mmm d, yyyy h:nn aa")#</td>
						<td><cfif long_view>Yes<cfelse>No</cfif></td>
					</tr>
					
				</cfif>
			
			</cfloop>
		
		</cfoutput>
		</table>
		
		<h3>Unread</h3>
		<cfoutput>
		<table class="stripe">
			<tr class="titlerow">
				<th>User</th>
			</tr>
			<cfloop query="getReadership">		
				
				<cfif NOT isDate(first_view_date)>
				
					<tr>
						<td>#first_name# #last_name# (#username#)</td>
					</tr>
					
				</cfif>
			
			</cfloop>
		
		</cfoutput>
		</table>
		
		<cfelse>

		<p>No users have viewed this article. </p>

	</cfif>
		
	<cfcatch>
		<p class="warning"><cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput></p>
	</cfcatch>
</cftry>

<cffunction name="getUsers">
	<cfargument name='maskList'><!---masks the user must have to be listed--->
	<cfargument name='negMaskList'><!---masks the user must NOT have to be listed--->
	
	<cfset var getUsers = "">
	<cfset var getNegUsers = "">
	<cfset var userList = "0"><!---list of users from getUsers--->
	<cfset var bulkMasks = "">
	<cfset var passes = ""><!---has the user passed the tests of both maskList and negMaskList?--->
	<cfset var myMask = ""><!---used when looping over maskLists--->
	<cfset var goodUsers = queryNew("user_id,username,last_name,first_name","integer,varchar,varchar,varchar")>
	
	<!---use a query to fetch all the users who satisfy the requirements of maskList, then use bulkGetUserMasks() and bulkHasMasks() to check if they violate negMaskList--->
	<cfquery datasource="#application.applicationDataSource#" name="getUsers">
		SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
		FROM tbl_users u
		<cfif listLen(maskList) gt 0>
			WHERE 1 = 1
			<cfloop list="#maskList#" index="myMask">
				AND EXISTS (SELECT amu.mask_id
				            FROM vi_all_masks_users amu
				            INNER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
				            WHERE amu.user_id = u.user_id
				                  AND um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#trim(myMask)#">)
			</cfloop>
		</cfif>
		ORDER BY last_name, first_name, username
	</cfquery>
	
	<!---build a list of users who have the masks we do want to know about.--->
	<cfloop query="getUsers">
		<cfset userList = listAppend(userList, user_id)>
	</cfloop>
	
	<!---now, if we have a negMaskList, we want to make sure none of our users have masks we don't want. Run a query to find the undesired users.--->
	<cfif listLen(negMaskList) gt 0>
		<cfquery datasource="#application.applicationDataSource#" name="getNegUsers">
			SELECT DISTINCT u.user_id, u.username, u.last_name, u.first_name
			FROM tbl_users u
			LEFT OUTER JOIN vi_all_masks_users amu ON amu.user_id = u.user_id
			LEFT OUTER JOIN tbl_user_masks um ON um.mask_id = amu.mask_id
			<cfif listLen(maskList) gt 0>
				WHERE 0 = 1
				<cfloop list="#negMaskList#" index="myMask">
					OR um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#trim(myMask)#">
				</cfloop>
			</cfif>
			AND u.user_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#userList#" list="true">)/*constrain to users we've decided could be included*/
			ORDER BY last_name, first_name, username
		</cfquery>
	</cfif>
	
	<cfloop query="getUsers">
		<cfset passes = 1><!---assume they've passed--->
		
		<!---if we have a negative mask list we need to make sure this user doesn't have any of those masks--->
		<cfif listLen(negMaskList) gt 0>
			<cfloop query="getNegUsers">
				<cfif getNegUsers.user_id eq getUsers.user_id>
					<cfset passes = 0>
					<cfbreak>
				</cfif>
			</cfloop>
		</cfif>
		
		<cfif passes>
			<cfset queryAddRow(goodUsers)>
			<cfset querySetCell(goodUsers, "user_id", user_id)>
			<cfset querySetCell(goodUsers, "username", username)>
			<cfset querySetCell(goodUsers, "last_name", last_name)>
			<cfset querySetCell(goodUsers, "first_name", first_name)>
		</cfif>
	</cfloop>
	
	<cfreturn goodUsers>

</cffunction>