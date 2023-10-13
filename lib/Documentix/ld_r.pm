package ld_r;

use strict;
use warnings;
use Cwd 'abs_path';
use POSIX;
use JSON;
use Sys::Hostname;
use Date::Parse;
use Encode qw{encode decode};
use Documentix::db;;
use Documentix::search;

print STDERR ">>> ld_r.pm\n" if $Documentix::config->{debug} > 2;

my $entries = $Documentix::config->{results_per_page};
#How many tags are shown
my $maxtags=60;

my $myhost = hostname();

my $ANY = "*ANY*";

sub new {
    my $class  = shift;

    my $self = {};
    $self->{pd} = pdfidx->new(0,$Documentix::config);
    $self->{dh} = Documentix::db::dh;
    return bless $self, $class;
}

sub setup_db {
    my $dh = shift;
    $dh->do(
q{ create table if not exists cache_lst ( qidx integer primary key autoincrement,
			query text unique, nresults integer, last_used integer )}
    );
    $dh->do(
q{ create table if not exists cache_q ( qidx integer, idx integer, cast(snippet as text) text, unique(qidx,idx))}
    );

    $dh->do(
        q{
		CREATE TRIGGER if not exists cache_del before delete on cache_lst begin delete
			from cache_q where cache_q.qidx = old.qidx ;
		end;
		}
    );
}

# qidx,idx,rowid,snippet from cache_q_tmp
sub ldres {
    my $self = shift;
    my $dh   = $self->{"dh"};

    my ( $class, $idx0, $ppage, $search ) = @_;
    $search =~ s/\s+$// if defined($search);
    $search =~ s/^\s+// if defined($search);

    my ( $hd, $res ) = ( "", "" );

    undef $search if $search && $search =~ /^\s*$/;
    $idx0  = 1        unless $idx0;
    $ppage = $entries unless $ppage;

    # ?? $class =~ s/:\d+$// if $class;
    undef $class if defined($class) && $class eq $ANY;

    # either do a new search or get the cached queryid anyhow results are in cache_q(idx) date-range is part of the cache
    # TODO:  does it make sense to make date-range a filter?
    #    (hint: I would loose the snippet part in the date-range)
    my $idx = search( $search );

    my $full_s   = qq{ select idx,mtime,cast(Content as text) snippet from mtime};;
    my $cached_s = qq{ select idx,mtime,snippet                       from mtime natural join (select idx,snippet from cache_q where qidx=:qidx)};

    my ( $classes, $ndata );

   my $selclass = "";
   my $param = {};
   $ndata = qq{ select count(*) from mtime };
   if ( $class ) {
      $selclass = qq{ natural join ( select idx from tags natural join tagname where tagname = :tgn )} ;
      $ndata = qq{select nresults from cache_lst $selclass};
      $param->{':tgn'} = $class;
   }

   $search = qq{$full_s $selclass natural join content order by mtime desc};


   if ( my $qidx=$idx ) {
       $search = qq{$cached_s $selclass};
       $param->{':qidx'} = $qidx;
       $ndata = qq{select nresults from cache_lst $selclass where qidx=:qidx};
   }
    # total count get number of results
    print STDERR "ndata: $ndata\n";
    $ndata   = $dh->prepare_cached($ndata);
    foreach ( keys %$param ){
	$ndata->bind_param($_,$param->{$_})
    }
    $ndata -> execute();
    my $nres   = $ndata->fetchrow_array();
    $ndata->finish;
    $ndata = $nres;

    if ($idx0 eq 1){
        # get a collection of tagnames for first result
	$param->{":lim"} = $maxtags;
	$classes=qq{ with search as ($search)
			select tagname,count(*) count
				from search
				natural join tags
				natural join tagname
				group by tagid
				order by count
				desc limit :lim
			};
	print STDERR "Classes:  $classes\n";
	my $sel_t=$dh->prepare_cached($classes);
	foreach (keys %$param) {
	    $sel_t->bind_param($_,$param->{$_});
	}
	$sel_t->execute();
	$classes = $sel_t->fetchall_arrayref({});
    }

    # Assemble final query
    # Now make it into a full result
    $search .= qq{ limit :lim offset :off};
    $param->{":lim"} = $ppage;
    $param->{":off"} = int($idx0-1);

    my $get_res=qq{
        with results as ($search)
    	select idx,md5,mtime dt,pdfinfo,cast(file as blob) file,tags,cast(snippet as text) snippet
		from results
			natural left join hash
			join pdfinfo using (idx)
			natural left join taglist
			natural left join file
			group by idx order by dt desc
    };

    # do the result query
    print STDERR "Search: $get_res\n";
    $get_res = $dh->prepare_cached($get_res);
    foreach (keys %$param) {
	    $get_res->bind_param($_,$param->{$_});
    }
    $get_res->execute();

    my $out = $get_res->fetchall_arrayref({});
    # Loop over query results and create hash to be returned
    foreach ( @$out ) {
	if ( my $mpdf = $_->{"pdfinfo"} ){
		$_->{sz}= conv_size($1) if $mpdf =~ /File size\s*<\/td><td>\s*(\d+)/;
		$_->{pg}= $1 if $mpdf =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
		# $_->{dt}= str2time($1) if ( $mpdf =~ /CreationDate\s*<\/td><td>\s*(.*?)\s*<\/td>/) unless $_->{dt};
		delete $_->{"pdfinfo"};
	}
	$_->{dt} = pr_time($_->{dt});
	my $f=$_->{file}; delete $_->{file};
	next unless $f;
	$f =~ s|^.*/||;
	$f =~ s|\.([^\.]*)$||;
	$_->{doct} = $1;
	utf8::decode($f);
	$_->{doc}  = $f;
	$_->{doc}  =~ s/%20/ /g;
	$_->{doc}  =~ s/%2F/\//g; #Not sure if best. The filename uses %xx and the doc-name is then problematic?

	$_->{tip} = $_->{snippet}; delete $_->{"snippet"};
	$_->{tip} =~ s/["']/&quot;/g;
	$_->{tip} =~ s/\n/<br>/g;
	$_->{tg} = $_->{tags}|| ""; delete $_->{"tags"};
    }
    my $msg = "results: $ndata<br>";
    $msg .= "qidx: $idx<br>" if $idx;
    my $m = {
	nresults => int($ndata),                        # max number of items
	idx      => int($idx0),                         # first item in response
	pageno   => int( ( $idx0 - 1 ) / $ppage ) + 1,
	nitems   => int($ppage),

	# dates => $dater,
	query => $search,

	classes => $classes,
	msg     => $msg,
	items   => $out,
    };
    return $m;
    $out = JSON->new->pretty->encode($m);

    return $out;
}

sub reocr
{
	my ($self,$app,$md5)=@_;
	$DB::single = 1;
	my $doclib=$self->{pd};
	my $fn=$doclib->pdf_filename($md5);
	return $doclib->pdf_totext($fn,$md5,$app->minion);
}

sub conv_size
{

    my $s=shift;
    return sprintf("%.1f Gb",$s/2**30) if $s > 2**30;
    return sprintf("%.1f Mb",$s/2**20) if $s > 2**20;
    return sprintf("%.1f kb",$s/2**10);
}

#
# print formated short time string depending on how long ago
sub pr_time {
	my $t   = shift;
	$t=0 unless defined($t) && $t =~ /^\d+$/;
	my $dt = time() - $t;
	my @str = ( "%a %H:%M",  "last %a",         "%b-%d",             "%b %Y" );
	my @off = ( 24 * 60 * 60, 7 * 24 * 60 * 60, 180 * 24 * 60 * 60 );
	foreach (@off) {
		last if $dt < $_;
		shift @str;
	}
	return strftime( $str[0], localtime($t) );
}

1;
