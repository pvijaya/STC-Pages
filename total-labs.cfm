<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfset dataset = [] />
<cffunction name="chkLabCount">

   <cfquery datasource="#application.applicationDataSource#" name="getLabsCount">

		SELECT tc.building_id as buildingId, build.short_building_name as buildShortName, tc.room_number as roomNumber, build.building_name as buildingName,  count(tc.contact_id) as customerContacts FROM tbl_contacts tc
		INNER JOIN vi_buildings build
		ON tc.building_id = build.building_id

		WHERE
		tc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
		AND build.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
		AND tc.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		AND tc.created_ts >'2015-12-11'
		<!---AND tc.created_ts >= CAST(CURRENT_TIMESTAMP AS DATE)
		AND tc.created_ts < DATEADD(DD, 1, CAST(CURRENT_TIMESTAMP AS DATE))--->

		GROUP BY  tc.building_id, tc.room_number, build.building_name, build.short_building_name
		ORDER BY  tc.building_id, tc.room_number, build.building_name

   </cfquery>

    <cfreturn getLabsCount>
 </cffunction>

<cfquery datasource="#application.applicationDataSource#" name="getTotalCount">

		SELECT count(tc.contact_id) as TotalCount FROM tbl_contacts tc
		INNER JOIN vi_buildings build
		ON tc.building_id = build.building_id

		WHERE
		tc.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
		AND build.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#Session.primary_instance#">
		AND tc.user_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">
		AND tc.created_ts >'2015-12-11'
		<!---AND tc.created_ts >= CAST(CURRENT_TIMESTAMP AS DATE)
		AND tc.created_ts < DATEADD(DD, 1, CAST(CURRENT_TIMESTAMP AS DATE))--->


</cfquery>

<cfset results = chkLabCount()>

<cfloop query="results">
    <cfset record = {} />
   <!--- <cfset record["user_id"] = getContactsCount.user_id />--->
	<cfset record["buildingName"] = getLabsCount.buildingName />
	<cfset record["buildShortName"] = getLabsCount.buildShortName />
	<cfset record["roomNumber"] = getLabsCount.roomNumber />
	<cfset record["customerContacts"] = getLabsCount.customerContacts />
	<cfset record["color"] = "##" & left( hash(getLabsCount.buildingId, "MD5"), 6 )><!---a unique color for each user can be generated by hashing--->
	<cfset record["Total_Count"] = getTotalCount.TotalCount>
    <cfset ArrayAppend(dataset, record) />

</cfloop>

<cfoutput>#SerializeJSON(dataset)#</cfoutput>
