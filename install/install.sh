#!/bin/sh

test -f client_srv.pl || (echo "start in top-level directory --- ERROR" ;false) || exit 99

# This is defined somewhere else -- you cannot change it yet
DB_FILE=db/doc_db.db
test -d $(dirname "$DB_FILE") || mkdir $(dirname "$DB_FILE") || exit 98
test -f "$DB_FILE" || sqlite3 $DB_FILE < install/doc_db.sql
test -d incomming || mkdir incomming

case $1 in
	start)
		test -f popuser/popfile.pid ||
			./run_local.sh perl start_pop.pl $PWD  || exit 96
		./run_local.sh perl client_srv.pl 0.0.0.0:28080 || exit 95
		;;
	stop)
		test -f popuser/popfile.pid &&
			kill $(cat popuser/popfile.pid)
		;;
	uninstall)
		test -f popuser/popfile.pid &&
			kill $(cat popuser/popfile.pid)
		rm -rf "$(dirname "$DB_FILE")" incomming
		rm -f /tmp/doc_cache.db* /tmp/documentix.*.lock
		rm -rf popuser/popfile.db popuser/messages
		echo "All databases have been removed"
		;;
	*)
		echo "Documentix ready to be started"
		;;
esac



exit 0

#######  UNSUPPORTED currently 
INSTDIR=/var/db/pdf
INSTUSER=documentix
INSTGROUP=www-data

case $1 in
 install)
        ( cd tools || exit 99; find . -type l | while read F ; do ln $(which "$F") ./"$F.new" && rm $F && mv "$F.new" "$F" || exit 98;done) || exit 99
	# cehck requirements:
	egrep -rah '^use\W.*;\s*$'  . | sort -u  | perl -Idoclib -c - || exit 99
	sudo mkdir -p  $INSTDIR
	sudo useradd  -d $INSTDIR $INSTUSER 
	sudo chsh -s /bin/false $INSTUSER
	sudo chown $INSTUSER.$INSTGROUP $INSTDIR
	sudo chmod 3775 $INSTDIR
	sudo -u $INSTUSER tar xzf install/popfile.tar.gz -C $INSTDIR
	sudo -u $INSTUSER tar xzf install/popuser.tar.gz -C $INSTDIR

	sudo -u $INSTUSER sqlite3 $INSTDIR/doc_db.db '.read install/doc_db.sql'
	sudo -u $INSTUSER $INSTDIR/start_pop.pl
	sudo  -u $INSTUSER perl install/add_user.pl
	sudo chmod 664 $INSTDIR/doc_db.db 

	echo "Run simple test"
	sh install/test_1.sh
	echo "Please configure popfile @http://localhost:8080"
	if type firefox ; then
		firefox http://localhost:8080
	fi

        echo DONE
	;;
 uninstall)
	sudo -u $INSTUSE$INSTUSER pkill -U $INSTUSER -f   popfile 
	sudo userdel $INSTUSER
	sudo rm -r $INSTDIR
	;;
	*)  echo "Usage install|uninstall"
	false
	;;
esac

