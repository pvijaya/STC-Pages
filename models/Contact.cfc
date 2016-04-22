<cfscript>
component  {
	property name="contactId" primaryKey="True" displayName="Contact ID" default="0" htmlFieldType="TextDisplay";
	property name="instanceId" displayName="Instance Id" default="0" htmlFieldType="Hidden";
	property name="statusId" displayName="Status Id" default="0" htmlFieldType="Hidden";
	property name="customers" displayName="Customers" default="" htmlFieldType="MultiText" placeholder="Customer Username(s)" helpText="One or more customers are connected to a contact. If you do not know the customer's username, simply type ##unknown instead.";
	property name="labId" displayName="Lab" default="" htmlFieldType="Select" placeholder="" helpText="";
	property name="links" displayName="Related Contacts" default="" htmlFieldType="MultiText" placeholder="Ex: 123456" helpText="Link to other similar contacts by using their ID";
	property name="categories" displayName="Categories" default="" htmlFieldType="MultiChoice";
	property name="notes" displayName="Notes" default="" htmlFieldType="History";
	property name="note" mapped="False" displayName="Add Note" default="" htmlFieldType="Editor";
	property name="minutesSpent" displayName="Minutes Spent" default="0" htmlFieldType="TextDisplay";
	

	public array function getPropertyOrder() {
		return ListToArray("contactId,instanceId,statusId,customers,labId,categories,links,minutesSpent,notes,note");
	}
	
	public array function getPropertyAttributes() {
		return ListToArray("name,mapped,primaryKey,displayName,default,htmlFieldType,placeholder,helpText");
	}

	public struct function getMetadata() {
		metadata = {};
		contactMetadata = GetMetaData(this);
		propertyAttributes = this.getPropertyAttributes();
		metadata["propertyOrder"] = this.getPropertyOrder();
		metadata["properties"] = {};
		for(var propertyIndex = 1; propertyIndex <= ArrayLen(contactMetadata.properties); propertyIndex++) {
			propertyName = contactMetadata["properties"][propertyIndex]["name"];
			metadata["properties"][propertyName] = {};
			if(StructKeyExists(contactMetadata["properties"][propertyIndex], "PrimaryKey") AND contactMetadata["properties"][propertyIndex]["PrimaryKey"] EQ True) {
				metadata["primaryKey"] = propertyName;
			}
			
			/*Coldfusion wants to uppercase all properties, but we must keep them in camelCase*/
			for(var attributeIndex = 1; attributeIndex <= ArrayLen(propertyAttributes); attributeIndex++) {
				attributeName = propertyAttributes[attributeIndex];
				if(StructKeyExists(contactMetadata["properties"][propertyIndex],attributeName)) {
					metadata["properties"][propertyName][attributeName] = contactMetadata["properties"][propertyIndex][attributeName];
				}
			}
		}
		return metadata;
	}
}







</cfscript>