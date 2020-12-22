#!/bin/sh

docker build -t thiloj/documentix .
docker run -v $PWD/X/Docs:/volume/Docs -v $PWD/X/db:/volume/db -v $PWD:/documentix -ti --entrypoint /bin/bash -p 8080:80 --name dx --rm thiloj/documentix
