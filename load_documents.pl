#!/usr/bin/perl
use doclib::pdfidx;
use Data::Dumper;

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }
sub get_store {
    my $digest=shift;
    my $md = shift || 0;
    my $wdir = $Docconf::config->{local_storage};
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    $digest =~ m/^(..)/;
    $wdir .= "/$1";
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    
    $wdir .= "/$digest";
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    return $wdir;
}


# my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;
# ARGS:  file-name  working-directory
# Result:
foreach (@ARGV) {
    my $txt = $pdfidx->index_pdf( $_, "/tmp" );
    my $c = substr( $txt->{"Content"}, 0, 150 );
    $c =~ s/[\r\n]+/\n     #/g;
    print "R: $txt->{Docname} : $txt->{Mime} : $c ...\n";
}

