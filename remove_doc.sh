#!/bin/sh

for f in "$@"; do
    if [ -f "$f" ]; then
	set X $(perl -e 'use Digest::MD5::File qw{file_md5_hex}; print file_md5_hex(@ARGV)' "$f")
	f=$2
    fi
    echo "select * from hash natural join file where md5='$f'; delete from hash where md5='$f';"
done |
    sqlite3 db/doc_db.db 

