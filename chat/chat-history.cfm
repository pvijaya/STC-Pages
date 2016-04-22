<cfmodule template="#application.appPath#/modules/check-access.cfm"  masks="Consultant">
<cfmodule template="#application.appPath#/header.cfm" title='Chat History' drawCustom=false noText=false>
<cftry>
	<cfparam name="currentUsername" type="string" default="">
	<cfparam name="startDate" type="date" default="#dateAdd('d', -7, now())#">
	<cfparam name="endDate" type="date" default="#now()#">
	<cfparam name="action" type="string" default="">
	
	<!---make sure our dates aren't poluted with any hours or minutes, and are formatted correctly.--->
	<cfset startDate = dateFormat(startDate, "mmm d, yyyy")>
	<cfset endDate = dateFormat(endDate, "mmm d, yyyy")>
	
	<!---additionally end date must always be greater or equal to start date, if they're out of order, just swap them.--->
	<cfif dateCompare(startDate, endDate) gt 0>
		<cfset tempEnd = startDate>
		<cfset startDate = endDate>
		<cfset endDate = tempEnd>
	</cfif>
	
	<cfif action EQ "Submit">	
			<cfquery datasource="#application.applicationDataSource#" name="getChatMessages">
				SELECT u.username, cm.Date_Time, cm.From_IP, cm.Message_ID, cm.Visible, cm.Message 
				FROM tbl_chat_messages cm 
				INNER JOIN tbl_users u ON u.user_id = cm.user_id 
				INNER JOIN tbl_instances i ON i.instance_id = cm.instance 
				WHERE cm.Date_Time BETWEEN <cfqueryparam cfsqltype="cf_sql_timestamp" value="#startDate# 00:00"> and <cfqueryparam cfsqltype="cf_sql_timestamp" value="#endDate# 23:59:59.9">
				AND 1 = dbo.userHasMasks(<cfqueryparam cfsqltype="cf_sql_integer" value="#session.cas_uid#">, i.instance_mask) 
				<cfif trim(currentUsername) neq ""> 
					AND u.username = <cfqueryparam cfsqltype="cf_sql_varchar" value="#currentUsername#"> 
				</cfif> 
				ORDER BY cm.Date_Time DESC
			</cfquery>
	</cfif>
	<cfcatch>
		<p class="warning">
			<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
		</p>
	</cfcatch>
</cftry>
<h1>Chat History</h1>
<cfset instanceList = userHasInstanceList().nameList>


<!---get all chat users for an auto-completing input.--->
<cfquery datasource="#application.applicationDataSource#" name="getChatUsers">
	SELECT DISTINCT u.user_id, u.last_name, u.first_name, u.username
	FROM tbl_chat_messages cm
	INNER JOIN tbl_users u on cm.user_id = u.user_id
	ORDER BY u.last_name, u.first_name, u.username
</cfquery>


<!---HTML--->
<cfoutput>
<form>
	
	<p>
		<label>Username:</label>
		<input type="text" name="currentUsername" id="frmUsername" value="#currentUsername#">(optional)
	</p>
	<label>
		Start Date:
		<input type="text" class="picker" name="startDate" value="#startDate#"/>
	</label> 
	
	<label>
		End Date:
		<input type="text" class="picker" name="endDate" value="#endDate#"/>
	</label> 
	
	<script type="text/javascript">
		$("input.picker").datepicker({
			dateFormat: "M d, yy",
			changeMonth: true,
			changeYear: true,
			minDate: 'Jun 21, 2004',
			maxDate: '#dateFormat(now(),"mmm d, yyyy")#'
		});
	</script>
	<br/><br/>
	<input  type="submit" value="Submit" name="action" />
	
</form>

<cfif action EQ "Submit">
	<cftry>
	<cfloop query="getChatMessages">
		<p>#username# (#Date_Time#) #message#</p>
	</cfloop>
		<cfcatch>
			<p class="warning">
				<cfoutput>#cfcatch.Message# - #cfcatch.Detail#</cfoutput>
			</p>
		</cfcatch>
	</cftry>
</cfif>

</cfoutput>
<script type="text/javascript">
	/*make the auto-complete for our text input.*/
	var ourUsers = [
		<cfset cnt = 1>
		<cfloop query="getChatUsers">
			<cfoutput>"#htmlEditFormat(username)#"</cfoutput><cfif cnt lt getChatUsers.recordCount>,</cfif>
			<cfset cnt = cnt + 1>
		</cfloop>
	]
	
	$(document).ready(function(){			
		$("input#frmUsername").autocomplete({source: ourUsers, minLength: 0});
		//make our dates calendars.
		$("input.date").datepicker({dateFormat: 'M d, yy'});
	});
</script>
<cfmodule template="#application.appPath#/footer.cfm" drawCustom=false>