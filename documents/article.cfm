

<cfparam name="articleId" type="integer" default="0">
<cfparam name="revisionId" type="integer" default="0"><!---users can speicify they wish to view a specific revision of the document.--->
<cfparam name="catId" type="integer" default="0">
<cfset isEditor = hasMasks("Article Editor")><!---is the current user someone who can edit articles?--->
<cfset isOwner = 0><!---are they an owner for this articles category?--->

<!---we have to fetch the article's information to know if the user has the permissions to view it.--->
<cfquery datasource="#application.applicationDataSource#" name="getArticle">
	SELECT a.category_id, a.creator_id, u.username, a.created_date, a.retired
	FROM tbl_articles a
	LEFT OUTER JOIN tbl_users u ON u.user_id = a.creator_id
	WHERE article_id = #articleId#
</cfquery>

<!---if we didn't find an article display a suitable error message.--->
<cfif getArticle.recordCount eq 0>
	<cfmodule template="#application.appPath#/header.cfm" title="Article Viewer">
	<div style="width:25%;float:left;margin-right:15px;" class="print-hide">
		<div class="panel panel-default">
			<cfmodule template="#application.appPath#/documents/mod_browse.cfm" width="100%" catId="#catId#">
		</div>
	</div>
	<div style="float:right;"  id="articleId">
	<cfoutput>
		<h1>Article Viewer</h1>
		<cfif articleId EQ 0>
			<h2>TCC Content</h2>
			<p>The TCC Content system is a collection of announcements, articles, the handbook, and the newsletter.
				In the sidebar, we have a set of folders and documents.
				Folders have a light gray background with an arrow pointing to the right if the folder is closed. Once you open a folder,
				it will have an arrow pointing down and a darker gray background. Documents appear with a white background and a red font.</p>
			<p></p>
			<div><img style="width: 447px;margin: 0px auto;display: block;" src="https://#cgi.server_name#/apps/stcpages/IUB/images/tcc_logo_big.jpg"></div>

		<cfelse>
		<h2>Lost Article</h2>
		<p>
			No article found with ID #articleId#. Try using the TCC Content on your left to navigate.
		</p>
		</cfif>
	</cfoutput>
	</div>
	<cfinclude template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>

<cfset catId = 0>
<cfset author = "">
<cfset created = "1900-01-01">
<cfset retired = 0>
<cfset title = "">
<cfset content = "">
<cfset editor = "">
<cfset editDate = "1900-01-01">
<cfset activeRevision = 0>
<cfset approvedId = -1>

<cfloop query="#getArticle#">
	<cfset catId = category_id>
	<cfset author = username>
	<cfset created = created_date>
	<cfset retired = retired>
</cfloop>

<!---fetch the masks required to view this article.--->
<cfquery datasource="#application.applicationDataSource#" name="getMasks">
	SELECT am.mask_id, m.mask_name
	FROM tbl_articles_masks am
	JOIN tbl_user_masks m ON m.mask_id = am.mask_id
	WHERE article_id = #articleId#
</cfquery>

<cfset maskList = "">
<cfset maskNames = "">
<cfloop query="getMasks">
	<cfset maskList = listAppend(maskList, mask_id)>
	<cfset maskNames = listAppend(maskNames, mask_name)>
</cfloop>

<!---determine if the article's category has ownership masks to satisfy.--->
<cfset ownerMasks = listAppend(maskList, getInheritedOwnerMasks(catId))>
<cfset isOwner = hasMasks(ownerMasks)>

<!---do they have all the maks required to view this article?--->
<cfif not hasMasks(maskList)>
	<cfmodule template="#application.appPath#/header.cfm" title="Article Viewer">
	<div style="width:25%;float:left;margin-right:15px;" class="print-hide">
		<div class="panel panel-default">
			<cfmodule template="#application.appPath#/documents/mod_browse.cfm" width="100%">
		</div>
	</div>
	<div style="float:right;"  id="articleId">
	<cfoutput>
		<h1>Article Viewer</h1>
		<h2>Access Denied</h2>
		<p>
			You do not possess all the masks required to view article ###articleId#.
		</p>
	</cfoutput>
	</div>
	<cfinclude template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>

<!---having gotten this far we can fetch the actual content of the article.--->
<cfquery datasource="#application.applicationDataSource#" name="getContent">
	SELECT TOP 1 r.revision_id, r.title, r.revision_content, r.user_id, u.username, use_revision, revision_date, r.approved,
					(SELECT category_id FROM tbl_articles WHERE article_id = #articleId#) AS "parentId"
	FROM tbl_articles_revisions r
	LEFT OUTER JOIN tbl_users u ON u.user_id = r.user_id
	WHERE r.article_id = #articleId#
	<cfif revisionId lte 0>
		AND r.use_revision = 1
	<cfelse>
		AND r.revision_id = #revisionId#
	</cfif>

	<cfif not isEditor>
		AND r.approved = 1
	</cfif>

	ORDER BY r.revision_date DESC
</cfquery>
<cfloop query="getContent">
	<cfset title = getContent.title>
	<cfset content = revision_content>
	<cfset editor = username>
	<cfset editDate = revision_date>
	<cfset revisionId = revision_id>
	<cfset activeRevision = use_revision>
	<cfset approvedId = approved>
	<cfset parentId = getContent.parentId>
</cfloop>

<cfif getContent.recordCount eq 0>
	<cfmodule template="#application.appPath#/header.cfm" title="Article Viewer">
	<cfoutput>
		<p class="warning">
			Article not found.
		</p>
		<p>
			Could not find an entry for article with ID #articleId# and revision ID #revisionId#.
		</p>
	</cfoutput>
	<cfinclude template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>

<!---now that we finally have the title we can include our header and draw the revision the user requested.--->
<cfmodule template="#application.appPath#/header.cfm" title="#title#">
<div style="width:25%;float:left;margin-right:15px;" class="print-hide">
	<div class="panel panel-default">
		<cfmodule template="#application.appPath#/documents/mod_browse.cfm" width="100%" catId="#parentId#" articleSelected="#articleId#">
	</div>
</div>
<div style="float:right;" id="articleId">
<!---if an article is retired, let them know such.--->
<cfif retired>
	<cfoutput>
		<p class="warning">
			Article ###articleId# has been retired.
		</p>

		<cfif not isEditor>
			<!---don't show the rest of the article to non-editors.--->
			<cfinclude template="#application.appPath#/footer.cfm">
			<cfabort>
		</cfif>
	</cfoutput>
</cfif>
<!---We've gotten this far, draw the actual article.--->
<cfoutput>
	<h1>#title#</h1>
	<cfloop list="#maskNames#" index="maskName">
		<span class="ui-state-default ui-corner-all">#maskName#</span>
	</cfloop>

	<p class="tinytext" style="font-style: italic;">
		Last Edited on #dateFormat(editDate, "mmm d, yyyy")# at #timeFormat(editDate, "short")# by #editor#
		<cfif isEditor>
			<br/><a href="article_editor.cfm?frmArticleId=#articleId#&frmRevisionId=#revisionId#" style="font-style: normal;">Edit This Article</a>
			| <a href="report_article_readership.cfm?frmArticleId=#articleId#" style="font-style: normal;">View Readership</a>
		</cfif>
	</p>

	<!---warn if we're looking at a non-current version--->
	<cfif not activeRevision>
		<p class="warning">
			Viewing a non-current version of this article
		</p>
	</cfif>

	<cfif approvedId neq 1>
		<div class="alert">
			This revision
			<cfif approvedId eq 0>
				has <b>not yet been approved</b>
			<cfelse>
				was <b>rejected</b>
			</cfif>
			and is not availble to non-editors.
			The information it provides may be out of date or incorrect.

			<!---if they are an owner of the article's category allow them to approve it.--->
			<cfif isOwner AND isEditor>
				<br/>
				<a href="my_approvals.cfm?frmAction=approve&frmRevisionId=#revisionId#" onClick="return(confirm('Approving this revision will make it visible to everyone who views this article.'));">Approve this revision</a>
				<br/>
				<a href="my_approvals.cfm?frmAction=reject-confirm&frmRevisionId=#revisionId#&fromArticle=1">Reject this revision</a>
			</cfif>

		</div>
	</cfif>

	<div class="content">
		#content#
	</div>
</cfoutput>


<!---now fetch and draw the history of this article--->

<br/><br/>
<span class="trigger">Article History</span>
<div class="shadow-border" id="articleHistory">
	<h2 style="padding:0px 5px;margin:5px 0px;">Article History</h2>

	<!---fetch the previous versions/revisions so the viewer can review them.--->
	<cfquery datasource="#application.applicationDataSource#" name="getRevisions">
		SELECT ar.revision_id, u.username, ar.title, ar.comment, ar.revision_date, ar.use_revision, ar.approved
		FROM tbl_articles_revisions ar
		INNER JOIN tbl_users u ON u.user_id = ar.user_id
		WHERE ar.article_id = #articleId#
		<cfif not isEditor>
			/*don't show normal users pending or rejected versions.*/
			AND approved = 1
		</cfif>
		ORDER BY ar.revision_date DESC
	</cfquery>

	<h3 style="padding:0px 5px;margin:5px 0px;">Versions</h3>
	<table class="stripe">
		<tr class="titlerow">
			<td colspan="3">
				Previous Versions
			</td>
		</tr>
		<tr class="titlerow2">
			<th>Date</th>
			<th>Details</th>
			<th>Status</th>
		</tr>

		<cfoutput query="getRevisions">
			<tr>
				<td align="right" class="tinytext">
					#dateFormat(revision_date, "mmm d, yyyy")#
					<span class="tinytext">#timeFormat(revision_date, "short")#</span><br/>
				</td>
				<td>
					<cfif revision_id neq revisionId>
						<a href="article.cfm?articleId=#articleId#&revisionId=#revision_id#">#title#</a>
					<cfelse>
						#title#
					</cfif>

					<span class="tinytext" style="font-style: italic;">by #username#</span>
					<cfif comment neq "">
						<br/>
						<!---If it's short just draw it, if it's long make it a trigger.--->
						<cfif len(comment) lt 20>
							<span class="tinytext">#comment#</span>
						<cfelse>
							<span class="tinytext trigger">Comment</span>
							<div class="tinytext">#comment#</div>
						</cfif>
					</cfif>
				</td>
				<td>
					<cfif revision_id eq revisionId>
						<em>Viewing</em><br/>
						<!---if the version they are view is approved and they are an editor let them set this as the revision to use.--->
						<cfif isEditor AND not activeRevision AND approved eq 1>
							<span class="tinytext">
								[<a href="article_editor.cfm?frmAction=setVersion&frmArticleId=#articleId#&frmRevisionId=#revisionId#" onClick="return confirm('Are you certain you want this revision to be the one people see when browsing to this article?');">set as current version</a>]
							</span>
							<br/>
						</cfif>

						<!---and allow owners to un-approve a revision.--->
						<cfif isOwner and isEditor and approved neq -1>
							<span class="tinytext">
								[<a href="my_approvals.cfm?frmAction=reject-confirm&frmRevisionId=#revision_id#&fromArticle=1">Reject</a>]
							</span>
							<br/>
						</cfif>
					</cfif>


					<cfif use_revision>
						Current Version
					<cfelse>
						<!---show the current status of this revision--->
						<cfif approved eq -1>
							<span class="tinytext">Rejected</span>
						<cfelseif approved eq 0>
							<span class="tinytext">Not Approved</span>
						<cfelse>
							<span class="tinytext">Approved</span>
						</cfif>
					</cfif>
				</td>
			</tr>
		</cfoutput>
	</table>

<!---for editors show the article's history of changes, too.--->
<cfif isEditor>
	<cfquery datasource="#application.applicationDataSource#" name="getAudits">
		SELECT aa.audit_id, u.username, aa.audit_date, aa.audit_text
		FROM tbl_articles_audit aa
		INNER JOIN tbl_users u ON u.user_id = aa.user_id
		WHERE aa.article_id = #articleId#
		ORDER BY audit_date DESC
	</cfquery>

	<h2 style="padding:0px 5px;margin:5px 0px;">Changes</h2>

	<cfif getAudits.recordCount eq 0>
		<em>No changes found.</em>
	<cfelse>
		<table class="stripe">
			<tr class="titlerow">
				<td colspan="2">Article Changes</td>
			</tr>
			<tr class="titlerow2">
				<th>Date</th>
				<th>Audit</th>
			</tr>



			<cfoutput query="getAudits">
				<tr>
					<td align="right">
						#dateFormat(audit_date, "mmm d, yyyy")#
						<span class="tinytext">#timeFormat(audit_date, "short")#</span><br/>
						<span class="tinytext">#username#</span>
					</td>

					<td>
						#audit_text#
					</td>
				</tr>
			</cfoutput>
		</table>

	</cfif>

</cfif>

</div>

<!---the last thing we need to do is our creepy readership stalking.--->
<cftry>
	<!---see if they already have a readership record.--->
	<cfquery datasource="#application.applicationDataSource#" name="getReadership">
		SELECT read_id
		FROM tbl_articles_readership
		WHERE article_id = #articleId#
		AND user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
	</cfquery>

	<cfif getReadership.recordCount eq 0>
		<!---they haven't viewed this article before, we need to make an entry--->
		<cfquery datasource="#application.applicationDataSource#" name="getReadership">
			INSERT INTO tbl_articles_readership (user_id, article_id)
			OUTPUT inserted.read_id
			VALUES (
				<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">,
				#articleId#
			)
		</cfquery>
	<cfelse>
		<!---they did already have a record, update the recent_view_date column.--->
		<cfquery datasource="#application.applicationDataSource#" name="updateReadership">
			UPDATE tbl_articles_readership
			SET recent_view_date = GETDATE()
			WHERE read_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#getReadership.read_id#">
			AND user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		</cfquery>
	</cfif>

	<!---either way we are now armed with a read_id for the user and this article.  Now place some javascript to see if they've read the article.--->


	<!---to set the time-out before an article is considered to have experienced a long view should be based on the word count, and the fact that even excellent speed-readers top-out at about 500wpm.  Let's get our word count.--->
	<cfset wordCount = 0>
	<cfset countString = stripTags(content)><!---remove HTML from the content--->
	<cfset countString = reReplace(countString, "\s+", " ", "all")><!---replace all whitespace with just a single space--->
	<cfset countString = trim(countString)><!---trim leading and ending whitespace--->
	<cfset wordCount = listLen(countString, " ")><!---now we can treat countString like a list deliminated by spaces to find our word count.--->


	<cfset longVisitLength = (wordCount / 500) * 60 * 1000><!--- word count divided by 500 words per minute, times 60 to give us seconds, times 1000 to give us miliseconds.--->
	<cfset longVisitLength = round(longVisitLength)>


	<script type="text/javascript">
		/*setup the AJAX call to record long visits*/
		delaySubmit = setTimeout("submitReadership()", <cfoutput>#longVisitLength#</cfoutput>);

		function submitReadership(){
			$.ajax({
				url: "<cfoutput>#application.appPath#/documents/ajax_article_read.cfm</cfoutput>",
				type: "POST",
				async: true,
				data: {<cfoutput>
					"readId": #getReadership.read_id#,
					"articleId": #articleId#
				</cfoutput>}
			});
		}
	</script>

<cfcatch type="any">
	<p class="warning">
	<cfoutput>
		Readership Error: #cfcatch.Message# - #cfcatch.Detail#
	</cfoutput>
	</p>
</cfcatch>
</cftry>
</div>


<cfinclude template="#application.appPath#/footer.cfm">
