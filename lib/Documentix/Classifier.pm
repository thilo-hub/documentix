package Documentix::Classifier;

use Exporter 'import';
our @EXPORT = qw(pdf_class_file pdf_class_md5);

use XMLRPC::Lite;
use File::Temp qw{tempfile };
use Documentix::db qw{dh};

# Special handled classes
my $unclass="unclassified";
my $empyt="empty";
my $deleted="deleted";
my $processing="processing";
my $failed="failed";
my $sk;

my $pop_xml="http://localhost:".$Documentix::config->{popfile_xmlrpc_port}."/RPC2";

my $pop_cnt = 0;


sub pdf_class_md5 {
    my $md5   = shift;
    my $class = shift;    # undef returns class else set class
    my $gt_info = dh->prepare_cached( q{ select file,substr(value,1,10000) txt from hash natural join file natural join metadata where md5=? and tag="Text"});

    my $r = dh->selectrow_hashref( $gt_info, undef, $md5 );
    return pdf_class_file( $r->{"file"}, \$r->{"txt"}, $md5, $class );

}

sub connect_pop
{
	return $sk if $sk;
        $sk = XMLRPC::Lite->proxy($pop_xml)
          ->call( 'POPFile/API.get_session_key', 'admin', '' )->result;
        print STDERR "POP Session: $sk\n";
	return $sk;
}
sub pop_call {
	my $op   = shift;
	my $sk   = connect_pop();
	my $r =
	  XMLRPC::Lite->proxy($pop_xml)->call( "POPFile/API.$op", $sk, @_ );
	return $r->result;
}

sub pop_session {
        my $self = shift;
	connect_pop();

     # ensure that at least a single bucket other than unclassified is available
        my $bucket_list = $self->pop_call('get_buckets');
        $self->pop_call( 'create_bucket', 'default' )
          unless ( scalar(@$bucket_list) );
        return $sk;
}

sub to_bucketname {
        my $bn = lc(shift);
        $bn =~ s/[^a-z0-9\-_]/_/g;
	return undef if $bn eq $deleted || $bn eq $failed;
        return $bn;
}

sub pop_release {
        return;

        # return if $pop_cnt>0;
        # $pop_cnt--;
        # XMLRPC::Lite->proxy($pop_xml)
        #   ->call( 'POPfile/API.release_session_key', $popsession )
        #   if $popsession;
        # undef $popsession;
}

sub get_popfile_r {
    my ( $fn, $md5, $rtxt ) = @_;

    # and a temporary file, with the full path specified
    my ( $fh, $tmp_doc ) = tempfile(
        'popfileinXXXXXXX',
        SUFFIX => ".msg",
        UNLINK => 1,
        DIR    => $temp_dir
    );
    binmode( $fh, ":utf8" );

    my $f = $fn;
    $f =~ s/^.*\///;
    print $fh "Subject:  $f\n";
    print $fh "From:  Docusys\n";
    print $fh "To:  Filesystem\n";
    print $fh "File:  $fn\n";
    print $fh "Message-ID: $md5\n";
    print $fh "\n";

    my $tx = substr( $$rtxt, 0, 100000 );
    $tx =~ s/[^a-zA-Z_0-9]+/ /g;
    $tx =~ s/(([a-zA-Z_0-9]+\s){20})/$1\n/g;
    print $fh $tx;

    print "T:$md5, $tx" if ( $debug > 2 );
    close($fh);
    system("cp $tmp_doc /tmp/new.txt");
    return $tmp_doc;
}

sub pdf_class_file {
    my $fn    = shift;    #optional file-name
    my $rtxt  = shift;    # text to classify
    my $md5   = shift;
    my $class = shift;    # undef returns class else set class a '-' as the first char removes the class

    my $rv;
    my $ln;

    print STDERR "Add tag: $class\n" if $debug > 0;
    if ( $class =~ m|/| ) {
        # allow multiple tags at once
	my $r="";
	foreach( split(m|/|,$class)) {
		($ln,$rv)=pdf_class_file($fn,$rtxt,$md5,$1.$_);
		$r.=$rv;
	}
	return ($ln,$r);
    }

    my $tmp_doc = get_popfile_r( $fn, $md5, $rtxt );
    my $op      = "handle_message";
    my $dbop    = "insert or ignore into tags (idx,tagid)
		       select idx,tagid from hash,tagname where md5=? and tagname =?";
    my $dh = dh();
    my $db_op = $dh->prepare_cached( $dbop );
    # dont try to classify too small documents
    my $toosmall= length($$rtxt) < 100 ;
    $class = $empty if ( !$class && $toosmall);

    if ( $class && $class =~ s/^-// ) {
	# remove tags and message from bucket
        my $dbop =
          "delete from tags where idx=(select idx from hash where md5=?) and
				 tagid = (select tagid from tagname where tagname = ?)";
        $db_op = $dh->prepare_cached( $dbop );
	
	my $b = to_bucketname($class);
	$b = undef if $toosmall;
	$rv = pop_call( "remove_message_from_bucket", $b, $tmp_doc ) if $b;

	$dh->do( qq{
		update metadata set value=trim(replace('/'||value||'/','/'||?2||'/','/'),'/') where idx=(select idx from hash where md5=?1)
		},undef,($md5,$class));
    }
    elsif ($class) {
        # Set&create  specific class and add tag
	my $b = to_bucketname($class);
	$b = undef if $toosmall;

        my $dbop = "insert or ignore into tagname (tagname) values(?)";
	$rv = pop_call( "create_bucket", $b ) if $b;
	$rv = pop_call( "add_message_to_bucket", $b, $tmp_doc ) if $b;
	$dh->prepare_cached( $dbop )->execute($class);
	$rv = $class if $rv;
	$dh->do( qq{
		update metadata set value=trim(trim(replace('/'||value||'/','/'||?2||'/','/'),'/'),'/')||'/'||?2  where idx=(select idx from hash where md5=?1)
		},undef,($md5,$class));

    }
    else {
        # ask for class
        my ( $fh_out, $tmp_out ) = tempfile(
            'popfileinXXXXXXX',
            SUFFIX => ".out",
            UNLINK => 1,
            DIR    => $temp_dir
        );
        $rv = pop_call( 'handle_message', $tmp_doc, $tmp_out );
        $class = $rv || $unclassified;
	# die "Ups: $class" unless $class;
        while (<$fh_out>) {
            ( $ln = $1, last ) if m/X-POPFile-Link:\s*(.*?)\s*$/;
        }

        print STDERR "$r\nLink: $ln\n" if $debug > 1;
        close($rh_out);
        unlink($tmp_out);

        my $dbop = "insert or ignore into tagname (tagname) values(?)";
	$dh->prepare_cached( $dbop )->execute($class);

    }
    close($fh_out);
    $db_op->execute( $md5, $class );
    unlink($tmp_doc);
    printf STDERR "Class: $rv\n" if $debug > 1;

    return ( $ln, $rv );
}

################# popfile interfaces
# classify unclassified

# get all unclassified files (not manually assigned) and ask popfile for classification
sub class_unk {
    my $self = shift;
    my $all_t =
q{select idx,md5,file,substr(value,1,10000) txt    from metadata natural join hash natural join file where tag="Text" and idx not in (select idx from tags) group by md5};

    my $all_s = dh->prepare_cached($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        $rv = pdf_class_file( $r->{"file"}, \$r->{"txt"}, $r->{"md5"},
            undef );
        $l = length( $r->{"txt"} );
        print STDERR "Tx: $r->{idx} $r->{md5} ($l)  -> $rv\n" if $debug > 1;
    }

}

sub get_class {
    my $self = shift;
    my $all_t =
q{select idx,count(*) cnt, group_concat(tagname) lst,value    from tags natural join tagname natural join metadata where tag="Text"  group by idx  order by idx };

    my $all_s = dh->prepare_cached($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        my ( $fh, $tmp_doc ) = tempfile(
            'popfileinXXXXXXX',
            SUFFIX => ".msg",
            UNLINK => 1,
            DIR    => $temp_dir
        );
        print $fh $r->{"value"};
        close($fh);
        my $rv = pop_call( 'classify', $tmp_doc );
        unlink $tmp_doc;
        next if ( $r->{lst} eq $rv );

        print STDERR "Tx: $r->{idx} $r->{lst}   -> $rv\n" if $debug > 1;
    }
}

sub set_classes {
    my $self = shift;
    my $all_t =
q{select tagname,group_concat(substr(value,1,10000)) txt  from tagname natural join tags natural join metadata where tag="Text"  group by tagname};

    # delete all buckets first ....
    my $rv = pop_call('get_buckets');
    print STDERR "cln: $tg -> $rv\n" if $debug > 1;

    foreach (@$rv) {
        $rv = pop_call( 'delete_bucket', $_ );
        print STDERR "Del: $_ ->$rv\n" if $debug > 1;
    }
    my $all_s = dh->prepare_cached($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        my @res =
          set_class_content( lc( $r->{"tagname"} ), \$r->{"txt"} );
    }
}

sub set_class_content {
    my ( $tg, $rtxt ) = @_;
    $b = to_bucketname($tg);
    $rv = pop_call( 'create_bucket', $b ) if $b;
    print STDERR "TG: $tg -> $rv\n" if $debug > 1;
    my ( $fh, $tmp_doc ) = tempfile(
        'popfileinXXXXXXX',
        SUFFIX => ".msg",
        UNLINK => 1,
        DIR    => $temp_dir
    );
    print $fh $$rtxt;
    close($fh);
    print STDERR " Add: $tg ($ln) -> " if $debug > 1;
    $rv =
      pop_call( 'add_message_to_bucket', $b, $tmp_doc ) if $b;
    my $ln = length($$rtxt);
    print STDERR "$rv\n" if $debug > 1;
    unlink($tmp_doc);
}

1;
