<cfmodule template="#application.appPath#/header.cfm" title='Form Report' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Admin">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<cfinclude template="#application.appPath#/tools/forms/form_functions.cfm">

<!--- cfparams --->
<cfparam name="formId" type="integer" default="0">
<!--- form parameters --->
<cfparam name="frmFormId" type="integer" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d",-1,now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">
<cfparam name="frmUserFor" type="integer" default="0">
<cfparam name="frmUserBy" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">
<!--- attribute parameters --->
<cfparam name="formAttributes" type="string" default="">
<cfparam name="isRepeatable" type="boolean" default="0">
<cfparam name="isAllLabs" type="boolean" default="0">
<cfparam name="isScored" type="boolean" default="0">
<cfparam name="isTrainingChecklist" type="boolean" default="0">
<cfparam name="isTrainingQuiz" type="boolean" default="0">
<cfparam name="isNumbered" type="boolean" default="0">

<!--- if provided this is where the user should be taken upon clicking 'Go Back' or getting a dropped ID.--->
<!--- this is necessary because we could be accessing our forms from several different places --->
<cfparam name="referrer" type="string" default="">

<!--- sanitize our dates for searching --->
<cfset frmStartDate = dateFormat(frmStartDate, "mmm d, yyyy ") & "00:00">
<cfset frmEndDate = dateFormat(frmEndDate, "mmm d, yyyy ") & "23:59:59.9">

<cfif frmAction EQ "Clear">
	<cfset frmId = "0">
	<cfset frmStartDate = "#dateAdd("d", -1, now())#">
	<cfset frmEndDate = "#now()#">
	<cfset frmAction = "">
</cfif>

<cfoutput>
	<h1>Form Report</h1>
	<p style="padding: 0px;margin-top: 0.5em;margin-bottom: 1em;">
		<cfif trim(referrer) neq "">
			<a href="#referrer#">Go Back</a> |
		</cfif>
		<cfif hasMasks("Admin")>
			<a href="<cfoutput>#application.appPath#/tools/forms/attribute_manager.cfm</cfoutput>">Manage Attributes</a>
			| <a href="<cfoutput>#application.appPath#/tools/forms/form_manager.cfm</cfoutput>">Manage Forms</a>
			| <a href="#application.appPath#/tools/forms/form_submission_report.cfm">Form Submissions</a>
		</cfif>
	</p>
</cfoutput>


<!---a few style elements used to display some form info.--->
<style type="text/css">
	span.cloudWord:hover {
		color: black !important;/*using !important to trump our inline-style for the span*/
		cursor: default;
	}

	span.cloudWord {
		/*display: inline-block;*/
		vertical-align: middle;
	}

</style>

<!--- draw forms --->

<!--- when showing search results, collapse our form --->
<span class="triggerexpanded">Search Parameters</span>

	<div>

		<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">

			<!--- get existing forms --->
			<cfquery datasource="#application.applicationDataSource#" name="getForms">
				SELECT a.form_id, a.form_name, a.form_description, a.retired
				FROM tbl_forms a
				ORDER BY a.retired, a.form_name
			</cfquery>

			<!--- get users who have recent forms --->
			<cfquery datasource="#application.applicationDataSource#" name="getUsers">
				SELECT DISTINCT t.user_id, u.username, u.last_name, u.first_name
				FROM tbl_forms_submissions t
				INNER JOIN tbl_users u ON u.user_id = t.user_id
				ORDER BY u.last_name, u.first_name, u.username
			</cfquery>
			<cfquery datasource="#application.applicationDataSource#" name="getSubmitters">
				SELECT DISTINCT t.submitted_by, u.username, u.last_name, u.first_name
				FROM tbl_forms_submissions t
				INNER JOIN tbl_users u ON u.user_id = t.submitted_by
				ORDER BY u.last_name, u.first_name, u.username
			</cfquery>

			<fieldset>

				<legend>Choose Search Parameters</legend>

				<label for="frmFormId">Form:</label>
					<select name="frmFormId">
						<option value = "0">
						<cfoutput query="getForms">
							<option value="#form_id#"
									<cfif frmFormId EQ form_id>selected="selected"</cfif>>
								#form_name# <cfif retired>(retired)</cfif>
							</option>
						</cfoutput>
					</select>
				</label>

				<br/><br/>

				<cfoutput>
					<label>From: <input class="date" name="frmStartDate" value="#dateFormat(frmStartDate,  "MMM d, yyyy")#"></label>
					<label>To: <input class="date" name="frmEndDate" value="#dateFormat(frmEndDate,  "MMM d, yyyy")#"></label>
				</cfoutput>

				<script type="text/javascript">
					$(document).ready(function() {
					// make the dates calendars.
					$("input.date").datepicker({dateFormat: 'M d, yy'});
					});
				</script>

				<br/><br/>

				<label for="frmUserFor">Form Submitted For:</label>
					<select name="frmUserFor">
						<option value = "0">
						<cfoutput query="getUsers">
							<option value="#user_id#"
									<cfif frmUserFor EQ user_id>selected="selected"</cfif>>
								#last_name#, #first_name# (#username#)
							</option>
						</cfoutput>
					</select>
				</label>

				<br/><br/>

				<label for="frmUserBy">Form Submitted By:</label>
					<select name="frmUserBy">
						<option value = "0">
						<cfoutput query="getSubmitters">
							<option value="#submitted_by#"
									<cfif frmUserBy EQ submitted_by>selected="selected"</cfif>>
								#last_name#, #first_name# (#username#)
							</option>
						</cfoutput>
					</select>
				</label>

				<br/><br/>

			</fieldset>

			<p class="submit">
				<input type="submit" value="Search" name="frmAction">
				<input type="submit" value="Clear" name="frmAction">
			</p>

		</form>

	</div>

<cfif frmAction EQ "Search">

	<cftry>

		<cfset formId = frmFormId>

		<cfif frmFormId eq 0>
			<cfthrow message="Invalid Search" detail="You must choose a form.">
		</cfif>

		<!--- based on the formId, grab our form, items, and attributes --->
		<cfquery datasource="#application.applicationDataSource#" name="getForm">
			SELECT a.form_name, a.form_description
			FROM tbl_forms a
			WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="getFormAttributes">
			SELECT a.attribute_id, b.attribute_name, b.attribute_details, b.attribute_text
			FROM tbl_forms_attributes a
			INNER JOIN tbl_attributes b ON b.attribute_id = a.attribute_id
			WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
			      AND b.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
			ORDER BY a.attribute_id ASC
		</cfquery>

		<cfquery datasource="#application.applicationDataSource#" name="getAllAnswers">
			SELECT a.form_item_id, a.user_answer, a.user_text, a.submission_id
			FROM tbl_forms_users_items a
			INNER JOIN tbl_forms_submissions b ON b.submission_id = a.submission_id
			WHERE a.form_id = <cfqueryparam cfsqltype="cf_sql_int" value="#formId#">
			      AND b.submission_date BETWEEN <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmStartDate#"> AND
			                                    <cfqueryparam cfsqltype="cf_sql_datetime" value="#frmEndDate#">
			      <cfif frmUserBy GT 0> AND b.submitted_by = <cfqueryparam cfsqltype="cf_sql_int" value="#frmUserBy#"></cfif>
				  <cfif frmUserFor GT 0> AND b.user_id = <cfqueryparam cfsqltype="cf_sql_int" value="#frmUserFor#"></cfif>
			ORDER BY a.form_item_id ASC, a.user_answer ASC, b.submission_date DESC
		</cfquery>

		<!--- fetch all existing attributes for this form --->
		<cfif formAttributes EQ "">
			<cfloop query="getFormAttributes">
				<cfset formAttributes = listappend(formAttributes, #attribute_id#)>
			</cfloop>
			<!--- set up params for each attribute for easier reading --->
			<cfset isRepeatable = hasAttribute("Repeatable", formAttributes)>
			<cfset isAllSites = hasAttribute("All Sites", formAttributes)>
			<cfset isScored = hasAttribute("Scored", formAttributes)>
			<cfset isTrainingChecklist = hasAttribute("Training - Checklist", formAttributes)>
			<cfset isTrainingQuiz = hasAttribute("Training - Quiz", formAttributes)>
			<cfset isNumbered = hasAttribute("Numbered", formAttributes)>
		</cfif>

		<!--- heading and navigation --->
		<cfoutput>
			<h2>#getForm.form_name#</h2>
		</cfoutput>

		<!--- draw form --->

		<cfset drawItems()>

		<cfcatch>
			<cfset frmAction = "">
			<cfoutput>
				<p class="warning">
					#cfcatch.Message# - #cfcatch.Detail#
				</p>
			</cfoutput>
		</cfcatch>

	</cftry>

</cfif>

<cffunction name="drawItems">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="fieldset" type="boolean" default="0">
	<cfargument name="header" type="boolean" default="0">
	<cfargument name="first" type="boolean" default="1">
	<cfargument name="recursive" type="boolean" default="0">

	<cfquery datasource="#application.applicationDataSource#" name="getAllItems">
		SELECT a.form_item_id, a.item_text, a.item_type
		FROM tbl_forms_items a
		WHERE a.form_id = #formId#
		      AND a.parent_id = <cfqueryparam cfsqltype="cf_sql_int" value="#parentId#">
		      AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
		ORDER BY a.sort_order
	</cfquery>

	<cfloop query="getAllItems">

<cfset item_type_text = getItemType(item_type)>

		<cfif item_type_text EQ "Header"
			  OR item_type_text EQ "Legend">
			<cfif fieldset AND NOT header>
				<cfif isNumbered></ol><cfset numbered = 0></cfif>
				</fieldset>
				<cfset fieldset = 0>
			</cfif>
			<cfif item_type_text EQ "Legend">
				<cfif not header>
					<br/>
				</cfif>
				<fieldset>
				<cfset fieldset = 1>
				<cfset first = 1>

				<!---<legend><cfoutput>#item_text#</cfoutput></legend>--->

				<cfif isNumbered><ol><cfset numbered = 1></cfif>
			</cfif>
			<cfset header = 1>
		<cfelseif isInputType(item_type)>
			<cfif NOT fieldset>
				<fieldset>
				<cfset fieldset = 1>
				<cfif isNumbered><ol><cfset numbered = 1></cfif>
				<cfset first = 1>
			</cfif>
			<cfset header = 0>

		</cfif>

		<cfset drawItem(parentId, form_item_id, item_type, item_type_text, item_text, fieldset, header, first)>

		<cfif first AND item_type_text NEQ "Header"
			  AND item_type_text NEQ "Legend">
			<cfset first = 0>
		</cfif>

	</cfloop>

	<cfif fieldset AND NOT recursive>
		<cfif isNumbered></ol></cfif>
		</fieldset>
	</cfif>

</cffunction>

<cffunction name="drawItem">
	<cfargument name="parentId" type="numeric" default="0">
	<cfargument name="form_item_id" type="numeric" default="0">
	<cfargument name="item_type" type="numeric" default="0">
	<cfargument name="item_type_text" type="string" default="">
	<cfargument name="item_text" type="string" default="">
	<cfargument name="fieldset" type="boolean" default="0">
	<cfargument name="header" type="boolean" default="0">
	<cfargument name="first" type="boolean" default="1">

	<cfoutput>

		<cfif item_type EQ 5>
			<legend>#item_text#</legend>
		</cfif>

		<div>

			<cfset inputType = isInputType(item_type)>

			<cfif NOT first AND inputType><br/></cfif>
			<cfif isNumbered AND inputType><li></cfif>

			<!--- based on type, draw the correct input (make params if necessary) --->
			<!--- header --->
			<cfif item_type_text EQ "Header">

				<h3>#item_text#</h3>

			<cfelseif item_type_text EQ "Paragraph">

				#item_text#

			<!--- checkbox --->
			<cfelseif item_type_text EQ "Checkbox">

				#item_text#
				<br/>
				<cfset drawData(form_item_id, item_type, item_type_text)>
			<!--- multiple choice (first task is to fetch the options) --->
			<cfelseif item_type_text EQ "Multiple Choice">

				#item_text#
				<br/>
				<cfset drawData(form_item_id, item_type, item_type_text)>
				<cfif isNumbered><ol></cfif>
					<cfset drawItems(form_item_id, fieldset, header, 0, 1)>
				<cfif isNumbered></ol></cfif>

			<!--- text field --->
			<cfelseif item_type_text EQ "Small Text Field"
					  OR item_type_text EQ "Large Text Field">

				#item_text#
				<br/>

				<span class="trigger">Frequent Answers</span>
				<div>
					<table class="stripe" style="padding:0px;">
						<tr class="titlerow" style="padding:5px;">
							<th>Submission</th>
							<th>User Answer</th>
						</tr>
						<cfset drawData(form_item_id, item_type, item_type_text)>
					</table>
				</div>

			<cfelseif item_type_text EQ "Table">

				<cfset drawData(form_item_id, item_type, item_type_text)>

			</cfif>

			<cfif isNumbered and isInputType(item_type)></li></cfif>

		</div>

	</cfoutput>

</cffunction>

<cffunction name="drawData">
	<cfargument name="item_id" type="numeric" default="0">
	<cfargument name="item_type" type="numeric" default="0">
	<cfargument name="item_type_text" type="string" default="">

	<cfif item_type_text EQ "Checkbox" or item_type_text EQ "Multiple Choice">

		<cfset answerArray = arrayNew(1)>
		<cfset answerList = "">
		<cfset i = 1>

		<cfif item_type_text EQ "Multiple Choice">

			<cfquery datasource="#application.applicationDataSource#" name="getOptions">
				SELECT a.form_item_option_id, a.option_text, a.retired
				FROM tbl_forms_items_options a
				WHERE a.form_item_id = <cfqueryparam cfsqltype="cf_sql_int" value="#form_item_id#">
					  AND a.retired = <cfqueryparam cfsqltype="cf_sql_bit" value="0">
				ORDER BY a.option_order ASC, a.form_item_option_id ASC
			</cfquery>

			<cfloop query="getOptions">

				<cfset answerStruct = structNew()>
				<cfset answerStruct["text"] = option_text>
				<cfset answerStruct["value"] = form_item_option_id>
				<cfset answerStruct["count"] = 0>
				<cfset answerList = listAppend(answerList, form_item_option_id)>
				<cfset answerArray[i] = answerStruct>
				<cfset i = i + 1>

			</cfloop>

		<cfelseif item_type_text EQ "Checkbox">

			<cfset answerStruct0 = structNew()>
			<cfset answerStruct0["text"] = "No">
			<cfset answerStruct0["value"] = 0>
			<cfset answerStruct0["count"] = 0>
			<cfset answerStruct1 = structNew()>
			<cfset answerStruct1["text"] = "Yes">
			<cfset answerStruct1["value"] = 1>
			<cfset answerStruct1["count"] = 0>

			<cfset answerList = listAppend(answerList, 0)>
			<cfset answerArray[1] = answerStruct0>
			<cfset answerList = listAppend(answerList, 1)>
			<cfset answerArray[2] = answerStruct1>

		</cfif>

		<cfloop query="getAllAnswers">

			<cfif form_item_id EQ item_id>

				<cfset index = listFindNoCase(answerList, user_answer)>
				<cfif index GT 0>
					<cfset count = answerArray[index].count>
					<cfset count = count + 1>
					<cfset answerArray[index].count = count>
				</cfif>

			</cfif>

		</cfloop>

		<cfchart show3d="yes" seriesplacement="stacked" format="png" showlegend="true">
			<cfchartseries type="bar"  serieslabel="Our Answers">
			<cfloop array="#answerArray#" index="myQA">
					<cfchartdata item="#myQA.text#" value="#myQA.count#">
			</cfloop>
			</cfchartseries>
		</cfchart>

	<cfelseif item_type_text EQ "Large Text Field" OR item_type_text EQ "Small Text Field">

		<cfloop query="getAllAnswers">

			<cfif form_item_id EQ item_id>

					<tr>
						<td><cfoutput><a href="#application.appPath#/tools/forms/form_view_submission.cfm?submissionId=#submission_id#">#submission_id#</cfoutput>
						<td><cfoutput>#user_text#</cfoutput></td>
					</tr>

			</cfif>

		</cfloop>

	   <!---draw a word could for the user's answers.--->
		<cfset answerArray = arrayNew(1)>
		<cfset wordsWeDontWant = "the,is,an">
		<cfset maxFontSize="56">
		<cfset maxCount = 1>


		<cfquery dbtype="query" name="getUniqueAnswers">
			SELECT user_text
			FROM getAllAnswers
			WHERE form_item_id = #item_id#
		</cfquery>

		<cfloop query="getUniqueAnswers">
			<cfset myAnswer = stripTags(user_text)>
			<!---now use regex to strip out any non-word characters.--->
			<cfset myAnswer = reReplace(myAnswer, "[^a-zA-Z'\-0-9`]+", " ", "all")>

			<!---So, what we have now is a list of words seperated by spaces.  Loop over our words and add them to answerArray.--->
			<cfloop list="#myAnswer#" delimiters=" " index="myWord">
				<cfif len(myWord) gt 1 AND not listFindNoCase(wordsWeDontWant, myWord)><!---tiny words like a, i etc. aren't helpful so skip them..--->
					<!---now, if the word already exists in answerArray update its count, otherwise add it to anwerArray.--->
					<cfset found = 0>
					<cfloop array="#answerArray#" index="arrayWord">
						<cfif arrayWord.word eq myWord>
							<cfset arrayWord.count = arrayWord.count + 1>

							<!---is this our new largest word count?--->
							<cfif arrayWord.count gt maxCount>
								<cfset maxCount = arrayWord.count>
							</cfif>

							<cfset found = 1>
							<cfbreak><!---we found it, we're done with this loop.--->
						</cfif>
					</cfloop>


					<cfif not found>
						<!---we didn't find our word, make a struct for it, and store it in answerArray.--->
						<cfset myStruct = structNew()>
						<cfset myStruct.word = myWord>
						<cfset myStruct.count = 1>

						<cfset arrayAppend(answerArray, myStruct)>
					</cfif>
				</cfif>
			</cfloop>
		</cfloop>

		<!---now before we draw the cloud it'd be nice to scramble the order so we don't have any sentences possibly running over eachother.  We could do this in CF itself, but java has a good method for just this action.--->
		<cfset CreateObject("java", "java.util.Collections").Shuffle(answerArray) />

		<div>
		<cfloop array="#answerArray#" index="arrayWord">
			<cfset sizeString = maxFontSize * (1 - ((maxCount - arrayWord.count)/maxCount))>
			<cfset colorString = "#randRange(20, 250)#,#randRange(20, 250)#,#randRange(20, 250)#"><!---a random color for each word to make them stand out.--->

			<cfoutput>
				<span class="cloudWord" style="font-size: #sizeString#pt; color: rgb(#colorString#);" title="found <cfif arrayWord.count eq 1>once<cfelse>#arrayWord.count# times</cfif>.">
					#arrayWord.word#
				</span>
			</cfoutput>
		</cfloop>
		</div>
	   <!---end of word cloud--->

	<cfelseif item_type_text EQ "Table">
	   	<cfset getRows = getTableCells(item_id, 1, 0)>
	   	<cfset getCols = getTableCells(item_id, 0, 0)>
	   	<cfoutput>
			<table class="stripe" style="padding:0px;">
				<tr class="titlerow" style="padding:5px;">
					<td></td>
					<cfloop query="getCols">
						<td>#cell_text#</td>
					</cfloop>
				</tr>
				<cfloop query="getRows">
					<tr><td>#cell_text#</td>
						<cfset rowi = #getRows.form_table_cell_id#>
						<cfloop query="getCols">
							<cfset coli = #getCols.form_table_cell_id#>

							<cfquery datasource="#application.applicationDataSource#" name="getAverages">
								SELECT AVG(fui.user_answer) AS avg_answer
								FROM tbl_forms_users_items fui
								WHERE fui.form_item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#item_id#">
									  AND fui.row_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#rowi#">
									  AND fui.col_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#coli#">
							</cfquery>

								<td>#getAverages.avg_answer#</td>

						</cfloop>
					</tr>
				</cfloop>

			</table>

		</cfoutput>

	</cfif>

</cffunction>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>