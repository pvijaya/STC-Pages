<cfmodule template="#application.appPath#/header.cfm" title="Newsletter Manager">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Article Editor">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- cfparams --->
<cfparam name="frmAction" type="string" default="">
<cfparam name="frmInstance" type="integer" default="0">
<cfparam name="frmNLtitle" type="string" default="">
<cfparam name="frmCatId" type="numeric" default="0">

<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- header / navigation --->
<cfoutput><h1>Newsletter Manager (#myInstance.instance_name#)</h1></cfoutput>

<!--- set-up --->
<cfset init()>

<!--- handle user input --->

<cfif frmAction EQ "create newsletter">

	<cftry>
		
		<cfif trim(frmNLTitle) eq "">
			<cfthrow message="Newsletter Title" detail="Newsletter Title is a required field, and cannot be left blank.">
		</cfif>
		
		<!---now, try to create our new newsletter--->
		<cfquery datasource="#application.applicationDataSource#" name="addCat">
			INSERT INTO tbl_articles_categories (parent_cat_id, category_name)
			OUTPUT inserted.category_id
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#nlCatId#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmNLTitle#">
			)
		</cfquery>
		
		<p class="ok">
			Newsletter created successfully.
		</p>
		
		<cfset init()>
			
	<cfcatch>
		<cfset frmAction = "create">
		<cfoutput>
			<p class="warning">
				#cfcatch.Message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
</cfif>

<!---now, if we have a frmCatId, let's whisk them off to the editor page.--->
<cfif frmCatId gt 0>
	<cflocation url="newsletter_editor.cfm?frmCatId=#frmCatId#" addtoken="false">
</cfif>

<!--- draw forms --->
<cfif frmAction EQ "create">
	
	<h2>New Newsletter</h2>
	
	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		
		<!--- we want to try and keep our newsletter titles in yyyy-mm format, so the date parser can understand them --->
		<label>Newsletter Title:
			<input name="frmNLtitle" placeholder="<cfoutput>#dateFormat(now(), "yyyy-mm")#</cfoutput>" value="<cfoutput>#htmlEditFormat(frmNLTitle)#</cfoutput>">
		</label>
		
		<input name="frmAction" type="submit" value="Create Newsletter">
		
	</form>
	
	<p><cfoutput><a href="#cgi.script_name#">Choose Another Newsletter</a></cfoutput></p>

<cfelse>

	<!---build up a query of all the articles that are under a given newsletter, we want to know how many there are and if they are all published.--->
	<cfset nlArticles = queryNew("category_id, article_count, published_count", "integer, integer, integer")>
	<cfloop query="getNewsletters">
		<cfset myCat = category_id>
		<cfset myArticles = 0>
		<cfset myPub = 0> <!---The count of how many articles are marked as published.--->
		 
		<cfset childCats = getCategoryChildrenList(myCat, getCategories)>
		<cfloop list="#childCats#" index="catId">
			<cfloop query="getArticles">
				<cfif catId eq category_id>
					<cfset myArticles = myArticles + 1>					
					<cfif approved eq 1>
						<cfset myPub = myPub + 1>
					</cfif>
				</cfif>
			</cfloop>
		</cfloop>
		
		<!---now that we have our counts, add them to nlArticles.--->
		<cfset queryAddRow(nlArticles)>
		<cfset querySetCell(nlArticles, "category_id", myCat)>
		<cfset querySetCell(nlArticles, "article_count", myArticles)>
		<cfset querySetCell(nlArticles, "published_count", myPub)>
	</cfloop>

	<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
		<fieldset>
			<legend>Choose</legend>
			
			<label>
				Select a Newsletter:
				<select name="frmCatId">
					<cfoutput query="getNewsletters">
						<option value="#category_id#">
							#category_name#
							<cfloop query="nlArticles">
								<cfif getNewsletters.category_id EQ nlArticles.category_id>
									<cfif article_count EQ 0>
										(No Articles)
									<cfelseif article_count EQ published_count>
										(Published)
									<cfelseif published_count EQ 0>
										(Unpublished)
									<cfelse>
										(Unpublished Articles)
									</cfif>
									<cfbreak><!---we got our info, break out of this loop.--->
								</cfif>
							</cfloop>
						</option>
					</cfoutput>
				</select>
			</label>
			<input type="submit"   value="Go">
			
			<!--- prevent non-owners from creating new newsletters --->
			<cfif hasMasks('newsletter owner')> 
			
				<span style="padding-left: 2em; padding-right: 2em; font-weight: bold;">OR</span>
				
				<a href="<cfoutput>#cgi.script_name#?frmAction=create</cfoutput>">Create New Newsletter</a>
			
			</cfif> 
			
		</fieldset>
	</form>

</cfif>

<!--- keep all of the set-up functions in one place for easy calling --->
<cffunction name="init">
		
	<!--- fetch all article categories to speed up certain queries and reduce database pings --->
	<cfset getCategories = getAllCategoriesQuery(0)> <!--- don't include retired categories. --->
	
	<!--- get the newsletter's cat id - 7 --->
	<cfset newsletter = 7>
	
	<!--- we need to determine which campus we are at, and default to that one --->
	<!--- fetch the newsletter cat associated with the user's Session.primary_instance --->
	<cfquery datasource="#application.applicationDataSource#" name="getNLInstance">
		SELECT ac.category_id 
		FROM tbl_articles_categories ac
		INNER JOIN tbl_articles_categories_owner aco ON aco.category_id = ac.category_id
		INNER JOIN tbl_user_masks um ON um.mask_id = aco.mask_id
		WHERE um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#myInstance.instance_mask#">
			  AND ac.parent_cat_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#newsletter#">
	</cfquery>
	
	<cfset nlCatId = getNLInstance.category_id>
	
	<!--- fetch the newsletter cats - the children of the instance cat found above --->
	<cfset getNewsletters = getChildCategoriesByParent(getNLInstance.category_id, getCategories)>
	
	<!--- now, fetch the newsletter kittens (children of cats) --->
	<cfset nlCatList = getCategoryChildrenList(getNLInstance.category_id, getCategories)>
	
	<!--- fetch info about all our newsletters' articles, so we can find out which ones are published. --->
	<cfquery datasource="#application.applicationDataSource#" name="getArticles">
		SELECT a.article_id, category_id, ar.approved
		FROM tbl_articles a
		INNER JOIN tbl_articles_revisions ar ON ar.article_id = a.article_id
		WHERE a.retired = 0
			  AND ar.use_revision = 1
			  AND a.category_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#nlCatList#" list="true">)
	</cfquery>
			
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">