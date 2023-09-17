#!/bin/sh
cd /documentix/Documentation
NEWHOST="$1"
sed "s|\$HOST|$NEWHOST|g" Documentation.md >Documentix.md

tar cf /volumes/doc.tar Documentix.md assets/image-1.png 
cd /volumes
/documentix/script/documentix get -M POST /upload < doc.tar 
rm doc.tar
cd /documentix/Documentation
# hide assets
for F in assets/* ;do
	OLD=$(md5sum < $F)
	get -M POST   -f json_string='{"op":"add","md5":"'$OLD'","tag":"deleted"}'  /tags
done
