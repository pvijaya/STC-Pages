<cfmodule template="#application.appPath#/header.cfm" title='Badge Search' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="frmUserId" type="integer" default="0">
<cfparam name="frmAssignerId" type="integer" default="0">
<cfparam name="frmBadgeId" type="integer" default="0">
<cfparam name="frmAction" type="string" default="">
<cfparam name="currentEmployee" type="boolean" default="0">
<cfparam name="frmStartDate" type="date" default="#dateAdd("d", -30, now())#">
<cfparam name="frmEndDate" type="date" default="#now()#">

<!---now trim out extraneous time portions from start date and end date.--->
<cfset frmStartDate = dateFormat(frmStartDate, "mm/dd/yyyy 00:00")>
<cfset frmEndDate = dateFormat(frmEndDate, "mm/dd/yyyy 23:59:59.999")>

<!---now find the details of the current instance based on instanceId--->
<cfset myInstance = getInstanceById(Session.primary_instance)>

<!--- HEADER / NAVIGATION --->
<cfoutput>
	<h1>Achievement Badges (#myInstance.instance_mask#)</h1>
	<cfinclude template="#application.appPath#/tools/badges/secondary-navigation.cfm">
</cfoutput>
<br/><br/>

<!---QUERIES--->
<cfquery datasource="#application.applicationDataSource#" name="getBadges">
	SELECT *
	FROM tbl_badges
	WHERE active = <cfqueryparam cfsqltype="cf_sql_integer" value="1">
		  AND instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
	ORDER BY instance_id, badge_name
</cfquery>

<cfquery datasource="#application.applicationDataSource#" name="getInstanceMasks">
	SELECT i.instance_mask
	FROM tbl_instances i
	WHERE i.instance_id != <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
</cfquery>

<!--- when we search users, we want consultants only; build up the blacklist for this --->
<cfset blackList = "Logistics"><!---we never want to display admins or Logistics folks here.--->
<cfset blackList = listAppend(blackList, "Admin")>
<cfif not hasMasks("Admin")>
	<cfset blackList= listAppend(blackList, "CS")>
</cfif>
<cfloop query="getInstanceMasks">
	<cfset blackList = listAppend(blackList, getInstanceMasks.instance_mask)>
</cfloop>


<!--- DRAW FORMS --->
<cfoutput>

	<!--- search by consultant --->
	<fieldset style="width:45%;display:inline-block;vertical-align:top;">
		<legend>Search By Consultant</legend>
		<form action="#cgi.script_name#" method="POST">
			#drawConsultantSelector('consultant', blackList, frmUserId, 0, "frmUserId")#
			<input type="submit"  name="frmAction" value="Find Badges">
		</form>
	</fieldset>

	<!--- search by badge --->
	<fieldset style="width:45%;display:inline-block;vertical-align:top;">
		<legend>Search By Badge</legend>
		<form action="#cgi.script_name#" method="POST">
			<label for="selectfrmBadgeId">Select Badge:</label>
			<select id="selectfrmBadgeId" name="frmBadgeId">
				<option value="0">---</option>
				<cfloop query="getBadges">
					<option value="#badge_id#"
							<cfif badge_id EQ frmBadgeId>selected="selected"</cfif>>#badge_name#
					</option>
				</cfloop>
			</select>
			<br/>&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp<input type="checkbox" id="currentEmployee" name="currentEmployee" value="1" <cfif currentEmployee>checked</cfif>/>Current Employees<br\>
			<input type="submit" id="submit" name="frmAction" value="Find Consultants">
		</form>
	</fieldset>

	<!--- search by assigning cs --->
	<!--- only draw this for users who don't have CS in their blacklist.--->
	<cfif not listFindNoCase(blackList, "CS")>
		<fieldset style="width:45%;display:inline-block;vertical-align:top;">
			<legend>Search By Assigning CS</legend>
			<form action="#cgi.script_name#" method="POST">
				#drawConsultantSelector('cs', blackList, frmAssignerId, 0, "frmAssignerId")#
				<input type="submit"  name="frmAction" value="Find Badges">
			</form>
		</fieldset>
	</cfif>

	<!--- search by from and to date --->
	<fieldset style="width:45%;display:inline-block;vertical-align:top;">
		<legend>Search By Date</legend>
		<form action="#cgi.script_name#" method="POST">
			<label>
		Starting: <input type="text" class="date" name="frmStartDate" value="<cfoutput>#dateFormat(frmStartDate, 'mmm d, yyyy')#</cfoutput>">
	</label>
	&nbsp;&nbsp;
	<label>
		Through: <input type="text" class="date" name="frmEndDate" value="<cfoutput>#dateFormat(frmEndDate, 'mmm d, yyyy')#</cfoutput>">
	</label>
			<input type="submit" id="submit" name="frmAction" value="Totals">
			<input type="submit" id="submit" name="frmAction" value="Find Badges">
		</form>
	</fieldset>
</cfoutput>
<script type="text/javascript">
	$(document).ready(function(){
		$("input.date").datepicker({dateFormat: "M d, yy"});
	});
</script>

<!--- HANDLE USER INPUT --->
<cfoutput>

	<!--- search by consultant --->
	<cfif frmAction EQ "Find Badges" AND frmUserId GT 0>

		<!--- fetch the viewing user's badges --->
		<cfquery datasource="#application.applicationDataSource#" name="getCurrentUserBadges">
			SELECT m.badge_id
			FROM tbl_badges_users_matches m
			JOIN tbl_badges b ON b.badge_id = m.badge_id
			WHERE m.active = 1
				  AND m.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
			ORDER BY b.badge_name
		</cfquery>

		<cfset currentUserBadgeList = ''>
		<cfloop query="getCurrentUserBadges">
			<cfset currentUserBadgeList = listAppend(currentUserBadgeList,getCurrentUserBadges.badge_id)>
		</cfloop>

		<!--- fetch the selected user's name--->
		<cfquery datasource="#application.applicationDataSource#" name="getUserName">
			SELECT preferred_name
			FROM tbl_users
			WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">
		</cfquery>

		<cfloop query="getUserName">
			<h2>#preferred_name#'s Badges</h2>
		</cfloop>

		<!--- fetch the selected user's badges --->
		<cfquery datasource="#application.applicationDataSource#" name="getUserBadges">
			SELECT count(b.badge_id) AS 'badge_count', b.badge_id, b.image_url, b.description, b.badge_name
			FROM tbl_badges_users_matches m
			INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
			WHERE m.active = 1
				  AND m.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">
			GROUP BY b.badge_id, b.image_url, b.description, b.badge_name
		</cfquery>

		<cfloop query="getUserBadges">

			<cfif listFind(currentUserBadgeList, getUserBadges.badge_id) GTE 1>
				<cfset lineColor = "##8CFFAB">
			<cfelse>
				<cfset lineColor = "##AB1A1A">
			</cfif>

			<!--- because the badges need to be grouped, we have to fetch the specific assignment --->
			<!--- info in an individual query --->
			<cfquery datasource="#application.applicationDataSource#" name="getAssignment">
				SELECT TOP 1 u.username, m.time_assigned
				FROM tbl_badges_users_matches m
				INNER JOIN tbl_users u ON u.user_id = m.assigner_id
				WHERE m.badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#badge_id#">
				AND m.user_id =<cfqueryparam cfsqltype="cf_sql_integer" value="#frmUserId#">
				ORDER BY m.time_assigned DESC
			</cfquery>

			<cfset auditMessage = "Last assigned on <br/>#dateTimeFormat(getAssignment.time_assigned, 'mmm dd, yyyy')# <br/>by #getAssignment.username#">

			<fieldset style="padding:5px;display:inline-block;vertical-align:top;width:140px;"  title="#getUserBadges.description#">
				<legend style="float:right;margin:-15px -15px 0px 0px;padding:2px 5px;"><strong>#getUserBadges.badge_count#</strong></legend>
				<strong>#getUserBadges.badge_name#</strong><br/>
				<div style="margin:5px 0px;text-align:center;"><img src="#getUserBadges.image_url#" style="width:125px;vertical-align:top;" /></div>
				<hr style="height:10px;background-color:#lineColor#;"/>
				<cfif hasMasks('CS')><div style="text-align:center;">#auditMessage#</div></cfif>
			</fieldset>

		</cfloop>

		<cfif getUserBadges.recordCount EQ 0>
			<p>This consultant has no badges.</p><br/>
		</cfif>

		<fieldset style="width:390px;">
			<legend>Legend</legend>

			<div class="block-card"  style="padding:5px;overflow:auto;display:inline-block;vertical-align:top;">
				<hr style="width:100px;height:10px;background-color:##8CFFAB;"/>
				<div>You have this badge</div>
			</div>
			<div class="block-card"  style="padding:5px;overflow:auto;display:inline-block;vertical-align:top;">
				<hr style="width:100px;height:10px;background-color:##AB1A1A;"/>
				<div>You don't have this badge</div>
			</div>

		</fieldset>
		<br/>

	<!--- search by assigning cs --->
	<cfelseif frmAction EQ "Find Badges" AND frmAssignerId GT 0>

		<!--- fetch the selected user's name--->
		<cfquery datasource="#application.applicationDataSource#" name="getUserName">
			SELECT preferred_name
			FROM tbl_users
			WHERE user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmAssignerId#">
		</cfquery>

		<cfloop query="getUserName">
			<h2>Badges Assigned By #preferred_name#</h2>
		</cfloop>

		<!--- fetch the badges assigned by the selected user --->
		<cfquery datasource="#application.applicationDataSource#" name="getUserBadges">
			SELECT b.badge_id, b.image_url, b.description, b.badge_name, m.time_assigned, m.user_id, u.username
			FROM tbl_badges_users_matches m
			INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
			INNER JOIN tbl_users u ON u.user_id = m.user_id
			WHERE m.active = 1
			AND 1 > (
						SELECT COUNT(user_id) AS 'total'
						FROM tbl_users_masks_match mm2
						INNER JOIN tbl_user_masks um2 ON um2.mask_id = mm2.mask_id
						WHERE um2.mask_name IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" list="true" value="#blackList#">)
						AND mm2.user_id = u.user_id
					 )
			AND m.assigner_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmAssignerId#">
		</cfquery>

		<cfloop query="getUserBadges">

			<cfset auditMessage = "Assigned on <br/>#dateTimeFormat(time_assigned, 'mmm dd, yyyy')# <br/>to <a href=""#cgi.script_name#?frmUserId=#user_id#&frmAction=#urlEncodedFormat('Find Badges')#"">#username#</a>">

			<fieldset style="padding:5px;display:inline-block;vertical-align:top;width:140px;"  title="#getUserBadges.description#">
				<strong>#getUserBadges.badge_name#</strong><br/>
				<div style="margin:5px 0px;text-align:center;"><img src="#getUserBadges.image_url#" style="width:125px;vertical-align:top;" /></div>
				<cfif hasMasks('CS')><div style="text-align:center;">#auditMessage#</div></cfif>
			</fieldset>

		</cfloop>

		<cfif getUserBadges.recordCount EQ 0>
			<p>This CS has not assigned any badges.</p>
		</cfif>

		<br/>

	<!--- search by badge --->
	<cfelseif frmAction EQ "Find Consultants">
			<cfif currentEmployee EQ "1">
				<cfquery datasource="#application.applicationDataSource#" name="getBadgeInfo">
				SELECT badge_name,description
				FROM tbl_badges
				WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmBadgeId#">
				</cfquery>

				<cfloop query="getBadgeInfo">
					<h2 style="margin-bottom:5px;line-height:100%;">Existing Consultants with the #badge_name# Achievement Badge</h2>
					<div style="margin-left:15px;">(#description#)</div>
				</cfloop>

			<!---Finds consultants who have this badge--->
			<cfquery datasource="#application.applicationDataSource#" name="getBadgeUsers">
				SELECT m.user_id, u.username, u.preferred_name, u.picture_source, a.username AS assigned_by, MAX(m.time_assigned) AS time_assigned
				FROM tbl_badges_users_matches m
				INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
				INNER JOIN tbl_users u ON m.user_id = u.user_id
				INNER JOIN tbl_users a ON m.assigner_id = a.user_id
				WHERE m.badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmBadgeId#">
				AND m.active = 1
				AND 1 > (
							SELECT COUNT(user_id) AS 'total'
							FROM tbl_users_masks_match mm2
							INNER JOIN tbl_user_masks um2 ON um2.mask_id = mm2.mask_id
							WHERE um2.mask_name IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" list="true" value="#blackList#">)
							AND mm2.user_id = u.user_id
						 )
				/*make sure they have the required masks*/
				AND 0 = (
					SELECT COUNT(m.mask_id)
					FROM tbl_user_masks m
					LEFT OUTER JOIN tbl_users_masks_match um
						ON um.mask_id = m.mask_id
						AND um.user_id = u.user_id
					WHERE mask_name IN ('Consultant')
					AND um.matchId IS NULL
				)
				GROUP BY m.user_id, u.username, u.preferred_name, u.picture_source, a.username
				ORDER BY time_assigned DESC, u.username
			</cfquery>

			<cfloop query="getBadgeUsers">
				<div class='block-card' style='width:140px;display:inline-block;vertical-align:top;'>
					<img src="#picture_source#" width="120px" style='margin:5px 0px;'/>
					Assigned on<br/>
					#dateFormat(time_assigned, "mmm dd, yyyy")#<br/>
					to <a href="#cgi.script_name#?frmUserId=#user_id#&frmAction=#urlEncodedFormat('Find Badges')#">#username#</a><br/>
					<cfif hasMasks('CS')>by #assigned_by#</cfif>
				</div>
			</cfloop>
		<cfelseif currentEmployee EQ "0">
			<cfquery datasource="#application.applicationDataSource#" name="getBadgeInfo">
					SELECT badge_name,description
					FROM tbl_badges
					WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmBadgeId#">
				</cfquery>

				<cfloop query="getBadgeInfo">
					<h2 style="margin-bottom:5px;line-height:100%;">Consultants with the #badge_name# Achievement Badge</h2>
					<div style="margin-left:15px;">(#description#)</div>
				</cfloop>

				<!---Finds consultants who have this badge--->
				<cfquery datasource="#application.applicationDataSource#" name="getBadgeUsers">
					SELECT m.user_id, u.username, u.preferred_name, u.picture_source, a.username AS assigned_by, MAX(m.time_assigned) AS time_assigned
					FROM tbl_badges_users_matches m
					INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
					INNER JOIN tbl_users u ON m.user_id = u.user_id
					INNER JOIN tbl_users a ON m.assigner_id = a.user_id
					WHERE m.badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmBadgeId#">
					AND m.active = 1
					/*make sure they don't have any of the blacklisted masks*/
					AND 1 > (
								SELECT COUNT(user_id) AS 'total'
								FROM tbl_users_masks_match mm2
								INNER JOIN tbl_user_masks um2 ON um2.mask_id = mm2.mask_id
								WHERE um2.mask_name IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" list="true" value="#blackList#">)
								AND mm2.user_id = u.user_id
							 )

					GROUP BY m.user_id, u.username, u.preferred_name, u.picture_source, a.username
					ORDER BY time_assigned DESC, u.username
				</cfquery>

				<cfloop query="getBadgeUsers">
					<div class='block-card' style='width:140px;display:inline-block;vertical-align:top;'>
						<img src="#picture_source#" width="120px" style='margin:5px 0px;'/>
						Assigned on<br/>
						#dateFormat(time_assigned, "mmm dd, yyyy")#<br/>
						to <a href="#cgi.script_name#?frmUserId=#user_id#&frmAction=#urlEncodedFormat('Find Badges')#">#username#</a><br/>
						<cfif hasMasks('CS')>by #assigned_by#</cfif>
					</div>
				</cfloop>
		</cfif>
	<!--- for the given date--->
	<cfelseif frmAction EQ "Find Badges">
		<cfquery datasource="#application.applicationDataSource#" name="getBadgeInfo">
					SELECT badge_name,description
					FROM tbl_badges
					WHERE badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#frmBadgeId#">
				</cfquery>

				<cfloop query="getBadgeInfo">
					<h2 style="margin-bottom:5px;line-height:100%;">Consultants with the #badge_name# Achievement Badge</h2>
					<div style="margin-left:15px;">(#description#)</div>
				</cfloop>

				<!---Finds consultants who were assigned badge during this time--->
				<cfquery datasource="#application.applicationDataSource#" name="getUsersTime">
					SELECT m.user_id, u.username AS username2, u.preferred_name, u.picture_source, a.username AS assigned_by, b.badge_name AS badge_name , MAX(m.time_assigned) AS time_assigned
					FROM tbl_badges_users_matches m
					INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
					INNER JOIN tbl_users u ON m.user_id = u.user_id
					INNER JOIN tbl_users a ON m.assigner_id = a.user_id
					WHERE m.time_assigned BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
					AND m.active = 1
					AND b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
					/*make sure they don't have any of the blacklisted masks*/
					AND 1 > (
								SELECT COUNT(user_id) AS 'total'
								FROM tbl_users_masks_match mm2
								INNER JOIN tbl_user_masks um2 ON um2.mask_id = mm2.mask_id
								WHERE um2.mask_name IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" list="true" value="#blackList#">)
								AND mm2.user_id = u.user_id
							 )

					GROUP BY m.user_id, u.username, u.preferred_name, u.picture_source, a.username, b.badge_name, m.time_assigned
					ORDER BY m.time_assigned DESC, b.badge_name
				</cfquery>
				<h2 style="margin-bottom:5px;line-height:100%;">Badges assigned from #dateFormat(frmStartDate, "mmm dd, yyyy")# through #dateFormat(frmEndDate, "mmm dd, yyyy")#</h2>
				<cfloop query="getUsersTime">
					<div class='block-card' style='width:140px;display:inline-block;vertical-align:top;'>
						<strong>#badge_name#</strong><br/>
						<img src="#picture_source#" width="120px" style='margin:5px 0px;'/>
						Assigned on<br/>
						#dateFormat(time_assigned, "mmm dd, yyyy")#<br/>
						to <a href="#cgi.script_name#?frmUserId=#user_id#&frmAction=#urlEncodedFormat('Find Badges')#">#username2#</a><br/>
						<cfif hasMasks('CS')>by #assigned_by#</cfif>
					</div>
				</cfloop>
<!--- this is for count --->
<cfelseif frmAction EQ "Totals">

				<!---Finds consultants who were assigned badge during this time--->
				<cfquery datasource="#application.applicationDataSource#" name="getUsersCount">
					SELECT b.badge_name AS badge_name , COUNT(b.badge_id) AS count_badges, MAX(m.time_assigned) AS time_assigned
					FROM tbl_badges_users_matches m
					INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
					INNER JOIN tbl_users u ON m.user_id = u.user_id
					WHERE m.time_assigned BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmStartDate#"> AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#frmEndDate#">
					AND m.active = 1
					AND b.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
					/*make sure they don't have any of the blacklisted masks*/
					AND 1 > (
								SELECT COUNT(user_id) AS 'total'
								FROM tbl_users_masks_match mm2
								INNER JOIN tbl_user_masks um2 ON um2.mask_id = mm2.mask_id
								WHERE um2.mask_name IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" list="true" value="#blackList#">)
								AND mm2.user_id = u.user_id
							 )

					GROUP BY b.badge_name
					ORDER BY b.badge_name ASC
				</cfquery>
				<h2 style="margin-bottom:5px;line-height:100%;">Total badges assigned from #dateFormat(frmStartDate, "mmm dd, yyyy")# through #dateFormat(frmEndDate, "mmm dd, yyyy")#</h2>
				<cfloop query="getUsersCount">
					<div class='block-card' style='width:140px;display:inline-block;vertical-align:top;'>
						<strong>#badge_name#</strong><br/>
						Total<br/>
						#count_badges#<br/>
					</div>
				</cfloop>

	<!--- otherwise, just show recent badge assignments --->
	<cfelse>

		<h2>Recent Badges Awarded</h2>

		<!---Finds consultants who have this badge--->
		<cfquery datasource="#application.applicationDataSource#" name="getRecentBadgeAwards">
			SELECT TOP 25 b.badge_name, m.user_id, u.username, b.image_url, b.description, m.time_assigned, a.username AS assigned_by
			FROM tbl_badges_users_matches m
			INNER JOIN tbl_badges b ON b.badge_id = m.badge_id
			INNER JOIN tbl_users u ON m.user_id = u.user_id
			INNER JOIN tbl_users a ON m.assigner_id = a.user_id
			WHERE b.active = 1
			AND 1 > (
						SELECT COUNT(user_id) AS 'total'
						FROM tbl_users_masks_match mm2
						INNER JOIN tbl_user_masks um2 ON um2.mask_id = mm2.mask_id
						WHERE um2.mask_name IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" list="true" value="#blackList#">)
						AND mm2.user_id = u.user_id
					 )
			ORDER BY m.time_assigned DESC

		</cfquery>

		<cfloop query="getRecentBadgeAwards">
			<div class="block-card" style="padding:5px;overflow:auto;display:inline-block;vertical-align:top;width:140px;"  title="#description#">
				<strong>#badge_name#</strong><br/>
				<img src="#image_url#" style="width:125px;float:left;vertical-align:top;" />
				<br/>
				<div style="align: center;">
					Assigned on<br/>
					#dateFormat(time_assigned, "mmm dd, yyyy")#<br/>
					to <a href="#cgi.script_name#?frmUserId=#user_id#&frmAction=#urlEncodedFormat('Find Badges')#">#username#</a><br/>
					<cfif hasMasks('CS')>by #assigned_by#</cfif>
				</div>
			</div>
		</cfloop>

	</cfif>

</cfoutput>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>