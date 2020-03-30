#!/bin/sh
INST="$(cd $(dirname $(which $0)); pwd)";

export PERL5LIB=$INST;
export POPFILE_ROOT=$INST/popfile 

DEFAULT_DB=db/doc.db
DEFAULT_POPUSER=db/popuser


if [ -d db/popuser ]; then

	(cd $DEFAULT_POPUSER &&  perl  $POPFILE_ROOT/popfile.pl )&
	sleep 1 && 
	test -f db/.firstrun || 
          ($INST/load_documents.pl  $INST/Documentation/FirstRun.pdf && touch db/.firstrun)
	perl  $INST/client_srv.pl 
else
	echo "No install available"
	echo "Create installation"
	
	mkdir db || exit 99
	$INST/conf_op.pl database $DEFAULT_DB
        mkdir -p "$($INST/conf_op.pl local_storage)"
	$INST/conf_op.pl "cache_db" "db/doc_cache.db"
	XMLPORT=$($INST/conf_op.pl xmlrpc_port)
	PORT2=$(($XMLPORT +1))
	
	sqlite3 $DEFAULT_DB  <$INST/install/doc_db.sql
	mkdir $DEFAULT_POPUSER && 
		sed "s/xmlrpc_port .*/xmlrpc_port $XMLPORT/; s/html_port .*/html_port $PORT2/" $INST/install/popuser_default.cfg > $DEFAULT_POPUSER/popfile.cfg  
	INF=$($INST/conf_op.pl server_listen_if)
	echo
	echo "Please manually recheck the created configuration in: $DEFAULT_POPUSER/popuser_default.cfg  and Docconf.js"
	echo and restart and connect to: "http://$INF" to complete configuration
	kill $PID
	wait
fi


#wait
