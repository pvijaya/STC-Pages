<!--- Functions / Queries --->
<cffunction name="getPostSubsFunc">
	<cfargument name="instanceId" type="numeric" default="#session.primary_instance#">
	<cfargument name="username" type="string" default="#session.cas_username#">

	<!--- if the given username is the empty string, this returns subs for all users --->

	<cfset var getPieDatabase = "">
	<cfset var getPostSubs = "">

	<cfquery name="getPieDatabase" datasource="#application.applicationDatasource#">
		SELECT datasource
		FROM tbl_instances
		WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#instanceId#">
	</cfquery>

	<cfloop query ="getPieDatabase">
		<cfset pieDatabase= getPieDatabase.datasource>
	</cfloop>

	<cfquery name='getPostSubs' datasource="#pieDatabase#">
		SELECT c.username, si.site_long_name, si.site_name, ps.comments, ps.post_id,
			   c.first_name, c.last_name,
			/*human readable shift start and end times*/
			convert(char(10), ps.shift_start_date, 121)+' '+convert(char(5), st.start_time, 114) "Start_Time",
			convert(char(10), ps.shift_end_date, 121)+' '+convert(char(5), et.start_time, 114) "End_Time"
		FROM tbl_post_subs ps
		INNER JOIN tbl_consultants c ON c.ssn = ps.owner_ssn
		INNER JOIN tbl_sites si ON si.site_id = ps.site_name_id
		INNER JOIN tbl_times st ON ps.start_time_id = st.time_id
		INNER JOIN tbl_times et ON ps.end_time_id = et.time_id
		WHERE ps.approved = 0
			  AND ps.deleted = 0
			  /*limit to subs in the future*/
			  AND GETDATE() < convert(char(10), ps.shift_start_date, 121)+' '+convert(char(5), st.start_time, 114)
			  AND ps.shift_start_date < DATEADD(day, +2, GETDATE())
			  <cfif username NEQ "">
				  AND c.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#username#">
			  </cfif>
		ORDER BY start_time
	</cfquery>

	<cfreturn getPostSubs>

</cffunction>

<!--- jquery --->
<cfoutput>
	<script type="text/javascript">

		$(document).ready(function() {

			$(document).on('click', '##showComments', (function(e) {
				$(this).parent().parent().find('.noComments').fadeOut('slow', function() {
					$(this).parent().find('.comments').fadeIn('slow');
				});
			}));

			$(document).on('click', '##hideComments', (function(e) {
				$(this).parent().parent().find('.comments').fadeOut('slow', function() {
					$(this).parent().find('.noComments').fadeIn('slow');
				});
			}));

		});

	</script>
</cfoutput>