#!/bin/sh
URL="http://localhost:9900/upload"

F=data/SCN_0162.pdf
F=data/asia-18-Wetzels_Abassi_dissecting_qnx__PPT.pdf
bn=$(basename "$F")
md5=$(md5 -q "$F")
sqlite3 db/doc_db.db  "delete from hash where md5 in (select md5 from file where file like 'uploads/%' group by md5)"; 
rm -fr uploads/*; 


# sqlite3 db/doc_db.db "delete from hash where md5='$md5'"
#curl --data-binary @$F   -H "X-File-Name: $bn" $URL &

 #exit
mkdir out
ARGS=""
N=1;
for F in data/* ; do 
   curl  --data-binary "@$F" -H "X-File-Name: $(basename "$F")" $URL | 
   jq -C >out/$N &
N=$(($N+1))
done

