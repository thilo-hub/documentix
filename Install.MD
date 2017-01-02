On a fresh Ubuntu you might need to run:

sudo apt-get install sqlite3 libdbd-sqlite3-perl  \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 tesseract-ocr tesseract-ocr-deu tesseract-ocr-equ \
	 imagemagick unoconv

install/install.sh start


To get things running.

quitting out of the install.sh causes the popfile to stop.

Automatically feeding the database with documents:
 perl start_pop.pl $PWD
 find /home -name '*.pdf' -print0 |
    xargs -0 load_documents.pl

BEWARE:  the tool will try to create {filename}.ocr.pdf files,
  in case the file does not contain enough characters.
This will horribly fail in read only directories
