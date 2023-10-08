#/bin/sh

# Docker builds like:
# docker buildx create --use --platform=linux/arm64,linux/amd64 --name multi-platform-builder\n
# docker buildx inspect --bootstrap
# docker buildx build   --tag thiloj/documentix --platform=linux/arm64,linux/amd64 --push  .
#
# or
# docker build -t thiloj/documentix .


#Build and install tools that are needed but not (yet) available as pre-build



#Build and install tools that are needed but not (yet) available as pre-build
MAKE=gmake
MAKE=make

DEST="$1";
INC="$(dirname "$(find / -name sqlite3ext.h | tail -1)")"

git submodule init   &&
git submodule update --init --recursive  &&
cd fts5-snowball/ &&
$MAKE SQLITE_FLAGS="-I$INC" && 
install -t $DEST/lib fts5stemmer.so &&
cd .. &&
git submodule deinit --all



