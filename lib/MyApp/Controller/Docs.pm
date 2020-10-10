package MyApp::Controller::Docs;
use Mojo::Base 'Mojolicious::Controller';
use MyApp::Docconf;
use MyApp::dbaccess;;
use MyApp::ld_r;
use Mojo::Asset;
use Mojo::Upload;
use Mojo::Util;
 use Mojo::Log;
use Data::Dumper;
use File::MimeInfo::Magic;
use IO::Scalar;
use Date::Parse;



my $log = Mojo::Log->new;
my $ld=dbaccess->new();
my $ld_r=ld_r->new();


# This action will render a template
sub senddoc {
   my $c   = shift;
   my $type = $c->stash('type');
   my $hash = $c->stash('hash');
   my $doc = $c->stash('doc');

   my $res = $ld->getFilePath($hash,$type);
   return $c->reply->asset($res) if $res;
   # Failures...
   return $c->reply->static("Error.pdf") if $type eq "pdf";
   return $c->reply->static("icon/Keys-icon.png");
}

# Multipart upload handler
sub upload {
   my $c = shift;

   # Check file size
   return $c->render(text => 'File is too big.', status => 200)
     if $c->req->is_limit_exceeded;

   my $f=Mojo::Asset::File->new()->add_chunk($c->req->body);
   $f->mtime(str2time($c->req->headers->header('X-File-Date'))) if $c->res->headers->header('X-File-Date');
   my ($status,$rv)=$ld->load_file($c,$f,$c->req->headers->header('X-File-Name'));

    my $hash = $c->req->headers->to_hash();
    # my $name = Dumper(  $hash ); $log->debug($name);

my $resp = {
	'nitems' => 9999,
	'items' => [ $rv ],
	'nresults' => 12433,
	'msg' => $status,
};

   my $size = length $c->req->body;
   $c->render(json => $resp );
};

  ## Render template "example/welcome.html.ep" with message
  #$self->render(msg => 'Welcome to the Mojolicious real-time web framework!');

sub search {
        my $c = shift;

        my $m = $ld_r->ldres( $c->param("class"), $c->param("idx"), $c->param("ppages"),
            $c->param("search") );
    $c->render(json => $m);
}

sub reocr {
 	my $c = shift;

	$c->render(json => $ld_r->reocr( $c,$c->param("md5") ));
}
1;
