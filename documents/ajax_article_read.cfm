<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">

<cftry>
	<cfparam name="readId" type="integer">
	<cfparam name="articleId" type="integer">
	
	<!---if we don't have a readId, create it.--->
	<cfif readId eq 0>
		<!---check if they already have a readId for this article--->
		<cfquery datasource="#application.applicationDataSource#" name="getReadId">
			SELECT read_id
			FROM tbl_articles_readership
			WHERE article_id = #articleId#
			AND user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		</cfquery>
		
		<cfif getReadId.recordCount gt 0>
			<cfset readId = getReadId.read_id>
		<cfelse>
			<cfquery datasource="#application.applicationDataSource#" name="addReadId">
				INSERT INTO tbl_articles_readership (user_id, article_id)
				OUTPUT inserted.read_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
					#articleId#
				)
			</cfquery>
			
			<cfset readId = addReadId.read_id>
		</cfif>
	</cfif>
	
	
	<!---make sure the session user is the user for the provided readId--->
	<cfquery datasource="#application.applicationDataSource#" name="getReadership">
		SELECT user_id, article_id, first_view_date, recent_view_date, long_view, long_view_date
		FROM tbl_articles_readership
		WHERE read_id = #readId#
	</cfquery>
	
	<cfif getReadership.recordCount eq 0>
		<cfthrow message="readId not found.">
	</cfif>
	
	<cfloop query="getReadership">
		<cfif user_id neq session.cas_uid>
			<cfthrow message="Bad readId" detail="The readId provided does not belong to this user.">
		</cfif>
		
		<cfif article_id neq articleId>
			<cfthrow message="Bad articleId" detail="The articleId you provided did not match the article_id in the databse for #readId#">
		</cfif>
		
		<cfif long_view OR isDate(long_view_date)>
			<cfthrow message="Article has already been read.">
		</cfif>
	</cfloop>
	
	<!---having passed all those tests we can now update the database--->
	<cfquery datasource="#application.applicationDataSource#">
		UPDATE tbl_articles_readership
		SET long_view = 1,
			long_view_date = GETDATE()
		WHERE read_id = #readId#
	</cfquery>
	
<cfcatch>
	<cfheader statuscode="400" statustext="#cfcatch.message# - #cfcatch.detail#">
	<cfabort>
</cfcatch>
</cftry>

<!---we've reached the end tell the user everything is cool.--->
<cfheader statuscode="200" statustext="OK">