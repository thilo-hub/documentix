use strict;
use XMLRPC::Lite;
 
my $xml= XMLRPC::Lite
   -> proxy('http://localhost:8081/RPC2')->on_fault(sub{});
 
# 
# Get a session key from POPFile
#
 
my $sk = $xml->call("POPFile/API.get_session_key",'admin','');
my $key = $sk->result;
my $method = "POPFile/API.$ARGV[0]";
my @params = @ARGV[1..10];
# print Dumper($sk);
 
unshift @params,$key;
use Data::Dumper;
 
my $can = $xml->can($method);
my $res = eval {$xml->call($method,@params)};
 
if ($@) {
    print join("\n","syntax error: " ,$@);
    exit(1);
} elsif ($can && !UNIVERSAL::isa($res => 'XMLRPC::SOM')) {
    print Dumper($res);
} elsif (defined($res) && $res->fault) {
    print join ("\n","XMLRPC FAULT: ", @{$res->fault}{'faultCode','faultString'});
    exit(1);
} elsif (!$xml->transport->is_success) {
    print join ("\n","TRANSPORT ERROR: ", $xml->transport->status);  
} else  {
    if ( ref $res->paramsall eq 'ARRAY' ) {
        print join "\n", @{$res->paramsall};
    } else {
        print Dumper($res->paramsall);
    }
}
print "\n";
 
#
# Release the session key
#
 
$xml->call("POPFile/API.release_session_key",$key);
 
#
# All Done
#
 
exit(0);
