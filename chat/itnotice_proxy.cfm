<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">

<!---Modern browsers are super fussy about cross site domain issues.  This let's us fetch the latest IT notices.--->

<cfhttp result="noticeBody" url="https://iu-status-prod.azurewebsites.net/rss"><!---notice this isn't status.uits.iu.edu since it's a CNAME and doesn't match the name on the SSL Cert.--->

<cfset binaryFile = toBinary(toBase64(noticeBody.Filecontent))>

<cfcontent variable="#binaryFile#" type="text/xml" reset="true">