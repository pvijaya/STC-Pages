<cfmodule template="#application.appPath#/header.cfm" title='V3 links' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">


<cfquery datasource="#application.applicationDataSource#" name="getRevisions">
	SELECT TOP 100 a.article_id, a.created_date, c.*, ar.*
	FROM tbl_articles a
	INNER JOIN tbl_articles_categories c ON c.category_id = a.category_id
	INNER JOIN tbl_articles_revisions ar ON ar.article_id = a.article_id
	WHERE a.retired = 0
	
	AND use_revision = 1
	AND (
		revision_content LIKE '%v3/forms/file%'
		OR revision_content LIKE '%"stcpages/v4/documents/view.cfm%'
	)
	
	ORDER BY revision_date DESC
</cfquery>


<!---find the masks for all our articles--->
<cfset articleList = "">
<cfloop query="getRevisions">
	<cfset articleList = listAppend(articleList, article_id)>
</cfloop>

<cfquery datasource="#application.applicationDataSource#" name="getArticlesMasks">
	SELECT am.article_id, um.mask_name
	FROM tbl_articles_masks am
	INNER JOIN tbl_user_masks um ON um.mask_id = am.mask_id
	WHERE am.article_id IN (<cfqueryparam cfsqltype="cf_sql_integer" value="#articleList#" list="true">)
</cfquery>


<!---the next few queries are needed for converting links in articles articles from V3 to V4--->
<!---both storeRevisions() and cleanArticle() use the following query.--->
<cfquery datasource="#application.applicationDataSource#" name="getArticleConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_articles
</cfquery>

<!---and the same for handbook articles.--->
<cfquery datasource="#application.applicationDataSource#" name="getHandbookConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_handbook_articles
</cfquery>

<!--- and handbook categories--->
<cfquery datasource="#application.applicationDataSource#" name="getHandbookCatConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_handbook_categories
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getFileConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_filemanager_files
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getAnnouncementConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_announcements
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getNewsletterConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_newsletter_articles
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getNewsletterCatConversions">
	SELECT instance_id, old_id, new_id
	FROM tbl_conversion_newsletter_categories
</cfquery>


<cfoutput query="getRevisions">
	<!---determine is this article came from IUB or IUPUI for use with cleanArticle--->
	<cfset instanceId = 1>
	<cfloop query="getArticlesMasks">
		<cfif getRevisions.article_id eq getArticlesMasks.article_id AND mask_name eq "IUPUI">
			<cfset instanceId = 2>
			<cfbreak>
		</cfif>
	</cfloop>
	
	
	<cfset prevContent = revision_content>
	<cfset cleanContent = cleanArticle(instanceId, revision_content)>
	
	<cfloop condition="cleanContent neq prevContent">
		
		<cfset prevContent = cleanContent>
		<cfset cleanContent = cleanArticle(instanceId, prevContent)>
	</cfloop>
	
	
	<cfif revision_content neq cleanContent>
		<h2>#article_id#</h2>
		<h3>Old</h3>
		#revision_content#
		<h3>New</h3>
		#cleanContent#
		<hr/>
		
		<!---make the change and audit the change.
		<cfquery datasource="#application.applicationDataSource#" name="updateRevision">
			UPDATE tbl_articles_revisions
			SET revision_content = <cfqueryparam cfsqltype="cf_sql_varchar" value="#cleanContent#">
			WHERE revision_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#revision_id#">
		</cfquery>
		
		<cfset auditText = "<ul><li>Fixed broken links from V3 import in <b>Revision #revision_id#</b></li></ul>">
		
		<cfquery datasource="#application.applicationDataSource#" name="auditRevision">
			INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
			VALUES(
				<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">,
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				<cfqueryparam cfsqltype="cf_sql_varchar" value="#auditText#">
			)
		</cfquery>
		--->
	</cfif>
</cfoutput>

<cffunction name="cleanArticle">
	<cfargument name="instanceId" type="numeric" required="1"><!---which instance's records should we be looking in when fixing links?--->
	<cfargument name="content" type="String" required="1">
	
	<cfset var match = ""><!---where our regex tests end up.--->
	<cfset var tempString = ""><!---a little work space for our edits.--->
	<cfset var v3IdTemp = "">
	<cfset var v3Id = 0>
	<cfset var v4Id = 0>
	<cfset var tstart = "">
	<cfset var tend = "">
	
	
	<!---first, let's try to catch and fix links to other articles.--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/view\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/view\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getARticleConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---there are still a few golden oldies knocking around with broken links to the original document viewer from before V3--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/content_view_article\.\s*cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/content_view_article\.\s*cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<!--- now that we have a v3id we can pair that up with the new v4id--->
		<cfset v4id = 0>
		<cfloop query="getARticleConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---in some of the tomes they used valid HTML that is a pain in the butt, just a ?article_id=nnn  Let's replace those with full URLs--->
	<cfset match = reFindNoCase('<a href="\?article_id=\d+', content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, '<a href="\?', '<a href="tetra/documents/article.cfm?')>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<!--- now that we have a v3id we can pair that up with the new v4id--->
		<cfset v4id = 0>
		<cfloop query="getARticleConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix links to handbook articles--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/+v3/docs/handbook/handbook_view_article\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/+v3/docs/handbook/handbook_view_article\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix older handbook links, too.--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/handbook/handbook\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/handbook/handbook\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---then fix EVEN OLDER handbook links.--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/content/handbook/handbook\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/content/handbook/handbook\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix old print handbook links--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/handbook/handbook_print\.cfm\?[^'"">]*article_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_print\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("article_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "article_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	
	<!---fix handbook categories--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/handbook/handbook_readthrough\.cfm\??[^'"">]*##cat_id_\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_readthrough\.cfm", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("cat_id_\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getHandbookCatConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "cat_id_\d+", "cat#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	<!---fix generic handbook readthrough links.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_readthrough\.cfm(?!##cat_id_\d+)", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm", "all")>
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook\.cfm\??[^'"">]*(?!article_id=\d+)", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm", "all")>
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook\.html", "tetra/documents/handbook_#iif(instanceId eq 1, de('iub'), de('iupui'))#.cfm", "all")>
	
	<!---fix links to the announcement viewer--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/docs/announcements/announcements_viewer\.cfm\?[^'"">]*ann_id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/docs/announcements/announcements_viewer\.cfm", "tetra/documents/article.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("ann_id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfloop query="getAnnouncementConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "ann_id=\d+", "articleId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	<!---file manager links, there are two cases, one were we have a fileId and another where we have a filePath--->
	<cfif reFindNoCase("stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm", content)><!---this prevents infinite loops of re-detected v4 id's to change.--->
		
		<!---We're ready to find and fix filemanager ID based links.--->
		<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm\?[^'"">]*fileId=\d+", content, 1, true)>
		
		<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
			<cfset tempString = mid(content, match.pos[1], match.len[1])>
			
			<!---debugging
			<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
			
			<!---now we need to find the correct v4 file_id number for the one linked to.--->
			<cfset v3IdTemp = reFindNoCase("fileId=\d+", tempString, 1, true)>
			<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
			
			<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
			<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
			
			<!---now that we have our v3 ID we need to find the matching v4id--->
			<cfset v4id = 0>
			<cfloop query="getFileConversions">
				<cfif instance_id eq instanceId AND old_id eq v3id>
					<cfset v4id = new_id>
					<cfbreak>
				</cfif>
			</cfloop>
			
			<!---cfdump var="#tempString#"><br/--->
			
			<!---with both ID's we can make our replacement.--->
			<cfset tempString = reReplaceNoCase(tempString, "fileId=\d+", "fileId=#v4Id#")>
			<!---Also fix the start of the URL to use our new location--->
			<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm", "tetra/tools/filemanager/get_file.cfm", "one")>
			
			<!---cfdump var="#tempString#"--->
			
			<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
			<cfset tEnd = match.pos[1] + match.len[1]>
			<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
		</cfif>
		
		<!---We're ready to find and fix filemanager path based links, urls should have been preservered between versions.--->
		<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm\?[^'"">]*filePath=", content, 1, true)>
		
		<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
			<cfset tempString = mid(content, match.pos[1], match.len[1])>
			
			<!---this is much simpler than the fileId, as filePaths should have been preserved during importing of files, we just need to change the base url.--->
			<!---cfdump var="#tempString#"><br/--->
			
			<!---Fix the start of the URL to use our new location--->
			<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/forms/filemanager/get_file\.cfm", "tetra/tools/filemanager/get_file.cfm", "one")>
			
			<!---cfdump var="#tempString#"--->
			
			<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
			<cfset tEnd = match.pos[1] + match.len[1]>
			<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
		</cfif>
	</cfif>
	
	<!---fix links to the filemanager itself--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/filemanager/manager\.cfm", "tetra/tools/filemanager/manager.cfm", "all")>
	
	<!---fix newsletter links--->
	<cfset match = reFindNoCase("stcpages/(iub|iupui)/v3/newsletter/newsletter_view\.cfm\?[^'"">]*id=\d+", content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		
		<!---debugging
		<li><cfoutput>#htmlEditFormat(tempString)#</cfoutput></li>--->
		
		<!---fix the base URL--->
		<cfset tempString = reReplaceNoCase(tempString, "stcpages/(iub|iupui)/v3/newsletter/newsletter_view\.cfm", "tetra/documents/newsletter.cfm")>
		<!---now we need to find the correct v4 article number for the one linked to.--->
		<cfset v3IdTemp = reFindNoCase("id=\d+", tempString, 1, true)>
		<cfset v3IdTemp = mid(tempString, v3IdTemp.pos[1], v3IdTemp.len[1])>
		
		<cfset v3Id = reFindNoCase("[\d]+", v3IdTemp, 1, true)>
		<cfset v3Id = mid(v3IdTemp, v3Id.pos[1], v3Id.len[1])>
		
		<cfset v4id = -1>
		<cfloop query="getNewsletterCatConversions">
			<cfif instance_id eq instanceId AND old_id eq v3id>
				<cfset v4Id = new_id>
				<cfbreak>
			</cfif>
		</cfloop>
		
		<!---armed with that ID we can create the correct URL.--->
		<cfset tempString = reReplaceNoCase(tempString, "id=\d+", "catId=#v4Id#")>
		
		<cfset tStart = iif(match.pos[1] gt 1, match.pos[1] - 1, 1)>
		<cfset tEnd = match.pos[1] + match.len[1]>
		<cfset content = left(content, tStart) & tempString & mid(content, tEnd, len(content) - tEnd + 1)>
	</cfif>
	
	<!---fix links to the old newsletter main page.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/newsletter/(?![\w\s])", "tetra/documents/newsletter.cfm", "all")>
	
	
	<!---There are some old images in a static folder of v3, and some img tags use relative links to find them.  make them explicit.--->
	<cfset content = reReplaceNoCase(content, "src=[""]+images[/\\]?", "src=""stcpages/" & iif(instanceId eq 1, de("IUB"), de("IUPUI")) & "/v3/docs/images/", "all")><!---double-quoted url--->
	<cfset content = reReplaceNoCase(content, "src=[']+images[/\\]?", "src='stcpages/" & iif(instanceId eq 1, de("IUB"), de("IUPUI")) & "/v3/docs/images/", "all")><!---single-quoted url--->
	<cfset content = reReplaceNoCase(content, "src=images[/\\]?", "src=stcpages/" & iif(instanceId eq 1, de("IUB"), de("IUPUI")) & "/v3/docs/images/", "all")><!---un-quoted url--->
	
	<!---links to lab distrobution.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/utils/labdist/labdist\.cfm", "tetra/tools/lab-distribution/lab-distribution.cfm", "all")>
	
	<!---fix links to the trainings report--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/return/consults_report\.cfm", "tetra/tools/training-report/training-report.cfm", "all")>
	
	<!---fix links to the search--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/search/index\.cfm", "tetra/search.index.cfm", "all")>
	
	<!---fix links to the incident report form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/incident\.cfm", "tetra/tools/incident-report/incident-report.cfm", "all")>
	
	<!---fix links to the routes listing.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/labs\.cfm", "tetra/tools/routes/view_routes.cfm", "all")>
	
	<!---old awards have been phased out, we have a Gold Star Hall of Fame instead.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/AwardsReport\.cfm", "tetra/tools/awards/gold-stars-report.cfm", "all")>
	
	<!---catch the IC-Cleaning form--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/ic-cleaning/", "tetra/tools/ic-cleaning/", "all")>
	<cfset content = replaceNoCase(content, "tetra/tools/ic-cleaning/index.cfm", "tetra/tools/ic-cleaning/ic-cleaning.cfm", "all")>
	
	<!---replace the old content browser with the new one.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/content_index\.cfm", "tetra/documents/index.cfm", "all")>
	
	<!---fix urls for PIE thumbnails--->
	<cfset content = replaceNoCase(content, "../../../../iupuistc/thumbnails", "/apps/iupuistc/thumbnails", "all")>
	<cfset content = replaceNoCase(content, "../../../../tcc/thumbnails", "/apps/tcc/thumbnails", "all")>
	
	<!---fix some bad relative links to the old article tool so they're caught by the next pass.--->
	<cfset content = replaceNoCase(content, "../../../iub/v3/docs/view.cfm", "stcpages/iub/v3/docs/view.cfm", "all")>
	
	<!---fix links to the chat icon editor--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/chat3/chat_edit_icons\.cfm", "tetra/chat/chat_edit_icons.cfm", "all")>
	
	<!---fix links to the chat database search--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/chat3/chat_db\.cfm", "tetra/chat/chat-history.cfm", "all")>
	
	<!---fix links to the shift report--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/utils/cs/shiftreport\.cfm", "tetra/tools/shift-report/shift-report.cfm", "all")>
	
	<!---point folks to the new account check form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/account_check\.cfm", "tetra/tools/account-check/account-check.cfm", "all")>
	
	<!---view all announcements have changed.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/announcements/announcements_box\.cfm\?[^'"">]*viewall=((yes)|(true)|(1))", "tetra/documents/index.cfm?frmCatId=3", "all")>
	
	<!---fix links to the handbook acknowledgement form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/docs/handbook/handbook_ack\.cfm", "tetra/handbook/acknowledgement-form.cfm", "all")>
	
	<!---fix links to the sub plea form.--->
	<cfset content = reReplaceNoCase(content, "stcpages/(iub|iupui)/v3/forms/sub_plea\.cfm", "tetra/tools/sub-plea/sub-plea.cfm", "all")>
	
	<!---I created a bug where I mis-imported several article links links--->
	<cfset content = reReplaceNoCase(content, '"stcpages/v4/documents/view.cfm', '"/apps/stcpages/v4/documents/article.cfm', "all")>
	
	<!---	DONE	--->
	<!---Now just find random links and display them/replace them.
	<cfset match = reFindNoCase('\<[^\>]+src[^\>]+\>|\<[^\>]+href[^\>]+\>|\<[^\>]+url[^\>]+\>', content, 1, true)>
	<cfif match.pos[1] gt 0 AND match.len[1] gt 0>
		<cfset tempString = mid(content, match.pos[1], match.len[1])>
		<cfoutput>
			<li <cfif findNoCase("v3", tempString)>style="background-color: yellow;"</cfif>>#htmlEditformat(tempString)#</li>
		</cfoutput>
		
		<!---now replace it so we can make our next pass.--->
		<cfset content = reReplaceNoCase(content, "\<[^\>]+src[^\>]+\>|\<[^\>]+href[^\>]+\>|\<[^\>]+url[^\>]+\>", "", "one")>
	</cfif>
	--->
	<cfreturn content>
</cffunction>