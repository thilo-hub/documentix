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

INC="/usr/local/include"
test -d /root/.cpan/build/DBD-SQLite-1.74-0/ && INC=/root/.cpan/build/DBD-SQLite-1.74-0
DEST="$1";
test -d $DEST || mkdir $DEST
SQLSRC="https://www.sqlite.org/2023/sqlite-amalgamation-3430100.zip"


echo NO cpan -g DBD::SQLite 
echo NO test -r DBD-SQLite-*.tar.gz &&
	echo NO tar xvfz DBD-SQLite*.tar.gz && rm -f DBD-SQLite*.tar.gz &&
	echo NO cd DBD-SQLite* &&
	echo NO wget "$SQLSRC"  &&  
	echo NO unzip -j -o  "$(basename "$SQLSRC")" &&
	echo NO perl Makefile.PL  && 
	echo NO make && 
	echo NO make DESTDIR=$DEST  install &&
        git submodule init   &&
	git submodule update --init --recursive  &&
	cd fts5-snowball/ &&
	$MAKE SQLITE_FLAGS="-I$INC" && 
	cp fts5stemmer.so $DEST/usr/local/lib/.
	cd .. &&
	git submodule deinit --all



