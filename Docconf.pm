package Docconf;

# Comments are OK
# Valid perl-code
$config = {
	database_provider => "SQLite",
	database          => "db/doc_db.db",
	database_user     => "",
	database_pass     => "",
	cache_db_provider => "SQLite",
	cache_db          => "/tmp/doc_cache.db",
	cache_db_user     => "",
	cache_db_pass     => "",
	lockfile          => "/tmp/documentix.$$.lock",
	debug             => 0,
	results_per_page  => 10,
	number_server_threads => 16,
        number_ocr_threads => 16,
	browser_start      => 1,

	server_listen_if => "127.0.0.1:8080",
};


1;
