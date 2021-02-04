package Documentix::Importer;

use File::Basename;
use Documentix::dbaccess;

our @importer=();
#HACK ??
my @importers = glob("$INC[0]/Documentix/Importer/*.pm");
foreach ( @importers ) {
	require $_;
}
# Call all registered importer(s)
sub update 
{
	my $dba = dbaccess->new();   
	$DB::single=1;
	my @items;
	foreach my $imp ( @importer ) {
		my @list=$imp->();
		foreach (@list) {

			# my $f=Mojo::Asset::File->new()->add_chunk($c->req->body);
		   # A bit hack:  hard link input to a new one so that the new one gets moved into the storage position
		   # This works as the scanner unlinks the old file firse if is is replaceing it for whatever reason
		   link( $_,"$_.tmp") || next;
		   my $f= Mojo::Asset::File->new(path => "$_.tmp");
		   my ($status,$rv)=$dba->load_asset("APP?",$f,basename($_),$f->mtime);
		   unlink "$_.tmp" if -f "$_.tmp";

		   push @items,$rv;
		}
	}
	return \@items;
}

sub refresh {
	my $file=shift;
	$DB::single=1;
	my $dba = dbaccess->new();   
   my $f=Mojo::Asset::File->new(path => $file);
   $file =~ s|^.*/||;
   return $dba->load_asset($c,$f,$file,$f->mtime);
}

1;

