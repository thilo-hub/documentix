#!/bin/sh

INSTDIR=/var/db/pdf
INSTUSER=documentix

case $1 in
 install)
	sudo mkdir $INSTDIR
	sudo useradd  -d $INSTDIR $INSTUSER 
	sudo chsh -s /bin/false $INSTUSER
	sudo chown $INSTUSER.www $INSTDIR
	sudo chmod 3775 $INSTDIR
	sudo -u $INSTUSER tar xzf install/popfile.tar.gz -C $INSTDIR
	sudo -u $INSTUSER tar xzf install/popuser.tar.gz -C $INSTDIR

	sudo -u $INSTUSER sqlite3 $INSTDIR/doc_db.db '.read install/doc_db.sql'
	sudo -u $INSTUSER $INSTDIR/start_pop
	sudo  -u $INSTUSER perl install/add_user.pl
	sudo chmod 664 $INSTDIR/doc_db.db 

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
