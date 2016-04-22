<cfmodule template="#application.appPath#/header.cfm" title="Site Map Link Editor">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/sitemap/sitemap_functions.cfm"><!---bring in some common functions--->

<!--- HEADER / NAVIGATION --->
<h1>Site Map Link Editor</h1>
<a href="<cfoutput>#application.appPath#/tools/sitemap/sitemap.cfm</cfoutput>">Go Back</a> |
<a href="<cfoutput>#cgi.script_name#</cfoutput>">Add New Link</a>

<!--- CFPARAMS --->
<cfparam name="frmLinkId" type="integer" default="0">
<cfparam name="frmText" type="string" default="">
<cfparam name="frmLink" type="string" default="">
<cfparam name="frmParentId" type="integer" default="0">

<!---cfparam name="frmMaskList" type="string" default="9"--->
<cfmodule template="#application.appPath#/modules/JSONparam.cfm" varName="frmMaskList" default="[9]">
<cfset frmMaskList = arrayToList(frmMaskList)><!---the multi-selector always returns an array, but we want a list.--->

<cfparam name="frmNewWindow" type="boolean" default="0">
<cfparam name="frmRetired" type="boolean" default="0">
<cfparam name="frmAction" type="string" default="">

<script type="text/javascript">
	$(document).ready(function(){
		//Activate any popovers on our page for tooltips.
		activatePopovers();
	});
</script>


<!---handle user input--->
<cfif frmAction eq "addLink" OR frmAction eq "editLink">
	<!---both adds and edits require the same verification.--->
	<cftry>
		<cfif trim(frmText) eq "">
			<cfthrow message="Missing Input" detail="<b>Text</b> field cannot be left blank.">
		</cfif>
		<cfif trim(frmLink) eq "" OR trim(frmLink) eq "##">
			<cfthrow message="Missing Input" detail="<b>Link</b> field cannot be left blank, nor simply '##'.">
		</cfif>

		<cfif frmLinkId gt 0>
			<cfquery datasource="#application.applicationDataSource#" name="updateLink">
				UPDATE tbl_header_links
				SET	text = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmText#">,
					link = <cfqueryparam cfsqltype="cf_sql_link" value="#frmLink#">,
					parent = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentId#">,
					new_window = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmNewWindow#">,
					retired = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmRetired#">
				WHERE link_id = #frmLinkId#
			</cfquery>
			<cfset message = "Link updated.">
			<p class="ok">
				<cfoutput>#message#</cfoutput>
			</p>
		<cfelse>
			<cfquery datasource="#application.applicationDataSource#" name="addLink">
				INSERT INTO tbl_header_links (text, link, parent, new_window)
				OUTPUT inserted.link_id
				VALUES (
					<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmText#">,
					<cfqueryparam cfsqltype="cf_sql_link" value="#frmLink#">,
					<cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentId#">,
					<cfqueryparam cfsqltype="cf_sql_bit" value="#frmNewWindow#">
				)
			</cfquery>
			<cfset frmLinkId = addLink.link_id>
			<cfset message = "Link Added.">
			<p class="ok">
				<cfoutput>#message#</cfoutput>
			</p>
		</cfif>

		<!---now handle the masks for our frmLinkId--->
		<cfquery datasource="#application.applicationDataSource#" name="linkMasks">
			BEGIN TRANSACTION
				DELETE FROM tbl_header_links_masks
				WHERE link_id = #frmLinkId#

				<cfif listLen(frmMaskList) gt 0>
					<cfset cnt = 1><!---this gets used to put a comma after each set of values, except for the last item in frmMaskList--->
					INSERT INTO tbl_header_links_masks (link_id, mask_id)
					VALUES
					<cfloop list="#frmMaskList#" index="maskId">
						(<cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkId#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">)<cfif cnt lt listLen(frmMaskList)>,</cfif>
						<cfset cnt = cnt + 1>
					</cfloop>
				</cfif>

				IF @@ERROR <> 0
					ROLLBACK
				ELSE
					COMMIT
		</cfquery>
		<cfset message = "#message#,Text:#frmText#,Link:#frmLink#,Parent:#frmParentId#,Masks: #frmMaskList#">
		<cfset recordLinkUpdate(frmLinkId,message)>
		<p class="ok">Required Masks updated.</p>

		<!---update the search index to reflect the change.--->
		<!---some links are complete URLS, some are relative.--->
		<cfset myLink = frmLink>
		<cfif not isValid('url', myLink) AND myLink neq "##">
			<cfset myLink = application.appPath & '/' & myLink>
		</cfif>

		<!---we need the mask_name for this link--->
		<cfset maskList = "">
		<cfquery datasource="#application.applicationDataSource#" name="getLinkMasks">
			SELECT um.mask_name
			FROM tbl_header_links_masks hlm
			INNER JOIN tbl_user_masks um ON um.mask_id = hlm.mask_id
			WHERE hlm.link_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmLinkId#">
			ORDER BY um.mask_name ASC
		</cfquery>
		<cfloop query="getLinkMasks">
			<cfset maskList = listAppend(maskList, mask_name)>
		</cfloop>

		<!---make an in-place query we can feed to indexSearchQuery()--->
		<cfset getLinks = queryNew("id,article_title,article_body,required_masks,article_date,article_url,category", "varchar,varchar,varchar,varchar,date,varchar,varchar")>
		<cfif myLink neq "##" AND not frmRetired><!---naturally we don't want links that don't go anywhere.--->
			<cfset queryAddRow(getLinks)>
			<cfset querySetCell(getLinks, "id", frmLinkId)>
			<cfset querySetCell(getLinks, "article_title", reReplace(frmText, "<[^>]*>", "", "all"))><!---trim out html tags and store the title--->
			<cfset querySetCell(getLinks, "article_body", reReplace(myLink, "<[^>]*>", "", "all"))>
			<cfset querySetCell(getLinks, "required_masks", maskList)>
			<cfset querySetCell(getLinks, "article_date", NOW())>
			<cfset querySetCell(getLinks, "article_url", myLink)>
			<cfset querySetCell(getLinks, "category", "Site&nbsp;Map")><!---weirdly categories can't contain a space.--->
			<cfset indexSearchQuery(getLinks)>
		<cfelse>
			<!---otherwise make sure this link isn't in the index anymore.--->
			<cfindex collection="v4-search" action="delete" type="custom" key="s#frmLinkId#">
		</cfif>

		<!---reset the user's input so we're pulling from the DB.--->
		<cfset form = structNew()>
	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</p>
	</cfcatch>
	</cftry>

</cfif>

<!---draw the form.  In the case of edits we need to fetch some data first.--->
<cfif frmLinkId gt 0>
	<h2 style="margin-bottom:0em; margin-top:0.5em;">Edit Link</h2>

	<!---fetch the link's information--->
	<cfquery datasource="#application.applicationDataSource#" name="getLink">
		SELECT text, link, parent, new_window, retired
		FROM tbl_header_links
		WHERE link_id = #frmLinkId#
	</cfquery>

	<cfif getLink.recordCount eq 0>
		<p class="warning">
			No link with ID <cfoutput>#frmLinkId#</cfoutput> was found.
		</p>
		<cfabort>
	</cfif>

	<cfloop query="getLink">
		<cfif structIsEmpty(form)>
			<cfset frmText = text>
			<cfset frmLink = link>
			<cfset frmParentId = parent>
			<cfset frmNewWindow = new_window>
			<cfset frmRetired = retired>

			<!---fetch the required masks, too and update those--->
			<cfquery datasource="#application.applicationDataSource#" name="getLinkMasks">
				SELECT lm.mask_id
				FROM tbl_header_links_masks lm
				INNER JOIN tbl_user_masks um ON um.mask_id = lm.mask_id
				WHERE link_id = #frmLinkId#
				ORDER BY mask_name
			</cfquery>
			<cfset frmMaskList = "">
			<cfloop query="getLinkMasks">
				<cfset frmMaskList = listAppend(frmMaskList, mask_id)>
			</cfloop>

		</cfif>
	</cfloop>
<cfelse>
	<h2 style="margin-bottom:0em; margin-top:0.5em;">Add Link</h2>
</cfif>


<form method="post" class="form-horizontal">
<cfoutput>
	<input type="hidden" name="frmLinkId" value="#frmLinkId#">
	<cfif frmLinkId gt 0>
		<input type="hidden" name="frmAction" value="editLink">
	<cfelse>
		<input type="hidden" name="frmAction" value="addLink">
	</cfif>

	#bootstrapCharField("frmText", "Link Text", frmText)#

	#bootstrapCharField("frmLink", "Link URL", frmLink, "Relative links will not be made relative to the server root, but to <b>#application.appPath#/</b>")#

	#bootstrapSelectField("frmParentId", getSMcategoriesArray(), "Category", frmParentId, "Links in top-level categories will be displayed in the header at the top of each page.", [0])#<!--the last item is to disable the no top-level category--->

	<cfset drawMasksSelector("frmMaskList", frmMaskList, "Required Masks", "Masks required to see this link.")>

	#bootstrapRadioField("frmNewWindow", [{"name"="Yes ", "value"="1"},{"name"="No ", "value"="0"}], "Open Link in New Window?", frmNewWindow)#

	<cfif frmLinkId gt 0>
		#bootstrapRadioField("frmRetired", [{"name"="Yes ", "value"="0"},{"name"="No ", "value"="1"}], "Active?", frmRetired)#
	</cfif>

	<br/>

	<cfif frmLinkId eq 0>
		<input class="btn btn-primary col-sm-offset-3" type="submit" value="Add Link">
	<cfelse>
		<input class="btn btn-primary col-sm-offset-3" type="submit" value="Edit Link">
	</cfif>
</cfoutput>
</form>




<cfmodule template="#application.appPath#/footer.cfm">