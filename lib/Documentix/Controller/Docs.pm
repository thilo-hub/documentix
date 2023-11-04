package Documentix::Controller::Docs;
use Data::Dumper;
use IO::Scalar;
use Date::Parse;
use Encode qw{encode decode};
use File::Basename;

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
use Documentix::Importer;



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
	# Manual tags /add are always starting with upper
	$tag =~ s/[A-Za-z]/uc($&)/e
		if $op ne "rem" && $tag ne "deleted";
	print STDERR "TAG $op $tag -> $id\n";
	my $r= ($tag eq "ForceOcr" && $op eq "add") ?
			$ld_r->reocr( $c,$id)
			: pdf_class_md5($id, ($op eq "rem" )? "-$tag" : "$tag");
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

sub importer {
   my $c = shift;
   # Check file size
   $DB::single=1;
   # my $items = Documentix::Importer::update();
   Documentix::Task::Processor::schedule_importer();

   my $status = "Importing";

   return $c->render(text => 'Refresh filesystem started ', status => 200);

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
	print STDERR Dumper($rv) if $Documentix::config->{debug} > 2;
        $c->res->headers->cache_control("no-cache")
		if  ($rv && $rv->[0]->{tip} eq "ProCessIng");
	$c->render(json => {
		   	nitems => scalar(@$rv),
			items  => [ @$rv ],
			nresults => scalar(@$rv),
			msg => "Info"
		});

}

sub refresh_file {
	my ($c,$file)=@_;
	$DB::single=1;
	my $dba = dbaccess->new();   
	my $f=Mojo::Asset::File->new(path => decode("utf-8",$file));
	$file =~ s|^.*/||;
	my ($status,$rv)=$dba->load_asset($c,$f,$file,$f->mtime);
	return $c->render(json => {status => $status, rv => $rv});;
}


sub reocr {
 	my $c = shift;

	$c->render(json => $ld_r->reocr( $c,$c->param("md5") ));
}

sub refresh {
	my $c = shift;
	$DB::single=1;
	my $top = $c->param("dir")  || Mojo::File->new($Documentix::config->{root_dir})->to_abs;
	return refresh_file($c,$c->param("file")) if $c->param("file");
	Documentix::Task::Processor::schedule_refresh($top);
       return $c->render(text => 'Refresh filesystem started '.$top, status => 200);
}
sub exportfiles {
	my $c = shift;
	my $tag = $c->param("tag");
	my $r = $dba->export_files($tag);
	return $c->reply->asset($r);
}
sub lkup {
	my $c = shift;
	my $id = $c->param("DXID");

	my $doc = $dba->lkup($id);
	if ( $doc ) {
		if(0) {
			# Start full view with document opened
			$c->cookie(autoshow => $doc,{path => '/'});
			$c->redirect_to("/index.html");
		} else {
			# Start document viewer
			my $viewer = "/web/viewer.html?file=..";
			my $f = basename($doc->{file});
			$c->redirect_to($viewer."/docs/pdf/$doc->{md5}/$f");
		}
	} else {
		Documentix::Task::Processor::schedule_importer();
		$c->render(text => 'Not for you', status => 451);
	}
}

sub fixsearchdb {
	#  Make small fixes to enable searches again
	#  not sure why the sqlite driver bugs this up
	#
	my $c = shift;
	Documentix::Task::Processor::schedule_dbfix();
	$c->render(text => 'Database maintenance scheduled');
	return $c->redirect_to("/minion/jobs?state=active");
}
# Return basic configuration info
sub config {
  my $c = shift;
 
  my $conf = {
	  instance => $Documentix::config->{Instance} ||
				  "Unnamed Documentix",
	  tokenizer => "snowball german english",
  };
	$c->render(json => $conf);
}

1;
