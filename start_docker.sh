#!/bin/sh
# adjust the variables below to suit your system


# Read-only document folder
DOCUMENTS=$PWD/Documents
# Location for uploaded and processed documents
INCOMING=$PWD/incoming
# Main web interface
PORT="127.0.0.1:28080"
# Access popfile (not needed usually)
PORT2="127.0.0.1:28081"

test -d "$INCOMING" || mkdir "$INCOMING"

echo "Documents: $DOCUMENTS"
echo "Incoming: $INCOMING"

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


