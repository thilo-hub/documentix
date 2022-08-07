#!/bin/sh
echo "DBI:"
  perl -MDBI -e 'DBI->installed_versions'
echo "DBD::SQLite:"
  perl -e 'use DBI; $dh=DBI->connect("dbi:SQLite:mem",undef,undef,{sqlite_unicode =>1}); print $DBD::SQLite::sqlite_version."\n"'
echo "SQlite3:"
  sqlite3 --version
