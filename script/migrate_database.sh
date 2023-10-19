#!/bin/sh

# Migrate database to new schema
#
# Arg1 is original DB
# remove *.wip as this is the work in progress db
# After conversion
# copy original to *.bak and rename *.wip to original
#
DB="$1";
WIP="$DB.wip";
BASE="$(dirname "$0")"
test ! -r "$DB" && echo "Database not available $DB" && exit 9
rm -f "$WIP"
DBVER=$(sqlite3 "$DB" "select value from config where var = 'dbversion'")
if [ $DBVER -lt 7 ] ; then

	test ! -r "$BASE"/../migrate_database.sql && echo "Migration script unavailable" && exit 8;

	(echo ".bail on"
	 echo ".read $BASE/../db_schema-snowball.sql"
	 echo "attach '$DB' as other;"
	 echo ".read $BASE/../migrate_database.sql"
	) |  sqlite3 "$WIP" &&
		cp "$DB" "$DB.bak" && mv "$WIP" "$DB" && echo "Done Backup in $DB.bak" || echo "Process stopped"
fi




