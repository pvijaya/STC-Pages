<cfmodule template="#application.appPath#/header.cfm" title="Search">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="searchTerm" type="string" default="">
<cfparam name="searchCats" type="string" default="Documentation">
<cfparam name="resultsPerPage" type="integer" default="50">
<cfparam name="pageNum" type="integer" default="0">
<cfparam name="sortByDate" type="integer" default="0">

<cfset myInstance = getInstanceById(session.primary_instance)>

<!---strip out unwanted spaces--->
<cfset searchCats = replace(searchCats, ", ", ",", "all")>

<!---handle pagination of results--->
<cfif resultsPerPage lt 1>
	<cfset resultsPerPage = 1>
</cfif>

<cfif pageNum lt 0>
	<cfset curPage = 0>
</cfif>

<!--- build a list of categories that could be checked off --->
<cfquery datasource="#application.applicationDataSource#" name="getTopCats">
	SELECT category_id, category_name
	FROM tbl_articles_categories
	WHERE parent_cat_id = 0
		  AND retired = 0
	ORDER BY sort_order, category_name
</cfquery>

<cfset catsList = "">
<cfloop query="getTopCats">
	<cfset catsList = listAppend(catsList, category_name)>
</cfloop>

<!---add files category since they live ourside of the article system--->
<cfset catsList = listAppend(catsList, "Files")>
<!---add the site map, too.--->
<cfset catsList = listAppend(catsList, "Site&nbsp;Map")><!---weirdly category names can't contain spaces, but this takes care of it.--->

<!---sort catsList so they are in alphabetical order.--->
<cfset catsList = listSort(catsList, "textnocase", "asc")>

<!--- trim out any problematic characters don't use with dismax
<cfset searchTerm = sanitizeSearch(searchTerm)> --->

<!--- STYLE --->
<!--- clean up the search results --->
<style type="text/css">

	div.result div.indent {
		margin-left: 1em;
	}

</style>

<!--- JAVASCRIPT --->
<!--- add auto-suggestions when typing --->
<script type="text/javascript">
	$(document).ready(function(){
		//listen to user input and suggest
		$("input[name='searchTerm']").autocomplete({
			source: "suggestions.cfm",
			minLength: 2
		});
	});
</script>

<!--- DRAW SEARCH FORM --->
<cfif session.primary_instance NEQ 0>
	<h1><cfoutput>#myInstance.instance_mask# Search</cfoutput></h1>
<cfelse>
	<h1>Search</h1>
</cfif>

<form action="index.cfm" method="post">

	<strong>Show Results From:</strong>

	<!--- draw category selectors --->
	<cfloop list="#catsList#" index="catName">
		<cfset catTextColor = catColor(catName)> <!--- see if there is a special color associated with this category --->
		<label style="color: <cfoutput>#catTextColor#;</cfoutput>">
			<input type="checkbox" name="searchCats" value="<cfoutput>#htmlEditFormat(catName)#</cfoutput>"
				   <cfif listContains(searchCats, catName) OR listLen(searchCats) eq 0>checked</cfif> />
			<cfoutput>#catName#</cfoutput>
		</label>
	</cfloop>

	<br/>

	<!--- draw sort options --->
	<strong>Sort Results By:</strong>
	<label>
		<input type="radio" name="sortByDate" value="0" <cfif sortByDate EQ 0>checked="true"</cfif>>Relevance
	</label>
	<label>
		<input type="radio" name="sortByDate" value="1" <cfif sortByDate EQ 1>checked="true"</cfif>>Date
	</label>

	<br/><br/>

	<input type="text"  placeholder="Search..." name="searchTerm" size="60"
		   value="<cfoutput>#htmlEditFormat(searchTerm)#</cfoutput>">

	<input type="Submit"  value="Go">

</form>

<hr/>

<!--- DRAW SEARCH RESULTS --->

<cftry>

	<cfif trim(searchTerm) neq "">

		<!--- this will allow us to turn term into a special Solr query if necessary --->
		<cfset term = searchTerm>

		<!--- this performs the search, and stores the results in a query called searchQry. --->
		<!--- we call lcase on the search term because cfsearch will be case-insensitive if the term consists --->
		<!--- of only uppercase or lowercase letters but case-sensitive if there is a mix. --->
		<!--- we want to be case-insensitive, so lcase the term string before searching --->
		<cfsearch collection="v4-search" name="searchQry" type="dismax" criteria="#lcase(term)#" suggestions="1"
				  contextBytes="5000" contextPassages="3" contexthighlightbegin="<span style='font-weight: bold;'>"
				  contexthighlightend="</span>" status="searchStatus" category="#searchCats#">

		<!--- weed out all the articles the viewer doesn't have the masks for. --->
		<cfquery datasource="#application.applicationDataSource#" name="getUserMasks">
			SELECT um.mask_id, um.mask_name
			FROM vi_all_masks_users mu
			INNER JOIN tbl_user_masks um ON um.mask_id = mu.mask_id
			WHERE mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		</cfquery>

		<cfset negUserMasks = "">

		<!--- if we have a valid primary instance, handle instance-splitting --->
		<cfif session.primary_instance GT 0>

			<!--- fetch all masks for instances other than the primary --->
			<cfquery datasource="#application.applicationDataSource#" name="getNegUserMasks">
				SELECT um.mask_id, um.mask_name
				FROM vi_all_masks_users mu
				INNER JOIN tbl_user_masks um ON um.mask_id = mu.mask_id
				INNER JOIN tbl_instances i ON i.instance_mask = um.mask_name
				WHERE mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
					  AND i.instance_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
			</cfquery>

			<!--- build a list of masks we don't want to consider for the search. --->
			<!--- since this is all non-primary instances, the search will only display results from --->
			<!--- one campus at a time. --->
			<cfloop query="getNegUserMasks">
				<cfset negUserMasks = listAppend(negUserMasks, mask_name)>
			</cfloop>

		</cfif>

		<!--- loop through getUserMasks; if a mask is in negUserMasks, do not include it --->
		<cfset userMasks = "">
		<cfloop query="getUserMasks">
			<cfif NOT listFindNoCase(negUserMasks, mask_name)>
				<cfset userMasks = listAppend(userMasks, mask_name)>
			</cfif>
		</cfloop>

		<!--- loop over the required masks for the results. --->
		<!--- if the user doesn't have the necessary masks for a result, do not display it. --->

		<!--- store all viewable search results in a new searchResults query --->
		<cfset searchResults = queryNew("category,context,key,rank,recordssearched,required_masks,revised,score,title,type,url",
										"varchar,varchar,varchar,integer,integer,varchar,date,decimal,varchar,varchar,varchar")>

		<cfloop query="searchQry">

			<cfset canView = 1>

			<cfloop list="#required_masks#" index="mask">

				<!--- if any masks are required, default to no --->
				<cfset canView = 0>

				<!--- loop over the user's masks and look for matches --->
				<cfloop list="#userMasks#" index="mask_name">
					<cfif mask EQ mask_name>
						<cfset canView = 1>
						<cfbreak>
					</cfif>
				</cfloop>

				<!--- if we ever reach this point and canView is still 0, break the loop. --->
				<cfif not canView>
					<cfbreak>
				</cfif>

			</cfloop>

			<cfif canView>

				<!--- solr uses a date format cf doesn't get, so make it compatible. --->
				<cfset myDate = replace(revised, "T", " ", "all")>
				<cfset myDate = replace(myDate, "Z", "", "all")>

				<!--- now convert it back from UTC time to local. --->
				<cfif isDate(myDate)>
					<cfset myDate = dateAdd("s", 0-GetTimeZoneInfo().UTCTotalOffset, myDate)>
				<cfelse>
					<cfset myDate = now()>
				</cfif>

				<!--- and here we want to weed out any WAY out of date announcements and newsletter articles --->
				<!--- those over 1 year old, in particular --->
				<cfif NOT (listFindNoCase("Announcements,Newsletter", category)
					  AND dateCompare(dateAdd('yyyy', 1, myDate), now()) LT 0)>

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

		<cfif sortByDate EQ 1>

			<!--- if the user selected 'Sort Results by Date', sort the query --->
			<cfquery name="sortedSearchResults" dbtype="query">
				SELECT *
				FROM searchResults
			 	ORDER BY revised DESC
			</cfquery>

			<cfset searchResults = sortedSearchResults>

		</cfif>

		<!--- draw our pagination. --->
		<cfset drawPage(pageNum, searchResults.recordCount, resultsPerPage)><p/>

		<!--- draw the results. --->

		<!--- cnt helps us number the results --->
		<cfset cnt = 1>

		<cfoutput query="searchResults">

			<!---handle pagination--->
			<cfif cnt gt (pageNum * resultsPerPage) AND cnt lte ((pageNum+1)*resultsPerPage)>

				<!--- display level by title, not digit --->
				<cfset pos = 'Any'>
				<cfif listLen(required_masks) gt 0>
					<cfset pos = required_masks>
				</cfif>

				<!--- we'll highlight the cat name to correspond to the filter options --->
				<cfset highLightColor = catColor(category)>


				<a style="display:block;text-align:left;" class="block-card hover-box" href="#url#">
					#cnt#. <strong>#title#</strong>

                    <span class="indent">

						<span style="display:block;" class="tinytext">
							<cfif isDate(revised)>#dateFormat(revised, "mmm d, yyyy")#</cfif>
							<span style="color: #highLightColor#;"><strong>#category#</strong></span>
							Masks: #pos#
						</span>

						<span style="display:block;" class="restxt">
							<!--- if this is a file, provide the thumbnai l--->
							<cfif category eq "Files">
								<cfset fileId = right(key, len(key)-1)>
								<img src="#application.appPath#/tools/filemanager/get_thumbnail.cfm?fileId=#fileId#" style="vertical-align: text-top; max-height: 75px;">
							</cfif>
							#context#
						</span>

					</span>

				</a>

			</cfif>

			<cfset cnt = cnt + 1>

		</cfoutput>

		<!--- search recording chunk --->
		<script type="text/javascript">

			$(document).ready(function(){
				$("a.searchlink").on("mousedown", function(e){
					e.preventDefault(); //prevent the page from whisking us away before our work is done.

					var myLink = $(this);
					var linkCnt = myLink.attr("linkcnt");
					var linkUrl = myLink.attr("href");

					$.ajax({
						url: '<cfoutput>#application.appPath#/search/recorder.cfm</cfoutput>',
						type: 'POST',
						dataType: 'html',
						async: false,//make this thing run like regular code.
						data: {
							searchTerm: '<cfoutput>#htmlEditFormat(searchTerm)#</cfoutput>',
							link: linkUrl,
							rank: linkCnt,
							searchCats: '<cfoutput>#htmlEditFormat(searchCats)#</cfoutput>'
						},
						error: function (){
							console.log("Error encountered recording search information.");
						},
						/*use complete because we don't care if it worked or not.*/
						complete: function(data,text){
							if($.trim(text) != 'success'){//Got weirdly case-sensitive.
								console.log("Error encountered recording search information.");
							}

							//take the user to their intended destination.
							//that doesn't work well with the middle mouse button.
							//window.location.href = linkUrl;
						}
					});

					return true; //this (might) make the event that was prevented keep on going?  Either way, the mouseUp is going to fire next, anyhow.

				});
			});

		</script>

		<!--- draw our pagination --->
		<cfset drawPage(pageNum, searchResults.recordCount, resultsPerPage)>

	<cfelse>
		<p>Please enter a search term.</p>
	</cfif>

<cfcatch type="any">
	<cfoutput>
		<p>#cfcatch.Message# - #cfcatch.detail#</p>
	</cfoutput>
</cfcatch>
</cftry>

<!--- FUNCTIONS --->

<!---this function trims out characters that might break the process of turning our user input into a Verity Query.--->
<cffunction name="sanitizeSearch">
	<cfargument name="userSearch" type="string" default="">

	<cfset var formattedSearch = userSearch>
	<!---trim out all but single quotes, matched double quotes, question marks, periods, spaces and *'s.--->
	<cfset formattedSearch = reReplace(formattedSearch, "[^a-z|A-Z|0-9|?|.|""|'|\ |*|\-|+|@]", "", "all")>


	<!---remove orphaned double quotes.--->
	<cfif arrayLen(ReMatch('"', formattedSearch)) mod 2 neq 0>
		<!---there is a dangling quote mark, trim it off.--->
		<cfset formattedSearch = reverse(replace(reverse(formattedSearch), '"', ''))>
	</cfif>

	<cfreturn formattedSearch>
</cffunction>

<!---takes a category, and returns a color associated with it, if any.--->
<cffunction name="catColor" output="false">
	<cfargument name="typeString" type="string" default="0">

	<cfset var colorClass = "">

	<!----Distributes color class based on typeId--->
	<cfswitch expression="#typeString#">
		<cfcase value="Announcements">
			<cfset colorClass = '##994800'>
		</cfcase>
		<cfcase value="Documentation">
			<cfset colorClass = '##209900'>
		</cfcase>
		<cfcase value="Site&nbsp;Map">
			<cfset colorClass = '##990099'>
		</cfcase>
		<cfcase value="Handbook">
			<cfset colorClass = '##999900'>
		</cfcase>
		<cfcase value="TCC Tome"><!---also gone.--->
			<cfset colorClass = '##009999'>
		</cfcase>
		<cfcase value="Files">
			<cfset colorClass = '##000099'>
		</cfcase>
		<cfcase value="Newsletter">
			<cfset colorClass = '##1D823E'>
		</cfcase>
		<cfdefaultcase>
			<cfset colorClass = '##000000'>
		</cfdefaultcase>
	</cfswitch>

	<cfreturn colorClass>
</cffunction>

<!---draw the links for navigating between pages, lifted from customer contacts. --->
<cffunction name="drawPage">
	<cfargument name="page" type="numeric" required="true">
	<cfargument name="total" type="numeric" required="true">
	<cfargument name="perPage" type="numeric" default="50">

	<cfset var getVars = "sortByDate=#urlEncodedFormat(sortByDate)#&searchTerm=#urlEncodedFormat(searchTerm)#&searchCats=#urlEncodedFormat(searchCats)#">
	<cfset var maxPage = iif(total mod perPage, total\perPage + 1, total\perPage)>

    <cfoutput>Results for "#searchterm#"</cfoutput><br />

	<cfoutput>Displaying records #(page * perPage) + 1# to #iif((total lt perPage * (page+1)), total, (page+1) * perPage)#  of #total#<br/></cfoutput>

	<cfif total gt perPage>
		<cfif page gt 0>
			<cfoutput><a href="index.cfm?pageNum=0&#getVars#">&lt;&lt;</a> <a href="index.cfm?pageNum=#page-1#&#getVars#">&lt;</a></cfoutput>
		</cfif>

		<cfoutput>Page #page+1# of #maxPage#</cfoutput>

		<cfif page lt maxPage-1>
			<cfoutput><a href="index.cfm?pageNum=#page+1#&#getVars#">&gt;</a> <a href="index.cfm?pageNum=#maxPage-1#&#getVars#">&gt;&gt;</a></cfoutput>
		</cfif>
	</cfif>
</cffunction>
<cfmodule template="#application.appPath#/footer.cfm">