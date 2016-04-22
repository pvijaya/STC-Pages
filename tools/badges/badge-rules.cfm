<!---All this module does is to return list of usernames that should be awarded a badge--->

<cffunction name="getNewBadgesUsersByBadgeRule">
	<cfargument name="badgeId" type="numeric" default="0">
	<cfargument name="curDate" type="date"  default="" required="false">

	<cfset var allowedUserList = ''>
	<!---because some badges are for an entire month, and we don't want to miss behavior for the previous day, we want our "current date" to be one day behind.--->
	<cfset var assignedDate = curDate>

	<cffunction name="consultantsWhoHaveBadge">
		<cfargument name="badgeId" type="numeric" required="yes">
		<cfargument name="startDate" type="date" default="#dateFormat(now())#">
		<cfargument name="endDate" type="date" default="#dateFormat(now())#">
		<cfset var alreadyHave = ''>
		<cfquery datasource="#application.applicationDataSource#" name="alreadyHave">
			SELECT u.username
			FROM tbl_badges_users_matches m
			INNER JOIN tbl_users u ON u.user_id = m.user_id
			WHERE m.badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.badgeId#">
			AND m.active = 1
			AND m.time_assigned BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.startDate#">
								 AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.endDate#">
		</cfquery>
		<cfset var alreadyHaveList = "">
		<cfloop query="alreadyHave">
			<cfset alreadyHaveList = listAppend(alreadyHaveList, alreadyHave.username)>
		</cfloop>
		<cfreturn alreadyhaveList>
	</cffunction>

	<cffunction name="GetConsultantsWithoutBadge">
		<cfargument name="instanceMask" type="string" required="yes">
		<cfargument name="listOfUsersWithBadge" type="string">
		<cfset var getEligible = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getEligible">
			SELECT DISTINCT u.username
			FROM  tbl_users u
			INNER JOIN tbl_users_masks_match umm ON umm.user_id = u.user_id
			INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
			WHERE u.username NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#listOfUsersWithBadge#" list="true">)
			AND um.mask_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#instanceMask#">
		</cfquery>
		<cfreturn getEligible>
	</cffunction>

	<cffunction name="getOnlyConsultantAndCs">
		<cfargument name="activeUsers" type="string">
		<cfargument name="instanceMask" type="string" required="yes">

		<!---to further winnow our eligible users fetch their masks, and ultimately only return those who are consultants or CS, but NOT Admins.--->
		<cfset var ourMasks = bulkGetUserMasks(activeUsers)>

		<cfset var checkUsers = "">
		<cfset var allowedList = "Consultant">

		<cfif arguments.instanceMask NEQ "">
			<cfset allowedList = listAppend(allowedList, arguments.instanceMask)>
		</cfif>

		<cfloop list="#activeUsers#" index="myUser">
			<cfif bulkHasMasks(ourMasks, myUser, allowedList) AND NOT bulkHasMasks(ourMasks, myUser, 'Admin')  AND NOT bulkHasMasks(ourMasks, myUser, 'Logistics')>
				<cfset checkUsers = listAppend(checkUsers, myUser)>
			</cfif>
		</cfloop>
		<cfreturn checkUsers>
	</cffunction>

	<!---Gets a list of Consultants and CS that haven't earned the badge in a particular timeframe--->
	<cffunction name="getAllowedUsers">
		<cfargument name="badgeId" type="numeric" required="yes">
		<cfargument name="instanceMask" type="string" required="yes">
		<cfargument name="startDate" type="date" default="#dateFormat(now())#">
		<cfargument name="endDate" type="date" default="#dateFormat(now())#">
		<cfargument name="skipSemesterWorkedCheck" type="boolean" default="false" required="false">
		<!---rule out people who already have this badge for this month.--->
		<cfset alreadyHaveList = consultantsWhoHaveBadge(arguments.badgeId, arguments.startDate, arguments.endDate)>

		<!---now get a list of users that are eligible for this badge--->
		<cfset var getEligible = ''>
		<cfif !skipSemesterWorkedCheck>
			<cfquery datasource="#getPieDatasource(badgeId)#" name="getEligible">
				/*this query does two checks - when their first shift was, and if they actually worked a shift in the last semester*/
				SELECT DISTINCT c.username
				FROM tbl_semesters s
				INNER JOIN tbl_checkins ci ON ci.start_time BETWEEN s.start_date AND s.end_date/*actually worked shifts during this semester*/
				INNER JOIN (
					SELECT c.ssn, MIN(ci.start_time) AS first_shift
					FROM tbl_consultants c
					INNER JOIN tbl_checkins ci ON ci.ssn = c.ssn
					GROUP BY c.ssn
				) fs
					ON fs.ssn = ci.ssn
					AND fs.first_shift < DATEADD(week, 1, s.start_date)/*someone's first shift could have been in this semester, so add a week to he constraint*/
				INNER JOIN tbl_consultants c ON c.ssn = ci.ssn
				WHERE s.start_date <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.startDate#">
				AND s.end_date >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.endDate#">
				AND c.username NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#alreadyHaveList#" list="true">)
			</cfquery>
		<cfelse>
			<cfset getEligible = GetConsultantsWithoutBadge(instanceMask, alreadyHaveList)>
		</cfif>
		<cfset activeUsers = "">
		<cfloop query="getEligible">
			<cfset activeUsers = listAppend(activeUsers, getEligible.username)>
		</cfloop>

		<cfreturn getOnlyConsultantAndCs(activeUsers, instanceMask)>
	</cffunction>

	<!---get pie datasource from badgeId--->
	<cffunction name="getPieDatasource">
		<cfargument name="badgeId" type="numeric" required="yes">
		<cfset var pieDatasource = "">
		<cfquery datasource="#application.applicationDataSource#" name="pieDatasource">
			SELECT TOP 1 datasource
			FROM tbl_badges b
			INNER JOIN tbl_instances i ON i.instance_id = b.instance_id
			WHERE b.badge_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.badgeId#" list="true">
		</cfquery>
		<cfreturn pieDatasource.datasource>
	</cffunction>

	<!---get current semester start and end dates--->
	<cffunction name="getCurrentSemesterInfo">
		<cfargument name="currentDate" type="date" default="#dateFormat(now())#">
		<cfargument name="datasource" type="string" default="">
		<cfset var getPreviousSemester = ''>
		<cfquery datasource="#arguments.datasource#" name="getCurrentSemester">
			SELECT TOP 1 *
			FROM TBL_SEMESTERS s
			WHERE s.END_DATE > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.currentDate#">
			AND s.START_DATE < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.currentDate#">
			AND 30 < DATEDIFF("d",s.START_DATE,s.END_DATE) /*ignore small semesters like breaks*/
			ORDER BY s.END_DATE DESC
		</cfquery>
		<cfset var semesterInfo = {}>
		<cfloop query="getCurrentSemester">
			<cfset semesterInfo.id = getCurrentSemester.semester_id>
			<cfset semesterInfo.startDate = getCurrentSemester.start_date>
			<cfset semesterInfo.endDate = getCurrentSemester.end_date>
		</cfloop>
		<cfreturn semesterInfo>
	</cffunction>

	<!---get previous semester start and end dates--->
	<cffunction name="getPreviousSemesterInfo">
		<cfargument name="currentDate" type="date" default="#dateFormat(now())#">
		<cfargument name="datasource" type="string" default="">
		<cfset var getPreviousSemester = ''>
		<cfquery datasource="#arguments.datasource#" name="getPreviousSemester">
			SELECT TOP 1 *
			FROM TBL_SEMESTERS s
			WHERE s.END_DATE < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.currentDate#">
			AND 30 < DATEDIFF("d",s.START_DATE,s.END_DATE) /*ignore small semesters like breaks*/
			ORDER BY s.END_DATE DESC
		</cfquery>
		<cfset var semesterInfo = {}>
		<cfloop query="getPreviousSemester">
			<cfset semesterInfo.id = getPreviousSemester.semester_id>
			<cfset semesterInfo.startDate = getPreviousSemester.start_date>
			<cfset semesterInfo.endDate = getPreviousSemester.end_date>
		</cfloop>
		<cfreturn semesterInfo>
	</cffunction>

	<!---get all users who worked in a semester--->
	<cffunction name="getWorkingSemesterUsers">
		<cfargument name="semesterId" type="numeric" required="yes">
		<cfargument name="usernamesAllowed" type="string" required="yes">
		<cfargument name="datasource" type="string" required="yes">
		<!---a query to find people who actually worked this semester, and a didn't start mid-semester, thus are eligible for badges.--->
		<cfset var semesterUsers = ''>
		<cfquery datasource="#datasource#" name="semesterUsers">
			/*this query does two checks - when their first shift was, and if they actually worked a shift in the last semester*/
			SELECT DISTINCT c.username
			FROM tbl_semesters s
			INNER JOIN tbl_checkins ci ON ci.start_time BETWEEN s.start_date AND s.end_date/*actually worked shifts during this semester*/
			INNER JOIN (
				SELECT c.ssn, MIN(ci.start_time) AS first_shift
				FROM tbl_consultants c
				INNER JOIN tbl_checkins ci ON ci.ssn = c.ssn
				GROUP BY c.ssn
			) fs
				ON fs.ssn = ci.ssn
				AND fs.first_shift < DATEADD(week, 1, s.start_date)/*someone's first shift could have been in this semester, so add a week to he constraint*/
			INNER JOIN tbl_consultants c ON c.ssn = ci.ssn
			WHERE s.semester_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#arguments.semesterId#">
			AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.usernamesAllowed#" list="true">)
		</cfquery>
		<cfreturn semesterUsers>
	</cffunction>

	<!---gets users points in a semester (semester based)--->
	<cffunction name="getSemesterPointsUsers">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="startDate" type="date" required="true">
		<cfargument name="endDate" type="date" required="true">
		<cfset var semesterPointsUsers = ''>
		<cfquery datasource="#datasource#" name="semesterPointsUsers">
			/*This query does not check to determine if the consultant actually worked at all. thus, new consultants would get awarded for the previous semester they didn't work*/
			SELECT c.username
			FROM
				(SELECT DISTINCT D.DIS_ID, D.SSN,D.DIS_TYPE,D.ASSIGNED_BY, D.ASSIGNED_COMMENT, D.ASSIGNED_DATE, W.WARNING_ID,
					(CASE
						WHEN (SELECT da.dis_id
								FROM TBL_DIS_APPEALS da
								LEFT OUTER JOIN TBL_DIS_APPEAL_GROUPS ag ON da.APPEAL_GROUP_ID = ag.APPEAL_GROUP_ID
								WHERE da.DIS_ID = d.DIS_ID) IS NULL THEN 0
						WHEN (SELECT ag.granted
								FROM TBL_DIS_APPEALS da
								LEFT OUTER JOIN TBL_DIS_APPEAL_GROUPS ag ON da.APPEAL_GROUP_ID = ag.APPEAL_GROUP_ID
								WHERE da.DIS_ID = d.DIS_ID) IS NULL THEN 2
						/*just using granted doesn't work because the logic in the file is the oposite of granted*/
						ELSE (SELECT (case when ag.granted = 0 THEN 1 ELSE 0 end)
								FROM TBL_DIS_APPEALS da
								LEFT OUTER JOIN TBL_DIS_APPEAL_GROUPS ag ON da.APPEAL_GROUP_ID = ag.APPEAL_GROUP_ID
								WHERE da.DIS_ID = d.DIS_ID)
					END) as appealed
					FROM	TBL_DISCIPLINE D
					LEFT JOIN TBL_DIS_WARNINGS W on w.dis_id = d.dis_id
					WHERE	D.ASSIGNED_DATE < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.endDate#">
					AND	D.ASSIGNED_DATE >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.startDate#">

					AND
						(		D.DIS_ID NOT IN
								(SELECT	DIS_ID
								   FROM	TBL_DIS_APPEALS
								  WHERE	APPEAL_GROUP_ID IN
										(SELECT	APPEAL_GROUP_ID
										   FROM	TBL_DIS_APPEAL_GROUPS
										  WHERE	GRANTED <> 0))

						)
				  ) AS dis
			INNER JOIN TBL_CONSULTANTS c ON c.ssn = dis.ssn
			GROUP BY c.username
		</cfquery>
		<cfreturn semesterPointsUsers>
	</cffunction>


	<!---get users without points in a semester (lifetime)--->
	<cffunction name="getLifetimePointlessSemesterUsers">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="minimumSemesters" type="numeric" required="true">
		<cfargument name="userList" type="string" required="true">
		<cfset var lifetimePointlessSemesterUsers = ''>
		<cfquery datasource="#datasource#" name="lifetimePointlessSemesterUsers">
			SELECT y.username, count(y.username) AS semesterCount
			FROM (
				SELECT *
				FROM (
						SELECT c.username, c.ssn, s.semester_id, s.start_date, s.end_date, COUNT(ci.checkin_id) AS sem_shifts
						FROM tbl_consultants c
						INNER JOIN tbl_checkins ci ON ci.ssn = c.ssn
						INNER JOIN tbl_semesters s ON ci.start_time BETWEEN s.start_date AND s.end_date
						WHERE 0 = (SELECT TOP 1 COUNT(D.DIS_ID) as points
									FROM TBL_DISCIPLINE D
									LEFT JOIN TBL_DIS_WARNINGS W on w.dis_id = d.dis_id
									WHERE	D.ASSIGNED_DATE < s.end_date
									AND	D.ASSIGNED_DATE >= s.start_date

									AND
										(		D.DIS_ID NOT IN
												(SELECT	DIS_ID
													FROM	TBL_DIS_APPEALS da
													WHERE	da.APPEAL_GROUP_ID IN
														(SELECT	dag.APPEAL_GROUP_ID
															FROM	TBL_DIS_APPEAL_GROUPS dag
															WHERE	dag.GRANTED <> 0))

										)
									AND d.ssn = c.ssn)
						AND DATEDIFF(day, s.start_date, s.end_date) > 30
						AND getDate() NOT Between s.start_date AND s.end_date
						AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)
						GROUP BY c.username, c.ssn, s.semester_id, s.start_date, s.end_date
					) x
				WHERE x.sem_shifts > 5
			) y
			GROUP BY y.username
			HAVING count(*) >= 3
		</cfquery>
		<cfreturn lifetimePointlessSemesterUsers>
	</cffunction>


	<!---gets users gold stars with minimum amount--->
	<cffunction name="getGoldStarUsers">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="startDate" type="date" required="true">
		<cfargument name="endDate" type="date" required="true">
		<cfargument name="minimumCount" type="numeric" required="true" default="1">
		<cfargument name="userList" type="string" required="true">
		<cfset var goldStarUsers = ''>
		<cfquery datasource="#datasource#" name="goldStarUsers">
			SELECT *
			FROM
				(SELECT g.username, g.group_id, g.description, COUNT(g.answer_group) AS cnt
				FROM (
					SELECT DISTINCT c.username, q.group_id, qg.description, qa.answer_group
					FROM tbl_consultants c
					INNER JOIN tbl_questions_answers qa ON qa.answered_about = c.ssn
					INNER JOIN tbl_questions q ON q.question_id = qa.question_id
					INNER JOIN tbl_questions_groups qg ON qg.group_id = q.group_id
					INNER JOIN tbl_questions_reviewed qr ON qr.answer_group = qa.answer_group
					INNER JOIN tbl_questions_reviewed_status qrs ON qrs.status_id = qr.status_id
					WHERE q.group_id IN (1) /*recognition and praise*/
					AND qr.reviewed_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
									AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
					AND qr.status_id = 6 /*resolved*/
					AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)
				) g
				GROUP BY g.username, g.group_id, g.description) AS a
			WHERE a.cnt >= <cfqueryparam cfsqltype="cf_sql_integer" value="#minimumCount#">
		</cfquery>
		<cfreturn goldStarUsers>
	</cffunction>

	<!---gets user contacts by minimum amount--->
	<cffunction name="getContactsUsers">
		<cfargument name="startDate" type="date" required="true">
		<cfargument name="endDate" type="date" required="true">
		<cfargument name="minimumCount" type="numeric" required="true" default="1">
		<cfargument name="userList" type="string" required="true">
		<cfset var contactHighQuery = ''>
		<cfquery datasource="#application.applicationDataSource#" name="contactHighQuery">
			SELECT subContact.username AS username, contacts
			FROM (
				SELECT count(*) AS 'contacts', u.username
				FROM tbl_contacts c
				INNER JOIN tbl_contacts_statuses cs ON c.status_id = cs.status_id
				INNER JOIN tbl_users u ON u.user_id = c.user_id
				LEFT OUTER JOIN tbl_contacts_customers cc ON cc.contact_id = c.contact_id
				WHERE u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)
				AND c.last_opened BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
									AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
				AND cs.status = 'Closed'
				GROUP BY u.username
				) AS subContact
			WHERE contacts >= <cfqueryparam cfsqltype="cf_sql_integer" value="#minimumCount#">
		</cfquery>
		<cfreturn contactHighQuery>
	</cffunction>

	<!---gets user shifts worked by minimum amount and a start time--->
	<cffunction name="getUserShiftsWorked">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="startDate" type="date" required="true">
		<cfargument name="endDate" type="date" required="true">
		<cfargument name="minimumCount" type="numeric" required="true" default="1">
		<cfargument name="userList" type="string" required="true">
		<cfargument name="shiftStartId" type="numeric" required="true">
		<cfargument name="shiftEndId" type="numeric" default="26" required="false">
		<cfset var userShiftsWorked = ''>
		<cfquery datasource="#datasource#" name="userShiftsWorked">
			SELECT username, cnt
			FROM (
				SELECT username, COUNT(x.ROLE) as 'cnt'
				FROM (
						SELECT DISTINCT c.USERNAME, cs.ROLE, ch.CHECKIN_ID, ch.SSN, s.SITE_ID, s.SITE_NAME, sh.PAYCODE_ID
						FROM TBL_PAYPERIODS p
						INNER JOIN TBL_CONSULTANT_SCHEDULE cs
							ON cs.SHIFT_DATE BETWEEN p.PAYPERIOD_START AND p.PAYPERIOD_END
						INNER JOIN TBL_CHECKINS ch ON ch.CHECKIN_ID =  cs.CHECKIN_ID
						INNER JOIN TBL_CONSULTANTS c ON c.SSN = ch.SSN
						INNER JOIN TBL_SHIFTS sh ON sh.SHIFT_ID = cs.SHIFT_ID
						INNER JOIN TBL_SITES s ON sh.SITE_ID = s.SITE_ID
						WHERE DATEPART(hh, ch.START_TIME) = <cfqueryparam cfsqltype="cf_sql_integer" value="#shiftStartId#">
						<cfif shiftEndId NEQ 26>
							AND DATEPART(hh, ch.END_TIME) = <cfqueryparam cfsqltype="cf_sql_integer" value="#shiftEndId#">
						</cfif>
						AND ch.START_TIME >= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#semesterInfo.startDate#">
						AND ch.END_TIME <= <cfqueryparam cfsqltype="cf_sql_timestamp" value="#semesterInfo.endDate#">
					) x

				GROUP BY x.username
				) y
			WHERE y.cnt >= <cfqueryparam cfsqltype="cf_sql_integer" value="#minimumCount#">
			AND y.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)

		</cfquery>
		<cfreturn userShiftsWorked>
	</cffunction>


	<!---gets user subs worked by a minimum number of hours and shift start and end dates--->
	<cffunction name="getUserSubs">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="startDate" type="date" required="true">
		<cfargument name="endDate" type="date" required="true">
		<cfargument name="minimumHours" type="numeric" required="true" default="1">
		<cfargument name="userList" type="string" required="true">
		<cfargument name="shiftStartId" type="numeric" required="true">
		<cfargument name="shiftEndId" type="numeric" required="false" default="26">
		<cfset var redeyeUsers = ''>
		<cfquery datasource="#datasource#" name="redeyeUsers">
	        SELECT DISTINCT username
	        FROM tbl_consultants c
	        INNER JOIN (
	            SELECT ci.ssn,
	                DATEPART(year, ps.shift_start_date) AS sub_year,
	                DATEPART(month, ps.shift_start_date) AS sub_month,
	                /*this is a little scary, but the math works out nice and sound*/
	                SUM(
	                    DATEDIFF(
	                        minute,
	                        CASE/*when did the user start working this sub?*/
	                            WHEN DATEADD(hour, ps.start_time_id-1, ps.shift_start_date) > ci.checkin_time THEN DATEADD(hour, ps.start_time_id-1, ps.shift_start_date)
	                            ELSE ci.checkin_time
	                        END,
	                        CASE/*when did the user stop working this sub?*/
	                            WHEN DATEADD(hour, ps.end_time_id-1, ps.shift_end_date) < ci.checkout_time THEN DATEADD(hour, ps.end_time_id-1, ps.shift_end_date)
	                            ELSE ci.checkout_time
	                        END
	                    )/60.0
	                ) AS hours_subbed_in
	            FROM tbl_post_subs ps
	            INNER JOIN tbl_checkins ci
	                ON ci.ssn = ps.new_owner_ssn
	                /*subs can become part of a larger pre-existing shift, so looke for any checkins that wholly contain this sub, and not just ones that perfectly match it.*/
	                AND ci.start_time <= DATEADD(hour, ps.start_time_id-1, ps.shift_start_date)
	                AND ci.end_time >= DATEADD(hour, ps.end_time_id-1, ps.shift_end_date)
	                AND ci.checkout_time IS NOT NULL /*checkins that haven't ended cause trouble, and we'll catch them later, anyway.*/
	            WHERE ps.new_owner_ssn IS NOT NULL
				AND ps.START_TIME_ID = <cfqueryparam cfsqltype="cf_sql_integer" value="#shiftStartId#">
				<cfif shiftEndId NEQ 26>
					AND ps.END_TIME_ID = <cfqueryparam cfsqltype="cf_sql_integer" value="#shiftEndId#">
				</cfif>
				AND ps.shift_start_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
	            						AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
	            /*limit how far back in time we look to speed things up*/
	            AND ps.shift_start_date > DATEADD(year, -2, GETDATE())
	            AND ps.approved = 1

	            /*now group the results so we can SUM() how many hours they've subbed-out*/
	            GROUP BY ci.ssn, DATEPART(year, ps.shift_start_date) , DATEPART(month, ps.shift_start_date)
	        ) si ON si.ssn = c.ssn

	        LEFT OUTER JOIN (
	            SELECT ps.owner_ssn,
	                 DATEPART(year, ps.shift_start_date) AS sub_year,
	                 DATEPART(month, ps.shift_start_date) AS sub_month,
	                 SUM(DATEDIFF(minute, DATEADD(hour, ps.start_time_id-1, ps.shift_start_date), DATEADD(hour, ps.end_time_id-1, ps.shift_end_date))/60.0) AS hours_subbed_out
	            FROM tbl_post_subs ps
	            WHERE ps.new_owner_ssn IS NOT NULL
	            AND ps.approved = 1
	            /*limit how far back in time we look to speed things up*/
	            AND ps.shift_start_date > DATEADD(year, -2, GETDATE())
	            /*now group the results so we can SUM() how many hours they've subbed-out*/
				AND ps.START_TIME_ID = <cfqueryparam cfsqltype="cf_sql_integer" value="#shiftStartId#">
				<cfif shiftEndId NEQ 26>
					AND ps.END_TIME_ID = <cfqueryparam cfsqltype="cf_sql_integer" value="#shiftEndId#">
				</cfif>
				AND ps.shift_start_date BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
	            						AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">
	            GROUP BY ps.owner_ssn, DATEPART(year, ps.shift_start_date) , DATEPART(month, ps.shift_start_date)
	        	) so
	            ON so.owner_ssn = c.ssn
	            AND so.sub_year = si.sub_year
	            AND so.sub_month = si.sub_month
	        WHERE si.hours_subbed_in >= <cfqueryparam cfsqltype="cf_sql_integer" value="#minimumHours#">
	        AND <cfqueryparam cfsqltype="cf_sql_integer" value="#minimumHours#"> <= CASE
	                    WHEN si.hours_subbed_in IS NULL THEN 0
	                    WHEN so.hours_subbed_out IS NULL THEN si.hours_subbed_in
	                    ELSE si.hours_subbed_in - so.hours_subbed_out
	                END
			AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)
		</cfquery>
		<cfreturn redeyeUsers>
	</cffunction>

	<!---get users who subbed into 8am shifts in a date range.--->
	<cffunction name="getEarlyBirdSubs">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="startDate" type="date" required="true">
		<cfargument name="endDate" type="date" required="true">
		<cfargument name="userList" type="string" required="true">
		<cfargument name="minimumShifts" type="numeric" default="1">

		<cfset var getSubs = "">

		<cfquery datasource="#datasource#" name="getSubs">
			SELECT x.username
			FROM (
				SELECT c.username, COUNT(DISTINCT checkin_id) AS eb_subs
				FROM tbl_post_subs ps
				INNER JOIN tbl_consultants c ON c.ssn = ps.new_owner_ssn
				INNER JOIN tbl_checkins ci
					ON ci.ssn = ps.new_owner_ssn
					/*subs can become part of a larger pre-existing shift, so looke for any checkins that wholly contain this sub, and not just ones that perfectly match it.*/
					AND ci.start_time <= DATEADD(hour, ps.start_time_id-1, ps.shift_start_date)
					AND ci.end_time >= DATEADD(hour, ps.end_time_id-1, ps.shift_end_date)
					AND ci.checkout_time IS NOT NULL /*checkins that haven't ended cause trouble, and we'll catch them later, anyway.*/
				WHERE ci.start_time > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
				AND ci.start_time < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate#">

				AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)

				AND 8 BETWEEN DATEPART(hour, ci.start_time) AND DATEPART(hour, ci.end_time) - 1 /*This includes shifts starting before 8, but excludes ones ending at 8.*/

				GROUP BY c.username
			) x

			WHERE x.eb_subs >= <cfqueryparam cfsqltype="cf_sql_integer" value="#minimumShifts#">
		</cfquery>

		<cfreturn getSubs>
	</cffunction>

	<!---get users heart count for a semester with a minimum count--->
	<cffunction name="getSemesterMissingHeartsUsers">
		<cfargument name="datasource" type="string" required="yes">
		<cfargument name="heartQuestionId" type="numeric" required="yes">
		<cfargument name="semesterId" type="numeric" required="yes">
		<cfargument name="userList" type="string" required="true">
		<cfset var semesterMissingHeartsUsers = ''>
		<cfquery datasource="#datasource#" name="semesterMissingHeartsUsers">
			/*these are all the users who lost a heart during the semester*/
			SELECT DISTINCT c.username
			FROM tbl_questions_answers qa
			INNER JOIN tbl_questions_reviewed qr
				ON qr.answer_group = qa.answer_group
				AND qr.approved = 0/*they either did not appeal the heart, or were rejected*/
			INNER JOIN tbl_consultants c ON c.ssn = qa.answered_about
			WHERE qa.question_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#heartQuestionId#">
			AND qa.link_integer = <cfqueryparam cfsqltype="cf_sql_integer" value="#semesterId#">/*this is a bit clunky, but link integer is the semester_id for when this heart was deducted*/
			AND username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)
			ORDER BY c.username
		</cfquery>
		<cfreturn semesterMissingHeartsUsers>
	</cffunction>


	<!---take a list of users and a maskId, then return a query containing all the users from the list who have that mask, along with the details of the mask--->
	<cffunction name="getUsersMasks">
		<cfargument name="userList" type="string" required="yes">
		<cfargument name="maskId" type="numeric" required="yes">
		<cfset var getUsersMasks = ''>
		<cfquery datasource="#application.applicationDataSource#" name="getUsersMasks">
			SELECT umm.user_id, u.username, umm.mask_id, um.mask_name
			FROM tbl_users u
			INNER JOIN tbl_users_masks_match umm ON u.user_id = umm.user_id
			INNER JOIN tbl_user_masks um ON um.mask_id = umm.mask_id
			WHERE u.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#userList#" list="true">)
			AND umm.mask_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#maskId#">
			ORDER BY u.user_id
		</cfquery>
		<cfreturn getUsersMasks>
	</cffunction>






	<!---CONTACT BASED BADGES--->

	<!---badges for contacts in a single month.--->
	<cfif badgeId EQ 7 OR badgeId EQ 28  OR badgeId EQ 56 OR badgeId EQ 176 OR badgeId EQ 58 OR badgeId EQ 126 OR badgeId EQ 57 OR badgeId EQ 125>
		<!---this badge is for contacts in a month, determine the start and end date of valid activity.--->
		<cfset startDate = dateFormat(curDate, "yyyy-mm") & "-01">
		<cfset endDate = dateAdd("m", 1, startDate)>
		<cfif badgeId EQ 7  OR badgeId EQ 56 OR badgeId EQ 58 OR badgeId EQ 57>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", startDate, endDate,true)>
		<cfelseif badgeId EQ 28 OR badgeId EQ 176 OR badgeId EQ 126 OR badgeId EQ 125>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", startDate, endDate,true)>
		</cfif>
		<cfif badgeId EQ 7 OR badgeId EQ 28>
			<cfset contactQuery = getContactsUsers(startDate, endDate, 100, checkUsers)>
		<cfelseif badgeId EQ 56>
			<cfset contactQuery = getContactsUsers(startDate, endDate, 75, checkUsers)>
		<cfelseif badgeId EQ 176>
			<cfset contactQuery = getContactsUsers(startDate, endDate, 50, checkUsers)>
		<cfelseif badgeId EQ 58 OR badgeId EQ 126>
			<cfset contactQuery = getContactsUsers(startDate, endDate, 200, checkUsers)>
		<cfelseif badgeId EQ 57 OR badgeId EQ 125>
			<cfset contactQuery = getContactsUsers(startDate, endDate, 150, checkUsers)>
		</cfif>
		<cfloop query="contactQuery">
			<cfset allowedUserList = listAppend(allowedUserList, contactQuery.username)>
		</cfloop>
	</cfif>

		<!---badges for contacts in a single semester.--->
	<cfif badgeId EQ 60 OR badgeId EQ 128  OR badgeId EQ 59 OR badgeId EQ 127 OR badgeId EQ 61 OR badgeId EQ 129>
		<!---this badge is for contacts in a semester, determine the start and end date of valid activity.--->
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>

		<cfif badgeId EQ 60 OR badgeId EQ 59 OR badgeId EQ 61>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate,true)>
		<cfelseif badgeId EQ 128 OR badgeId EQ 127 OR badgeId EQ 129>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate,true)>
		</cfif>

		<cfif badgeId EQ 60 OR badgeId EQ 128>
			<cfset contactQuery = getContactsUsers(semesterInfo.startDate, semesterInfo.endDate, 700, checkUsers)>
		<cfelseif badgeId EQ 59 OR badgeId EQ 127>
			<cfset contactQuery = getContactsUsers(semesterInfo.startDate, semesterInfo.endDate, 300, checkUsers)>
		<cfelseif badgeId EQ 61 OR badgeId EQ 129>
			<cfset contactQuery = getContactsUsers(semesterInfo.startDate, semesterInfo.endDate, 1000, checkUsers)>
		</cfif>
		<cfloop query="contactQuery">
			<cfset allowedUserList = listAppend(allowedUserList, contactQuery.username)>
		</cfloop>
	</cfif>





	<!---GOLDSTAR BASED BADGES--->

	<!---badges based purely on goldstars semester--->
	<cfif badgeId EQ 4 OR badgeId EQ 25 OR badgeId EQ 73 OR badgeId EQ 140 OR badgeId EQ 141 OR badgeId EQ 177>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
		<cfif badgeId EQ 4 OR badgeId EQ 73 OR badgeId EQ 116 OR badgeId EQ 177>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate,true)>
		<cfelseif badgeId EQ 25 OR badgeId EQ 140 OR badgeId EQ 141>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate,true)>
		</cfif>
		<cfif badgeId EQ 177 OR badgeId EQ 25>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), semesterInfo.startDate, semesterInfo.endDate, 5, checkUsers)>
		<cfelseif badgeId EQ 73 OR badgeId EQ 140>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), semesterInfo.startDate, semesterInfo.endDate, 1, checkUsers)>
		<cfelseif badgeId EQ 4 OR badgeId EQ 141>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), semesterInfo.startDate, semesterInfo.endDate, 3, checkUsers)>
		</cfif>
   		<cfloop query="totalGoldStarCount">
			<cfset allowedUserList = listAppend(allowedUserList, totalGoldStarCount.username)>
		</cfloop>
	</cfif>

	<!---badges based purely on goldstars in a lifetime--->
	<cfif badgeId EQ 78 OR badgeId EQ 118 OR badgeId EQ 79 OR badgeId EQ 145 OR badgeId EQ 76 OR badgeId EQ 143 OR badgeId EQ 77 OR badgeId EQ 144>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
		<cfif badgeId EQ 78 OR badgeId EQ 79 OR badgeId EQ 76 OR badgeId EQ 77>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate,true)>
		<cfelseif badgeId EQ 118 OR badgeId EQ 145 OR badgeId EQ 143 OR badgeId EQ 144>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate,true)>
		</cfif>
		<cfif badgeId EQ 78 OR badgeId EQ 118>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate, 15, checkUsers)>
		<cfelseif badgeId EQ 79 OR badgeId EQ 145>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate, 20, checkUsers)>
		<cfelseif badgeId EQ 76 OR badgeId EQ 143>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate, 5, checkUsers)>
		<cfelseif badgeId EQ 77 OR badgeId EQ 144>
			<cfset totalGoldStarCount = getGoldStarUsers(getPieDatasource(badgeId), dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate, 10, checkUsers)>
		</cfif>
   		<cfloop query="totalGoldStarCount">
			<cfset allowedUserList = listAppend(allowedUserList, totalGoldStarCount.username)>
		</cfloop>
	</cfif>


	<!---MISCELLANEOUS BASED BADGES--->

	<!---check for veteran badge aka worked for 3+ semesters --->
	<cfif badgeId EQ 17 OR badgeId EQ 38>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
		<cfif badgeId EQ 17>
			<cfset checkUsers = GetConsultantsWithoutBadge("IUB", consultantsWhoHaveBadge(badgeId, dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate))>
		<cfelseif badgeId EQ 38>
			<cfset checkUsers = GetConsultantsWithoutBadge("IUPUI", consultantsWhoHaveBadge(badgeId, dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate))>
		</cfif>

		<cfset candidates = "">
		<cfloop query="checkUsers">
			<cfset candidates = listAppend(candidates, checkUsers.username)>
		</cfloop>

		<cfif badgeId EQ 17>
			<cfset candidates = getOnlyConsultantAndCs(candidates, "IUB")>
		<cfelseif badgeId EQ 38>
			<cfset candidates = getOnlyConsultantAndCs(candidates, "IUPUI")>
		</cfif>

	    <cfquery datasource="#getPieDatasource(badgeId)#" name="getVeteranQuery">
			SELECT * FROM
				(
				SELECT c.username, COUNT(DISTINCT s.semester_id) AS semesters_worked
				FROM tbl_checkins ci
				INNER JOIN tbl_consultants c ON c.ssn = ci.ssn
				INNER JOIN tbl_semesters s
				ON ci.start_time BETWEEN s.start_date AND s.end_date
				/*but don't include the super short training/vacation semesters*/
				AND DATEDIFF(day, s.start_date, s.end_date) > 30
				AND getDate() NOT Between s.start_date AND s.end_date
				AND ci.CHECKIN_TIME < DATEADD(week,-2,s.end_date)
				AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#candidates#" list="true">)
				GROUP BY c.username
				) AS x
			WHERE x.semesters_worked >=3
			ORDER BY semesters_worked DESC
		</cfquery>
   		<cfloop query="getVeteranQuery">
			<cfset allowedUserList = listAppend(allowedUserList, getVeteranQuery.username)>
		</cfloop>
	</cfif>




	<!---POINT/HEART BASED BADGES--->

	<!---finished 2 semesters with perfect scores and 2+ in each--->
	<cfif badgeId EQ 87 OR badgeId EQ 120>
		<cfset pieDatasource = getPieDatasource(badgeId)>
		<cfset semesterInfo = getPreviousSemesterInfo(curDate, pieDatasource)>
		<cfset assignedDate = dateAdd("d", -1, semesterInfo.endDate)>

		<cfif badgeId EQ 87>
			<cfset heartQuestionId = 133>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
		<cfelseif badgeId EQ 120>
	       	<cfset heartQuestionId = 185><!---IUPUI's Badge ID--->
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
		</cfif>
		<cfquery datasource="#pieDatasource#" name="semesterHighScoreUsers">
			SELECT y.username, count(y.username) AS semesterCount
			FROM (
				SELECT *
				FROM (
						SELECT c.username, c.ssn, s.semester_id, s.start_date, s.end_date, COUNT(ci.checkin_id) AS sem_shifts
						FROM tbl_consultants c
						INNER JOIN tbl_checkins ci ON ci.ssn = c.ssn
						INNER JOIN tbl_semesters s ON ci.start_time BETWEEN s.start_date AND s.end_date
						WHERE EXISTS ( /*users must have atlast 2 goldstars*/
												SELECT *
												FROM
													(SELECT g4.username, g4.group_id, g4.description, COUNT(g4.answer_group) AS cnt
													FROM (
														SELECT DISTINCT c4.username, q4.group_id, qg4.description, qa4.answer_group
														FROM tbl_consultants c4
														INNER JOIN tbl_questions_answers qa4 ON qa4.answered_about = c.ssn
														INNER JOIN tbl_questions q4 ON q4.question_id = qa4.question_id
														INNER JOIN tbl_questions_groups qg4 ON qg4.group_id = q4.group_id
														INNER JOIN tbl_questions_reviewed qr4 ON qr4.answer_group = qa4.answer_group
														INNER JOIN tbl_questions_reviewed_status qrs4 ON qrs4.status_id = qr4.status_id
														WHERE q4.group_id IN (1) /*recognition and praise*/
														AND qr4.reviewed_date BETWEEN s.start_date
																		AND s.end_date
														AND c4.USERNAME = c.USERNAME
														AND qr4.status_id = 6 /*resolved*/
													) g4
													GROUP BY g4.username, g4.group_id, g4.description) AS a4
												WHERE a4.cnt >= 2
											)
						AND NOT EXISTS ( /*users must have 0 pdis*/
												SELECT COUNT(c3.username)
												FROM tbl_consultants c3
												INNER JOIN tbl_questions_answers qa3 ON qa3.answered_about = c.ssn
												INNER JOIN tbl_questions q3 ON q3.question_id = qa3.question_id
												INNER JOIN tbl_questions_groups qg3 ON qg3.group_id = q3.group_id
												INNER JOIN tbl_questions_reviewed qr3 ON qr3.answer_group = qa3.answer_group
												INNER JOIN tbl_questions_reviewed_status qrs3 ON qrs3.status_id = qr3.status_id
												WHERE q3.group_id IN (2)
												AND qa3.ts BETWEEN s.start_date AND s.end_date
												AND qr3.status_id = 6
												AND c3.username = c.username
												GROUP BY c3.username
											)
						AND 0 = ( /*users must have 0 lost heart*/
												SELECT TOP 1 COUNT(c2.username)
												FROM tbl_questions_answers qa2
												INNER JOIN tbl_questions_reviewed qr2
													ON qr2.answer_group = qa2.answer_group
													AND qr2.approved = 0/*they either did not appeal the heart, or were rejected*/
												INNER JOIN tbl_consultants c2 ON c.ssn = qa2.answered_about
												WHERE qa2.question_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#heartQuestionId#">
												AND qa2.link_integer = s.semester_id/*this is a bit clunky, but link integer is the semester_id for when this heart was deducted*/
												AND c2.username = c.username
												GROUP BY c2.username
											)
						AND 0 = (/*Check for  0 points*/
												SELECT TOP 1 COUNT(D.DIS_ID) as points
												FROM TBL_DISCIPLINE D
												LEFT JOIN TBL_DIS_WARNINGS W on w.dis_id = d.dis_id
												WHERE	D.ASSIGNED_DATE < s.end_date
												AND	D.ASSIGNED_DATE >= s.start_date
												AND
													(		D.DIS_ID NOT IN
															(SELECT	DIS_ID
																FROM	TBL_DIS_APPEALS da
																WHERE	da.APPEAL_GROUP_ID IN
																	(SELECT	dag.APPEAL_GROUP_ID
																		FROM	TBL_DIS_APPEAL_GROUPS dag
																		WHERE	dag.GRANTED <> 0))

													)
												AND d.ssn = c.ssn
											)
						AND DATEDIFF(day, s.start_date, s.end_date) > 30
						AND getDate() NOT Between s.start_date AND s.end_date
						AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#checkUsers#" list="true">)
						GROUP BY c.username, c.ssn, s.semester_id, s.start_date, s.end_date
					) x
				WHERE x.sem_shifts > 5
			) y
			GROUP BY y.username
			HAVING count(*) >= 2
		</cfquery>
  		<cfloop query="semesterHighScoreUsers">
			<cfset allowedUserList = listAppend(allowedUserList, semesterHighScoreUsers.username)>
		</cfloop>
	</cfif>

	<!---check zero to hero badge for the team badge zero points in a semester--->
	<cfif badgeId EQ 18 OR badgeId EQ 39>
		<cfset pieDatasource = getPieDatasource(badgeId)>
		<cfset semesterInfo = getPreviousSemesterInfo(curDate, pieDatasource)>
		<cfset assignedDate = dateAdd("d", -1, semesterInfo.endDate)>
		<cfif badgeId EQ 18>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
		<cfelseif badgeId EQ 39>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
		</cfif>

		<cfset zeroToHeroUsersQuery = queryNew("username", "varchar")>

		<cfset semesterUsers = getWorkingSemesterUsers(semesterInfo.id, checkUsers, pieDatasource)>

		<cfset semesterPointsUsers = getSemesterPointsUsers(pieDatasource, semesterInfo.startDate, semesterInfo.endDate)>
		<cfloop query="#semesterUsers#">
			<cfset onList = 0>
			<cfloop query="semesterPointsUsers">
				<cfif semesterUsers.username EQ semesterPointsUsers.username>
					<cfset onList = 1>
					<cfbreak>
				</cfif>
			</cfloop>

			<cfif onList EQ 0>
				<cfset queryAddRow(zeroToHeroUsersQuery)>
			    <cfset querySetCell(zeroToHeroUsersQuery,"username", semesterUsers.username)>
			</cfif>
		</cfloop>
   		<cfloop query="zeroToHeroUsersQuery">
			<cfset allowedUserList = listAppend(allowedUserList, zeroToHeroUsersQuery.username)>
		</cfloop>
	</cfif>


	<!---check for users with all of their hearts in a semester--->
	<cfif badgeId EQ 84 OR badgeId EQ 150>
		<cfset pieDatasource = getPieDatasource(badgeId)>
		<cfset semesterInfo = getPreviousSemesterInfo(curDate, pieDatasource)>
		<cfset assignedDate = dateAdd("d", -1, semesterInfo.endDate)>

		<cfif badgeId EQ 84>
			<cfset heartQuestionId = 133>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
		<cfelseif badgeId EQ 150>
		<cfset heartQuestionId = 185><!---IUPUI's Badge ID--->
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
		</cfif>

		<cfset semesterHeartLostUsers = getSemesterMissingHeartsUsers(pieDatasource, heartQuestionId, semesterInfo.id, checkUsers)>
		<cfset semesterHeartLostUsersList = ValueList(semesterHeartLostUsers.username)>
		<cfloop list="#checkUsers#" index="checkUser">
			<cfif listFind(semesterHeartLostUsersList, checkUser) EQ 0>
				<cfset allowedUserList = listAppend(allowedUserList, checkUser)>
			</cfif>
		</cfloop>
	</cfif>



	<!---check for perfect game badge 0pdis 0hearts 0points 1+ goldstar in a semester--->
	<cfif badgeId EQ 3 OR badgeId EQ 24>
		<cfset pieDatasource = getPieDatasource(badgeId)>
		<cfset semesterInfo = getPreviousSemesterInfo(curDate, pieDatasource)>
		<cfset assignedDate = dateAdd("d", -1, semesterInfo.endDate)>

		<cfif badgeId EQ 3>
			<cfset heartQuestionId = 133>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
		<cfelseif badgeId EQ 24>
	       	<cfset heartQuestionId = 185><!---IUPUI's Badge ID--->
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
		</cfif>

		<cfset semesterUsers = getWorkingSemesterUsers(semesterInfo.id, checkUsers, pieDatasource)>

		<cfset semesterGoldStarUsers = getGoldStarUsers(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, 1, checkUsers)>
		<cfquery datasource="#pieDatasource#" name="semesterPdisUsers">
			/*This query does not check to determine if the consultant actually worked at all. thus, new consultants would get awarded for the previous semester they didn't work*/
			SELECT DISTINCT c.username
			FROM tbl_consultants c
			INNER JOIN tbl_questions_answers qa ON qa.answered_about = c.ssn
			INNER JOIN tbl_questions q ON q.question_id = qa.question_id
			INNER JOIN tbl_questions_groups qg ON qg.group_id = q.group_id
			INNER JOIN tbl_questions_reviewed qr ON qr.answer_group = qa.answer_group
			INNER JOIN tbl_questions_reviewed_status qrs ON qrs.status_id = qr.status_id
			WHERE q.group_id IN (2)
			AND qa.ts BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#semesterInfo.startDate#">
									AND <cfqueryparam cfsqltype="cf_sql_timestamp" value="#semesterInfo.endDate#">
			AND qr.status_id = 6
		</cfquery>

		<cfset semesterPointsUsers = getSemesterPointsUsers(pieDatasource, semesterInfo.startDate, semesterInfo.endDate)>
		<cfset semesterHeartsUsers = getSemesterMissingHeartsUsers(pieDatasource, heartQuestionId, semesterInfo.id, checkUsers)>

		<cfset perfectGameUsersQuery = queryNew("username", "varchar")>

		<cfloop query="semesterUsers">
			<!---assume by default they do not have a perfect game--->
			<cfset hasPerfectGame = 0>

			<!---they must have at least one gold star--->
			<cfloop query="semesterGoldStarUsers">
				<cfif semesterGoldStarUsers.username eq semesterUsers.username>
					<cfset hasPerfectGame = 1>
					<cfbreak>
				</cfif>
			</cfloop>

			<!---if they don't have a gold star move onto the next user--->
			<cfif hasPerfectGame EQ 0>
				<cfcontinue>
			</cfif>

			<!---they must not have any PDIs for the semester--->
			<cfloop query="semesterPdisUsers">
				<cfif semesterUsers.username EQ semesterPdisUsers.username>
					<cfset hasPerfectGame = 0>
					<cfbreak>
				</cfif>
			</cfloop>

			<cfif hasPerfectGame EQ 0>
				<cfcontinue>
			</cfif>
			<!---they must not have any points--->
			<cfloop query="semesterPointsUsers">
				<cfif semesterUsers.username EQ semesterPointsUsers.username>
					<cfset hasPerfectGame = 0>
					<cfbreak>
				</cfif>
			</cfloop>
			<cfif hasPerfectGame EQ 0>
				<cfcontinue/>
			</cfif>

			<!---they must not have lost any hearts--->
			<cfloop query="semesterHeartsUsers">
				<cfif semesterUsers.username EQ semesterHeartsUsers.username>
					<cfset hasPerfectGame = 0>
					<cfbreak>
				</cfif>
			</cfloop>

			<!---if they have a perfect game add them to perfectGameUsersQuery--->
			<cfif hasPerfectGame EQ 1>
			    <cfset queryAddRow(perfectGameUsersQuery)>
			    <cfset querySetCell(perfectGameUsersQuery,"username", semesterUsers.username)>
			</cfif>
		</cfloop>
  		<cfloop query="perfectGameUsersQuery">
			<cfset allowedUserList = listAppend(allowedUserList, perfectGameUsersQuery.username)>
		</cfloop>
	</cfif>

	<!---check for users without points in any 3 semesters--->
	<cfif badgeId EQ 86 OR badgeId EQ 152>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
		<cfif badgeId EQ 86>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate)>
		<cfelseif badgeId EQ 152>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", dateFormat(dateAdd("yyyy", -10, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate)>
		</cfif>

		<cfset pointlessQuery = getLifetimePointlessSemesterUsers(getPieDatasource(badgeId),3,checkUsers)>

		<cfloop query="pointlessQuery">
			<cfset allowedUserList = listAppend(allowedUserList, pointlessQuery.username)>
		</cfloop>
	</cfif>













	<!---SHIFT RELATED BASED BADGES--->

	<!---check current semesters for shift related stuff--->
	<cfif badgeId EQ 97 OR badgeId EQ 117 OR badgeId EQ 15 OR badgeId EQ 36 OR badgeId EQ 100 OR badgeId EQ 163 OR badgeId EQ 14 OR badgeId EQ 35>
		<cfset pieDatasource = getPieDatasource(badgeId)>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, pieDatasource)>

		<cfif badgeId EQ 97 OR badgeId EQ 15 OR badgeId EQ 100 OR badgeId EQ 14>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate,true)>
		<cfelseif badgeId EQ 117 OR badgeId EQ 36 OR badgeId EQ 163 OR badgeId EQ 35>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate,true)>
		</cfif>

		<!---sub badges--->
		<cfif badgeId EQ 97 OR badgeId EQ 117>
			<cfset returnedUsers = getUserSubs(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, 4, checkUsers, 9)>
		<cfelseif badgeId EQ 15 OR badgeId EQ 36>
			<cfset returnedUsers = getEarlyBirdSubs(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, checkUsers, 10)>
		<cfelseif badgeId EQ 100 OR badgeId EQ 163>
			<cfset returnedUsers = getUserSubs(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, 39, checkUsers, 1, 9)>
		<cfelseif badgeId EQ 14 OR badgeId EQ 35>
			<cfset returnedUsers = getUserSubs(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, 16, checkUsers, 1,9)>
		</cfif>
		<cfloop query="returnedUsers">
			<cfset allowedUserList = listAppend(allowedUserList, returnedUsers.username)>
		</cfloop>
	</cfif>

	<!---check previous semesters for shift related stuff--->
	<cfif badgeId EQ 98 OR badgeId EQ 161 OR badgeId EQ 13 OR badgeId EQ 34>
		<cfset pieDatasource = getPieDatasource(badgeId)>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, pieDatasource)>

		<cfif badgeId EQ 13 OR badgeId EQ 98>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate,true)>
		<cfelseif badgeId EQ 34 OR badgeId EQ 161>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate,true)>
		</cfif>

		<cfif badgeId EQ 13 OR badgeId EQ 34>
			<cfset returnedUsers = getUserShiftsWorked(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, 10, checkUsers, 0,8)>
		<cfelseif badgeId EQ 98 OR badgeId EQ 161>
			<cfset returnedUsers = getUserShiftsWorked(pieDatasource, semesterInfo.startDate, semesterInfo.endDate, 10, checkUsers, 8)>
		</cfif>
		<cfloop query="returnedUsers">
			<cfset allowedUserList = listAppend(allowedUserList, returnedUsers.username)>
		</cfloop>
	</cfif>


	<!---check for 6th man badge aka subbing into 20 hours a month--->
	<cfif badgeId EQ 16 OR badgeId EQ 37>
		<cfset startDate = dateFormat(curDate, "yyyy-mm") & "-01">
		<cfset endDate = dateAdd("m", 1, startDate)>

		<cfif badgeId EQ 16>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", startDate, endDate, true)>
		<cfelseif badgeId EQ 37>
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", startDate, endDate, true)>
		</cfif>
	    <cfquery datasource="#getPieDatasource(badgeId)#" name="sixthManQuery">
	        SELECT c.username
	        FROM tbl_consultants c
	        INNER JOIN (
	            SELECT ci.ssn,
	                DATEPART(year, ps.shift_start_date) AS sub_year,
	                DATEPART(month, ps.shift_start_date) AS sub_month,
	                /*this is a little scary, but the math works out nice and sound*/
	                SUM(
	                    DATEDIFF(
	                        minute,
	                        CASE/*when did the user start working this sub?*/
	                            WHEN DATEADD(hour, ps.start_time_id-1, ps.shift_start_date) > ci.checkin_time THEN DATEADD(hour, ps.start_time_id-1, ps.shift_start_date)
	                            ELSE ci.checkin_time
	                        END,
	                        CASE/*when did the user stop working this sub?*/
	                            WHEN DATEADD(hour, ps.end_time_id-1, ps.shift_end_date) < ci.checkout_time THEN DATEADD(hour, ps.end_time_id-1, ps.shift_end_date)
	                            ELSE ci.checkout_time
	                        END
	                    )/60.0
	                ) AS hours_subbed_in
	            FROM tbl_post_subs ps
	            INNER JOIN tbl_checkins ci
	                ON ci.ssn = ps.new_owner_ssn
	                /*subs can become part of a larger pre-existing shift, so looke for any checkins that wholly contain this sub, and not just ones that perfectly match it.*/
	                AND ci.start_time <= DATEADD(hour, ps.start_time_id-1, ps.shift_start_date)
	                AND ci.end_time >= DATEADD(hour, ps.end_time_id-1, ps.shift_end_date)
	                AND ci.checkout_time IS NOT NULL /*checkins that haven't ended cause trouble, and we'll catch them later, anyway.*/
	            WHERE ps.new_owner_ssn IS NOT NULL
	            /*limit how far back in time we look to speed things up*/
	            AND ps.shift_start_date > DATEADD(month, -6, GETDATE())
	            AND ps.approved = 1

	            /*now group the results so we can SUM() how many hours they've subbed-out*/
	            GROUP BY ci.ssn, DATEPART(year, ps.shift_start_date) , DATEPART(month, ps.shift_start_date)
	        ) si ON si.ssn = c.ssn

	        LEFT OUTER JOIN (
	            SELECT ps.owner_ssn,
	                 DATEPART(year, ps.shift_start_date) AS sub_year,
	                 DATEPART(month, ps.shift_start_date) AS sub_month,
	                 SUM(DATEDIFF(minute, DATEADD(hour, ps.start_time_id-1, ps.shift_start_date), DATEADD(hour, ps.end_time_id-1, ps.shift_end_date))/60.0) AS hours_subbed_out
	            FROM tbl_post_subs ps
	            WHERE ps.new_owner_ssn IS NOT NULL
	            AND ps.approved = 1
	            /*limit how far back in time we look to speed things up*/
	            AND ps.shift_start_date > DATEADD(month, -6, GETDATE())
	            /*now group the results so we can SUM() how many hours they've subbed-out*/
	            GROUP BY ps.owner_ssn, DATEPART(year, ps.shift_start_date) , DATEPART(month, ps.shift_start_date)
	        	) so
	            ON so.owner_ssn = c.ssn
	            AND so.sub_year = si.sub_year
	            AND so.sub_month = si.sub_month
	        WHERE si.hours_subbed_in >= 20
	        AND si.sub_year = year(<cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">)
	        AND si.sub_month = month(<cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">)
	        AND 20 <= CASE
	                    WHEN si.hours_subbed_in IS NULL THEN 0
	                    WHEN so.hours_subbed_out IS NULL THEN si.hours_subbed_in
	                    ELSE si.hours_subbed_in - so.hours_subbed_out
	                END
			AND c.username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#checkUsers#" list="true">)
	    </cfquery>
   		<cfloop query="sixthManQuery">
			<cfset allowedUserList = listAppend(allowedUserList, sixthManQuery.username)>
		</cfloop>
	</cfif>



	<!---TITLE and POSITION BASED BADGES--->

	<!---badges based purely on someones title/position in TCC--->
	<cfif listFind("113,124,110,171,169,108,47,46,170,109", badgeId)>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
		<cfif badgeId EQ 113 OR badgeId EQ 110 OR badgeId EQ 108 OR badgeId EQ 46 OR badgeId EQ 109>
			<!---if it's an IUB badge find the IUB users who are eligible for this badge over a certain date range.--->
			<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate,true)>
		<cfelseif badgeId EQ 124 OR badgeId EQ 171  OR badgeId EQ 169 OR badgeId EQ 47 OR badgeId EQ 170>
			<!---if it's an IUPUI badge find the IUPUI users who are eligible for this badge over a certain date range.--->
			<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate,true)>
		</cfif>
		<cfset var titleUsersQuery = ''>
		<cfif badgeId EQ 113 OR badgeId EQ 124> <!---PR team--->
			<cfset titleUsersQuery = getUsersMasks(checkUsers, 27)>
		<cfelseif badgeId EQ 110 OR badgeId EQ 171><!---CS team--->
			<cfset titleUsersQuery = getUsersMasks(checkUsers, 10)>
		<cfelseif badgeId EQ 108 OR badgeId EQ 169><!---Consultants team--->
			<cfset titleUsersQuery = getUsersMasks(checkUsers, 9)><!---of our eligigle users who has the consultant mask?--->
		<cfelseif badgeId EQ 109 OR badgeId EQ 170><!---tech team--->
			<cfset titleUsersQuery = getUsersMasks(checkUsers, 22)>
		<cfelseif badgeId EQ 46 OR badgeId EQ 47><!---social media team--->
			<cfset titleUsersQuery = getUsersMasks(checkUsers, 28)>
		</cfif>

   		<cfloop query="titleUsersQuery">
			<cfset allowedUserList = listAppend(allowedUserList, titleUsersQuery.username)>
		</cfloop>
	</cfif>


	<!---check for Laptop ER badge worked a laptop er shift --->
	<cfif badgeId EQ 43 OR badgeId EQ 44>
		<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>

		<cfif badgeId EQ 43>
			<cfset checkUsers = GetConsultantsWithoutBadge("IUB", consultantsWhoHaveBadge(badgeId, dateFormat(dateAdd("d", -150, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate))>
		<cfelseif badgeId EQ 44>
			<cfset checkUsers = GetConsultantsWithoutBadge("IUPUI", consultantsWhoHaveBadge(badgeId, dateFormat(dateAdd("yyyy", -150, now()), "yyyy-mm-dd") & " 23:59:59", semesterInfo.endDate))>
		</cfif>

		<cfset candidates = "">
		<cfloop query="checkUsers">
			<cfset candidates = listAppend(candidates, checkUsers.username)>
		</cfloop>

		<cfif badgeId EQ 43>
			<cfset candidates = getOnlyConsultantAndCs(candidates, "IUB")>
		<cfelseif badgeId EQ 44>
			<cfset candidates = getOnlyConsultantAndCs(candidates, "IUPUI")>
		</cfif>


		<cfquery datasource="#getPieDatasource(badgeId)#" name="laptopErUsers">
		SELECT username, cnt
		FROM (
			SELECT username, COUNT(x.site_id) AS cnt
			FROM (
					SELECT DISTINCT c.USERNAME, s.site_id
					FROM TBL_PAYPERIODS p
					INNER JOIN TBL_CONSULTANT_SCHEDULE cs
						ON cs.SHIFT_DATE BETWEEN p.PAYPERIOD_START AND p.PAYPERIOD_END
					INNER JOIN TBL_CHECKINS ch ON ch.CHECKIN_ID =  cs.CHECKIN_ID
					INNER JOIN TBL_CONSULTANTS c ON c.SSN = ch.SSN
					INNER JOIN TBL_SHIFTS sh ON sh.SHIFT_ID = cs.SHIFT_ID
					INNER JOIN TBL_SITES s ON sh.SITE_ID = s.SITE_ID
					WHERE s.SITE_NAME LIKE 'ER_%'
					OR s.SITE_NAME LIKE 'MOVEIN%'
				) x
			WHERE username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#candidates#" list="true">)
			GROUP BY x.username
			) y
		ORDER BY cnt DESC
		</cfquery>
   		<cfloop query="laptopErUsers">
			<cfset allowedUserList = listAppend(allowedUserList, laptopErUsers.username)>
		</cfloop>
	</cfif>



















	<!---convert username list to user_id list--->
	<cffunction name="getUserIdsByUsernames">
		<cfargument name="usernameList" type="string">
		<cfset var userIdsByUsernames = ''>
		<cfset var userIdList = ''>
		<cfquery datasource="#application.applicationDataSource#" name="userIdsByUsernames">
			SELECT user_id
			FROM tbl_users
			WHERE username IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.usernameList#" list="true">)
		</cfquery>
		<cfloop query="userIdsByUsernames">
			<cfset userIdList = listAppend(userIdList, userIdsByUsernames.user_id)>
		</cfloop>
		<cfreturn userIdList>
	</cffunction>


	<!---create a return query that contains the badgeId, userId, and timestamp--->
	<cfset var newUserBadgeMatchQuery = queryNew("user_id,badge_id,time_assigned", "integer,integer,timestamp")>

	<cfif allowedUserList NEQ ''>
		<cfset var badgeUsernameList = getUserIdsByUsernames(allowedUserList)>

		<cfloop list="#badgeUsernameList#" index="badgeUserId">
			<cfset queryAddRow(newUserBadgeMatchQuery)>
		    <cfset querySetCell(newUserBadgeMatchQuery, "user_id", badgeUserId)>
			<cfset querySetCell(newUserBadgeMatchQuery, "badge_id", badgeId)>
			<cfset querySetCell(newUserBadgeMatchQuery, "time_assigned", assignedDate)>
		</cfloop>
	</cfif>
	<cfreturn newUserBadgeMatchQuery>
</cffunction>





<!---These are older forms--->
<!---check for walking dead badge 10 graveyards worked in a semester
<cfif badgeId EQ 13 OR badgeId EQ 34>
	<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
	<cfif badgeId EQ 13>
		<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
	<cfelseif badgeId EQ 34>
		<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
	</cfif>

	<cfset semesterWalkingDeadUsers = getUserShiftsWorked(getPieDatasource(badgeId), semesterInfo.startDate, semesterInfo.endDate, 10, checkUsers, 0, 8)>
  		<cfloop query="semesterWalkingDeadUsers">
		<cfset allowedUserList = listAppend(allowedUserList, semesterWalkingDeadUsers.username)>
	</cfloop>
</cfif>

<!---check for early bird badge 10 8am shifts worked in a semester --->
<cfif badgeId EQ 15 OR badgeId EQ 36>
	<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
	<cfif badgeId EQ 15>
		<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
	<cfelseif badgeId EQ 36>
		<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
	</cfif>
	<cfset semesterEarlyBirdUsers = getUserShiftsWorked(getPieDatasource(badgeId), semesterInfo.startDate, semesterInfo.endDate, 10, checkUsers, 8)>
  		<cfloop query="semesterEarlyBirdUsers">
		<cfset allowedUserList = listAppend(allowedUserList, semesterEarlyBirdUsers.username)>
	</cfloop>
</cfif>

<!---check for redeye badge subbed into 2 graveyards in a semester --->
<cfif badgeId EQ 14 OR badgeId EQ 35>
	<cfset semesterInfo = getCurrentSemesterInfo(curDate, getPieDatasource(badgeId))>
	<cfif badgeId EQ 14>
		<cfset checkUsers = getAllowedUsers(badgeId, "IUB", semesterInfo.startDate, semesterInfo.endDate)>
	<cfelseif badgeId EQ 35>
		<cfset checkUsers = getAllowedUsers(badgeId, "IUPUI", semesterInfo.startDate, semesterInfo.endDate)>
	</cfif>

	<cfset redeyeUsers = getUserSubs(getPieDatasource(badgeId), semesterInfo.startDate, semesterInfo.endDate, 16, checkUsers, 1, 9)>
  		<cfloop query="redeyeUsers">
		<cfset allowedUserList = listAppend(allowedUserList, laptopErUsers.username)>
	</cfloop>
</cfif>

--->



