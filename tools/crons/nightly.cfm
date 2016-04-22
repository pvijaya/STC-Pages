<!---
	NOTE NOTE NOTE!
	This file runs as a cron-job, and could be run by just about anyone.
	Make sure that the page does not generate any output.

	These are cron jobs that should be run every night around 2am.
--->
<cfsetting requesttimeout="120"><!---this can take a good while to run.--->

<!---run the nightly update-access--->
<cfinclude template="#application.appPath#/tools/crons/update-access.cfm">

<!---archive outdated announcements.--->
<cfinclude template="#application.appPath#/tools/crons/archive-announcements.cfm">

<!---check the PIE's for more recent badge images of active users.--->
<cfinclude template="#application.appPath#/tools/crons/update-thumbnails.cfm">
