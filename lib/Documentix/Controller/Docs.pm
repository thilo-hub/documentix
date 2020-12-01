package Documentix::Controller::Docs;
use Data::Dumper;
use IO::Scalar;
use Date::Parse;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw{url_unescape};
use Mojo::Asset;
use Mojo::Upload;
use Mojo::Util;
use Mojo::Log;

use Documentix::Classifier qw{pdf_class_md5};
use Documentix::dbaccess;;
use Documentix::ld_r;



my $log = Mojo::Log->new;
my $dba=dbaccess->new();
my $ld_r=ld_r->new();


# This action will render a template
sub senddoc {
   my $c   = shift;
   my $type = $c->stash('type');
   my $hash = $c->stash('hash');
   my $doc = $c->stash('doc');


   my $res = $dba->getFilePath($hash,$type);
   return $c->reply->asset($res) if $res;
   # Failures...
   $c->res->headers->cache_control("no-cache");
   return $c->redirect_to("/Error.pdf") if $type eq "pdf";
   return $c->redirect_to("/icon/Keys-icon.png");
}
sub tags {
	my $c = shift;
	my $p=decode_json( url_unescape($c->param('json_string')) );

	my $op=$p->{op};
	my $id=$p->{md5};
	my $tag=$p->{tag};
	my $r= pdf_class_md5($id, ($op eq "rem" )? "-$tag" : "$tag");
	$c->render(json => $r);

}

#  API's below return json results and should not be cached if items are still in processing
# Multipart upload handler
sub upload {
   my $c = shift;
   # Check file size
   return $c->render(text => 'File is too big.', status => 200)
     if $c->req->is_limit_exceeded;

   my $f=Mojo::Asset::File->new()->add_chunk($c->req->body);
   my $mtime = str2time($c->req->headers->header('X-File-Date')) || time;
   my ($status,$rv)=$dba->load_asset($c,$f,url_unescape($c->req->headers->header('X-File-Name')),$mtime);

   # capture tags returnd from load_file
   if ( $rv->{newtags} ) {
	   my $md5=$rv->{md5};
	   foreach( @{$rv->{newtags}} ) {
		   pdf_class_md5($md5, $_);
	   }
   }

   $c->render(json => {
		   	nitems => 1,
			items  => [ $rv ],
			nresults => 9999,
			msg => $status
		});

};

sub search {
        my $c = shift;

        my $m = $ld_r->ldres( $c->param("class"), $c->param("idx"), $c->param("ppages"), $c->param("search") );
        $c->res->headers->cache_control("no-cache");
        $c->render(json => $m);
}

sub status {
 	my $c = shift;
	my $rv=$dba->item( $c->param("md5") );
use Data::Dumper; print STDERR Dumper($rv);
        $c->res->headers->cache_control("no-cache")
		if  $rv->[0]->{tip} eq "ProCessIng";
	$c->render(json => {
		   	nitems => scalar(@$rv),
			items  => [ @$rv ],
			nresults => scalar(@$rv),
			msg => "Info"
		});

}

sub reocr {
 	my $c = shift;

	$c->render(json => $ld_r->reocr( $c,$c->param("md5") ));
}

sub refresh {
	my $c = shift;
	my $top = $c->param("dir")  || Mojo::File->new($Documentix::config->{root_dir})->to_abs;
	Documentix::Task::Processor::schedule_refresh($top);
       return $c->render(text => 'Refresh filesystem started '.$top, status => 200);
}
sub exportfiles {
	my $c = shift;
	my $tag = $c->param("tag");
	my $r = $dba->export_files($tag);
	return $c->reply->asset($r);
}


1;
