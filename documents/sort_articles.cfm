<cfmodule template="#application.appPath#/header.cfm" title="Sort Articles">
<cfmodule template="#application.appPath#/modules/check-access.cfm" masks="Article Editor">

<!--- cfparams --->
<cfparam name="frmSubmit" type="integer" default="0">
<cfparam name="frmCatId" type="integer" default="0">
<cfparam name="frmReferrer" type="string" default=""><!---if provided this is where it will take us after a successful sorting.--->

<cfset catList = getFormattedParentList(frmCatId)>
<cfset catName = getCatName(frmCatId)>

<!---check if we have the ownership masks we need.--->
<cfset ownerMasks = getInheritedOwnerMasks(frmCatId)>

<cfif listLen(ownerMasks) gt 0 AND not hasMasks(ownerMasks)>
	<p class="warning">Only the owner of this category - with masks <cfoutput><em>#ownerMasks#</em></cfoutput> - may revise the sort order of these articles.</p>
	<cfmodule template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>

<!---Snag the articles in this category, and draw them in order.--->
<cfset getArticles = getCatArticles()>


<cfif getArticles.recordCount eq 0>
	<p class="warning">No articles found in this category.</p>
	<cfmodule template="#application.appPath#/footer.cfm">
	<cfabort>
</cfif>

<!--- header / navigation --->
<h1>Sort Articles</h1>
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
	<cfoutput>
		<cfif trim(frmReferrer) NEQ "">
			[<a href="#frmReferrer#">Go Back</a>]
		</cfif>
		[<a href="sort-articles-selection.cfm">Sort Article Selector</a>]
	</cfoutput>
</p>

<h2><cfoutput>#catName#</cfoutput></h2>

<!---handle user input if they've submitted the form.--->
<cfif frmSubmit eq 1>
	<!---set the current values as the default sort-orders--->
	<cfloop query="getArticles">
		<cfparam name="frmArtOrder#article_id#" type="integer" default="#sort_order#">
		
		<cfset curValue = evaluate("frmArtOrder#article_id#")>
		
		<!---The user submitted value doesn't match we need to update the database, and audit the change.--->
		<cfif curValue neq sort_order>
			<cfquery datasource="#application.applicationDataSource#" name="updateOrder">
				UPDATE tbl_articles
				SET sort_order = <cfqueryparam cfsqltype="cf_sql_integer" value="#curValue#">
				WHERE article_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">
			</cfquery>
			
			<cfset auditText = "<ul><li><b>Sort Order</b> changed from <em>#sort_order#</em> to <em>#curValue#</em>.</li></ul>">
			
			<cfquery datasource="#application.applicationDataSource#" name="addAudit">
				INSERT INTO tbl_articles_audit (article_id, user_id, audit_text)
				VALUES (<cfqueryparam cfsqltype="cf_sql_integer" value="#article_id#">, <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, <cfqueryparam cfsqltype="cf_sql_longvarchar" value="#auditText#">)
			</cfquery>
		</cfif>
	</cfloop>
	
	<!---now re-fetch our articles with the new order--->
	<cfset getArticles = getCatArticles()>
	
	<p class="ok">
		Sort Order has been updated, and all changes have been audited.
	</p>
	
	<cfif trim(frmReferrer) neq "">
		<cflocation url="#frmReferrer#" addtoken="false">
	</cfif>
</cfif>

<!---we're ready to draw the list of articles.--->
<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">
<input type="hidden" name="frmSubmit" value="1">
<input type="hidden" name="frmCatId" value="<cfoutput>#frmCatId#</cfoutput>">
<input type="hidden" name="frmReferrer" value="<cfoutput>#htmlEditFormat(frmReferrer)#</cfoutput>">
<ul class="categories">
	<cfoutput query="getArticles">
		<li class="item">
			<span class="pos"><!---where we'll render our up/down arrows--->
				<button class="up" title="Move Article Up"></button><button class="down" title="Move Article Down"></button>
			</span>
			#title#
			<input type="hidden" name="frmArtOrder#article_id#" class="sortOrder" value="#sort_order#">
		</li>
	</cfoutput>
</ul>

<input type="submit"  value="Save Order">
</form>

<!---style and javascript that makes lists sortable.--->
<!---a little style for our links.--->
<style type="text/css">
	span.retired {
		color: gray;
		font-style: italic;
	}
	
	p#listStatus {
		display: none;
	}

	/*we want to make the lists slimmer, but the big three padd lists differently, this forces them to be the same.*/
	ul.categories {
		list-style-type: none;
		border-left: solid 2px lightgray;
		/*border-top: solid 2px lightgray;*/
		margin-left: 2em;
		padding-left: 0px;
		margin-top: 0.5em;
	}
	
	ul.categories li {
		padding-left: 0px;
		margin-left: 0px;
	}
	
	ul.categories li.item span.pos {
		margin-right: 0.5em;
	}
</style>

<!---jquery to make our lists into sortable lists.--->
<script type="text/javascript">
	$(document).ready(function(){
		/*prevent clicks on edit links from bubbling up and firing trigger/triggerexpanded items*/
		$("a.editLink").click(function(e){
			e.stopPropagation();
		});
		
		/*the handlers that'll let us raise and lower items' sort_order.*/
		//make them neat jQuery buttons.
		$("button.up")
			.addClass("glyphicon glyphicon-arrow-up")
			.css("width", "24px")
			.css("height", "24px")
			.css("vertical-align", "middle")
			.on("click", this, function(e){
				e.preventDefault();//don't submit the form.
				/*we're going to find the list item for this button, then find the one above it, highlight them, and swap them.*/
				var myItem = $(this).parent().parent();//thats our li.item
				var prevItem = $(myItem).prev("li.item");
				
				//now that we have both our items switch their sortOrder values.
				var myItemOrder = $("input.sortOrder", myItem).val();
				var prevItemOrder = $("input.sortOrder", prevItem).val();
				
				//if either one is not a numuber, we've reached the top, do nothing.
				if(isNaN(myItemOrder) || isNaN(prevItemOrder)){
					myItem.effect("highlight");//highlight so they know their click registered.
					return;//stop executing before we move stuf around.
				}
				
				//having passed that test swap their sort orders.
				$("input.sortOrder", prevItem).val(myItemOrder);
				$("input.sortOrder", myItem).val(prevItemOrder);
				
				//now visually swap them for our user.
				myItem.effect("highlight");
				prevItem.effect("highlight");
				
				//now actually move myItem to before prevItem.
				prevItem.before(myItem);
				
				//show the warning that the order has changed.
				$("p#listStatus").css("display", "block");
				
				//disable and re-enable arrows as needed.
				fixArrows()
			});
		
		$("button.down")
			.addClass("glyphicon glyphicon-arrow-down")
			.css("width", "24px")
			.css("height", "24px")
			.css("vertical-align", "middle")
			.on("click", this, function(e){
				e.preventDefault();//don't submit the form.
				/*we're going to find the list item for this button, then find the one below it, highlight them, and swap them.*/
				var myItem = $(this).parent().parent();//thats our li.item
				var nextItem = $(myItem).next("li.item");
				
				//now that we have both our items switch their sortOrder values.
				var myItemOrder = $("input.sortOrder", myItem).val();
				var nextItemOrder = $("input.sortOrder", nextItem).val();
				
				//if either one is not a numuber, we've reached the bottom, do nothing.
				if(isNaN(myItemOrder) || isNaN(nextItemOrder)){
					myItem.effect("highlight");//highlight so they know their click registered.
					return;//stop executing before we move stuf around.
				}
				
				//having passed that test swap their sort orders.
				$("input.sortOrder", nextItem).val(myItemOrder);
				$("input.sortOrder", myItem).val(nextItemOrder);
				
				//now visually swap them for our user.
				myItem.effect("highlight");
				nextItem.effect("highlight");
				
				//now actually move myItem to after nextItem.
				nextItem.after(myItem);
				
				//show the warning that the order has changed.
				$("p#listStatus").css("display", "block");
				
				//disable and re-enable arrows as needed.
				fixArrows()
			});
		
		//now fix the appearance of the up and down arrows.
		fixArrows();
	});
	
	/*this function fixes arrows.  It disables the "up" arrow on the top item, and disabled the "down" arrow on the bottom item, of each list.*/
	function fixArrows(){
		var u = 0;
		var i = 0;
		//first, for each list we need to know how many items there are.
		$("ul.categories").each(function(u){
			var listLen = $(this).children("li.item").length;
			
			if(isNaN(listLen)) listLen = 0;//listLen MUST be a number.
			
			//now find each li's current sortOrder
			$(this).children("li.item").each(function(i){/*we're using .children(), because we only want the first-level childen, and not all the nested li.items under the current ul*/
				var curItem = $(this);
				var curSort = $("input.sortOrder", curItem);
				curSort.val(i+1);//just a little insurance to make sure items never fall out of the order the user sees.
				var curSortValue = curSort.val();
				
				//now disable the up arrow if we're at the top, enable it everywhere else.
				if(curSortValue == 1) {
					$("span.pos button.up", curItem).prop("disabled", true);
				} else {
					$("span.pos button.up", curItem).prop("disabled", false);
				}
				
				
				//now disable the down arrow if we're at the bottom, enable it everywhere else.
				if(curSortValue == listLen){
					$("span.pos button.down", curItem).prop("disabled", true);
				} else {
					$("span.pos button.down", curItem).prop("disabled", false);
				}
			});
		});
	}
</script>

<!--- functions --->

<cffunction name="getCatArticles">
	
	<cfset var getArticles = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getArticles">
		SELECT a.article_id, a.category_id, a.retired, ar.title, ar.approved, a.sort_order
		FROM tbl_articles a
		INNER JOIN tbl_articles_revisions ar 
			ON ar.article_id = a.article_id
			AND ar.use_revision = 1
			/*AND ar.approved = 1*/
		WHERE a.retired = 0
		AND a.category_id = #frmcatId#
		AND 0 NOT IN (
			SELECT 
				CASE
					WHEN mu.mask_id IS NULL THEN 0
					ELSE 1
				END AS has_mask
			FROM tbl_articles_masks am
			LEFT OUTER JOIN vi_all_masks_users mu
				ON mu.mask_id = am.mask_id
				AND mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			WHERE am.article_id = a.article_id
		)
		ORDER BY a.sort_order
	</cfquery>
	
	<cfreturn getArticles>
	
</cffunction>

<cfmodule template="#application.appPath#/footer.cfm">
