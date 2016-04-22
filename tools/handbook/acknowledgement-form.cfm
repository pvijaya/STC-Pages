<cfmodule template="#application.appPath#/header.cfm" title='Handbook Acknowledgment Form' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="consultant">
<cfparam name="action" type="string" default="">

<h1>Handbook Acknowledgment Form</h1>
<cfset maskList = "consultant">
<cfif hasMasks("CS")>
	<cfset maskList = "CS">
</cfif>

<cfif action EQ "Acknowledge">
	<cftry>
		<cfquery name="insertConsultant" datasource="#application.applicationDataSource#">
			INSERT INTO tbl_handbook_acknowledgements(user_id)
			VALUES(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">)
		</cfquery>
		<cfoutput>
			<p class="ok">
			<b>Success</b>
			You have confirmed your acknowledgement of the handbook!
			</p>
		</cfoutput>
		
		<!---
			Now, here's where it gets a little crazy.  Also insert their acknowledgement into the applicable PIEs they have masks for.
			Start by finding which instance masks they have, along with the PIE's DSN.
		--->
		<cfquery datasource="#application.applicationDataSource#" name="getUserInstances">
			SELECT i.instance_id, i.datasource
			FROM tbl_instances i
			WHERE 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask)
		</cfquery>
		
		<!---loop over those tables checking if they already have an answer, and updating it, or inserting a new answer if needed--->
		<cfloop query="getUserInstances">
			<cfset hbQid = 0><!---Sadly the question_id in the two PIEs is not the same, and there's no easy way to find it, swet the value with a switch.--->
			<cfswitch expression="#instance_id#">
				<cfcase value="1">
					<cfset hbQid = 209>
				</cfcase>
				<cfcase value="2">
					<cfset hbQid = 231>
				</cfcase>
			</cfswitch>
			
			<cfif hbQid eq 0>
				<cfthrow type="custom" message="Instance Issue" detail="Could not find the PIE handbook question for instance ###instance_id#">
			</cfif>
			
			<!---we also need the user's pie_id, or "ssn"(don't panic, it isn't a real ssn) so we can check for existing answers, or create new ones.--->
			<cfquery datasource="#application.applicationDataSource#" name="getPieId">
				SELECT ssn
				FROM [#datasource#].dbo.tbl_consultants
				WHERE LOWER(username) = <cfqueryparam cfsqltype="cf_sql_varchar" value="#lcase(session.cas_username)#">
			</cfquery>
			
			<!---throw an error if we couldn't find the user--->
			<cfif getPieId.recordCount eq 0>
				<cfthrow type="custom" message="Database Error" detail="Could not find user #session.cas_username# in #datasource#">
			</cfif>
			<cfset pieId = getPieId.ssn>
			
			<!---now we can actually check if the handbook questions has already been answered on this PIE.--->
			<cfquery datasource="#application.applicationDataSource#" name="getPieAnswer">
				SELECT TOP 1 answer_id, answer
				FROM [#datasource#].dbo.tbl_questions_answers
				WHERE question_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#hbQid#">
				AND answered_about = <cfqueryparam cfsqltype="cf_sql_integer" value="#pieId#">
				ORDER BY ts DESC
			</cfquery>
			
			<!---Finally, we can update or insert to this instance of PIE accordingly.--->
			<cfif getPieAnswer.recordCount gt 0>
				<cfif getPieAnswer.answer eq "" OR getPieAnswer.answer eq 0>
					<cfquery datasource="#application.applicationDataSource#" name="updatePieHBAnswer">
						UPDATE [#datasource#].dbo.tbl_questions_answers
						SET
							ANSWERED_BY = <cfqueryparam cfsqltype="cf_sql_integer" value="#pieId#">, 
							ANSWERED_ABOUT = <cfqueryparam cfsqltype="cf_sql_integer" value="#pieId#">,
							ANSWER = 1,
							TS = GETDATE()
						WHERE ANSWER_ID = <cfqueryparam cfsqltype="cf_sql_integer" value="#getPieAnswer.answer_id#">
					</cfquery>
				</cfif>
			<cfelse>
				<cfquery datasource="#application.applicationDataSource#" name="insertPieHBAnswer">
					EXEC [#datasource#].dbo.answers_insert
						@question_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#hbQid#">,
						@answered_by = <cfqueryparam cfsqltype="cf_sql_integer" value="#pieId#">,
						@answered_about = <cfqueryparam cfsqltype="cf_sql_integer" value="#pieId#">,
						@answer = 1,
						@answer_group = 0,
						@TS = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
						@link_integer = NULL,
						@make_review_entry = 0
				</cfquery>
			</cfif>
		</cfloop>
		
	<cfcatch>
		<cfoutput>
			<p class="warning">
			<b>Error</b>
			#cfcatch.message# - #cfcatch.Detail#
			</p>
		</cfoutput>
	</cfcatch>
	</cftry>
</cfif>





<!---HTML--->
<p><b>This form must be acknowledged before consultants will receive their first paycheck.</b></p>

<p>
	Technology Center Consulting has shared this Employee Handbook with the Dean of Students, Employee Relations Office, 
	University Counsel and the Student Employment Office and has received excellent guidance and approval from them for 
	the policies and procedures contained herein. This employee handbook describes important information about TCC and, 
	as a consultant, I understand I should refer any policy questions not answered in this handbook to TCC management.
</p>


<p>
	I acknowledge the information, policies, and benefits described herein are necessarily subject to change and 
	revisions to this handbook may occur. All such changes will be communicated through official notices, and I 
	understand revised information supersedes, modifies, or eliminates existing policies. Only the Management of 
	Technology Center Consulting has the authority to adopt revisions to the policies in this handbook.</p>


<p>
	I understand employment for positions covered by this handbook is strictly on a semester basis and employment for 
	covered employees hired prior to or at any time during the semester ceases the last day of the semester. The two 
	summer sessions will be considered as a single "semester" for purposes of this handbook. I also understand TCC 
	reserves the right to immediately discharge any employee at its sole discretion. All employees are employed at will,
	 and both they and TCC may terminate the employment relationship at any time, with or without cause, without 
	 following any specific procedure.
</p>


<p>
	I further understand I must reapply a minimum of four weeks prior to the end of the current semester in order to 
	be considered for a position for the following semester and I will be notified two weeks before the end of the semester,
	 if I am being offered a position for the following semester. Lacking such notification, I understand my employment 
	 terminates the last day of the semester.
</p>


<p>
	I acknowledge I have been directed to the electronic version of the Technology Center Consulting Consultant Handbook
	 and that it is my responsibility to read, understand, and comply with the policies and procedures contained therein
	  and any revisions made to the handbook. In signing this acknowledgement form I am confirming my agreement to abide
	   by policies and follow procedures as stated in the TCC Consultant Handbook and subsequent revisions.
</p>


<form action="<cfoutput>#cgi.script_name#</cfoutput>" method="POST">
	<input type="submit" name="action" value="Acknowledge">
</form>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>