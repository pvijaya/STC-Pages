<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfparam name="searchTerm" type="string" default="">
<cfparam name="link" type="string" default="">
<cfparam name="rank" type="integer" default="">
<cfparam name="searchCats" type="string" default="">

<!---we need to drop the user's masks as a list of masks, just storing their user_id would be easier; but way, way, creepier--->
<cfset usermasks = "">

<cfquery datasource="#application.applicationDataSource#" name="getUserMasks">
	SELECT um.mask_id, um.mask_name
	FROM vi_all_masks_users mu
	INNER JOIN tbl_user_masks um ON um.mask_id = mu.mask_id
	WHERE mu.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
</cfquery>

<cfloop query="getUserMasks">
	<cfset userMasks = listAppend(userMasks, mask_name)>
</cfloop>

<cfquery name="insertSearchRecord" datasource="#application.applicationDataSource#">
		INSERT INTO tbl_search_metrics (words_searched,user_masks,link_clicked,link_position,search_cats)
		VALUES(<cfqueryparam value="#searchTerm#" cfsqltype="cf_sql_varchar">,
		<cfqueryparam value="#userMasks#" cfsqltype="cf_sql_varchar">,
		<cfqueryparam value="#link#" cfsqltype="cf_sql_text">,
		<cfqueryparam value="#rank#" cfsqltype="cf_sql_integer">,
		<cfqueryparam value="#searchCats#" cfsqltype="cf_sql_varchar">)
</cfquery>

<cfoutput>success</cfoutput>