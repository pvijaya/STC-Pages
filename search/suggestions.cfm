<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<!---this page takes a parameter "term" and returns any article titles it finds in our search index.--->


<cfparam name="term" type="string" default="">
<cfset output = "">

<!--don't start searching until we have at least two characters--->
<cfif len(trim(term)) gt 1>
	<!---conduct the search, but only in the handbook and documentation.--->
	<cfsearch collection="v4-search" name="searchQry" type="dismax" criteria="#term#" suggestions="1" status="searchStatus" category="Documentation,Handbook">
	
	<!--- here things get a little wild.   We need to weed out all the articles the viewer doesn't have the masks for.--->
	<cfquery datasource="#application.applicationDataSource#" name="getUserMasks">
		SELECT um.mask_id, um.mask_name
		FROM vi_all_masks_users mu
		INNER JOIN tbl_user_masks um ON um.mask_id = mu.mask_id
		WHERE mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	</cfquery>
	
	<!---loop over the require masks, if the user doesn't have one, say they can't view it.--->
	<cfset searchResults = queryNew("category,context,key,rank,recordssearched,required_masks,revised,score,title,type,url", "varchar,varchar,varchar,integer,integer,varchar,date,decimal,varchar,varchar,varchar")>
	
	<cfloop query="searchQry">
		<cfset canView = 1>
		<cfloop list="#required_masks#" index="mask">
			<!---if we require masks, default to they cannot view it.--->
			<cfset canView = 0>
			<cfloop query="getUserMasks">
				<cfif mask eq mask_name>
					<cfset canView = 1>
					<cfbreak>
				</cfif>
			</cfloop>
			<!---if we ever reach this point and canView is still 0, they can't view it and we can break the loop.--->
			<cfif not canView>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<cfif canView>
			<!---solr uses a date format cf doesn't get, so make it compatible.--->
			<cfset myDate = replace(revised, "T", " ", "all")>
			<cfset myDate = replace(myDate, "Z", "", "all")>
			<!---now convert it back from UTC time to local.--->
			<cfif isDate(myDate)>
				<cfset myDate = dateAdd("s", 0-GetTimeZoneInfo().UTCTotalOffset, myDate)>
			<cfelse>
				<cfset myDate = now()>
			</cfif>
			
			<!---and here we want to weed out any WAY out of date announcements and newsletter articles(those over 1 year old)--->
			<cfif not (listFindNoCase("Announcements,Newsletter", category) AND dateCompare(dateAdd('yyyy', 1, myDate), now()) lt 0)>
				<cfset queryAddRow(searchResults)>
				
				<cfset querySetCell(searchResults, "category", category)>
				<cfset querySetCell(searchResults, "context", context)>
				<cfset querySetCell(searchResults, "key", key)>
				<cfset querySetCell(searchResults, "rank", rank)>
				<cfset querySetCell(searchResults, "recordssearched", recordssearched)>
				<cfset querySetCell(searchResults, "required_masks", required_masks)>
				<cfset querySetCell(searchResults, "revised", myDate)>
				<cfset querySetCell(searchResults, "score", score)>
				<cfset querySetCell(searchResults, "title", title)>
				<cfset querySetCell(searchResults, "type", type)>
				<cfset querySetCell(searchResults, "url", url)>
			</cfif>
		</cfif>
	</cfloop>
	<!---cfdump var="#searchResults#" expand="false"--->
	
	<!---limit the number of suggestions--->
	<cfquery dbtype="query" name="searchResults" maxrows="10">
		SELECT *
		FROM searchResults
		ORDER BY rank ASC
	</cfquery>
	
	<cfset cnt = 1><!---should we append a comma?--->
	<cfloop query="searchResults">
		<cfset output = output & '{"id": "#htmlEditFormat(title)#", "label": "#htmlEditFormat(title)#", "value": "#htmlEditFormat(title)#"}'>
		<cfif cnt lt searchResults.recordCount>
			<cfset output = output & ",">
		</cfif>
		
		<cfset cnt = cnt+1>
	</cfloop>
	
</cfif>

<cfoutput>[#output#]</cfoutput>