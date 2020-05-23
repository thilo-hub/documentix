use Data::Dumper;
my $f = {};
my @a = <>;
$f->{data} = \@a;
$f->{pid}  = ();
print "Scalar: " . scalar( @{ $f->{data} } ) . "\n";

sub spl {
    unshift @{ $f->{pid} }, fork() ? "X" : "-";;
    $h = scalar( @{ $f->{data} } );
    @{ $f->{data} } =
      splice( @{ $f->{data} }, ${ $f->{pid} }[0] ? 0 : $h / 2, $h / 2 );
}
spl();
spl();
spl();
# spl();
# spl();

my $tstart=time();
my $t0=time();

print "F: "
  . join( ":", @{ $f->{pid} } )
  . "    \t"
  . scalar( @{ $f->{data} } ) . "\n";

$j = $f->{data};
$ctr=0;
my $s=0;
my @jq=();
foreach (@$j) {
    chomp;
    next unless /^[0-9a-f]*$/;
    #$job=qq{http://localhost:8080/docs/raw/$_/x.ico };


    #$job=qq{http://localhost:9900/docs/raw/$_/x.ico };
    #$job=qq{http://localhost:8080/docs/ico/$_/x.ico };
    $job=qq{http://localhost:9900/docs/ico/$_/x.ico };
    #$job=qq{ls -l};
    push @jq, $job;
    next unless scalar(@jq)>8;
    $job = "curl -s ".join(" ",@jq);
    @jq=();
#print STDERR ">>\n$job\n<<";
    open(Q,"-|",$job);  while(<Q>){ $s+=length($_); } close(Q);
    #system(qq{curl -s http://localhost:9900/docs/raw/$_/x.ico |wc >>y});
    #system(qq{curl -s http://localhost:9900/docs/ico/$_/x.ico |wc >>y});
    #system(qq{curl -s http://localhost:8080/docs/ico/$_/x.ico |wc >>y});
    #system(qq{curl -s http://localhost:8080/docs/raw/$_/x.ico |wc >>y});
    print STDERR ".";
    if ( time() > ($t0+10) ) {
	$t0=time();
        my $p= conv_size($s /($t0-$tstart)) ."/s ";
	$sctr += $ctr;
print STDERR "\nR: " . join( ":", @{ $f->{pid} } ) . "    \t $ctr $sctr $p";
	$ctr=0;
	}
    $ctr++;
}
	$sctr += $ctr;
	$t0=time();
        my $p= conv_size($s /(0.0001+$t0-$tstart)) ."/s ";
print STDERR "\nEND: " . join( ":", @{ $f->{pid} } ) . "    \t $ctr $sctr Total:$p\n";
while (wait () != -1 ) {}
 ;
sub conv_size
{  

    my $s=shift;
    return sprintf("%.1f Gb",$s/2**30) if $s > 2**30;
    return sprintf("%.1f Mb",$s/2**20) if $s > 2**20;
    return sprintf("%.1f kb",$s/2**10);
}

