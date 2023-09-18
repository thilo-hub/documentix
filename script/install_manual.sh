#!/bin/sh
DOCEX=$(dirname "$0")/..
test -r documentix.conf || (echo "Must be run from Document folder" >&2;false) ||  exit 99
ln -s $DOCEX/Documentation Documentix

NEWHOST="$1"
sed "s|\$HOST|$NEWHOST|g" Documentix/Documentation.md >Documentix/Manual.md

tar cf doc.tar Documentix/Manual.md Documentix/assets

$DOCEX/script/documentix get -M POST /upload < doc.tar 
MD5="md5sum"
MD5="md5 -r"

for F in Documentix/assets/* ;do
	set $($MD5 "$F") --
	$DOCEX/script/documentix get -M POST   -f json_string='{"op":"add","md5":"'$1'","tag":"deleted"}'  /tags
done
rm doc.tar
rm Documentix
