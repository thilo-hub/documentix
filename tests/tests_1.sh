PORT="http://*:65000"
../script/documentix daemon -l $PORT &
BG=$!
sleep 4
curl -v --data-binary '@data.tar.gz' -H "X-File-Name: testdata.tar.gz" http://localhost:65000/upload
curl -v --data-binary '@data.zip' -H "X-File-Name: testdata.zip" http://localhost:65000/upload
perl  -I../lib -e 'BEGIN{ $Documentix::config=require "./documentix.conf";}  use Documentix::classifier; pdf_class_md5();'
perl  ../script/documentix get -M POST -f 'json_string={"op":"rem","md5":"b5681751a87cdd5dc1b79c89791a822f","tag":"WWW"}'  /tags
perl ../script/documentix get /docs/ico/b5681751a87cdd5dc1b79c89791a822f/a%20new%20pdf.ico > a

#Import a directory
tar xvfz Import.Dir.tar.gz -C Docs/.
curl http://localhost:65000/refresh

echo press enter to stop
read F
kill -INT $BG
wait
 pkill -f 'perl ../script/documenti'
 pkill -f popfile

echo Finish
