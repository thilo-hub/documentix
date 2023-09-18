#/bin/sh

#Build and install tools that are needed but not (yet) available as pre-build

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
	gmake SQLITE_FLAGS="-I/usr/local/include" && 
	sudo cp fts5stemmer.so $DEST/usr/local/lib/.
	cd .. &&
	git submodule deinit --all



