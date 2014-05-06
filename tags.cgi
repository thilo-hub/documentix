#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use WWW::Authen::Simple;
use pdfidx;
use Cwd 'abs_path';
use CGI;
use JSON::PP;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $__meta_sel;
my $q = CGI->new;

my $pdfidx = pdfidx->new();

#if we have the authetication cookies in the parameters
# put them into a cookie
my @mycookies;

# push @mycookies, $q->cookie(-name=>'login',-value=>[$q->param('login')]) if $q->param('login');
# push @mycookies, $q->cookie(-name=>'ticket',-value=>[$q->param('ticket')]) if $q->param('ticket');

my $auth = WWW::Authen::Simple->new(
    db             => $pdfidx->{"dh"},
    expire_seconds => 9999,
    cookie_domain  => $ENV{"SERVER_NAME"}
);
my ( $user, $uid ) = check_auth($q);

#===== AUTHENTICATED BELOW ===========

my $dh = $pdfidx->{"dh"};
print $q->header( -charset => 'utf-8' ),    # , -cookie=> \@mycookies),,
  my $json_text = $q->param('json_string');
if ($json_text) {
    my $json        = JSON::PP->new->utf8;
    my $perl_scalar = $json->decode($json_text);
    my $op_add =
"insert or ignore into tags (tagid,idx) select tagid,idx from tagname, hash  where tagname = ?  and md5  = ?";
    my $op_del =
"delete from tags where tagid = (select tagid from tagname where tagname = ? ) and idx = (select idx from hash where md5 = ?) ";
    $dh->prepare(
"delete from tagname where tagid in (select distinct(tagid) from tagname where tagid not in (select distinct(tagid) from tags))"
    ) if ( $perl_scalar->{"op"} eq "rem" );
    $dh->prepare("insert or ignore into tagname (tagname) values(?)")
      ->execute( $perl_scalar->{"tag"} )
      if ( $perl_scalar->{"op"} eq "add" );
    my $op = ( $perl_scalar->{"op"} eq "rem" ) ? $op_del : $op_add;
    $dh->prepare($op)->execute( $perl_scalar->{"tag"}, $perl_scalar->{"md5"} );
    print $q->header( -charset => 'utf-8' ),    # , -cookie=> \@mycookies),
      $q->start_html( -title => 'PDF Database' ),
      $q->body( Dumper($perl_scalar) );
    open( FH, ">/tmp/tags.log" ) && print FH Dumper($perl_scalar) && close FH;

}
else {

    print $q->start_html(
        -style => {
            -code =>
"input.tagbox_l { border:1px solid #CCC; background: #cccc00; padding:5px; width 30;auto; -moz-border-radius: 15px; border-radius: 15px;} unsel { background: #cccccc; }"
        }
      ),
      $q->Link(
        {
            -rel  => "stylesheet",
            -type => "text/css",
            href  => "js/jquery.tagsinput.css"
        }
      ),
      $q->script(
        { -type => 'text/javascript', -src => "js/jquery/jquery.min.js" }, ""
      ),
      $q->script(
        { -type => 'text/javascript', -src => "js/jquery/jquery-ui.min.js" },
        "" ),
      $q->script(
        { -type => 'text/javascript', -src => "js/wz_tooltip.js" }, ""
      ),
      $q->script(
        { -type => 'text/javascript' },
        q{ 
		$(function() {
			$( "#search" ).keydown(function( event ) {
				if ( event.which == 13 ) {
				update_res();
				}
			});
			function update_res(clitm)
			{
			if ( clitm ) {
					meme={class:$(clitm).val(), md5:clitm.id};
					jeje= { json_string:JSON.stringify(meme) };
					jeje="class=" + $(clitm).val();
					}
					jeje+="&search=" + $('#search').val();
					//$.post("env.cgi", jeje, function( data ) { $('#msg').html( data ); } );
					$.post("ldres.cgi", jeje,
						function( data ) { 
							$('#result').html( data ); 
							$('#taglist').html( $('#classes').html() ); 
							} 
						);
				
			}

			$('.tagbox_l').each( function(i) { 
				$(this).click(function() { 
					update_res(this);
				})
			})
			})
		}
      );

    my $tags = $dh->selectall_hashref(
"select tagname,count(*) cnt from tags natural join tagname group by tagname",
        "tagname"
    );
    my $left;
    my $sum = 0;
    foreach my $tv ( sort keys %$tags ) {
        $sum += $tags->{$tv}->{cnt};
    }
    $left .=
      $q->br . "Search:" . $q->textfield( { -id => "search" }, 'search' );

    $tags = $dh->selectall_hashref(
"select tagname,count(*) cnt from tags natural join tagname group by tagname order by cnt desc limit 20",
        "tagname"
    );
    my $limit = 20;
    my $tagl;
    foreach my $tv ( sort keys %$tags ) {

        last if $limit-- eq 0;

        #print "$tv : $tags->{$tv}->{cnt}\n";
        my $ts = $tags->{$tv}->{"cnt"} / $sum;
        my $bg = ( $ts < 0.02 ) ? "background: #bbb" : "";
        $ts = 0.2 if $ts < 0.1;
        $ts = int( $ts * 30 );
        $tagl .= $q->button(
            -name  => 'button_name',
            -class => 'tagbox_l',
            -style => "font-size: ${ts}px; $bg ",
            -value => $tv
        );

    }
    $left .= $q->div( { -id => 'taglist' }, $tagl );
    $left .= "<p>" . $q->hr . $q->div( { -id => 'msg' }, "msg" ) . "</p>";

    print <<EOP;
<div style="padding:0px; border-width:0px; width:100%;height:80px" > 
	<div id="title" style="border-width:3px; border: solid red; text-align:center; width:100%; height:100%">
		Title line
	</div>
	</div>
	<div>
	<div style="padding:0px; border-width:0px; width:20%; float:left">
<div id="left" style="border-width:3px; border:solid red; text-align:center; width:100%; height:100%; float:left" > 
$left
	</div>
	</div>
	<div style="padding:0px; border-width:0px; width:80%; float:left">
<div id="result" style="border-width:2px;border:solid red; width:100%; height:100%; float: left " > 
		left content
	</div>
	</div>
	</div>
EOP
}

print $q->end_html;
exit 0;

sub pages {
    my ( $q, $p0, $maxpage ) = @_;
    my @pgurl;
    my $myself = $q->url( -query => 1, -relative => 1 );
    $myself =~ s/%/%%/g;
    $myself =~ s/(;|\?)/\&/g;
    $myself =~ s/&page=\d+//;
    $myself =~ s/(&|$)/\?page=%d$1/;
    push @pgurl, sprintf( "<a href=$myself>&lt;&lt;</a>", 1 );
    push @pgurl, sprintf( "<a href=$myself>&lt;</a>", $p0 > 1 ? $p0 - 1 : 1 );
    my $entries = 6;
    my $lo      = $p0 - $entries / 2;
    $maxpage++;
    $lo = $maxpage - $entries if $lo > $maxpage - $entries;
    $lo = 1 if $lo < 1;
    my $hi = $lo + $entries;
    $hi = $maxpage if $hi > $maxpage;

    foreach ( $lo .. $hi ) {
        push @pgurl,
          sprintf( "<a href=$myself>%s</a>",
            $_, ( $_ == $p0 ? "<big>&nbsp;$_&nbsp;</big>" : $_ ) );
    }
    push @pgurl, sprintf( "<a href=$myself>&gt;<a>",     $p0 + 1 );
    push @pgurl, sprintf( "<a href=$myself>&gt;&gt;<a>", $maxpage );
    return $q->table( $q->Tr( $q->td( \@pgurl ) ) );
}

sub check_auth {
    my $q = shift;
    $auth->logout() if $q->param('Logout');

    my ( $s, $user, $uid ) =
      $auth->login( $q->param('user'), $q->param('passwd') );
    if ( $s != 1 ) {
        do "login.cgi";
        exit 0;
        my $dst = "login.cgi";

        #print $q->redirect($dst);
        print $q->header(),
          $q->html(
            $q->script(
                { -type => 'text/javascript' },
                "window.location.href='$dst'"
            ),
            $q->a( { -href => $dst }, 'Refresh page' )
          );
        exit 0;
    }
    return ( $user, $uid );
}

sub load_results {
    my ($stmt_hdl) = @_;
    my $t0 = 0;
    my @outrow;
    my @out;
    while ( my $r = $stmt_hdl->fetchrow_hashref ) {
        if ( $t0 ne $r->{"date"} ) {
            push @out, join( "\n  ", splice(@outrow) );

            push @out, $q->th( { -colspan => 3 }, $q->hr, $r->{"date"} );
            $t0 = $r->{"date"};
        }
        my $meta = get_meta( $r->{"idx"} );
        my $md5  = $meta->{"hash"}->{"value"};

        my $mod1_pdf = "../pdf/t2/mod1_pdf.cgi?send=";
        my $qt       = "'";
        my $modf     = $mod1_pdf . "$md5&type=lowres";
        my $s        = $1
          if $meta->{"pdfinfo"}->{"value"} =~ /File size\s*<\/td><td>\s*(\d+)/;
        my $p = $1
          if $meta->{"pdfinfo"}->{"value"} =~
          /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
        my $d = $1
          if $meta->{"pdfinfo"}->{"value"} =~
          /CreationDate\s*<\/td><td>(.*?)<\/td>/;
        $d = "--" unless $d;
        $p = 1    unless $p;

        my $tags = $meta->{"tags"}->{"value"} || "";

        #$tags= $q->p({-class=>"tags"},"enney,money,mo");
        $tags = $q->p(
            $q->input(
                {
                    -name  => "tags1",
                    -id    => "tags_2",
                    -type  => "text",
                    -class => "tags",
                    -value => $tags
                }
            )
        );

        my $short_name = $meta->{"Docname"}->{"value"};
        $short_name =~ s/^.*\///;
        my $sshort_name = $short_name;
        $short_name =~ s/#/%23/g;

        # build various URLS
        my $pdf    = "docs/pdf/$md5/$short_name";
        my $lowres = "docs/lowres/$md5/$short_name";
        my $ico = qq{<img width=150 heigth=212 src='docs/ico/$md5/$short_name'};
        my $tip =
qq{<object type=text/x-scriptlet width=475 height=300 data="docs/Content/$md5/$short_name"> </object>};
        $tip = $r->{snip} if $r->{"snip"};
        $tip =~ s/'/&quot;/g;
        $tip =~ s/\n/<br>/g;
        $tip = qq{'$tip'};
        print STDERR "TIP:$tip\n";

# my @a=stat($pdf); my $e= strftime("%Y-%b-%d %a  %H:%M ($a[7]) $_",localtime($a[10]));
        $meta->{PopFile}->{value} =~ s|http://maggi|$q->url(-base=>'1')|e;
        my $day = $d;
        $day =~ s/\s+\d+:\d+:\d+\s+/ /;
        $d = $&;
        my @data = $q->td(
            [
                $q->a(
                    {
                        -href        => $pdf,
                        -onmouseover => "Tip($tip)",
                        -onmouseout  => "UnTip()"
                    },
                    $ico
                ),
                $q->a(
                    {
                        -href   => $meta->{PopFile}->{value},
                        -target => "_popfile"
                    },
                    $meta->{Class}->{value}
                  )
                  . $q->br
                  . $q->a( { -href => $pdf }, $sshort_name )
                  . $q->a($tags),

# $q->a({-href=>$pdf, -onmouseover=>"Tip($tip)", -onmouseout=>"UnTip()"},$short_name).
#  ($r->{"snip"} ? "<br>$r->{snip}" :"").
                (
                    ( ( $s / $p ) > 500000 )
                    ? "<br>"
                      . $q->a( { -href => $lowres, -target => "_pdf" },
                        "&lt;Lowres&gt;" )
                    : ""
                  )
                  . "<br>"
                  . $q->a( { -href => $modf, -target => "_edit" },
                    "&lt;Edit&gt;" )
                  . "<br> Pages: $p <br>$s"
            ]
        );

        push @outrow, $q->td( $q->table( $q->Tr(@data) ) );
        push @out, join( "\n  ", splice(@outrow) ) if scalar(@outrow) >= 3;
    }
    push @out, join( "\n  ", splice(@outrow) );
    return \@out;
}

sub get_meta {
    my $tag = shift;
    $__meta_sel = $dh->prepare(q{select * from metadata where idx=?})
      unless $__meta_sel;
    $__meta_sel->execute($tag);
    my $r = $__meta_sel->fetchall_hashref("tag");
    return $r;
}
