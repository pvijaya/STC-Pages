<!---COLD FUSION FUNCTIONS --->

<!--- fetches all customer contact categories in a query --->
<cffunction name="getAllCats">
	<cfset var getCategories = "">

	<cfquery datasource="#application.applicationDataSource#" name="getCategories">
		SELECT cc.category_id, cc.category_name, cc.parent_category_id, cc.active
		FROM tbl_contacts_categories cc
		WHERE active != 0
		ORDER BY cc.category_name
	</cfquery>

	<cfreturn getCategories>
</cffunction>

<!--- returns the option html as a string for easier use by javascript below --->
<cffunction name="getCatString" output="false">
	<cfargument name="getCats" type="query" default="#getAllCats()#">
	<cfargument name="parentCat" type="numeric" default="0">
	<cfargument name="level" type="numeric" default="0">
	<cfargument name="returnString" type="string" default="">

	<cfset var indentString = "&nbsp;&nbsp;">

	<cfloop query="getCats">

		<cfif parent_category_id EQ parentCat>

			<cfset returnString = returnString & '<option value="#category_id#"'>

			<cfif not active>
				<cfset returnString = returnString & ' style="display: none;"'>
			</cfif>

			<cfset returnString = returnString & '>'>

			<cfloop from="1" to="#level#" index="n">
				<cfset returnString = returnString & #indentString#>
			</cfloop>

			<cfset returnString = returnString & #category_name#>

			<cfif not active>
				<cfset returnString = returnString & "(retired)">
			</cfif>

			<cfset returnString = returnString & '</option>'>

			<cfset returnString = getCatString(getCats, category_id, level+1, returnString)>

		</cfif>

	</cfloop>

	<cfreturn returnString>

</cffunction>

<!--- draws the options for the category select box --->
<cffunction name="drawCats">
	<cfargument name="getCats" type="query" default="#getAllCats()#">
	<cfargument name="parentCat" type="numeric" default="0">
	<cfargument name="level" type="numeric" default="0">

	<cfset var indentString = "&nbsp;&nbsp;">

	<cfloop query="getCats">
		<cfif parent_category_id EQ parentCat>
			<cfoutput>
				<option value="#category_id#">

					<cfloop from="1" to="#level#" index="n">
						#indentString#
					</cfloop>
					#category_name#
				</option>
			</cfoutput>
			<cfset drawCats(getCats, category_id, level+1)>
		</cfif>
	</cfloop>

</cffunction>


<!--- returns the options for the category select box --->
<cffunction name="getCatsObject" output="false">
	<cfargument name="getCats" type="query" default="#getAllCats()#">
	<cfargument name="parentCat" type="numeric" default="0">
	<cfargument name="level" type="numeric" default="0">

	<cfset var indentString = "&nbsp;&nbsp;">
	<cfset var catObj = arrayNew(1)>
	<cfset var myCat = structNew()>
	<cfset var myChildren = arrayNew(1)>
	<cfset var i = 0>

	<cfloop query="getCats">
		<cfif parent_category_id EQ parentCat>
			<cfset myCat = structNew()><!---reset myCat to avoid disaster--->

			<cfset myCat["name"] = htmlEditFormat(category_name)>
			<cfset myCat["value"] = htmlEditFormat(category_id)>

			<!---pad out the name with the apropriate level of indentation.--->
			<cfloop from="1" to="#level#" index="i">
				<cfset myCat["name"] = indentString & myCat["name"]>
			</cfloop>

			<!---add our category to our array.--->
			<cfset arrayAppend(catObj, myCat)>

			<!---now fetch any child categories--->
			<cfset myChildren = getCatsObject(getCats, category_id, level + 1)>

			<cfloop from="1" to="#arrayLen(myChildren)#" index="i">
				<cfset arrayAppend(catObj, myChildren[i])>
			</cfloop>

		</cfif>
	</cfloop>

	<cfreturn catObj>
</cffunction>


<!--- JAVASCRIPT FUNCTIONS --->
<script type="text/javascript">

	function getContactInfo(id) {

		var d = 0;

		//send the id to mod-contact-info
		$.ajax({

			dataType: 'json',
			type: 'post',
			url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-contact-info.cfm',
			data: {
				contactId: id,
			},
			async: false,

			success: function(data) {

				d = data; /* just return the data */

			},

			error: function() {
				alert('Error, could not find specified contact.');
			}

		});

		return d;

	}

	function getLabs() {

		var labArray = new Array();

		$.ajax({

			dataType: 'json',
			type: 'post',
			url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-labs.cfm',
			data: {
			},
			async: false,
			success: function(data) {
				labArray = data.labArray;
			},
			error: function() {
				alert('Error, could not retrieve labs.');
			}

		});

		return labArray;

	}

	/*ContactDisplay objects take a selector like any jQuery function would, and when a method is passed
	* a contact ID it will fetch it and display it inside the selector provided*/
	ContactDisplay = function(selector, labArray) {
		if(typeof labArray === 'undefined') /* if a labArray is not passed in, call getLabs to get one */
			labArray = getLabs();

		this.container = $(selector);//make a jQuery object we can reference and use.
		this.contactId = 0;
		this.contactNote = {};//ultimately this will be a ckeditor object for adding a note.
		this.data = {};//a top level variable to store the data we'll fetch about this contact using AJAX.
		this.labArray = labArray; // an array of lab structs that is used to draw a selector

		var local = this;//a "local" version of this so we can use it in anonymous functions, like jQuery event handlers.

		//before methods we want to include some event handlers for forms and the like.

		$(this.container).on("submit", "form#update", function(e) {
			e.preventDefault();
			local.updateContact();
		});

		//hijack the re-open link.
		$(this.container).on("click", "a.reopen", function(e){
			e.preventDefault();

			local.openContact();
		});


		//hijack adding a note
		$(this.container).on("submit", "form.addNote", function(e){
			e.preventDefault();//prevent regular submission.

			//fetch the value of our note, and pass it to the addNote() method.
			var myNote = local.contactNote.getData();

			local.addNote(myNote);
		});

		//hijack the close contact button
		$(this.container).on("click", "form.addNote input[name='closeButton']", function(e){
			e.preventDefault();
			//if they've provided a note, submit it before we do other work.
			var myNote = local.contactNote.getData();

			if(myNote != "")
				local.addNote(myNote);

			//add/remove any changes to categories or users before we try to close the contact.
			var updated = local.updateContact();

			//if local.updateContact() didn't succeed it will have shown the user an alert, and we do not want to continue with our submission.
			if(updated != 1) {
				return 0;
			}

			//prevent them from closing the contact if there is no note for this contact.
			if(local.data.noteArray.length == 0){
				alert("Cannot close ticket without any notes.");
				return 0;
			}

			//Looks like we're good, update and close the contact.
			local.closeContact();

			/*Adding in calls to the updateContact() method slowed things down a bit, and our click-handler doesn't catch closed tickets.  We'll fix this by manually firing a click event.*/
			$(this.container).parents("div#existingContacts").click();//this should make our recently closed contact vanish from its container
		});

		//hijack adding a link
		$(this.container).on("submit", "form.addLink", function(e){
			e.preventDefault();//prevent regular submission.

			//fetch the contact the user wants to add.
			var linkTo = $("input[name='frmNewLinkId']", this).val();

			//call the addLink() method
			local.addLink(linkTo);
		});

		//hijack removing a link
		$(this.container).on("click", "a.remLink", function(e){
			e.preventDefault();

			//find the contact Id we want to remove the link to.
			var myVal = $(this).attr("linkto");

			//confirm that they intend to remove it.
			if(confirm('Remove this link?')){
				local.removeLink(myVal);
			}
		});

		//the drawContact method will fetch and draw our contact in the selector.
		this.drawContact = function(contactId){
			//first replace the content of our div with a loading image.
			this.container.html("<center><img src='<cfoutput>#application.appPath#/images/loading.gif</cfoutput>' alt='Loading Contact'><br/>Fetching contact " + contactId + "...");

			//update our this.contactId
			this.contactId = contactId;

			//now fetch the contact's details.
			this.data = this.fetchContact(contactId);
			//make a copy of this.data scoped locally to make life easier.
			var data = this.data;

			if(data.contact_id > 0)	{

				/* show the basic contact info */
				var info = '';
				info += '<h1>Contact #' + data.contact_id + '</h1>';
				info += '<br/>'
				info += '<fieldset class="info">';
				info += '<legend>Information</legend>';
					info += '<img src="<cfoutput>#application.appPath#</cfoutput>/images/loading.gif"> Loading Information.';
									//a form for adding new links
				info += '</fieldset>';

				info += '<br/>';

				/* draw the links as HTML links to each contact's view page */
				info += '<fieldset>';
				info += '<legend>Links To Other Contacts</legend>'
				info +='<div class="linksTo">';
					info += '<p style="align: center;"><img src="<cfoutput>#application.appPath#/images/loading.gif</cfoutput>" alt="Loading links"> Loading Linked Contacts...</p>';
				info += '</div><br/>';

				//a form for adding new links
				info += '<span class="trigger">Add Link</span>';
				info += '<div>';
				info += '<form class="addLink" action="<cfoutput>#application.appPath#/tools/contacts/view-contact.cfm</cfoutput>" method="post">';
					info += '<input type="hidden" name="contactId" value="' + data.contact_id + '">';
					info += '<label><strong>Contact ID:</strong>';
					info += '<input type="text" value="" name="frmNewLinkId">';
					info += '</label>';
					info += '<input type="submit" name="frmAction" value="Add Link">';
				info += '</form>';
				info += '</div>';

				info += '</fieldset>';

				info += '<br/>';

				if(this.data.linkListFrom != "") {
					info += '<fieldset class="linksFrom">';
					info += '<legend>Contacts Linked to This</legend>'
					info +='<div class="linksFrom">';
						info += '<p style="align: center;"><img src="<cfoutput>#application.appPath#/images/loading.gif</cfoutput>" alt="Loading links"> Loading Linked Contacts...</p>';
					info += '</div><br/>';
					info += '</fieldset>';

					info += '<br/>';
				}

				/* draw the notes and timestamps in an organized fashion */
				info += '<fieldset>';
				info += '<legend>Notes</legend>'
				info += '<div class="notes">';
					info += '<img src="<cfoutput>#application.appPath#</cfoutput>/images/loading.gif"> Loading Notes';
				info += '</div>';//closing div.notes

				//now also add a form for adding more notes.
				info += '<div>';
					info += '<form class="addNote" action="<cfoutput>#application.appPath#/tools/contacts/view-contact.cfm</cfoutput>" method="post">';
					info += '<input type="hidden" name="contactId" value="' + data.contact_id + '">';
					info += '<label><strong>New Note: </strong><br/>';
					info += '<textarea name="frmNewNote' + this.contactId + '"></textarea>';
					info += '</label>';
					info +='<br/>';
					info += '<input type="submit" name="frmAction" value="Add Note"> ';
					info += '<input type="button" name="closeButton" value="Close Contact">';
					info += '</form>';
				info += '</div>';
				info += '</fieldset>';


				//we're done building info, draw it to our container.
				this.container.html(info);


				/*having added our new values to this.container we still need to make sure our textareas are ckeditors.*/
				this.contactNote = CKEDITOR.replace('frmNewNote' + this.contactId ,{
			        toolbar_Basic: [['Bold','Italic','Underline'],['RemoveFormat'],['NumberedList','BulletedList','-','Outdent','Indent'],['Link','Unlink'],['SpecialChar']],
			        toolbar:  'Basic',
			        height: '200px',
			        width: '500px',
			        removePlugins: 'contextmenu, tabletools' //the context menu hijacks right-clicks - this is bad.  the     tabletools plugin also requires the context menu, so we had to remove it, as well.
			        //enterMode: CKEDITOR.ENTER_BR replaces enclosing p tags with line breaks
			    });

				//if the contact is already closed hide the button for closing the contact.
			    if(this.data.status == "Closed") {
			    	//we tried doing a fadeOut here, but it didn't cooperate with the jQuery-ui dialog boxes.
					$("form.addNote input[name='closeButton']", this.container).css("display", "none");
				}
				//Draw the info/status for our contact
				this.drawInfo();

				//since we've paved the way for drawing notes fill the area now.
				this.drawNotes();

				//lastly pass our data along to a helper method to draw details for all of the linked contacts.
				this.drawLinks(data.linkListTo, 1);
				this.drawLinks(data.linkListFrom, 0);

			} else {
				//If we got an error back from mod-contact-info.cfm just display it.
				this.container.html(data.message);
			}

		}


		//a method for drawing the status/info for a contact
		this.drawInfo = function (){

			var output = '<legend>Information</legend>';

			output += '<form id="update" action="<cfoutput>#cgi.script_name#</cfoutput>" method="post">';
			output += '<table>';
				output += '<tr><td style="font-weight:bold;">Status:  </td><td>';

				if(this.data.status == "Closed")
					output += this.data.status + ' <span class="tinytext">[<a class="reopen" href="<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-change-status.cfm?frmContactId=' + this.data.contactId + '&frmStatusId=' + 1 + '">reopen</a>]</span>';
				else
					output += this.data.status;
				output += '</td></tr>';
				output += '<tr><td style="font-weight:bold;">Opened By:  </td><td>' + this.data.username + '</td></tr>';
				output += '<tr><td style="font-weight:bold;">Opened:  </td><td>' + this.data.ts + '</td></tr>';
				output += '<tr><td style="font-weight:bold;">Lab:  </td><td>' + this.data.lab + ' ';
				output += '<span class="tinytext" id="changeLabSpan">[<a id="changeLab" href="##" onclick="return false;">Change</a>]</span>';
				output += '</td></tr>';

				//console.log(this.data.labArray);

				var array = this.labArray;
				var select = '<tr id="newLabSelect" style="display:none;"><td></td><td>';
				select += '<select id="labId" name="labId" class="siteSelector">';
				select += '<option value="i0l0">---</option>';

				for(var i = 0; i < array.length; i++) {
					//console.log(array[i]);
					//console.log(array[i]['labId']);
					//console.log(this.data.labId);
					select += '<option value="' + array[i]['labId'] + '"';
					if(array[i]['labId'] == this.data.labId) {
						select += 'selected="true"';
					}
					select += '>    ' + array[i]['labName'] + '</option>';

				}

				select += '</select>';
				select += '<span class="tinytext">[<a id="hideSelect" href="##" onclick="return false;">Hide</a>]</span>';
				select += '</td></tr>';

				output += select;
				output += '<tr><td style="font-weight:bold;">Usernames:  </td>';
				output += '<td>';
				output += '<div class="usernameDiv">';
				output += '<input type="hidden" name="usernameList" value="' + this.data.userList + '" id="usernameList">';
				output += '<label>';
				output += '<input type="text" name="frmUsername" value="" id="username">';
				output += '</label>';
				output += '<input type="button" class="addUsername" value="Add"></br>';
				output += '</td></tr>';
				output += '<tr><td></td><td>';
				output += '<span id="usernames"></span>';
				output += '</td></tr>';

				output += '<tr><td style="font-weight:bold;">Categories:  </td>';
				output += '<td>'
				output += '<div class="categoryDiv">';
				output += '<input type="hidden" name="categoryList" value="' + this.data.catIdList + '" id="categoryList">';
				output += '<label>';
				output += '<select name="frmCategory" value="" id="category">';
				output += '<cfoutput>#SerializeJSON(getCatString())#</cfoutput>';
				output += '</select>';
				output += '</label>';
				output += '<input type="button" class="addCategory" value="Add"></br>';
				output += '</td></tr>';
				output += '<tr><td></td><td>';
				output += '<span id="categories"></span>';
				output += '</td></tr>';

			output += '</table>';

			output += '<input type="submit" value="Update" id="update">';
			output += '</form>';

			//now replace the contents of the info fieldset with the new data.
			$("fieldset.info", this.container).html(output);

			/*  initialize the SelectMultiChoice objects for the info we just drew. */

			this.multiUserObject = new SelectMultiChoice("input#username", "input#usernameList",
														 "input.addUsername", "span#usernames",
														 "remUser", "None", this.container);
			this.multiUserObject.init();

			this.multiCatObject = new SelectMultiChoice("select#category", "input#categoryList",
														"input.addCategory", "span#categories",
														"remCat", "None", this.container);
			this.multiCatObject.init();

			/* in the category selector, disable all options the contact already has */
			var catIdList = new List(this.data.catIdList);
			var catArray = catIdList.toArray();
			for(var i in catArray) {
				this.multiCatObject.disableOption(catArray[i]);
			}

		}

		//a method for looping over all the note data and drawing all the notes.
		this.drawNotes = function (){
			//start by blanking existing notes with a loading message
			$("div.notes", this.container).html('<img src="<cfoutput>#application.appPath#</cfoutput>/images/loading.gif"> Loading Notes');

			var output = "";

			if (this.data.noteArray.length != 0)
				for (var i in this.data.noteArray) {
					this.drawNote(i);
				}
			else
				$("div.notes", this.container).html('<p>There are no notes for this contact.</p>');
		}

		this.updateNotes = function(){
			//first, make a copy of our existing noteArray.  Just using equal would point to the original value, so we use splice because we want a COPY to compare against.
			var oldNotes = this.data.noteArray.splice(0);

			//now fetch new data, and upate our object's noteArray.
			var newData = this.fetchContact(this.contactId);
			this.data.noteArray = newData.noteArray;

			//loop over our objects current noteArray, and draw any notes that aren't found in the old notes.
			for(var n in this.data.noteArray){
				var myNoteId = this.data.noteArray[n].note_id;

				var foundMatch = 0;

				for(var i in oldNotes) {
					if(oldNotes[i].note_id == myNoteId){
						foundMatch = 1;
						break;//we found a match, we can break-out of our inner loop.
					}
				}

				//if we didn't find a match, draw the new note.
				if(!foundMatch)
					this.drawNote(n);
			}
		}

		//a method for drawing a particular note located in this.data.noteArray[].
		this.drawNote = function(pos){
			var output = "";
			output += '<div class="note" style="display: none;">'; //don't display because we want to fade in.
				output +='<em><span style="font-size:11; margin-bottom:0em;">' + this.data.noteArray[pos].note_ts + '<br/>' + this.data.noteArray[pos].username +'</span></em>';
				output += '<blockquote>' + this.data.noteArray[pos].note_text + '</blockquote>';
			output += '</div>';

			//having built up our output, append it where it belongs.
			if(pos == 0)
				$("div.notes", this.container).html(output);
			else
				$("div.notes", this.container).append(output);

			//now fade in the note we just added.
			$("div.notes div.note", this.container).last().fadeIn();
		}

		//A method that draws information about all contacts this one is linked to.
		this.drawLinks = function(links, to) {

			var linkList = new List(links);
			var linkArray = linkList.toArray();

			if(to == 1) {
				var warning = "No links to other contacts.";
				var div = "div.linksTo";
				var class_name = ".linksTo";
			} else {
				var warning = "No links from other contacts.";
				var div = "div.linksFrom";
				var class_name = ".linksFrom"
			}

			//loop over all the linked contacts, fetch data and draw them.
			for(var n in linkArray) {
				var lData = this.fetchContact(linkArray[n]);
				this.drawLink(lData, to, n);
			}

			//if we didn't have any contacts, then output placeholder text.
			if(linkArray.length == 0) {
				$(div, this.container).html("<p>" + warning + "</p>");
			}
		}

		//this method helps drawLinks() and addLink draw uniform links information.
		this.drawLink = function(lData, to, pos){

			if(to == 1) {
				var id = "linkTo";
				var div_id = "div#linkTo";
				var div_class = "div.linksTo";
			} else {
				var id = "linkFrom";
				var div_id = "div#linkFrom";
				var div_class = "div.linksFrom";
			}

			//pos is optional, it just lets us know if this is the first item we're drawing or not.
			if(typeof pos === 'undefined')
				pos = 1;

			//use lData to generate the desired output.
			var output = "";

			output += '<div style="opacity: 0.0; display: inline-block; width: 20em;border: solid 1px gray;" id="' + id + lData.contact_id +'">';
			output += '<a href="<cfoutput>#application.appPath#/tools/contacts/view-contact.cfm</cfoutput>?contactId=' + lData.contact_id + '">' + lData.contact_id + '</a> ';

			if(to == 1) {
				output += '<span class="tinytext">[';
					output += '<a class="remLink" linkTo="' + lData.contact_id + '" href="<cfoutput>#application.appPath#/tools/contacts/view-contact.cfm</cfoutput>?contactId=' + this.data.contact_id + '&frmRemLinkId=' + lData.contact_id + '&frmAction=Remove%20Link">remove</a>'
				output += ']</span>';
			}

			output += '<br/>';

			output += lData.ts + ' by ' + lData.username + '<br/>';
			output += lData.status + '<br/>';
			output += lData.catList;
			output += '</div>';

			//we want to fade-in each link individually.  But the first one should rewrite any existing HTML.
			if(pos == 0)
				$(div_class, this.container).html(output)
			else
				$(div_class, this.container).append(output)

			//we added it invisibly, now fade it in.(we're using animate instead of .fadeIn because we're dealing with an inline-block div).
			$(div_id + lData.contact_id).animate({
				opacity: 1
			});

		}

		//The method that actually fetches the data returning a data object.
		this.fetchContact = function(contactId) {
			var d = {"contact_id": 0};

			//send the id to mod-contact-info
			$.ajax({

				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-contact-info.cfm',
				data: {
					"contactId": contactId,
				},
				async: false,

				success: function(data) {

					d = data; /* just return the data */

				},

				error: function() {
					alert('Error, could not find specified contact.');
				}

			});

			return d;
		}

		this.updateContact = function() {
			var success = 0;

			//make the ajax call. Since we'll be in an anonymous function we'll be using our var local instead of 'this'
			$.ajax({
				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-update-info.cfm',
				data: {
					'frmContactId': local.contactId,
					'usernameList': $("input#usernameList", local.container).val(),
					'categoryList': $("input#categoryList", local.container).val(),
					'labId': $("select#labId", local.container).val()
				},
				async: false,
				success: function(data){
					if(data.status == 1){
						//fetch the updated data and redraw the contact data that may have changed.
						local.data = local.fetchContact(local.contactId);
						//redraw the info and the notes.
						local.drawInfo();
						local.drawNotes();

						success = 1;
					} else {
						alert("An error was encountered while attempting to update the contact's information:\n" + data.message);
						success = 0;
					}
				},
				error: function(data){
					alert("Unable to submit your updated Information.");
					success = 0;
				}
			});
			return success;//return our promise so we can move on to the next one
		}

		//a method for closing contacts using mod-close-contact.cfm
		this.closeContact = function() {
			//make the ajax call. Since we'll be in an anonymous function we'll be using our var local instead of 'this'
			$.ajax({
				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-change-status.cfm',
				data: {
					'frmContactId': local.contactId,
					'frmStatusId': 2,
					'frmCategoryList': local.data.catList
				},
				async: false,
				success: function(data){
					//do success stuff here.
					if(data.status == 1){
						//fetch the updated data and redraw the contact data that may have changed.
						local.data = local.fetchContact(local.contactId);
						//redraw the info and the notes.
						local.drawInfo();
						local.drawNotes();

						//hide the close button so they cannot see it
						$("form.addNote input[name='closeButton']", local.container).fadeOut();

					}
				},
				error: function(data){
					//We hit a snag.
					alert('An error was encountered when attempting to close this contact.');
				}
			})
		}

		//a method for re-opening contacts using mod-close-contact.cfm
		this.openContact = function() {
			//make the ajax call.
			$.ajax({
				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-change-status.cfm',
				data: {
					'frmContactId': local.contactId,
					'frmStatusId': 1
				},
				async: false,
				success: function(data){
					//do success stuff here.
					if(data.status == 1){
						//fetch the updated data and redraw the contact data that may have changed.
						local.data = local.fetchContact(local.contactId);
						//redraw the info and the notes.
						local.drawInfo();
						local.drawNotes();

						//show the close button so they can use it
						$("form.addNote input[name='closeButton']", local.container).fadeIn();
					}else
						local.container.html('<p class="alert">An error was encountered when attempting to re-open this contact.<br/>' + data.message + '</p>');
				},
				error: function(data){
					//We hit a snag.
					local.container.html('<p class="alert">An error was encountered when attempting to re-open this contact.</p>');
				}
			});
		}

		//A method for adding notes to our contact.
		this.addNote = function(myNote) {
			//make the ajax call to add the note.
			$.ajax({
				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-add-note.cfm',
				data: {
					'frmContactId': local.contactId,
					'frmNoteText': myNote
				},
				async: false,
				success: function(data){
					if(data.status == 1){
						//it worked display our new note.

						//clear out the existing value of our ckeditor.
						local.contactNote.setData("");


						//calee the updateNotes method to draw our new note(s).
						local.updateNotes();
					} else {
						//there was some kind of issue, display the error.
						alert(data.message);
					}
				},
				error: function(data){
					alert("Unable to send new note request.")
				}
			});
		}

		//A method for adding a link to another contact.
		this.addLink = function(linkToContactId) {
			//make the ajax call to add it
			$.ajax({
				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-manage-links.cfm',
				data: {
					'frmAction': 'Add Link',
					'frmContactId': local.contactId,
					'frmLinkContactId': linkToContactId
				},
				async: false,
				success: function(data){

					//if it worked simply push the linkToContactId into local.data's array of linked contacts, and draw our link.
					if(data.status == 1){
						//make a list object of existing links
						var myLinks = new List(local.data.linkListTo);

						//add our new link.
						myLinks.append(linkToContactId);

						//update the existing links
						local.data.linkListTo = myLinks.toString();

						//fetch the data for the linked-to contact so we can draw it.
						var lData = local.fetchContact(linkToContactId);

						local.drawLink(lData, 1, myLinks.length()-1);

						//having done all that blank out the contact id field.
						$("form.addLink input[name='frmNewLinkId']", local.containter).val("");

						//as a last step fetch any new messages for our contact and display them.
						local.updateNotes();

					} else {
						alert(data.message);
					}
				},
				error: function(data){
					alert("Unable to send linking requests.")
				}
			});
		}

		//A method for removing a link to another contact.
		this.removeLink = function(linkToContactId){

			//make the ajax call to remove it
			$.ajax({
				dataType: 'json',
				type: 'post',
				url: '<cfoutput>#application.appPath#</cfoutput>/tools/contacts/mod-manage-links.cfm',
				data: {
					'frmAction': 'Remove Link',
					'frmContactId': local.contactId,
					'frmLinkContactId': linkToContactId
				},
				async: false,
				success: function(data){

					//if it worked simply push the linkToContactId into local.data's array of linked contacts, and draw our link.
					if(data.status == 1){

						//make a list object of existing links
						var myLinks = new List(local.data.linkListTo);
						var myLinksArray = myLinks.toArray();
						var myNewLinksArray = new Array();

						//fill myNewLinksArray by looping over myLinksArray and skipping the value we removed.
						for(var n in myLinksArray) {
							if( myLinksArray[n] != linkToContactId)
								myNewLinksArray.push(myLinksArray[n]);
						}

						//update the existing links with our new values.
						local.data.linkListTo = myNewLinksArray.toString();


						//remove the drawn version of the contact
						$("div#linkTo" + linkToContactId, local.container).fadeOut()
							.queue(function(nxt) {
								$(this).remove();//remove the item after it fades out.
								nxt();
							});

						//if we don't have any contacts left call drawLinks() to draw the placeholder.
						if(myNewLinksArray.length == 0)
							local.drawLinks(new List(local.data.linkListTo), 1);

						//as a last step fetch any new messages for our contact and display them.
						local.updateNotes();

					} else {
						alert(data.message);
					}
				},
				error: function(data){
					alert("Unable to send linking requests.")
				}
			});
		}

		var fading = false;

		$(local.container).on('click', '#changeLab', (function() {
			if(!fading) {
				fading = true;
				$('#changeLabSpan').fadeOut('slow', function() {
					$('#newLabSelect', local.container).fadeIn('slow', function() {
						fading = false;
					});
				});
			}
		}));

		$(local.container).on('click', '#hideSelect', (function() {
			if(!fading) {
				fading = true;
				$('#newLabSelect').fadeOut('slow', function() {
					$('#changeLabSpan', local.container).fadeIn('slow', function() {
						fading = false;
					});
				});
			}
		}));

	}

</script>