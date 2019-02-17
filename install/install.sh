#!/bin/sh
INSTALL_V="Documentix V0.02 - alpha"
ERR=0;
OPT="$@"

test -f client_srv.pl || (echo "start in top-level directory --- ERROR" ;false) || exit 99

# This is defined somewhere else -- you cannot change it yet
DB_FILE="$(./conf_op.pl database)"
INDIR="$(./conf_op.pl local_storage)"
# Skip all lengthy tests if a instsall passed before
if [ -f .install_ok ] && [ "$(cat .install_ok)" = "$(cat version.txt)" ]; then
        echo "Skip tests"
else
	# Check required programms 
	
	/bin/echo -n "Test for: " ; which unoconv || (echo "Disable unoconv - no extra conversion available"; ./conf_op.pl unoconv_enabled 0  )
	/bin/echo -n "Test for: " ; which ebook-convert  || (echo "Disable ebook-convert  - no extra conversion available"; ./conf_op.pl ebook_convert_enabled  0  )
	/bin/echo -n "Test for: " ; which tesseract && 
                 tesseract -v | awk '/tesseract/{ sub("\\.",",");gsub("\\.",""); sub(",","."); i=$2; exit ( i < 3.0401 )}' ||
		(echo "FAILED: Need tesseract to OCR  pdfs -- New version 3.04 for pdf creation required " ; false) || ERR=90
	/bin/echo -n "Test for: " ; which pdftocairo || (echo "FAILED: Need pdftocairo from Poppler to help for OCR" ; false) || ERR=90
	/bin/echo -n "Test for: " ; which convert || (echo "FAILED: Need convert from ImageMagic  to help for OCR" ; false) || ERR=90
	test -d $(dirname "$DB_FILE") || mkdir $(dirname "$DB_FILE") || exit 98
	test -d "$INDIR" || mkdir -p "$INDIR"
	test -d popuser || ( mkdir popuser && cp install/popuser_default.cfg popuser/popfile.cfg )

echo "check the availability of required perl modules..."
# Filter out some false negatives
find . -name '*.p[lm]' -type f | egrep -v './local' | xargs cat | 
   ./run_local.sh perl -I. -Idates  -ne '
  use Docconf;
  $main::debug=0;
  BEGIN{
    %dm=( pdfidx =>1);
  }
  next unless s/^\s*(use|require) ([a-zA-Z0-9_:]+)[\s;].*/require $2/; next if $dm{$2}++; open(STDERR,">/tmp/a.log"); eval($_); print "Failed: $2\n" if $@;'  2>/dev/null|
# These are not really required.. so do not report them
egrep -v 'Failed: File::ChangeNotify
Failed: Email::MIME
Failed: POPFile::Module
Failed: POPFile::Loader
Failed: Proxy::Proxy
Failed: IO::Socket::Socks
Failed: UI::HTTP
Failed: File::Glob::Windows
Failed: POPFile::API
Failed: Services::IMAP::Client
Failed: Classifier::MailParse
Failed: POPFile::Mutex
Failed: BerkeleyDB
Failed: MeCab
Failed: Text::Kakasi' | tee /tmp/test.install.$$

	if [ -s /tmp/test.install.$$ ]; then
		ERR=89
	fi
	rm -f /tmp/test.install.$$


	if [ "$ERR" -eq 0 ]; then
		echo "Documentix ready to be started"
		cp version.txt .install_ok
	fi
fi


case $OPT in
	start)
		# Ensure db is there (or old db gets updated)
		if [ ! -r "$DB_FILE" ]; then
			test -f "$DB_FILE" || sqlite3 $DB_FILE < install/doc_db.sql
		fi
		DB_V="$(sqlite3 "$DB_FILE" 'select value  from config where var = "version"')"
		if [ ! -z "$DOCUMENTIX_CONF" -a ! -f "$DOCUMENTIX_CONF" -a -f Docconf.js ]; then
			cp Docconf.js "$DOCUMENTIX_CONF"
		fi
	        if [ -z "$DB_V" -o "$DB_V" '<' "$INSTALL_V" ]; then
			# Do all db-updates
			perl -I . tests/update_incoming.pl
			sqlite3 "$DB_FILE" "insert or replace into config (var,value) values('version','$INSTALL_V')"
		fi
		test -f popuser/popfile.pid ||
			./run_local.sh perl start_pop.pl $PWD  || exit 96
		test -f popuser/popfile.pid || exit 95
		echo " Add first document...."
		./run_local.sh ./load_documents.pl  Documentation/FirstRun.pdf   || exit 91
		./run_local.sh perl client_srv.pl || exit 95
		;;
	stop)
		test -f popuser/popfile.pid &&
			kill $(cat popuser/popfile.pid)
		;;
	uninstall)
		test -f popuser/popfile.pid &&
			kill $(cat popuser/popfile.pid)
		DB="$(dirname "$DB_FILE")" 
		test -d "$DB" && rm -rf "$DB"
		test -d "$INDIR" && rm -rf "$INDIR"
		test -d popuser && rm -r popuser
		rm -f .install_ok
		rm -f /tmp/doc_cache.db* /tmp/documentix.*.lock
		echo "All databases have been removed"
		;;
esac



exit $ERR


