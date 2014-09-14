#!/usr/bin/perl
use CGI;
use Data::Dumper;
use WWW::Authen::Simple;
use doclib::pdfidx;
my $q = CGI->new;
my $pdfidx=pdfidx->new();
my $dh=$pdfidx->{"dh"};

my $auth = WWW::Authen::Simple->new(
    db             => $pdfidx->{"dh"},
    expire_seconds => 9999,
    cookie_domain  => $ENV{"SERVER_NAME"}
);
my ( $user, $uid ) = check_auth($q);
sub check_auth {
    my $q = shift;
    $auth->logout() if $q->param('Logout');

    my ( $s, $user, $uid ) =
      $auth->login( $q->param('user'), $q->param('passwd') );
    $s=$auth->in_group('admins','rw') if ( $s == 1 );
    if ( $s != 1 ) {
        do "login.cgi";
        exit 0;
    }
    return ( $user, $uid );
}


my $g=$dh->selectcol_arrayref('select g.name from groups g');
my $u=$dh->selectcol_arrayref('select u.login from Users u');
# my @g=$auth->groups();

my $c=$auth->conf();
if ( $q->param('newuser') && $q->param('newpasswd') )
{
	$q->param('newpasswd',$auth->_getcrypt($q->param('newpasswd')));
	$user="XXXX";
	my $uid=$dh->selectcol_arrayref('select uid from Users where login=?',undef,$q->param('newuser'));
	$uid=$$uid[0] if $uid;
	$user=$uid;
	$uid=$dh->selectcol_arrayref('select max(uid)+1 from Users')->[0]
	#$uid=$dh->last_insert_id(undef,undef,undef,undef)+100
		unless $uid;
	my $adduser = $dh->prepare("INSERT or replace INTO Users (uid,login,passwd,Disabled) VALUES (?,?,?,?)")
	or die "can't prepare new user statement: $DBI::errstr";
	$adduser->execute($uid,$q->param('newuser'),$q->param('newpasswd'),0)
		 or die "can't insert user: $DBI::errstr";
	$q->param('newpasswd',"");
}
if ( $q->param('newuser') && $q->param('newgroups') )
{
	$dh->do('delete from UserGroups where  uid=(select uid from Users where login=?)',undef,$q->param('newuser'));
	foreach( $q->param('newgroups'))
	{
		$dh->do('insert or replace into UserGroups (uid,gid,accessbit) values(
			(select uid from Users where Login=?),
			(select gid from Groups where Name=?),
			3)',undef,$q->param('newuser'),$_);
	}

}
print $q->header(-charset=>'utf-8'),
$q->start_html(-title=>'config '.$user),
$q->start_form,"New Username:",$q->textfield('newuser'),
"Password:",$q->textfield('newpasswd'),$q->p,
"Users:",$q->p,$q->checkbox_group(-name=>'newusers', -linebreak=>'yes',-values=>$u),$q->p,
"Groups:",$q->p,$q->checkbox_group(-name=>'newgroups', -linebreak=>'yes',-values=>$g),$q->p,
$q->submit,
$q->end_form;

my @heading=["User",@g];
my $ug=$dh->prepare("select login,group_concat(name,':') grps  from Users natural join UserGroups natural join Groups group by login order by Login,Name");
# my $ug=$dh->prepare("select * from Users natural join Groups");

$ug->execute();
$r=$ug->fetchall_hashref("login");



print $q->table(),$q->Th(@heading);
foreach(@$u)
{
	my @r=[$_];
	foreach(@$g)
	{
	
		push @r,"X";
	}
}




print "<PRE>\n";
print join(":",$q->param('newgroups'));
print Dumper($q->Vars);
print Dumper(@g);
print Dumper($c);
print Dumper(\%ENV);
print "</PRE>\n";
print end_html;
		 

