package tags;

use strict;
use warnings;
use Data::Dumper;
use Cwd 'abs_path';
use JSON;
use Encode;
use URI::Escape;

use doclib::pdfidx;

my $__meta_sel;

sub new {
    my $class = shift;
    my $chldno= shift;

    my $self = {};
    $self->{pd} = pdfidx->new($chldno);
    $self->{dh} = $self->{pd}->{dh};

    if ( $chldno ) {
    $self->{add_l} =
      $self->{dh}->prepare("insert or ignore into tagname (tagname) values(?)");
    $self->{add} =
      $self->{dh}->prepare(
"insert or ignore into tags (tagid,idx) select tagid,idx from tagname, hash  where tagname = ?  and md5  = ?"
      );
    $self->{rem} =
      $self->{dh}->prepare(
"delete from tags where tagid = (select tagid from tagname where tagname = ? ) and idx = (select idx from hash where md5 = ?) "
      );
    }

    return bless $self, $class;
}

sub add_tag {
    my $self      = shift;
    my $args      = shift;
    my $json_text = $args->{"json_string"};

    return undef unless $json_text;
    $json_text = uri_unescape($json_text);

    print STDERR Dumper($json_text);
    my $json        = JSON->new->utf8;
    my $perl_scalar = $json->decode($json_text);

    my $p = $perl_scalar->{"op"};

    return "<html><body>Failure</body></html>" unless $p =~ /^(add|rem)$/;
    my $cl = $perl_scalar->{"tag"};
    $cl =~ s/^/-/ if $p eq "rem";

    $self->{"pd"}->pdf_class_md5( $perl_scalar->{"md5"}, $cl );

    return "
     <html>
	<body>
		Tag $p§ ($perl_scalar->{tag})
	</body>
    </html>
   "

}
1;
