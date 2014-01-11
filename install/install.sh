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
	;;
 uninstall)
	sudo userdel $INSTUSER
	sudo rm -r $INSTDIR
	;;
	*)  echo "Usage install|uninstall"
	false
	;;
esac
