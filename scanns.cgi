#!/usr/pkg/bin/perl
##
##  printenv -- demo CGI program which just prints its environment
##

print "Content-type: text/html; charset=iso-8859-1\n\n";
$ENV{"PATH"}.= ":/usr/pkg/bin";
print "<html><body><h>Collecting data from scanner</h><pre>\n";

system("id; pwd");
system("cd ../search/scanner; ./sync_scanner.sh " );
print "Creating thumbnails\n";
system("perl index_files.pl 2>&1" );
print "</pre>\n";
print "<h>Redirecting to index page</h>";


print  '<script type="text/javascript"> window.location.href = "index.html" </script>';
print "<a href=index.html> Refreshed page</a>";
print "</body></html>\n";
