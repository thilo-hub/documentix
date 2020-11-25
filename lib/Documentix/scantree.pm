package Documentix::scantree;

use Cwd;
use Documentix::Magic qw{magic};
use File::Find qw{find};
use Data::Dumper;
use Documentix::dbaccess;;
use Mojo::File qw{curfile path };
use Mojo::Asset::File;
use Encode qw{encode decode};

use doclib::pdfidx;

my %mime_supported = (
    "application/zip" => 1,
    "application/x-gzip" => 1,
    "application/pdf"    => 1,
    "application/msword" => 1,
    "image/png"         => 1,
    "image/jpeg"         => 1,
    "image/jpg"         => 1,
    "text/plain"	     => 1,
"application/vnd.openxmlformats-officedocument.presentationml.presentation" => 1,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => 1,
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => 1,
    "application/epub+zip"          => 1,
    "application/vnd.ms-powerpoint" => 1
);

# Directory to scan is input
# all trees up to the root_dir are tags
sub scantree {
    my ($top) = @_;
    print STDERR ">>>>> $top\n";
    my $dir = getcwd;

    my $pdfidx  = pdfidx->new(0,$Documentix::config);
    my $dba = dbaccess->new();
    my $check = $pdfidx->{dh}->prepare_cached(q{select md5,file from file where file not like ? and file like ?});

    # make sure its all absolute
    $top = Mojo::File->new($top)->to_abs;;

    # Ignore the local storage
    my $skip= Mojo::File->new($Documentix::config->{local_storage})->to_abs;
    my $md5 = Digest::MD5->new;

    my $ignore={};
    my $update_file = sub
    {
	print STDERR "File changed @_\n";
    };
    my $remove_file = sub
    {
	print STDERR "File removed @_\n";
    };
    my $add_file = sub
    {
	my $f = decode("UTF-8",shift);
	    my $type = magic($f);
	    print STDERR "File added $f ->  >$type<\n";
	    if ( $mime_supported{$type}) {
		# Turn back into relative to root-dir file
		$f =~ s|^$dir/*|$Documentix::config{root_dir}|;
		$dba->load_asset("??APP??",undef,$f);
		return;
	    }
	    #die "Type: $type";
    };

    # Check local files in db
    
    $check->execute( $Documentix::config->{local_storage}."%",$Documentix::config->{root_dir}."%" );
    while ( my $r = $check->fetchrow_hashref) 
    {
	print STDERR Dumper ($r);
	$r->{file}=Mojo::File->new($r->{file})->to_abs ;
	$remove_file->($r) unless -r $r->{file};
	my $asset = Mojo::Asset::File->new(path => $r->{file});
	my $dgst = $md5->add($asset->slurp)->hexdigest;
	$update_file->($r) unless $r->{md5} eq $dgst;

	$ignore->{ $r->{file}}++;
    }
    # check filesystem

print STDERR "PWD: $dir\n";
    my @flist=();
    find( { wanted => sub {
	    return unless -f $_;

	    my $f = $File::Find::name;
	    return if $ignore->{$f};
	    return if $f =~ /^$skip/;
	

	    push @flist,$f;
	    }
	  }, $top);
    chdir($dir);

    # process the files
    foreach( @flist ) {
	    $add_file->($_);
    }



}



