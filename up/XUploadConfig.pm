package XUploadConfig;

my $base_uri=$ENV{"SCRIPT_URI"};
$base_uri =~ s/\/[^\/]*$//;
my $base_dir=$ENV{"SCRIPT_FILENAME"};
$base_dir =~ s/\/[^\/]*$//;

BEGIN
{
  use Exporter;
  @XUploadConfig::ISA = qw( Exporter );
  @XUploadConfig::EXPORT = qw( $c );
}

our $c=
{
 # Directory for temporary using files
 temp_dir        => '/usr/local/http/tmp',

 # Directory for uploaded files
 target_dir      => "$base_dir/uploads",

 # Path to the template using for upload status window
 templates_dir   => "$base_dir/Templates",

 # Allowed file extensions delimited with '|'
 ext_allowed     => 'jpg|jpeg|gif|png|rar|zip|mp3|avi|txt|pdf|csv',

 # URL to send all input values from upload page
 url_post        => "$base_uri/post.cgi",

 # The link to redirect after complete upload
 # This setting can be submitted from HTML form, then it will have priority
 redirect_link   => "$base_uri/upload_form.html",

 # Max length of uploaded filenames(without ext). Longer filenames will be cuted.
 max_name_length => 64,

 # Type of behavior when uploaded file already exist on disc. Available 3 modes: Rewrite/Rename/Warn
 copy_mode       => 'Rename',

 # Maximum total upload size in Kbytes
 max_upload_size => 70000000,      

 # Time to keep temp upload files on server, sec (24 hours = 86400 seconds)
 temp_files_lifetime => 86400,

};

1;
