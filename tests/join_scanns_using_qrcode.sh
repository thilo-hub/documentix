#!/bin/sh
ls -t /home/thilo/documentix/Documents/incomming/Scanner/*.pdf |  
# tail -12 |
perl  -w -e '
# 
# itterate all docs
# check pdf first and last page
# if previous doc then
#    if previous.last & current.first then  
# 	join  previous: front current back
# 	unset previous
#    else if previous.first and current.last then
#         join current: front previous: back
# 	unset previous
#    else
# 	previous = next
#    end
# end loop
# 
# 
use File::Temp qw/tempfile tmpnam tempdir/;

my $QR_TAG = "QR-Code:\\s*(Front|Back)\\s+Page";
my $ext = "_combined.pdf";


sub g_tmp
{
   my $tmpdir = File::Temp->newdir("/var/tmp/joining__XXXXXX");
   return $tmpdir;
}

    my $prev;
    while(<>) {
        
	chomp;
	my $cur;
	last if /$ext$/; # Older files are already scanned
	foreach( qx{pdfinfo  "$_"} ) {
		last if (/Pages:\s*(\d+)/ && ($l=$1));
	} 
	# print "$l : $_\n";
	next  if $l < 2;
	my $tmp = File::Temp->new( SUFFIX => ".png" );
	my $p1 = qx{  pdftocairo "$_" -singlefile -mono -png -f 1  - >"$tmp" && zbarimg "$tmp" 2>/dev/null};
	my $pl = qx{  pdftocairo "$_" -singlefile -mono -png -f $l - >"$tmp" && zbarimg "$tmp" 2>/dev/null};
	$p1 =~ s/\s+/ /g;
	$pl =~ s/\s+/ /g;

	$cur->{file} = $_;
	$cur->{pages} = $l;
	($cur->{part} , $cur->{qr_page})  = ( $p1 =~ /$QR_TAG/s ) ? ($1,1)  : 
					    ( $pl =~ /$QR_TAG/s ) ? ($1,$l)  : ("","");

	print "$_ ($cur->{pages}):  $cur->{qr_page} : $cur->{part}\n";
	sub mkout {
	    my $in = shift;
	    #  $in =~ s|^.*/|./|;
	    $in =~ s/\.pdf$/$ext/i;
	    return $in;
	}
		
	my $p = $prev;
	$prev = $cur;
	if ( $p && $p->{pages} == $cur->{pages} ) {
print STDERR "Start combine...\n";
	    my $out = mkout($p->{file});
	    if ($p->{part}  eq "Front" && $cur->{part} eq "Back") {
			join_pdf($p->{file},$cur->{file},$out,$p->{qr_page},$cur->{qr_page});
			$prev = undef;
	    } elsif ($cur->{part}  eq "Front" && $p->{part} eq "Back") {
			join_pdf($cur->{file},$p->{file},$out,$cur->{qr_page},$p->{qr_page});
			$prev = undef;
	   }
	}
    }

sub join_pdf
{
    my ($front,$back,$out,$strip_front,$strip_back)=@_;
    print "Join $front $back -> $out\n";
    warn "Output $out already exists" if -f $out;
    print "Output: $out\n";
    return  if -f $out;

    my $tmp = g_tmp();
    system("pdfseparate  $back  $tmp/page-%03d.pdf");
    my @l=sort {$b cmp $a}  glob("$tmp/page*.pdf");  # reverse order
    my $p="001"; 
    foreach(@l){ 
	$s=$_; 
	s/-\d+/-$p-b/; 
	$p++; 
	rename( $s,$_); 
    }
    system("pdfseparate  $front  $tmp/page-%03d-a.pdf");
    my @o=sort {$a cmp $b}  glob("$tmp/page*.pdf"); 
    print STDERR "Joining ".(scalar(@o)-scalar(@l))." front pages and ".scalar(@l)." back pages to $out\n";
    splice(@o,($strip_front-1)*2,2);
    system("pdfunite",@o,$out);
    unlink @o or die "failed remove @o";
    chmod 0,$front,$back;
}
' 

