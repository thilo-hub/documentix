PORT="http://localhost:65000"
../script/documentix daemon -l $PORT &
BG=$!
sleep 4
perl  -I../lib -e 'BEGIN{ $Documentix::config=require "./documentix.conf";}  use Documentix::classifier; pdf_class_md5();'
perl  ../script/documentix get -M POST -f 'json_string={"op":"rem","md5":"0c294f6e80f1e5dfe27fbf74027154f3","tag":"WWW"}'  /tags
perl ../script/documentix get /docs/ico/aa96e95cbe71de105e7d51388b334ad8/a%20new%20pdf.ico > a

kill -INT $BG
wait
 pkill -f 'perl ../script/documenti'
 pkill -f popfile
