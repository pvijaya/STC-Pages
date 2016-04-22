<cfcontent type="text/javascript; charset=ISO-8859-1">
<cfsetting showdebugoutput="false">
<cfsetting enablecfoutputonly="true">
<!---We can use the hasMasks() function to pick who gets to use which buttons--->
<cfoutput>
/**
 * @license Copyright (c) 2003-2013, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.html or http://ckeditor.com/license
 */

/* an array of css files used in Tetra */
var css = ['<cfoutput>#application.appPath#</cfoutput>/css/text.css',
	   '<cfoutput>#application.appPath#</cfoutput>/css/special.css',
       '<cfoutput>#application.appPath#</cfoutput>/css/standards.css']

CKEDITOR.editorConfig = function( config ) {
	// Define changes to default configuration here.
	// For the complete reference:
	// http://docs.ckeditor.com/##!/api/CKEDITOR.config
	// The toolbar groups arrangement, optimized for two toolbar rows.
	config.toolbarGroups = [
		{ name: 'clipboard',   groups: [ 'clipboard' ] },
		{ name: 'editing',     groups: [ 'find', 'selection' ] },
		{ name: 'align' },
		{ name: 'links' },
		{ name: 'insert' },
		{ name: 'forms' },
		{ name: 'tools' },
		{ name: 'document',	   groups: [ 'mode', 'document', 'doctools' ] },
		{ name: 'others' },
		'/',
		{ name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ] },
		{ name: 'paragraph',   groups: [ 'list', 'indent', 'blocks' ] },
		{ name: 'styles' },
		{ name: 'colors' },
		{ name: 'about' }
	];
	
	//From CKE 4.1 on they've turned on a content filter.  We could probably make good use of it, but it's too strict by default.
	config.allowedContent = true;
	
	// Remove some buttons, provided by the standard plugins, which we don't
	// need to have in the Standard(s) toolbar.
	config.removeButtons = 'Underline,Subscript,Superscript,Font,<cfif hasMasks('Admin') EQ false>Source</cfif>';
	
	config.shiftEnterMode = CKEDITOR.ENTER_BR;
	config.disableNativeSpellChecker = false;
	/*config.removePlugins='contextmenu,tabletools';the context menu hijacks right-clicks - this is bad.  the tabletools plugin also requires the context menu, so we had to remove it, as well.*/
	config.height = 400;
	//config.width = 800;
	
	/* text in the ckeditor window will be displayed as the css files above expect. */
    config.contentsCss = css;
 
	
};
</cfoutput>
<cfsetting enablecfoutputonly="false">