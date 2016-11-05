#!/usr/bin/perl -w
# use strict;
$ENV{"PATH"}="/usr/bin:/usr/pkg/bin:/bin";
# use File::Temp qw/tempfile/; 
# use XMLRPC::Lite;
# use  CGI::Util; 

# Check and start popfile
$sdir=$0;
$sdir =~ s|/[^/]*$||;
$sdir="/var/db/pdf";
$sdir=$ARGV[0];
die "Where is $sdir" unless -d $sdir;
$ENV{"POPFILE_ROOT"}="$sdir/popfile";
$ENV{"POPFILE_USER"}="$sdir/popuser";
system('cd  $POPFILE_USER ; test -f popfile.pid && kill -0 `cat popfile.pid ` || (  perl -I$POPFILE_ROOT  $POPFILE_ROOT/popfile.pl & sleep 2)');
 
