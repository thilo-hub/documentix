use Data::Dumper;
use File::ChangeNotify;

@k= File::ChangeNotify->usable_classes();
print Dumper( @k );
my @dir=@ARGV;
    my $watcher =
        File::ChangeNotify->instantiate_watcher
            ( directories =>  @dir ,
              # filter      => qr/\.(?:pm|pl|conf|yml)$/,
            );

    if ( my @events = $watcher->new_events() ) { 
	print "Event: ".Dumper(@events); }

    # blocking
    while ( my @events = $watcher->wait_for_events() ) { 
	print "Event: ".Dumper(@events); }
