<cftry>
	<cfparam name="attributes.userId" type="integer" default="-1">
	<cfparam name="attributes.badgeSize" type="string" default="50px">
	<cfquery datasource="#application.applicationDataSource#" name="getUserBadges">
		SELECT * 
		FROM tbl_badges_users_matches m
		JOIN tbl_badges b ON b.badge_id = m.badge_id
		AND b.active = 1
		AND m.active = 1
		AND m.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#attributes.userId#">
		ORDER BY b.badge_name
	</cfquery>
	<cfoutput query="getUserBadges">
		<div class="block-card"  style="padding:5px;overflow:auto;display:inline-block;vertical-align:top;">
			<img src="#getUserBadges.image_url#" style="width:#attributes.badgeSize#;vertical-align:top;" />
		</div>
	</cfoutput>
	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</p>
	</cfcatch>
</cftry>