<cfmodule template="#application.appPath#/header.cfm" title='Contact Categories' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">

<h1>Contact Categories</h1>



<cfparam name="frmAction" type="string" default="list">
<cfparam name="frmCatId" type="integer" default="0">

<cfparam name="frmCatName" type="string" default="">
<cfparam name="frmParentCategory" type="integer" default="0">
<cfparam name="frmDetails" type="string" default="">
<cfparam name="frmActive" type="boolean" default="1">

<!---some quick links for getting around--->
<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 0.5em;">
	<cfoutput>
		<cfif listFind("add,edit", frmAction)>
			[<a href="#cgi.script_name#">Select Category</a>]
		<cfelse>
			[<a href="#cgi.script_name#?frmAction=add">New Category</a>]
		</cfif>
	</cfoutput>
</p>

<style type="text/css">
	dl {
		padding-left: 0.5em;
		margin-left: 40px;
		border-left: solid 1px white;
		
	}
	
	dl:nth-child(2n){
		background-color: #E1E0D9;
	}
	
	dl:nth-child(2n+1){
		background-color: #F8F3D2;
	}
	
	dt {
		font-weight: bold;
	}
	
	dt.retired {
		font-style: italic;
		color: gray;
	}
	
	dd {
		padding-left: 0px;
		margin-left: 20px;
	}
	
	dd.empty {
		color: gray;
		font-style: italic;
	}
	
	dd.links {
		font-size: smaller;
	}
	
	table.stripe th {
		text-align: right;
	}
</style>



<!---fetch all the existing contact categories for use throughout this page.--->
<cfset getCategories = fnGetCategories()>

<!---handle user input here--->
<cfif frmAction eq "addSub">
	<cftry>
	<!---Let's do some checks to make sure we can add this category--->
	<cfif trim(frmCatname) eq "">
		<cfthrow message="Category Name" detail="Category Name is a required field.">
	</cfif>
	
	<!---we can't have duplicates, either.--->
	<cfloop query="getCategories">
		<cfif lcase(frmCatName) eq lcase(category_name)>
			<cfthrow message="Category Name" detail="A category named ""#category_name#"" already exists.">
		</cfif>
	</cfloop>
	
	<!---looks like we've passed our checks, we can add the category now.--->
	<cfquery datasource="#application.applicationDataSource#" name="addCategory">
		INSERT INTO tbl_contacts_categories (category_name, parent_category_id, category_details)
		VALUES (
			<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmCatName#">,
			<cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentCategory#">,
			<cfqueryparam cfsqltype="cf_sql_longvarchar" value="#frmDetails#">
		)
	</cfquery>
	
	<!---having done that, we need to update getCategories--->
	<p class="ok">Category Added.</p>
	<cfset getCategories = fnGetCategories()>
	
	<cfcatch type="any">
		<!---thorw them back to the add form--->
		<cfset frmAction = "add">
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.detail#</cfoutput>
		</p>
	</cfcatch>
	</cftry>
</cfif>

<cfif frmAction eq "editSub">
	<cftry>
	<!---we need to do a few checks on the category we're editing.--->
	<cfloop query="getCategories">
		<cfif category_id eq frmCatId>
			<!---a category can't be it's own parent--->
			<cfif frmParentCategory eq category_id>
				<cfthrow message="Parent Category" detail="A category cannot be it's own parent, please select another Parent Category.">
			</cfif>
			
			<!---if there are already provided details we cannot edit them--->
			<cfif len(trim(category_details)) gt 0>
				<!---cfthrow message="Description" detail="You may not alter the name or description of a category since contacts were made according to the existing description."--->
				<cfset frmDetails = category_details>
			</cfif>
			
			<!---if we cleared those checks we can now update the category in the DB--->
			<cfquery datasource="#application.applicationDataSource#" name="updateCategory">
				UPDATE tbl_contacts_categories
				SET	parent_category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmParentCategory#">,
					category_details = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmDetails#">,
					active = <cfqueryparam cfsqltype="cf_sql_bit" value="#frmActive#">
				WHERE category_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmCatId#">
			</cfquery>
			
			<!---we're done with the loop, break out.--->
			<cfbreak>
		</cfif>
	</cfloop>
	
	<!---having done that, we need to update getCategories--->
	<cfset getCategories = fnGetCategories()>
	
	<cfcatch type="any">
		<!---thorw them back to the edit form--->
		<cfset frmAction = "edit">
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.detail#</cfoutput>
		</p>
	</cfcatch>
	</cftry>
</cfif>


	
<cfif frmAction eq "edit" OR frmAction eq "add"><!---add and edit share a common form, so just add a few special clauses for each.--->
	<!---draw a form form editing a category--->
	<cfset origDetails = "">
	<cfloop query="getCategories">
		<cfif category_id eq frmCatId>
			<!---set defaults for the user input--->
			<cfif frmAction eq "edit" OR not isDefined("form.frmCatName")>
				<cfset frmCatName = category_name>
			</cfif>		
			<cfif not isDefined("form.frmParentCategory")>
				<cfset frmParentCategory = parent_category_id>
			</cfif>
			<cfif not isDefined("form.frmDetails")>
				<cfset frmDetails = category_details>
			</cfif>
			<cfif not isDefined("form.frmActive")>
				<cfset frmActive = active>
			</cfif>
			
			<!---also set origDetails to category_details, so we can check if there is already a value in the DB.--->
			<cfset origDetails = category_details>
			
			<!---we're done with the loop.--->
			<cfbreak>
		</cfif>
	</cfloop>
			
	<cfoutput>
	<form method="post" action="#cgi.script_name#">
		<cfif frmAction eq "edit">
			<input type="hidden" name="frmAction" value="editSub">
		<cfelse>
			<input type="hidden" name="frmAction" value="addSub">
		</cfif>
		<input type="hidden" name="frmCatId" value="#frmCatId#">
		
		
		<table class="stripe">
			<tr class="titlerow">
				<td colspan="2">
					<cfif frmAction eq "edit">
						#frmCatName#
					<cfelse>
						New Category
					</cfif>
				</td>
			</tr>
			
			<cfif frmAction eq "add">
				<tr>
					<th>
						Category Name:
					</th>
					<td>
						<input type="text" name="frmCatName" value="<cfoutput>#htmlEditFormat(frmCatName)#</cfoutput>" size="15">
					</td>
				</tr>
			</cfif>
			
			<tr>
				<th>
					Parent Category:
				</th>
				<td>
					<select name="frmParentCategory">
						<cfoutput>#drawCatSelOptions(0, frmParentCategory, frmCatId)#</cfoutput>
					</select>
				</td>
			</tr>
			<tr>
				<th>Description:</th>
				<td>
					<!---only let them edit the text if there isn't any already.--->
					<textarea name="frmDetails" rows="5" cols="20" <cfif trim(origDetails) neq "">disabled="true"</cfif>>#htmlEditFormat(frmDetails)#</textarea>
				</td>
			</tr>
			
			<!---when editing we need to be able to (de)activate categories--->
			<cfif frmAction eq "edit">
				<tr>
					<th>
						Active:
					</th>
					<td>
						<label>
							<input type="radio" name="frmActive" value="1" <cfif frmActive>checked="true"</cfif>> Yes
						</label>
						<label>
							<input type="radio" name="frmActive" value="0" <cfif not frmActive>checked="true"</cfif>> No
						</label>
					</td>
				</tr>
			</cfif>
			
			<tr class="titlerow2">
				<td colspan="2" align="center">
					<cfif frmAction eq "edit">
						<input type="submit" value="Edit">
					<cfelse>
						<input type="submit" value="Add">
					</cfif>
				</td>
			</tr>
		</table>
		
	</form>
	</cfoutput>
	
	
<cfelse>
	<!---let's draw the existing contacts.--->
	<div>
		<cfoutput>#drawCat(0)#</cfoutput>
	</div>
</cfif>



<!---this relies on the getCategories query we ran earlier--->
<cffunction name="drawCat" output="false">
	<cfargument name="parentCatId" type="numeric" default="0">
	
	<cfset var = myOutput = "">
	
	<cfloop query="getCategories">
		<cfif parent_category_id eq parentCatId>
			<cfset myOutput = myOutput & "<dt class='" & iif(not active, """retired""", """""") & "'>#category_name#" &  iif(not active, """(retired)""", """""") & "</dt>">
			
			<!---when we have a description draw that, otherwise note its absence.--->
			<cfif len(trim(category_details)) eq 0>
				<cfset myOutput = myOutput & "<dd class=""empty"">No Description</dd>">
			<cfelse>	
				<cfset myOutput = myOutput & "<dd>#category_details#</dd>">
			</cfif>
			
			<cfset myOutput = myOutput & "<dd class=""links"">[<a href=""#cgi.script_name#?frmAction=edit&frmCatId=#category_id#"">Edit</a>]</dd>">
			
			<!---now snag any child categories--->
			<cfset myOutput = myOutput & drawCat(category_id)>
		</cfif>
	</cfloop>
	
	<cfif len(myOutput) gt 0>
		<cfset myOutput = "<dl>" & myOutput & "</dl>">
	</cfif>
	
	<cfreturn myOutput>
</cffunction>

<cffunction name="fnGetCategories" output="false">
	<cfset var getCategories = "">
	
	<cfquery datasource="#application.applicationDataSource#" name="getCategories">
		SELECT category_id, category_name, category_details, parent_category_id, active
		FROM tbl_contacts_categories
		ORDER BY parent_category_id, active DESC, category_name
	</cfquery>
	
	<cfreturn getCategories>
</cffunction>

<cffunction name="drawCatSelOptions" output="false">
	<cfargument name="parentCatId" type="numeric" default="0">
	<cfargument name="selectedCat" type="numeric" default="0">
	<cfargument name="disableCat" type="numeric" default="-1"><!---don't allow categories to be their own parent.--->
	<cfargument name="indentLevel" type="numeric" default="0">
	
	<cfset var myOutput = "">
	<cfset var indentString = "">
	<cfset var i = 0>
	
	<cfloop from="1" to="#indentLevel#" index="i">
		<cfset indentString = indentString & "&nbsp;&nbsp;&nbsp;&nbsp;">
	</cfloop>
	
	<cfif parentCatId eq 0>
		<cfset myOutput = "<option value='0'>No Parent</option>">
	</cfif>
	
	<cfloop query="getCategories">
		<cfif parentCatId eq parent_category_id>
			<cfset myOutput = myOutput & "<option value='#category_id#'" & iif(category_id eq selectedCat, """ selected='true' """, """ """) & iif(category_id eq disableCat, """disabled='true' """, """ """) & ">#indentString# #category_name#</option>">
			
			<!---now append any children--->
			<cfset myOutput = myOutput & drawCatSelOptions(category_id, selectedCat, disableCat, indentLevel + 1)>
		</cfif>
	</cfloop>
	
	<cfreturn myOutput>
</cffunction>

<p>
	Go to the main <a href="<cfoutput>#application.appPath#/tools/contacts/contacts.cfm</cfoutput>">Customer Contacts</a> page.
</p>

<cfmodule template="#application.appPath#/footer.cfm">