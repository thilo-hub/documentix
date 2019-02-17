#!/bin/sh
# adjust the variables below to suit your system

# To access your local DOCUMENTS through http://localhost:8888
# Documents will be found under the Documents folder below 
# Work-space for uploaded and ocr'd documents is in incoming
# New documents (drag&drop) will be stored in .../incoming/
#use:

DOCUMENTS=$PWD/Documents
INCOMING=$PWD/incoming
PORT="127.0.0.1:28080"
PORT2="127.0.0.1:28081"

test -d "$INCOMING" || mkdir "$INCOMING"

echo "Documents: $DOCUMENTS"
echo "Incoming: $INCOMING"
# --entrypoint bash -ti \
docker run -p $PORT:80/tcp  -p $PORT2:18080/tcp \
	--rm --detach \
	--mount type=bind,src=$DOCUMENTS,dst=/documentix/Documents/Documents,readonly \
	--mount type=bind,src=$INCOMING,dst=/documentix/Documents/incoming  \
	--volume Database:/documentix/db\
	--name documentix \
	thiloj/documentix

echo "Use 'docker logs documentix' to see internal ongoings"
echo "Please goto:  http://$PORT2 to view the Popfile classifier"
echo "Please goto:  http://$PORT to view the Documentix database"


