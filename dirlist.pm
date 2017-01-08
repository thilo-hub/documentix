package dirlist;
use HTML::Entities;
use Cwd;

my $root = getcwd();

#----------------------------------------------------------

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

sub list {
    my ( $self, $args ) = @_;

    my $list = dlist( $args->{"dir"} );
}

sub dlist {
    my $dir = shift;

    my $out = "";    # "Content-type: text/html\n\n";

    my $fullDir = $root . $dir;

    exit if !-e $fullDir;

    opendir( BIN, $fullDir ) or die "Can't open $dir: $!";
    my ( @folders, @files );
    my $total = 0;
    while ( defined( my $file = readdir BIN ) ) {
        next if $file eq '.' or $file eq '..';
        $total++;
        if ( -d "$fullDir/$file" ) {
            push( @folders, $file );
        }
        else {
            push( @files, $file );
        }
    }
    closedir(BIN);

    return if $total == 0;
    $out .= "<ul class=\"jqueryFileTree\" style=\"display: none;\">";

    # print Folders
    foreach my $file ( sort @folders ) {
        next if !-e $fullDir . $file;

        $out .=
            '<li class="directory collapsed"><a href="#" rel="'
          . &HTML::Entities::encode( $dir . $file ) . '/">'
          . &HTML::Entities::encode($file)
          . '</a></li>';
    }

    # print Files
    foreach my $file ( sort @files ) {
        next if !-e $fullDir . $file;

        $file =~ /\.(.+)$/;
        my $ext = $1;
        $out .=
            '<li class="file ext_'
          . $ext
          . '"><a href="#" rel="'
          . &HTML::Entities::encode( $dir . $file ) . '/">'
          . &HTML::Entities::encode($file)
          . '</a></li>';
    }

    $out .= "</ul>\n";

    return $out;
}
1;

