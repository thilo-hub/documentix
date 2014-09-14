#!/bin/sh

INSTDIR=/var/db/pdf
INSTUSER=documentix
INSTGROUP=www-data

case $1 in
 install)
	# cehck requirements:
	egrep -rh '^use\W.*;\s*$'  . | sort -u  | perl -Idoclib -c - || exit 99
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

