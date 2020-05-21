use lib "lib";
use MyApp::dbaccess; 
$k=dbaccess->new();
print $k->getFilePath("476cdf78164932bae8106a9a12cc8e52","raw")."\n"
