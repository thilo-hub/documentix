#!/bin/sh
INSTALL_V="Documentix V0.01 - alpha"
ERR=0;

test -f client_srv.pl || (echo "start in top-level directory --- ERROR" ;false) || exit 99

# This is defined somewhere else -- you cannot change it yet
DB_FILE=db/doc_db.db
# Skip all lengthy tests if a instsall passed before
if [ -f .install_ok ] && [ "$(cat .install_ok)" == "$(cat version.txt)" ]; then
        echo "Skip tests"
else
	# Check required programms 
	
	echo -n "Test for: " ; which unoconv || (echo "Need unoconv from Libreoffice to convert things to PDF" ; false) || ERR=90
	echo -n "Test for: " ; which tesseract && pkg-config --atleast-version 3.04  tesseract  ||
							(echo "Need tesseract to OCR  pdfs -- New version 3.04 for pdf creation required " ; false) || ERR=90
	echo -n "Test for: " ; which pdftocairo || (echo "Need pdftocairo from Poppler to help for OCR" ; false) || ERR=90
	echo -n "Test for: " ; which convert || (echo "Need convert from ImageMagic  to help for OCR" ; false) || ERR=90
	test -d $(dirname "$DB_FILE") || mkdir $(dirname "$DB_FILE") || exit 98
	test -f "$DB_FILE" || sqlite3 $DB_FILE < install/doc_db.sql
	test -d incomming || mkdir incomming
	test -d popuser || ( mkdir popuser && cp install/popuser_default.cfg popuser/popfile.cfg )

echo "check the availability of required perl modules..."
# Filter out some false negatives
find . -name '*.p[lm]' -type f | egrep -v './local' | xargs cat | 
   ./run_local.sh perl -Idates  -ne '
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


case $1 in
	start)
		test -f popuser/popfile.pid ||
			./run_local.sh perl start_pop.pl $PWD  || exit 96
		test -f popuser/popfile.pid || exit 95
		echo " Add first document...."
		./run_local.sh ./load_documents.pl  Documentation/FirstRun.pdf   || exit 91
		./run_local.sh perl client_srv.pl 0.0.0.0:28080 || exit 95
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
		test -d incomming && rm -rf incomming
		test -d popuser && rm -r popuser
		rm -f .install_ok
		rm -f /tmp/doc_cache.db* /tmp/documentix.*.lock
		echo "All databases have been removed"
		;;
esac



exit $ERR


