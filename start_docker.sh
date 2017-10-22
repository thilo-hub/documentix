#!/bin/sh
# adjust the variables below to suit your system

# To access your local DOCUMENTS through http://localhost:8888
# Documents will be found under the Documents folder below 
# Work-space for uploaded and ocr'd documents is in incoming
# New documents (drag&drop) will be stored in .../incoming/
#use:

DOCUMENTS=$PWD/Docs/Documents
INCOMMING=$PWD/incoming
PORT="127.0.0.1:8888"


echo "Documents: $DOCUMENTS"
echo "Incoming: $INCOMMING"
# --entrypoint bash -ti \
docker run -p $PORT:80  \
	--rm --detach \
	--mount type=bind,src=$DOCUMENTS,dst=/documentix/Documents/Documents,readonly \
	--mount type=bind,src=$INCOMMING,dst=/documentix/Documents/incoming  \
	--mount type=volume,source=Database,destination=/documentix/db\
	--name documentix \
	thiloj/documentix

echo "Please goto:  http://$PORT to view the Documentix database"


