/*
 Copyright (c) 2003-2013, CKSource - Frederico Knabben. All rights reserved.
 For licensing, see LICENSE.html or http://ckeditor.com/license
*/

/*This script has been considerably modified for use at TCC*/

//build up an output string rather than trying to dump it all in one go.
CKEDITOR.dialog.output = "";

CKEDITOR.dialog.output += "";
CKEDITOR.dialog.output += '<style type="text/css">';
CKEDITOR.dialog.output += ".cke_about_container{color:#000 !important;padding:10px 10px 0;}";
CKEDITOR.dialog.output += ".cke_about_container p{margin: 0 0 10px;}";
CKEDITOR.dialog.output += '.cke_about_container .cke_about_logo{height:81px;background-color:#fff;background-image:url('+CKEDITOR.plugins.get("about").path+'dialogs/logo_ckeditor.png);background-position:center;background-repeat:no-repeat;margin-bottom:10px;}';
CKEDITOR.dialog.output += ".cke_about_container ul{padding-left: 2em;}";
CKEDITOR.dialog.output += "	.cke_about_container a{cursor:pointer !important;color:#00B2CE !important;text-decoration:underline !important;}";
CKEDITOR.dialog.output += "</style>";
CKEDITOR.dialog.output += '<div class="cke_about_container">';
CKEDITOR.dialog.output += '<div class="cke_about_logo"></div>';
CKEDITOR.dialog.output += '<p>	CKEditor '+ CKEDITOR.version + '(revision '+ CKEDITOR.revision +')</p>';
CKEDITOR.dialog.output += '<p>Check <a href="http://docs.ckeditor.com/user">CKEditor User\'s Guide</a> for help.</p>';
/*begin custom tips for TCC*/
CKEDITOR.dialog.output += '<strong>TCC Tips:</strong>';
CKEDITOR.dialog.output += '<ul>';
CKEDITOR.dialog.output += '<li>Use <em>Shift + Enter</em> to create a single line-break.';
CKEDITOR.dialog.output += '<li>To use your browser\'s native Context Menu(eg. for spell-checking) use <em>Ctrl + Right-click</em>.</li>';
CKEDITOR.dialog.output += '<li>Do not Drag & Drop text from MS Office, use copy and paste to prevent bringing in bad formatting information.</li>';
CKEDITOR.dialog.output += '<li>When uploading an image consider browsing the server first to see if a suitable image is already available.</li>';
CKEDITOR.dialog.output += '</ul>';
/*end custom tips for TCC*/
CKEDITOR.dialog.output += '<p><br/>For licensing information please visit our <a href="http://ckeditor.com/about/license">web site</a></p>';
CKEDITOR.dialog.output += '<p>Copyright © <a href="http://cksource.com/">CKSource</a> - Frederico Knabben. All rights reserved.</p>';
CKEDITOR.dialog.output += "</div>";
	
CKEDITOR.dialog.add(
		"about",
		function(a){
			a=a.lang.about;
			return{
				title:CKEDITOR.env.ie?a.dlgTitle:a.title,
				minWidth:390,
				minHeight:230,
				contents:[{
					id:"tab1",
					label:"",
					title:"",
					expand:!0,
					padding:0,
					elements:[{
						type:"html",
						html:CKEDITOR.dialog.output
					}]
				}],
				buttons:[CKEDITOR.dialog.cancelButton]
		}
	}
);