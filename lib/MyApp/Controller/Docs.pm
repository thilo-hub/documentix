package MyApp::Controller::Docs;
use Mojo::Base 'Mojolicious::Controller';
use MyApp::Docconf;
use MyApp::dbaccess;;
use MyApp::ld_r;
use Mojo::Asset;

my $ld=dbaccess->new();
my $ld_r=ld_r->new();


# This action will render a template
sub senddoc {
   my $c   = shift;
   my $type = $c->stash('type');
   my $hash = $c->stash('hash');
   my $doc = $c->stash('doc');

   my $res = $ld->getFilePath($hash,$type);
   return $c->reply->asset($res);
}

# Multipart upload handler
sub upload {
   my $c = shift;

   # Check file size
   return $c->render(text => 'File is too big.', status => 200)
     if $c->req->is_limit_exceeded;

   # Process uploaded file
   # return $c->redirect_to('form') 
   return $c->render(test => "Wrong") unless my $example = $c->param('example');
   my $size = $example->size;
   my $name = $example->filename;
   $c->render(text => "Thanks for uploading $size byte file $name.");
 };

  ## Render template "example/welcome.html.ep" with message
  #$self->render(msg => 'Welcome to the Mojolicious real-time web framework!');

sub search {
        my $c = shift;

        my $m = $ld_r->ldres( $c->param("class"), $c->param("idx"), $c->param("ppages"),
            $c->param("search") );
    $c->render(json => $m);
}

1;
