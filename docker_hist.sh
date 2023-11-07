#!/bin/sh
IMAGE="thiloj/documentix"
ARM="$IMAGE:buildcache-arm64"
AMD="$IMAGE:buildcache-amd64"


# Rebuild arm64 and amd64 and upload
docker buildx build --cache-from $ARM  --platform=linux/arm64 --cache-to $ARM -t $IMAGE:latest -f Dockerfile.t  --load  .
docker buildx build --cache-from $AMD  --platform=linux/amd64 --cache-to $AMD -t $IMAGE:latest -f Dockerfile.t  .
docker buildx build --cache-from $ARM --cache-from $AMD -t $IMAGE:latest --platform=linux/amd64,linux/arm64 -f Dockerfile.t  --push .

# How to run
DOCS="$PWD/Documents.a"
DB="database"
PORT="18080"

echo "Start instance for example like:"
echo "docker run -ti -p $PORT:18080 -v $DB:/volumes/db -v $DOCS:/volumes/Docs --rm --name documentix thiloj/documentix:latest"

echo "And then connect using:"
echo "http://localhost:$PORT"
