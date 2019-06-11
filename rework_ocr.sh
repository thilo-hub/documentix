#!/bin/sh

mkdir obsolete
DIR="$PWD/Documents/*/*"
find $DIR -name '*.ocr.pdf' | 
	while read F ; do
	BD="$(dirname "$F")"
	MD5="$(basename "$BD")"

        EX="$(pdfinfo "$F")"
	if echo $EX | grep $MD5 ; then
		echo "File OK"
	else
		echo "Need update"
		mkdir "obsolete/$MD5"
		mv "$F" "obsolete/$MD5/."
		ORIG="$(./run_local.sh perl tests/test_getfname.pl "$MD5")"
		sqlite3 db/doc_db.db "delete from hash where md5='$MD5'"
		if [ -r "$ORIG" ]; then
			./run_local.sh perl tests/test_index_pdf.pl "$ORIG" >>log.out
		else
			echo "File gone...  $ORIG"
		fi
	fi
done



