#!/usr/bin/perl -It2
use Digest::MD5 qw(md5_hex);
use CGI;
use WWW::Authen::Simple;
use pdfidx;

my $q = CGI->new;
if ($ENV{"DEBUG"} ) { $q->restore_parameters(STDIN);}
else { open(F,">/tmp/state.cgi") && $q->save(F);}

my $pdfidx=pdfidx->new();
my $dh=$pdfidx->{"dh"};

my $auth=WWW::Authen::Simple->new(
	db => $dh,
	cookie_domain => $ENV{"SERVER_NAME"}
);
my @state=$auth->login( $q->param('user'), $q->param('login') );
print $q->header(-charset=>'utf-8'),
	$q->start_html(-title=>'Login');

$auth->logout() if $q->param('logout') && !defined($q->param('login'));
push @state,$auth->login(undef,undef);
	
if ( $auth->logged_in() )
{
	my $dst=$ENV{"HTTP_REFERER"} || "main.cgi";
	$dst="main.cgi" if $dst=~ /\/login.cgi$/;
	#$dst="env.cgi";
	#print $q->redirect($dst); exit 0;
	print $q->script({-type=>'text/javascript'},
		"window.location.href='$dst'"),
	      $q->a({-href=>$dst},'Refresh page');
}
else
{

print $q->start_form(-method=>'post'),
	$q->h3("RES:".join(':',@state)),
	$q->br,
	$q->label("Username:"),
	$q->textfield('user'),
	$q->br,
	$q->label("Password:"),
	$q->password_field(-name => 'login', -autocomplete=>'off' ),
	$q->br,
	$q->submit(-value=>'Login'),
	$q->end_form;
}
pr_env();
print $q->end_html;
exit (0);

sub pr_env
{
use Data::Dumper;
print "<PRE>\n";
print Dumper($q->Vars);
print Dumper(\%ENV);
print "</PRE>\n";
}


