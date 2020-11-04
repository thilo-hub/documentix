#/bin/sh

#Build and install tools that are needed but not (yet) available as pre-build

DEST="$1";
test -d $DEST || mkdir $DEST
perl -MCPAN  -e 'get "I/IS/ISHIGAKI/DBD-SQLite-1.66.tar.gz"' && 
	tar xf /root/.cpan/sources/authors/id/I/IS/ISHIGAKI/DBD-SQLite-1.66.tar.gz && 
	cd DBD-SQLite-1.66/ &&
	wget https://www.sqlite.org/2020/sqlite-amalgamation-3330000.zip &&  
	unzip -j -o  sqlite-amalgamation-3330000.zip &&
	perl Makefile.PL  && 
	make && 
	make DESTDIR=$DEST  install &&
	git clone --depth 1 https://github.com/abiliojr/fts5-snowball.git &&
	cd fts5-snowball/ &&  
	(cd snowball/ &&  git clone --depth 1 https://github.com/snowballstem/snowball.git .) && 
	make SQLITE_FLAGS="-I$PWD/.." && 
	mkdir -p $DEST/usr/lib  && 
	cp fts5stemmer.so $DEST/usr/lib/.



