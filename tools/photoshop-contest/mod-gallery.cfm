<!--- this module allows us to display a set of images from a folder in the Filemanager --->
<!--- the images are initially displayed in 'grid view', all the same size --->
<!--- when an image is clicked on, switches to 'gallery view', allowing single images to be --->
<!--- enlarged and browsed through --->

<!--- structure --->
<!--- #gallery = a div containing the gallery, both grid view and gallery view --->
<!--- #largeImage = a div containing the large image in gallery view --->
<!--- #smallImages = a .thumbs div containing the images of the current row in gallery view --->
<!--- .thumbs = class assigned to a row of image thumbnails --->
<!--- each .thumbs contains 4 block-card divs, each of which contains a thumbnail img --->
<!--- each img in .thumbs has a unique data-id value corresponding to its file id --->
<!--- .row = class assigned to .thumbs rows in grid view only --->
<!--- each .row has a unique data-r value corresponding to its row index --->

<!--- GRID VIEW --->
<!--- ______________________________ --->
<!--- |_#gallery__________________ | --->
<!--- || |    ||    ||    ||    | || .thumbs --->
<!--- ||_|____||____||____||____|_|| .row data-r = 1 --->
<!--- |___________________________ | --->
<!--- || |    ||    ||    ||    | || .thumbs --->
<!--- ||_|____||____||____||____|_|| .row data-r = 2 --->
<!--- |___________________________ | --->
<!--- || |    ||    ||    ||    | || .thumbs --->
<!--- ||_|____||____||____||____|_|| .row data=r = 3 --->
<!--- |____________________________| --->

<!--- GALLERY VIEW --->
<!--- _____________________________  --->
<!--- | #gallery__________________ | --->
<!--- || ____ #largeImage__      x|| --->
<!--- |||info||img         |      || --->
<!--- |||____||            |      || --->
<!--- ||      |            |      || --->
<!--- ||      |            |      || --->
<!--- ||      |____________|      || --->
<!--- ||__________________________|| --->
<!--- |#smallImages_.thumbs_______ | --->
<!--- ||<|div ||div ||div ||div |>|| two arrow buttons allow the row to be changed--->
<!--- ||_|____||____||____||____|_|| each div contains an img --->
<!--- |____________________________| --->

<cfif not isDefined("attributes")>
	<h1>Error</h1>
	<p>
		This page is to be exclusively used as a module, and cannot be browsed to.
	</p>
	<cfabort>
</cfif>

<cfif not isDefined("hasMasks")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>

<!--- the images displayed by the gallery module are pulled from a query --->
<!--- this query will vary depending on the page calling the module --->
<cfparam name="attributes.images" type="query">
<cfparam name="attributes.psc" type="boolean" default="0">
<cfparam name="attributes.psc_source" type="boolean" default="0">
<cfparam name="attributes.psc_entries" type="boolean" default="0">
<cfparam name="attributes.psc_winners" type="boolean" default="0">
<cfparam name="attributes.psc_voting" type="boolean" default="0">
<cfparam name="attributes.psc_rejected" type="boolean" default="0">
<cfparam name="attributes.psc_userView" type="boolean" default="0">
<cfparam name="attributes.gallery_url" type="string" default="">

<cfset getImages = attributes.images>

<!--- css --->
<style type="text/css">

	.thumbs {
		width:100%
		padding-top:10px;
		margin-left: auto;
		margin-right: auto;
		white-space:nowrap;
		text-align:center;
	}

	.thumbs div {
		width: 18%;
		height: 18%;
		display: inline-block;
		margin: 1%;
	}

	.thumbs div:before, #largeImage:before {
		content:'';
		display: inline-block;
		height:100%;
		vertical-align: middle;
	}

	.thumbs div img {
		max-height: 90%;
		max-width: 90%;
		height:auto;
		width:auto;
		padding: 4px;
		background-color: white;
		display: inline-block;
		vertical-align: middle;
		margin-left:auto;
		margin-right:auto;
	}

	#largeImage {
		height: 60%;
		margin-left:auto;
		margin-right:auto;
		position:relative;
	}

	#largeImage img {
		max-height: 90%;
		max-width: 55%;
		height:auto;
		width: auto;
		vertical-align:middle;
	}

	#largeImage #info {
		position:absolute;  /* this helps keep the image centered absolutely */
		left:0px;
		top:0px;
		display:inline-block;
	}

	button:disabled {
		color:#CDCDCD;
	}

</style>

<!--- javascript --->
<script type="text/javascript">

	$(document).ready(function() {

		/* variables */
		var img = $('#largeImage img');
		var id = 0; /* keeps track of which image is in #largeImage in gallery view */
		var row = 0; /* this will be our cloned row once we hit gallery view */
		var r = 0; /* keeps track of which row's images are in #smallImages in gallery view */
		var min_r = 1; /* minimum row value */
		var max_r = $('#gallery div.row').length; /* maximum row value */
		var gal_view = 0; /* a bit toggle showing which view mode we are in */
		var fading = 0;  /* a bit toggle that keeps track of whether something is currently fading */
		/* this last variable helps prevent click-happy users from triggering multiple functions or the same
		* function multiple times, which can turn the page into a mess */

		/* the triggers and calls for the various functions */
		$(document).on("click", '.thumbs div img', selectThumbnail);
		$(document).on("click", '#closeBtn', closeGalleryView);
		$(document).keyup(function(e) {
			if (e.which == 27) { closeGalleryView(); } /* ESC key */
		});
		$(document).keyup(function(e) {
			if (e.which == 37) { prevThumbnail(); } /* Left Arrow key */
		});
		$(document).keyup(function(e) {
			if (e.which == 39) { nextThumbnail(); } /* Right Arrow Key key */
		});
		$(document).on("click", 'button', changeRow);

		$(document).on("click", "a.nextLink", function(e){
			e.preventDefault();
			nextThumbnail();
		});

		$(document).on("click", "a.prevLink", function(e){
			e.preventDefault();
			prevThumbnail();
		})

		function nextThumbnail() {

			/* if we are already in gallery view and not fading */
			if(gal_view && !fading) {

				fading = true;

				var row_shift = false;

				/* find the current .block-card div and row */
				var temp_div = $('#gallery .row .block-card').filter(function() {
					return $(this).find('img').attr('data-id') == id;
				})

				var temp_row = $('#gallery .row').filter(function() {
					return $(this).attr('data-r') == r;
				})

				/* if temp_div is the last div in temp_row */
				if($(temp_div).is(':last-child')) {

					/* and if r isn't at the max value */
					if(r < max_r) {

						/* use this later to know whether to repopulate #smallImages */
						var row_shift = true;

						/* increment the row */
						temp_row = $('#gallery .row').filter(function() {
							return $(this).attr('data-r') == r + 1;
						});

						/* select the first div in the new row */
						temp_div = $(temp_row).find('.block-card:first');

					}

				} else {

					/* otherwise, just hop to the next div in the same row */
					temp_div = $(temp_div).next();

				}

				/* find the 'new' id and r values */
				temp_id = $(temp_div).find('img').data('id');
				temp_r = $(temp_row).data('r');

				/* if the ids are different, go ahead and switch the images */
				if(temp_id != id) {

					id = temp_id;
					r = temp_r;

					row = temp_row.clone();

					switchImages($(temp_div).find('img'));

					if(row_shift) { switchRow(); }

				}

				fading = false;
			}
		};

		function prevThumbnail() {

			if(gal_view && !fading) {

				fading = true;

				var row_shift = false;
				var stop = false;

				var temp_div = $('#gallery .row .block-card').filter(function() {
					return $(this).find('img').attr('data-id') == id;
				})

				var temp_row = $('#gallery .row').filter(function() {
					return $(this).attr('data-r') == r;
				})

				if($(temp_div).is(':first-child')) {

					if(r > min_r) {

						var row_shift = true;

						temp_row = $('#gallery .row').filter(function() {
							return $(this).attr('data-r') == r - 1;
						})

						temp_div = $(temp_row).find('.block-card:last');

					} else {
						stop = true;
					}

				} else {

					temp_div = $(temp_div).prev();

				}

				temp_id = $(temp_div).find('img').data('id');
				temp_r = $(temp_row).data('r');

				if(temp_id != id) {

					id = temp_id;
					r = temp_r;

					row = temp_row.clone();

					switchImages($(temp_div).find('img'));

					if(row_shift) { switchRow(); }

				}

				fading = false;
			}
		};


		/* helper function that switches the images in #smallimages with the current value of row */
		function switchRow() {

			/* remove any images currently in #smallImages, then insert our cloned row's images */
			$('#smallImages div').remove().fadeOut('slow', function() {
				$(row).children().insertAfter('#left_arrow');
			});

			/* enable the arrow buttons */
			$('#left_arrow').prop('disabled', false);
			$('#right_arrow').prop('disabled', false);

			/* if necessary (i.e. if r is on a min/max boundary), disable the arrow buttons */
			if(r == min_r) {
				$('#left_arrow').prop('disabled', true);
			}
			if(r == max_r) {
				$('#right_arrow').prop('disabled', true);
			}

		}

		/* helper function that switches hid and vis, assuming their paths have already been updated */
		function switchImages(image) {

			/* #largeImage contains two img objects: a visible one and a hidden one */
			/* vis is the img currently visible in gallery mode */
			/* hid will be set to the new img and faded in after vis is faded out */
			/* assign these variables by checking which img has attribute display:none; */
			var hid = $('#largeImage img').filter(function() {
				return $(this).css("display") == "none";
			});
			var vis = $('#largeImage img').filter(function() {
				return $(this).css("display") != "none";
			});

			/* we have to use a path to access the image in Filemanager, so build it
			* using the new id */
			var path = "<cfoutput>#application.appPath#/tools/filemanager/get_file.cfm?fileId="
			path += id;
			path += "</cfoutput>";

			var update = 1;

			/* make extra sure that everything is updated BEFORE we start fading */
			/* this doesn't seem to avoid it completely, but it prevents a good chunk of transition glitches */
			while(update != 0) {
				updateInfo(image, id);
				/* set hid's src to the newly built path - this changes the image */
				$(hid).attr('src', path);
				var update = 0;
			}

			/* fade out vis, THEN fade in hid */
			/* trying to do this simultaneously looks funny */
			$(vis).fadeOut('slow', function() {
				$(hid).fadeIn('slow');
			});

		}

		/* helper function that updates the image box in gallery view */
		function updateInfo(image, id) {

			/* fetch the data fields from the img */
			var name = $(image).data('name');
			var date = $(image).data('date');
			var contest_name = $(image).data('contest_name');
			var runner_up = $(image).data('runner_up');
			var rejected_by = 'Rejected by: ';
			rejected_by += $(image).data('rejected_by');
			rejected_by += '</br>';

			/* build and set the new paths for reject / vote / reinstate links */
			var removePath = "<cfoutput>#application.appPath#/tools/photoshop-contest/#attributes.gallery_url#?userView=1&action=remove&fileId="
			removePath += id;
			removePath += "</cfoutput>";
			var rejectPath = "<cfoutput>#application.appPath#/tools/photoshop-contest/#attributes.gallery_url#?action=reject&fileId="
			rejectPath += id;
			rejectPath += "</cfoutput>";
			var votePath = "<cfoutput>#application.appPath#/tools/photoshop-contest/#attributes.gallery_url#?action=vote&fileId=";
			votePath += id;
			votePath += "</cfoutput>";
			var reinstatePath = "<cfoutput>#application.appPath#/tools/photoshop-contest/rejected-entries.cfm?action=reinstate&fileId=";
			reinstatePath += id;
			reinstatePath += "</cfoutput>";
			var removeSourcePath = "<cfoutput>#application.appPath#/tools/photoshop-contest/source-images.cfm?action=remove&fileId="
			removeSourcePath += id;
			removeSourcePath += "</cfoutput>";

			$('#reject').attr('href', rejectPath);
			$('#vote').attr('href', votePath);
			$('#reinstate').attr('href', reinstatePath);
			$('#remove').attr('href', removePath);
			$('#remove-source').attr('href', removeSourcePath);

			/* build the new content for the info box */
			var content = name;
			content += '<br/>';
			content += date;
			content += '<br/>';

			var winner_content = contest_name;
			if(runner_up) {
				winner_content += ' Runner-up<br/>';
			} else {
				winner_content += ' Winner<br/>';
			}
			winner_content += content;

			/* using the name and date stored in the img, build, draw, and fade in the image information
			 * box and management links */
			$('#info').fadeOut('slow', function() {
				$('#info-content').html(content);
				$('#winner-content').html(winner_content);
				$('#rejected-by').html(rejected_by);
				$('#info').fadeIn('slow');
			});

		}

		/* switch to gallery view (if necessary) and set that image as the large image */
		function selectThumbnail() {

			/* only continue if the clicked image is not the current enlarged image*/
			if($(this).data('id') != id) {

				/* #largeImage contains two img objects: a visible one and a hidden one */
				/* vis is the img currently visible in gallery mode */
				/* hid will be set to the new img and faded in after vis is faded out */
				/* assign these variables by checking which img has attribute display:none; */
				var hid = $('#largeImage img').filter(function() {
					return $(this).css("display") == "none";
				});
				var vis = $('#largeImage img').filter(function() {
					return $(this).css("display") != "none";
				});

				/* if fading is true for any reason, do nothing */
				/* this means something else is trying to fade */
				if(!fading) {

					/* set id to the clicked img id */
					id = $(this).data('id');

					/* we have to use a path to access the image in Filemanager, so build it
					* using the new id */
					var path = "<cfoutput>#application.appPath#/tools/filemanager/get_file.cfm?fileId="
					path += id;
					path += "</cfoutput>";

					updateInfo(this, id);

					/* if we are already in gallery view, simply switch the images */
					if(gal_view == 1) {

						/* set hid's src to the newly built path - this changes the image */
						$(hid).attr('src', path);

						/* fade out vis, THEN fade in hid */
						/* trying to do this simultaneously looks funny */
						$(vis).fadeOut('slow', function() {
							$(hid).fadeIn('slow');
						});

					/* if we are in grid view, switch to gallery view with the proper image */
					} else {

						/* we don't have to worry about fading out vis, so directly set the new path */
						$(vis).attr('src', path);

						/* clone the .row containing the clicked image (we need to preserve the existing one) */
						row = $(this).parent().parent('.row').clone();

						/* if r does not match the data-r value of the row we just cloned,
						* we need to change the images in #smallImages */
						if(r != $(row).data('r')) {

							/* remove the images currently in smallImages div, and replace them with
							* the images of the current row */
							$('#smallImages div').remove();
							$(row).children().insertAfter('#left_arrow');
							/* finally, set r to the current row's data-r */
							r = $(row).data('r');

						}

						/* enable the arrows buttons by default */
						$('#left_arrow').prop('disabled', false);
						$('#right_arrow').prop('disabled', false);

						/* if r hits either of the row value bounds, disable the corresponding arrow button */
						if(r == min_r) {
							$('#left_arrow').prop('disabled', true);
						}
						if(r == max_r) {
							$('#right_arrow').prop('disabled', true);
						}

						/* fade out all of the grid view rows, THEN fade in the gallery view components */
						/* once again, avoids funny-looking transitions */
						$('#gallery div.row').each(function() {
							$(this).fadeOut('slow', function() {
								$('#largeImage').fadeIn('slow');
								$('#smallImages').fadeIn('slow');
							});
						});

						/* since the user may be scrolled anywhere on the page in grid view, scroll back to
						* the top when entering gallery view */
						$('html, body').animate({
			        		scrollTop: 0
			   			}, 1000);

						/* we are in gallery view */
						gal_view = 1;

					}

					/* done fading */
					fading = false;

				}
			}

		};

		/* switch back to grid view */
		function closeGalleryView() {

			/* if we are currently fading, do nothing */
			if(!fading)	{

				/* start fading */
				fading = true;

				/* search for the row corresponding to the one in #smallImages */
				var row = $('#gallery .row').filter(function() {
					return $(this).attr('data-r') == r;
				});

				/* fade out #largeImage and #smallImages, then fade in all .row .thumbs */
				$('#largeImage').fadeOut('slow');
				$('#smallImages').fadeOut('slow', function() {
					$('#smallImages div').remove();
					$('#gallery div.row').each(function() {
						$(this).fadeIn('slow');
					});
					/* scroll to the current row (#smallImages) in grid view */
					if(r > 2) {
						$('html, body').animate({
			        		scrollTop: $(row).offset().top
			    		}, 1000);
					}
				});

				/* set r to zero, and we are no longer in gallery view */
				id = 0;
				r = 0;
				gal_view = 0;

				/* done fading */
				fading = false;

			}

		};

		/* go to the previous / next row */
		function changeRow() {

			/* if currently fading, do nothing */
			if(!fading) {

				/* start fading */
				fading = true;

				/* figure out which button was pressed; choose the new r value accordingly */
				if ($(this).attr('id') == 'left_arrow') {
					r = r - 1;
				} else if ($(this).attr('id') == 'right_arrow') {
					r = r + 1;
				}

				/* find the .row corresponding to our new r, and clone it */
				var row = $('#gallery .row').filter(function() {
					return $(this).attr('data-r') == r;
				}).clone();

				/* remove any images currently in #smallImages, then insert our cloned row's images */
				$('#smallImages div').remove().fadeOut('slow', function() {
					$(row).children().insertAfter('#left_arrow');
				});

				/* enable the arrow buttons */
				$('#left_arrow').prop('disabled', false);
				$('#right_arrow').prop('disabled', false);

				/* if necessary (i.e. if r is on a min/max boundary), disable the arrow buttons */
				if(r == min_r) {
					$('#left_arrow').prop('disabled', true);
				}
				if(r == max_r) {
					$('#right_arrow').prop('disabled', true);
				}

				/* done fading */
				fading = false;
			}

		};

	});

</script>


<!--- html --->
<div id="gallery">

	<cfset r = 1> <!--- marks current row index --->
	<cfset i = 1> <!--- counts to 4 (the number of images per row) --->
	<cfset d = 0> <!--- boolean toggle indicating whether we are in an open div tag or not --->

	<!--- grid view - shown by default --->
	<cfoutput>

		<cfif getImages.recordCount EQ 0>
			There are no images in this gallery.
		</cfif>

		<!--- loop through the images found above to draw the rows --->
		<cfloop query="getImages">

			<cfquery datasource="#application.applicationDataSource#" name="getImage">
				SELECT u.first_name, u.last_name, u.username, pe.entry_date, pe.rejected, pe.rejected_by
				FROM tbl_psc_entries pe
				INNER JOIN tbl_users u ON u.user_id = pe.user_id
				WHERE pe.file_id = <cfqueryparam cfsqltype="cf_sql_integer" value="#file_id#">
			</cfquery>

			<!--- if we are not in a div tag, open one with data-r value r --->
			<cfif NOT d><div class="thumbs row" data-r="#r#"><cfset d = 1></cfif>

			<!--- draw the thumbnail image inside a block-card div, using the file_id to find the path --->
			<div class="block-card">
				<img src="#application.appPath#/tools/filemanager/get_thumbnail.cfm?fileId=#getImages.file_id#"
					 data-id="#getImages.file_id#"
					 data-name="#getImage.first_name# #getImage.last_name# (#getImage.username#)"
					 data-date="#dateTimeFormat(getImage.entry_date, 'mmmm dd yyyy hh:nn tt')#"
					 <cfif attributes.psc_winners>
					 	data-contest_name="#getImages.contest_name#"
					 	data-runner_up="#getImages.runner_up#"
					 <cfelse>
					 	data-contest_name=""
					 	data-runner_up="0"
					 </cfif>
					 <cfif getImage.recordCount GT 0>
						 <cfif attributes.psc AND getImage.rejected>
						 	data-rejected_by="#getImage.rejected_by#"
						 <cfelse>
						 	data-rejected_by=""
						 </cfif>
					</cfif>
					 />
			</div>

			<!--- if i has reached four, close the div and reset the count; otherwise increment i --->
			<cfif i GTE 4></div>
				<cfset r = r + 1><cfset d = 0><cfset i = 1>
			<cfelse>
				<cfset i = i + 1>
			</cfif>

		</cfloop>
	</cfoutput>

	<!--- if a div tag is still open, close it --->
	<cfif d></div></cfif>

	<!--- gallery view - hidden by default --->
	<!--- draw the skeletons for #largeImage and #smallImages - no need to populate them yet --->
	<cfoutput>
		<div id="largeImage" class="block-card" style="display:none;">

			<!--- the info box is only needed in gallery and rejected-entries --->
			<cfif attributes.psc>
				<div id="info">

					<fieldset>
						<legend>Image Info</legend>

						<cfif attributes.psc_source>

							<cfif attributes.psc_source and hasMasks('cs')>
								[<a id="remove-source" href="" onClick="return(confirm('Are you sure you wish to remove this source image?'))">Remove</a>]
							</cfif>

						<cfelseif attributes.psc_winners>

							<!--- only populated by information --->
							<div id="winner-content"></div>

						<cfelse>

							<!--- info-content will be populated with the user name and submission date --->
							<div id="info-content"></div>

							<cfif attributes.psc_userView and attributes.psc_entries>
								[<a id="remove" href="" onClick="return(confirm('Are you sure you wish to remove this entry?'))">Remove</a>]
							</cfif>

							<!--- admins get reject / reinstate privileges --->
							<cfif hasMasks('admin')>
								<cfif not attributes.psc_rejected>
									[<a id="reject" href="" onClick="return(confirm('Are you sure you wish to reject this image?'))">Reject</a>]
								<cfelse>
									<!--- this span will be populated with the username of the rejecting admin --->
									<span id="rejected-by"></span>
									[<a id="reinstate" href="" onClick="return(confirm('Are you sure you wish to reinstate this image?'))">Reinstate</a>]
								</cfif>
							</cfif>

							<!--- cs can vote on images --->
							<cfif hasMasks('consultant') AND attributes.psc_voting AND not attributes.psc_rejected>
								[<a id="vote" href="" onClick="return(confirm('Are you sure you wish to vote for this image?'))">Vote</a>]
							</cfif>

						</cfif>

					</fieldset>

				</div>

			</cfif>

			<!--- the close x --->
			<span id="closeBtn" class="btn btn-default btn-xs pull-right"><span class="glyphicon glyphicon-remove"></span></span>

			<a href="##" class="prevLink" style="font-size: 3em;">&larr;</a>
			<!--- two img objects which will be used to fade images in and out --->
			<img src="" data-fading="false"></img>
			<img style="display:none;" data-fading="false"></img>
			<a href="##" class="nextLink" style="font-size: 3em;">&rarr;</a>
		</div>
	</cfoutput>

	<div class="thumbs" id="smallImages" style="display:none;">
		<button id="left_arrow"><</button>
		<!--- this area will be populated with images as needed by our jQuery --->
		<button id="right_arrow">></button>
	</div>

</div>