<!---since this is a module we may need to bring in our common functions.--->
<cfif not isDefined("getAllCategoriesQuery")>
	<cfinclude template="#application.appPath#/common-functions.cfm">
</cfif>
<cfparam name="attributes.url" type="url">
<cfparam name="attributes.title" type="string" default="RSS Feed">

<!---create a unique name for our container, so if we use more than one feed we don't clobber it.--->
<cfset rssId = "rss" & createUUID()>


<cfoutput>
	<div class="panel-heading red-heading">#attributes.title#</div>
	<div id="#rssId#" class="panel-body">
		<div id="#rssId#Text" class="content" class="rss_item" style='margin-top:5px;'>Loading...</div>
	</div>
</cfoutput>

<script type="text/javascript">
	window.setInterval('loadITNotices()', 300000);

	function loadITNotices() {
		$.get(<cfoutput>'#attributes.url#'</cfoutput>, function(data) {
			$('#<cfoutput>#rssId#Text</cfoutput>').html('<a href="http://status.uits.iu.edu/" target="_blank">Status.IU</a>');
		    var xml = $(data);
		    xml.find("item").each(function() {
		        var $this = $(this),
		            item = {
		            	title: $this.find("title").text(),
		            	link: $this.find("link").text(),
		                lastUpdated: $this.find("lastUpdated").text(),
		                noticeOpen: $this.find("noticeOpen").text(),
		                noticeClose: $this.find("noticeClose").text()
		        }
		        item.lastUpdated = item.lastUpdated.substring(4,item.lastUpdated.length -4)
		        item.noticeOpen = item.noticeOpen.substring(4,item.noticeOpen.length -4)
		        item.noticeClose = item.noticeClose.substring(4,item.noticeClose.length -4)
		        $('#<cfoutput>#rssId#Text</cfoutput>').append("<hr/><a href='"+item.link+"' target='_blank'>"+item.title + "</a><br/>Starts: "+ item.noticeOpen + "<br/>Ends: " + item.noticeClose + "<br/>Updated: " + item.lastUpdated);
		    });
		});
	}
	loadITNotices();
</script>
