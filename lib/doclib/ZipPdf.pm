package doclib::ZipPdf;
use File::Basename;

sub new {
  my ($class,$archive,$url) = @_;
  my $zipBase = basename($archive);
  my $markdown = <<"EOM";
---
title: Archive Contents 
...

# Content of *$zipBase*

EOM

   my $self = bless { markdown => $markdown, url=>$url };

   return $self;
}


sub addEntry {
 my($self,$name,$dgst) = @_;
 # no dgst implies "Folder"
 return unless $dgst;
 my $bse = $name;
 $bse = dirname($name) unless $bse =~ s|/$||;
 push @{$self->{hier}->{$bse}}, $name
 	if $dgst;
 
 # $self->{markdown} .= "## Folder *$name*\n\n" unless $dgst;

  my $fn = basename($name);
  $fn =~ s/([\(\)\[\]])/"&#".ord($1).";"/ges;
  # my $url = "../../docs/pdf/$dgst/$fn";
  my $url = "$dgst/$fn";
  # Not good my $url = "file://docs/pdf/$dgst/$fn";
  $self->{urls}->{$name} = $self->{url}.$url;

  # $self->{markdown} .= " - [$fn]($url)\n";
}
# Emit the collected files and folders as a pdf
sub generatePdf {
 my ($self,$outpdf) = @_;

 my $m="";
 foreach( sort keys %{$self->{hier}} ) { 
     $m .= "\n## *$_*\n\n";
     foreach ( sort @{$self->{hier}->{$_}} ) {
	 $b = basename($_);
	 $m .= "  - [$b]($self->{urls}->{$_})\n";
     }
 }
 $DB::single = 1;
 $self->{markdown} .= $m;


 # 1 while($self->{markdown} =~ s/\n## [^\n]+\n+## /\n## /gs);
 open(my $dbg,">dbg.markdown"); print $dbg $self->{markdown}; 
 open(TOPDF,qq{|pandoc -s --pdf-engine=wkhtmltopdf --pdf-engine-opt=--keep-relative-links  --pdf-engine-opt=--disable-local-file-access --pdf-engine-opt=--allow --pdf-engine-opt="." -o '$outpdf'});
 print TOPDF $self->{markdown};
 close(TOPDF);
 }
 

1;

