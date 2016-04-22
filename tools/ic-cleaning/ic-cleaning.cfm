<cfmodule template="#application.appPath#/header.cfm" title='IC Cleaning Form'>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">


<h1>IC Cleaning Form</h1>
<cfif hasMasks('admin')>
<cfoutput><a href="#application.appPath#/tools/ic-cleaning/edit_sections.cfm">Edit sections</a></cfoutput>
</cfif>

<p>The graveyard and 8am IC crew works as a team to detail clean a specific section each shift under the Auditor's direction. </p>


<h3>Consultant and CS level:</h3>
<ol>
<li>The dark gray area indicates areas we do not clean.</li>
<li>Consultants should clean the section displayed in the <strong>Needs Cleaning</strong> section. This section displays:
	<ul>
		<li> The name and number of the section that needs to be cleaned.</li>
		<li> The last time the area was cleaned.</li>
		<li> The highlighted area of that section.</li>
    </ul>
</li>
</ol><br />


<cfif hasMasks('CS')>
<h3>Consultant Supervisor level:</h3>
<p>Consultants may reference this page so they are aware of what section needs to be cleaned and what areas may need some attention.</p>
<p>Graveyard and 8am Auditors should use this page to submit information concerning the section that was cleaned.</p>
<p><strong>It is important to keep this page accurate so that each Auditor and IC team cleans the correct section.</strong></p>

<ol>
<li>Consultant Supervisors will submit info on the area that has been cleaned once that area meets their standards.</li> 
<li>The <strong>Cleaning Form</strong> will automatically populate itself. The form includes:
	<ul>
		<li> The timestamp of when this page was opened.</li>
		<li> The username of logged in CS/Auditor.</li>
		<li> The section highlighted in the <strong>Needs Cleaning</strong> section.</li>
		<li> The comments box: please feel free to use this box for any information you'd like to share.	</li>
	</ul>
</li>
    
<li>Note: The <strong>"Cleaning Form"</strong> can be edited. For example, if more than one area is cleaned during a shift, use the dropdown option to change the section area.</li>
<li>Click Submit when you have completed this form.</li>
<li><strong>Cleaning History</strong>
	<ul>
		<li> This report shows all previous cleaning submissions.</li>
		<li> You can edit submissions if needed. Avoid deleting other submissions on this page except when appropriate.</li>
    </ul>
</ol><br />
</cfif>




<!---handle any user input --->
<cftry>
	<cfparam name="frmCleaningId" type="integer" default="0">
	<cfparam name="frmDate" type="date" default="#dateFormat(now(), 'MMM d, yyyy')# #timeFormat(now(), 'short')#">
	<cfparam name="frmUsername" type="string" default="#session.cas_username#">
	<cfparam name="frmSectionId" type="integer" default="0">
	<cfparam name="frmComments" type="string" default="">
	<cfparam name="frmSubmit" type="string" default="">
	
	<cfif frmCleaningId gt 0>
		<!---fetch the values from the database--->
		<cfquery datasource="#application.applicationDataSource#" name="getCleaning">
			SELECT username, section_id, comments, date_cleaned
			FROM tbl_ic_cleaning 
			WHERE clean_id = #frmCleaningId#
		</cfquery>
		
		<cfloop query="getCleaning">
			<!---items that have been submitted by the form should not be overwritten--->
			<cfif not isDefined("form.frmDate")>
				<cfset frmDate = date_cleaned>
			</cfif>
			<cfif not isDefined("form.frmUsername")>
				<cfset frmUsername = username>
			</cfif>
			<cfif not isDefined("form.frmSectionId")>
				<cfset frmSectionId = section_id>
			</cfif>
			<cfif not isDefined("form.frmComments")>
				<cfset frmComments = comments>
			</cfif>
		</cfloop>
	</cfif>
	
	<cfif frmSubmit eq "Submit" or frmSubmit eq "Update">

		<cfset frmDate = now()>
		<cfset frmUsername = session.cas_username>
		
		<!---username cannot be blank--->
		<cfif len(trim(frmUsername)) eq 0>
			<cfthrow type="custom" message="No Username" detail="You must enter the username of the user who did the cleaning.">
		</cfif>
		
		<!---is it a valid username?--->
		<cfquery datasource="#application.applicationDatasource#" name="getUser">
			SELECT user_id
			FROM tbl_users
			WHERE username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">
		</cfquery>
		<cfif getUser.recordCount lt 1>
			<cfthrow type="custom" message="Username Not Found" detail="The username you entered was not found in the database.">
		</cfif>
		
		<!---sectionId cannot be blank--->
		<cfif frmSectionId lte 0>
			<cfthrow type="custom" message="No Section Selecte" detail="You must select the section that was cleaned.">
		</cfif>
		
		<!---all our input checks out, store the data in the database--->
		<cfif frmSubmit eq "Submit">
			<cfquery datasource="#application.applicationDatasource#" name="addCleaning">
				INSERT INTO tbl_ic_cleaning (username, section_id, comments, date_cleaned)
				VALUES(<cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">, #frmSectionId#, <cfqueryparam cfsqltype="cf_sql_longvarchar" value="#frmComments#">, <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmDate#">)
			</cfquery>
		<cfelseif frmSubmit eq "Update">
			<cfquery datasource="#application.applicationDatasource#" name="UpdateCleaning">
				UPDATE tbl_ic_cleaning
				SET username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#frmUsername#">,
					section_id = #frmSectionId#,
					comments = <cfqueryparam cfsqltype="cf_sql_longvarchar" value="#frmComments#">,
					date_cleaned = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmDate#">
				WHERE id = #frmCleaningId#
			</cfquery>
		</cfif>
		
		<!---now reset our values--->
		<cfset frmCleaningId = 0>
		<cfset frmDate = "#dateFormat(now(), 'MMM d, yyyy')# #timeFormat(now(), 'short')#">
		<cfset frmUsername = session.cas_username>
		<cfset frmSectionId = 0>
		<cfset frmComments = "">
		<cfset frmSubmit = "">
        
		<h2>Cleaning Recorded</h2>
    <cfelseif frmSubmit eq "Delete">
		<!---nuke the row from the database--->
		<cfquery datasource="#application.applicationDataSource#" name="removeCleaning">
			DELETE FROM tbl_ic_cleaning
			WHERE clean_id = #frmCleaningId#
		</cfquery>
		
		<!---now reset our values--->
		<cfset frmCleaningId = 0>
		<cfset frmDate = "#dateFormat(now(), 'MMM d, yyyy')# #timeFormat(now(), 'short')#">
		<cfset frmUsername = session.cas_username>
		<cfset frmSectionId = 0>
		<cfset frmComments = "">
		<cfset frmSubmit = "">
		
		<h2>Cleaning Deleted</h2>
	</cfif>
	
<cfcatch type="any">
	<h2>Error</h2>
	<cfoutput>
	<p><b>#cfcatch.Message#</b> - #cfcatch.detail#</p>
	</cfoutput>
</cfcatch>
</cftry>


<!---show sections in need of cleaning, and the map.--->
<cfif frmCleaningId lte 0>
	<cfquery datasource="#application.applicationDataSource#" name="needsCleaning">
		SELECT TOP 1 cs.section_id, cs.section_name, cs.image,
			/*if there aren't recent items give an old date*/
			CASE
				WHEN c.date_cleaned IS NULL THEN DATEADD(day, -30, GETDATE())
				ELSE c.date_cleaned
			END AS date_cleaned
		FROM tbl_ic_cleaning_sections cs
		LEFT OUTER JOIN
			(SELECT section_id, MAX(date_cleaned) AS date_cleaned FROM tbl_ic_cleaning GROUP BY section_id) c ON c.section_id = cs.section_id
		WHERE cs.active = 1
		ORDER BY date_cleaned ASC
	</cfquery>
	
	<cfif needsCleaning.recordCount gt 0>
		<h3>Needs Cleaning</h3>
		<cfoutput query="needsCleaning">
			<b>#section_name#</b><br /> Last cleaned #dateFormat(date_cleaned, "mmm d, yyyy")# #timeFormat(date_cleaned, "short")# (<em>#dateDiff("d", date_cleaned, now())# days ago</em>)<br/><br/>
            <img src="#image#" align="#htmlEditFormat(section_name)#" style="width:740px;"><br/>
			<cfif frmSectionId lte 0>
				<cfset frmSectionId = section_id>
			</cfif> 
		</cfoutput>
	</cfif>
</cfif>

<br />
<!---draw a form for CS to report/revise cleaning--->
<cfset canEdit = 0>
<cfif hasMasks('CS')>
	<cfif hasMasks('Admin')>
		<cfset canEdit = 1>
	<cfelseif frmCleaningId gt 0 AND frmUsername eq session.cas_username>
		<cfset canEdit = 1>
	</cfif>
	<h3>Cleaning Form</h3>
	<form action="ic-cleaning.cfm" method="post">
		<table>
	<cfif frmCleaningId gt 0><input type="hidden" name="frmCleaningId" value="<cfoutput>#frmCleaningId#</cfoutput>"></cfif>
			<cfoutput>
				<!---for admins let them enter custom dates, everyone else gets the default--->
				<tr>
				<cfif canEdit>
					<td><label for="dateFieldId">Date: </label></td>
					<td><input id="dateFieldId" type="text" name="frmDate" value="#htmlEditFormat(frmDate)#"></td>
				<cfelse>
					#htmlEditFormat(frmDate)#
				</cfif>
				</tr>
			</cfoutput>

			<cfoutput>
				<!---for admins allow custom input, everyone else just records their username--->
				<tr>
				<cfif hasMasks('Admin')>
					
					<td><label for="usernameTextId">Username: </label></td>
					<td><input id="usernameTextId" type="text" name="frmUsername" size="8" value="#htmlEditFormat(frmUsername)#"></td>
				<cfelse>
					<td colspan="2">#htmlEditFormat(frmUsername)#</td>
				</cfif>
				</tr>
			</cfoutput>

				<cfquery datasource="#application.applicationDatasource#" name="getSections">
					SELECT section_id, section_name
					FROM tbl_ic_cleaning_sections
					WHERE active = 1
					ORDER BY section_name ASC
				</cfquery>
				<tr>
				<cfif frmCleaningId eq 0 OR canEdit>
					<td><label for="selectFieldId">Section: </label></td>
					<td><select id="selectFieldId"  name="frmSectionId">
					<cfoutput query="getSections">
						<option value="#section_id#" <cfif section_id eq frmSectionId>selected</cfif>>#htmlEditFormat(section_name)#</option>
					</cfoutput>
					</select>
					</td>
				<cfelse>
					<cfloop query="getSections">
						<td colspan="2"><cfif section_id eq frmSectionId><cfoutput>#section_name#</cfoutput><cfbreak></cfif></td>
					</cfloop>
				</cfif>
				</tr>
				<tr>
				<cfif hasMasks('Admin')>
					<td><label for="commentFieldId">Comments: </label></td>
					<td><textarea id="commentFieldId" class="special" style="width:100%;height:50px;"name="frmComments"><cfoutput>#htmlEditFormat(frmComments)#</cfoutput></textarea></td>
				<cfelse>
					<td colspan="2"><cfoutput>#stripTags(frmComments)#</cfoutput></td>
				</cfif>
				</tr>
				<tr>
				<td colspan="2"><input type="submit"  name="frmSubmit" value="<cfif frmCleaningId gt 0>Update<cfelse>Submit</cfif>"></td>
		</tr>
		<table>
	</form>
</cfif>
<br />
<!---show recent cleanings--->
<cfif frmCleaningId lte 0>
	<h3>Recent Cleanings</h3>
	<cfquery datasource="#application.applicationDataSource#" name="getCleanings">
		SELECT TOP 8 c.clean_id, c.username, cs.section_name, c.comments, c.date_cleaned
		FROM tbl_ic_cleaning c
		INNER JOIN tbl_ic_cleaning_sections cs ON cs.section_id = c.section_id
		ORDER BY c.date_cleaned DESC
	</cfquery>
	
	<table>
		<tr>
			<th scope="col">Date</th>
			<th scope="col">Cleaned By</th>
			<th scope="col">Section</th>
			<th scope="col">Comments</th>
		</tr>
	<cfset cnt = 0>
	<cfoutput query="getCleanings">
		<tr class="<cfif cnt mod 2 eq 0>row3<cfelse>row2</cfif>">
			<td>
				 #dateFormat(date_cleaned, "MMM d, yyyy")# #timeFormat(date_cleaned, "short")#
                 <cfif canEdit>
					<span>[<a href="?frmSubmit=Delete&frmCleaningId=#clean_id#" onClick="return confirm ('Are You Sure You Want To Delete This Cleaning?');">Delete</a>]</span>
				</cfif>
			</td>
			<td>#htmlEditFormat(username)#</td>
			<td>#htmlEditFormat(section_name)#</td>
			<td>
				<cfif len(comments) eq 0><em>none</em></cfif>
				#htmlEditFormat(left(comments, 80))#<cfif len(comments) gt 80>...</cfif>
			</td>
		</tr>
		<cfset cnt = cnt + 1>
	</cfoutput>
	</table>
</cfif>
<cfinclude template="#application.appPath#/footer.cfm">