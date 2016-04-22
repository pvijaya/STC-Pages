<cfmodule template="#application.appPath#/header.cfm" title='Lab Distribution History' drawCustom=false noText=false>
<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="cs">
<cfmodule template="#application.appPath#/modules/check-instance.cfm" referrer="#cgi.script_name#">

<!--- CFPARAMS --->
<cfparam name="action" type="string" default="">
<cfparam name="labId" type="string" default="">
<cfparam name="itemId" type="integer" default="0">
<cfparam name="startDate" default="#DateFormat(Fix(Now()-7),'yyyy-mm-dd')#" type="date">
<cfparam name="endDate" default="#DateFormat(Now(),'yyyy-mm-dd')#" type="date">

<!--- HEADER / NAVIGATION --->
<h1>Lab Distribution History</h1>
<a href='<cfoutput>#cgi.script_name#</cfoutput>'>Reset Page</a> |
<a href='lab-distribution.cfm'>Lab Distribution</a> | 
<a href='item-list-editor.cfm'>Item Manager</a> |
<a href='ticket-editor.cfm'>Ticket Editor</a>
<br/><br/>

<!--- QUERIES --->
<cfquery datasource="#application.applicationDataSource#" name="getItemNames">
	SELECT item_id, item_name
	FROM tbl_lab_dist_item_list
</cfquery>

<!--- DRAW FORMS --->
<cfoutput>
	
	<fieldset>
		<legend>Search Everything</legend>
		<form action="#cgi.script_name#" method="POST">
	
			<label for="startDateId0">Start Date:</label>
			<input id="startDateId0" type="text"  name="startDate" value="#startDate#">
			
			<script type="text/javascript">
				$("##startDateId0").datepicker({dateFormat: "yy-mm-dd"});
			</script>
			
			<label for="endDateId0">End Date:</label>
			<input id="endDateId0" type="text"  name="endDate" value="#endDate#">
			
			<script type="text/javascript">
				$("##endDateId0").datepicker({dateFormat: "yy-mm-dd"});
			</script>
			
			<input type="submit"  name="action" value="Search All">
			
		</form>
	</fieldset>
	
	<div>
		
		<fieldset style="width:45%;display:inline-block;">
			<legend>Search By Lab</legend>
			
			<form action="#cgi.script_name#" method="POST">
				<style>##labId {vertical-align:middle;}</style>
				<label for="labId">Lab: </label><cfset drawlabsSelector('labId',labId)>
				<br/><br/>
				<label for="startDateId">Start Date:</label>
				<input id="startDateId" type="text"  name="startDate" value="#startDate#">
				<script type="text/javascript">
					$("##startDateId").datepicker({dateFormat: "yy-mm-dd"});
				</script>
				<label for="endDateId">End Date:</label>
				<input id="endDateId" type="text"  name="endDate" value="#endDate#">
				<script type="text/javascript">
					$("##endDateId").datepicker({dateFormat: "yy-mm-dd"});
				</script>
				<br/><br/>
				<input type="submit"  name="action" value="Lab Search">
			</form>
			
		</fieldset>
		
		<fieldset style="width:45%;display:inline-block;">
			<legend>Search By Item</legend>
			
			<form action="#cgi.script_name#" method="POST">
				<label for="itemId">Item: </label>
				<select id="itemId" name="itemId">
					
					<cfloop query="getItemNames">
						<cfif itemId EQ getItemNames.item_id>
							<option value="#getItemNames.item_id#" selected="selected">#getItemNames.item_name#</option>
						<cfelse>
							<option value="#getItemNames.item_id#">#getItemNames.item_name#</option>
						</cfif>
					</cfloop>
					
				</select>
				
				<br/><br/>
				
				<label for="startDateId2">Start Date:</label>
				<input id="startDateId2" type="text"  name="startDate" value="#startDate#">
				
				<script type="text/javascript">
					$("##startDateId2").datepicker({dateFormat: "yy-mm-dd"});
				</script>
				
				<label for="endDateId2">End Date:</label>
				<input id="endDateId2" type="text"  name="endDate" value="#endDate#">
				
				<script type="text/javascript">
					$("##endDateId2").datepicker({dateFormat: "yy-mm-dd"});
				</script>
				
				<br/><br/>
				<input type="submit"  name="action" value="Item Search">
				
			</form>
		</fieldset>
		
	</div>

</cfoutput>

<br/>
<hr>

<!--- HANDLE USER INPUT --->
<cfif action EQ "Lab Search">
	
	<cfset labObj = parselabname(labId)>
	
	<cfquery datasource="#application.applicationDataSource#" name="getlabName">
		SELECT lab_name
		FROM vi_labs
		WHERE instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.instance#">
		AND lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.lab#">
	</cfquery>
	
	<cfoutput query="getlabName">
		<h2>#lab_name#'s Delivered Items</h2>
	</cfoutput>
	
	<cfoutput>
		<h3>#dateTimeFormat(startDate, 'mmm dd, yyyy')# to #dateTimeFormat(endDate, 'mmm dd, yyyy')#</h3>
	</cfoutput>
	
	<cfquery datasource="#application.applicationDataSource#" name="getLabItemsDelivered">
		SELECT *
		FROM vi_lab_dist_ticket_entries e
		JOIN tbl_lab_dist_ticket t ON e.ticket_id = t.ticket_id
		JOIN tbl_lab_dist_item_list i ON i.item_id = t.item_id
		JOIN tbl_users u ON u.user_id = e.user_id
		JOIN vi_labs l ON l.instance_id = e.instance_id
			AND l.lab_id = e.lab_id
		WHERE e.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.instance#">
			AND e.lab_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#labObj.lab#">
			AND e.submitted_ts > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
			AND e.submitted_ts < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate# 23:59:59.999">
			AND e.is_complete = 1
			AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY e.submitted_ts DESC
	</cfquery>
	
	<cfif getLabItemsDelivered.recordCount EQ 0>
		<p>No results found.</p>
	</cfif>
	
	<cfoutput query="getLabItemsDelivered">
		<div class="shadow-border" style="width:auto;display:inline-block;padding:10px;">
			<strong>#item_name#</strong><br/>
			Delivered On: #dateTimeFormat(submitted_ts, 'mmm dd, hh:nn tt')#<br/>
			Delivered By: #username#
		</div>
	</cfoutput>
	
<cfelseif action EQ "Item Search">

	<cfquery datasource="#application.applicationDataSource#" name="getItemName">
		SELECT item_name
		FROM tbl_lab_dist_item_list i
		WHERE item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
	</cfquery>
	
	<cfoutput query="getItemName">
		<h2>#item_name# Deliveries</h2>
	</cfoutput>
	
	<cfoutput>
		<h3>#dateTimeFormat(startDate, 'mmm dd, yyyy')# to #dateTimeFormat(endDate, 'mmm dd, yyyy')#</h3>
	</cfoutput>
	
	<cfquery datasource="#application.applicationDataSource#" name="getItemsDeliveredLabs">
		SELECT *
		FROM vi_lab_dist_ticket_entries e
		JOIN tbl_lab_dist_ticket t ON e.ticket_id = t.ticket_id
		JOIN tbl_lab_dist_item_list i ON i.item_id = t.item_id
		JOIN tbl_users u ON u.user_id = e.user_id
		JOIN vi_labs l ON l.instance_id = e.instance_id
			AND l.lab_id = e.lab_id
		WHERE i.item_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#itemId#">
		   AND e.submitted_ts > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
		   AND e.submitted_ts < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate# 23:59:59.999">
		   AND e.is_complete = 1
		   AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY e.submitted_ts DESC
	</cfquery>
	
	<cfif getItemsDeliveredLabs.recordCount EQ 0>
		<p>No results found.</p>
	</cfif>
	
	<cfoutput query="getItemsDeliveredLabs">
		<div class="shadow-border" style="width:auto;display:inline-block;padding:10px;">
			<strong>#lab_name#</strong><br/>
			Delivered On: #dateTimeFormat(submitted_ts, 'mmm dd, hh:nn tt')#<br/>
			Delivered By: #username#
		</div>
	</cfoutput>
	
<cfelse>

	<cfoutput>
		<h3>#dateTimeFormat(startDate, 'mmm dd, yyyy')# to #dateTimeFormat(endDate, 'mmm dd, yyyy')#</h3>
	</cfoutput>
	
	<cfquery datasource="#application.applicationDataSource#" name="getAllDelivered">
		SELECT *
		FROM vi_lab_dist_ticket_entries e
		JOIN tbl_lab_dist_ticket t ON e.ticket_id = t.ticket_id
		JOIN tbl_lab_dist_item_list i ON i.item_id = t.item_id
		JOIN tbl_users u ON u.user_id = e.user_id
		JOIN vi_labs l
			ON l.instance_id = e.instance_id
			AND l.lab_id = e.lab_id
		JOIN tbl_instances ins ON ins.instance_id = e.instance_id
		   AND e.submitted_ts > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate#">
		   AND e.submitted_ts < <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate# 23:59:59.999">
		   AND e.is_complete = 1
		   AND l.instance_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#session.primary_instance#">
		ORDER BY ins.instance_name, l.lab_name, e.submitted_ts DESC
	</cfquery>
	
	<cfif getAllDelivered.recordCount EQ 0>
		<p>No results found.</p>
	</cfif>
	
	<cfoutput query="getAllDelivered"  group="instance_name">
	
		<cfoutput group="instance_name">
			
			<cfoutput group="lab_id">
				<div class="shadow-border" style="width:30%; display:inline-block;padding:10px;margin:5px;">
				
					<h4 style="margin-top:0em; margin-bottom:0.5em;">#lab_name#</h4>
					<cfoutput>
						<div class="shadow-border" 
						     style="width:90%; display:inline-block; padding:10px; margin:5px; clear:both;">
							<strong>#item_name#</strong><br/>
							Delivered On: #dateTimeFormat(submitted_ts, 'mmm dd, hh:nn tt')#<br/>
							Delivered By: #username#
						</div>
					</cfoutput>
				
				</div>
				
			</cfoutput>
			
		</cfoutput>
		
	</cfoutput>
	
</cfif>

<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>