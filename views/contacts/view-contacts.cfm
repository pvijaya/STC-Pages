<cfsetting showdebugoutput="false">
<script>
	var contactViewer = function(container, searchObject, createFormOnEmpty) {
		var defaultLab = {}
		if(typeof(createFormOnEmpty) === "undefined") {
			createFormOnEmpty = false;
		}
		new LoadingElement(container, "Loading");

		//creating a new contact form and controller
		var contactModel = new Crud('<cfoutput>#application.appPath#</cfoutput>/controllers/ContactController.cfm');
		var formDesigner = new FormDesigner();

		var getOpenContacts = function() {
			$.when(contactModel.get(searchObject)).done(function(result) {
				createContactForms(result);
			});
		}
		getOpenContacts();

		SubPub.subscribe("contact",getOpenContacts);

		var createContactForms = function(result) {
			$('.open-contact-counter').html("(" + result["result"].length + ")"); // update our open contact number
			if(result.result.length > 1 ) { // if this is many contacts, show them in a collapsible container
				var contactsPanelTemplate = [];
				for(var a = 0; a < result["result"].length; a++) {
					contactsPanelTemplate[a] = {
						title: result["result"][a].lastOpened + " - " + result["result"][a].customers.toString(),
						body:'<div class="contact' + a + '"></div>'
					};
				}
				new CollapsibleContainer(container,'', contactsPanelTemplate, "You have no open contacts at the moment.");
			} else { // if it's just one, let's show it without a collapsible container
				$(container).html('')
				$(container).append('<div class="contact0"></div>');
			}

			var openContacts = new Array();
			if(result["result"].length == 0 && createFormOnEmpty) { //the results don't return a contact, create an empty contact to show a create form
				result["result"][0] = {}
				if (defaultLab != {}) {
					result["result"][0] = {"labId": defaultLab}
				}
			}

			if(result["result"].length) {
				for(var i = 0; i < result["result"].length; i++) {
					drawContact(openContacts, result, i)
				}
			} else {
				$(container).append("<p>You have no open contacts</p>");
			}
		}

		var drawContact = function(openContacts, result, count) {
			var contactContainer = container + " div.contact" + count;
			contactObject = formDesigner.drawEditableObject(contactContainer, result["metadata"], result["result"][count])
			openContacts.push(contactObject);

			if(result["result"][count]["statusId"] != 2) {
				$(contactContainer + ' .minutesSpent-id').hide();

			} else {
				<cfif hasMasks("CS") EQ true>
					var value = $(contactContainer + ' .text-display-Minutes-Spent').html();
					var contactId = $(".text-display-Contact-ID", contactContainer).html();
					$(contactContainer + ' .text-display-Minutes-Spent').html(value + " <span class='tinytext'>[<a href='<cfoutput>#application.appPath#</cfoutput>/tools/contacts/update-time-spent.cfm?contactId=" + result["result"][count]["contactId"] +  "' class='minuteLink' contactId='"+ contactId +"' minutes='" + value +"'>Edit</a>]</span>");
				</cfif>
			}

			if(result["result"][count]["statusId"] == 0 || typeof(result["result"][count]["statusId"]) === "undefined") { // a new contact should have the ability to open and close a contact
				$(contactContainer + " .contactId-id").hide();
				//adding an update button and its event handler
				$(contactContainer + " .event-container").html('<input type="button" data="' + count + '" name="update-button" type="submit" class="btn btn-default" value="Open">');
				$(contactContainer + " .event-container input[name='update-button']").on("click", function() {
					var editingContact = openContacts[$(this).attr('data')]
					editingContact["properties"]["statusId"].setValue(1);
					$.when( contactModel.addOrUpdate(editingContact) ).done(function(result) {
						editingContact.showSuccess("Contact created")
						SubPub.publish("contact");
						defaultLab = JSON.stringify(editingContact.properties.labId.getValue());
					}).fail(function(result) {
						editingContact.showError(result.statusText)
					});

				});
				//adding an finish button and its event handler
				$(contactContainer + " .event-container").append('<input type="button" data="' + count + '"  name="finish-button" type="submit" class="btn btn-default" value="Close">');
				$(contactContainer + " .event-container input[name='finish-button']").on("click",function() {
					openContacts[$(this).attr('data')]["properties"]["statusId"].setValue(2);
					var editingContact = openContacts[$(this).attr('data')]
					$.when( contactModel.addOrUpdate(editingContact) ).done(function(result) {
						editingContact.showSuccess("Contact finished")
						SubPub.publish("contact");
						defaultLab = JSON.stringify(editingContact.properties.labId.getValue());
					}).fail(function(result) {
						editingContact["properties"]["statusId"].setValue(1);
						editingContact.showError(result.statusText)
					});
				});

			} if(result["result"][count]["statusId"] == 1) { // an open contact should have the ability to update or close a contact
				//adding an update button and its event handler
				$(contactContainer + " .event-container").html('<input type="button" data="' + count + '" name="update-button" type="submit" class="btn btn-default" value="Update">');
				$(contactContainer + " .event-container input[name='update-button']").on("click", function() {
					var editingContact = openContacts[$(this).attr('data')]
					$.when( contactModel.addOrUpdate(editingContact) ).done(function(result) {
						editingContact.showSuccess("Contact updated")
						SubPub.publish("contact");
					}).fail(function(result) {
						editingContact.showError(result.statusText)
					});

				});
				//adding an finish button and its event handler
				$(contactContainer + " .event-container").append('<input type="button" data="' + count + '"  name="finish-button" type="submit" class="btn btn-default" value="Close">');
				$(contactContainer + " .event-container input[name='finish-button']").on("click",function() {
					openContacts[$(this).attr('data')]["properties"]["statusId"].setValue(2);
					var editingContact = openContacts[$(this).attr('data')]
					$.when( contactModel.addOrUpdate(editingContact) ).done(function(result) {
						editingContact.showSuccess("Contact finished")
						SubPub.publish("contact");
					}).fail(function(result) {
						editingContact["properties"]["statusId"].setValue(1);
						editingContact.showError(result.statusText)
					});
				});
			} else if(result["result"][count]["statusId"] == 2){
				//adding an finish button and its event handler
				$(contactContainer + " .event-container").append('<input type="button" data="' + count + '"  name="finish-button" type="submit" class="btn btn-default" value="Reopen">');
				$(contactContainer + " .event-container input[name='finish-button']").on("click",function() {
					openContacts[$(this).attr('data')]["properties"]["statusId"].setValue(1);
					var editingContact = openContacts[$(this).attr('data')]
					$.when( contactModel.addOrUpdate(editingContact) ).done(function(result) {
						editingContact.showSuccess("Contact Reopened")
						SubPub.publish("contact");
					}).fail(function(result) {
						editingContact["properties"]["statusId"].setValue(2);
						editingContact.showError(result.statusText)
					});
				});
			}

			//add an event handler so when our Customer multi-select is blank and the user clicks the add button we add an unknown customer.
			$(contactContainer + " .customers-id .add-button").on("click", function(e){
				//it's harder than when we're doing the creation form.  We need to find the object that goes with this particular form.
				var contactId = 0
				$(this).parents().each(function(count, item){
					contactForm = $(item).closest("form")
					contactId = $(".text-display-Contact-ID", contactForm).html();
					if(typeof contactId !== 'undefined'){
						return false;//we've found the nearset contactId, and can break out of the loop.
					}
				});

				//at this point we should have a contactId we can use to find the matching contact object.
				var editingContact = {};
				for(i in openContacts){
					if(openContacts[i].properties.contactId.getValue() == contactId){
						editingContact = openContacts[i];
						break;
					}
				}

				if(editingContact.properties.customers.getSelectorValue() == ""){
					editingContact.properties.customers.addValue("#unknown");//add the value to our selection.
				}
			});
		}
	}
</script>