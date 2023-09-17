#/bin/sh

#Build and install tools that are needed but not (yet) available as pre-build

DEST="$1";
test -d $DEST || mkdir $DEST
SQLSRC="https://www.sqlite.org/2023/sqlite-amalgamation-3430100.zip"


cpan -g DBD::SQLite 
test -r DBD-SQLite-*.tar.gz &&
	tar xvfz DBD-SQLite*.tar.gz && rm -f DBD-SQLite*.tar.gz &&
	cd DBD-SQLite* &&
	wget "$SQLSRC"  &&  
	unzip -j -o  "$(basename "$SQLSRC")" &&
	perl Makefile.PL  && 
	make && 
	make DESTDIR=$DEST  install &&
	git clone --recursive --depth 1 https://github.com/abiliojr/fts5-snowball.git &&
	cd fts5-snowball/ &&  
	make SQLITE_FLAGS="-I$PWD/.." && 
	mkdir -p $DEST/usr/lib  && 
	cp fts5stemmer.so $DEST/usr/lib/.



