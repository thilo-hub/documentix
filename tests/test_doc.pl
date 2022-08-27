use lib "lib";
use Test::More tests => 22;

require_ok("Document");

ok(Document->new());
$res={};
foreach( glob("testData/*") ) {
	ok($d=Document->new(file=>$_));
	ok(length($ign->{$_}->{content}=$d->content)>0);
	ok(length($ign->{$_}->{pdf}=$d->pdf)>0);
	ok(length($res->{$_}->{text}=$d->text)>0);
}
use Data::Dumper;
$Data::Dumper::Sortkeys=1;
open(F,">res"); print F Dumper($res); close(F);
