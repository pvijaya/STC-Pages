<!---
	This page is inteded to be called as a module using cfJSONparam tag or invoked with cfmodule.
	It works much like cfparam, but is intended to get JSON strings, parse them into objects, and then compare them against
	a "constructor" that makes sure each value in the object is the expected type.
--->
<cfif not isDefined("jsonSanitize")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<cfparam name="attributes.varName" type="string" default="">
<cfparam name="attributes.constructor" type="string" default="{}"><!---and empty object means anything goes - not recommended.--->
<cfparam name="attributes.default" type="string" default="{}">

<!---validate our user's provided attributes.--->
<cfif trim(attributes.varName) eq "">
	<cfthrow type="custom" message="JSONparam - Missing attribute" detail="you must provide a NAME attribute.">
</cfif>

<!---if the user provided a name try to find it in the FORM or URL scopes, just like cfparam would.--->
<cfif isDefined("form.#attributes.varName#")>
	<cfif trim(form['#attributes.varName#']) neq "">
		<cfset attributes.default = form['#attributes.varName#']>
	</cfif>
<cfelseif isDefined("url.#attributes.varName#")>
	<cfif trim(url['#attributes.varName#']) neq "">
		<cfset attributes.default = url['#attributes.varName#']>
	</cfif>
</cfif>

<!---at this point we have attributes.constructor and attributes.default at their desired values, parse them both into real objects.--->
<cfset constructor = deserializeJSON(attributes.constructor)>
<cfset testObj = deserializeJSON(attributes.default)>

<!---now we can check to make sure our testObj is a valid expression of our constructor.--->
<cfif attributes.constructor neq "{}"><!---don't bother if there are no restrictions in attributes.constructor--->
	<cfset isGood = validateObj(constructor, testObj)>
	
	<cfif not isGood>
		<cfthrow type="custom" message="JSONparam - Improper Data" detail="Data provided did not pass tests for the provided CONSTRUCTOR.">
	</cfif>
</cfif>

<!---if we got this far we can set the value of the variable attributes.varName in the calling script.--->
<cfset Caller['#attributes.varName#'] = testObj>

<!---cfoutput>
	From JSONparam.cfm<br/>
	Name: #attributes.varName#<br/>
	isGood: #isGood#<br/>
	constructor: <cfdump var="#constructor#"><br/>
	#attributes.varName#: <cfdump var="#testObj#">
</cfoutput--->

<cffunction name="validateObj" output="false">
	<cfargument name="conObj" type="any" required="true">
	<cfargument name="myObj" type="any" required="true">
	
	<cfset var isValid = 1>
	<cfset var key = "">
	
	<!---we behave differently if conObj is a struct, array, or string--->
	<cfif isStruct(conObj)>
		<!---if myObj contains something that isn't in conObj it's bad.--->
		<cfloop list="#structKeyList(conObj)#" index="key">
			<cfif not listFindNoCase(structKeyList(conObj), key)>
				<cfreturn 0>
			</cfif>
		</cfloop>
		
		<cfloop list="#structKeyList(conObj)#" index="key">
			<!---if myObj doesn't match the structure of conObj we know it's bad.--->
			<cfif not isDefined("myObj.#key#")>
				<cfreturn 0>
			</cfif>
			
			<cfset isValid = validateObj(conObj[key], myObj[key])>
			
			<cfif not isValid>
				<cfreturn 0>
			</cfif>
		</cfloop>
	
	<cfelseif isArray(conObj)>
		<!---if the user value isn't an array it's bad.--->
		<cfif not isArray(myObj)>
			<cfreturn 0>
		</cfif>
		
		<cfloop from="1" to="#arrayLen(myObj)#" index="key">
			<cfset isValid = validateObj(conObj[1], myObj[key])>
			
			<!---if it didn't pass we're done.--->
			<cfif not isValid>
				<cfreturn 0>
			</cfif>
		</cfloop>
		
	<cfelse><!---the last case, a string conObj will be a type, and myObj should be of that type.--->
		<cfif not isValid(conObj, myObj)>
			<cfreturn 0>
		</cfif>
	</cfif>
	
	<cfreturn isValid>
</cffunction>