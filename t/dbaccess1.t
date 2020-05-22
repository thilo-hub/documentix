use lib "lib";
use Data::Dumper;
use MyApp::dbaccess; 
$k=dbaccess->new();
print Dumper($k->getFilePath("05296b1e4d5b7c5c7ce176d91fd249c4","raw"));
print Dumper($k->getFilePath("05296b1e4d5b7c5c7ce176d91fd249c4","pdf"));
