FROM ubuntu:latest
MAINTAINER thilo-hub@nispuk.com
RUN apt-get update &&  apt-get install -y sqlite3 libdbd-sqlite3-perl  \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 tesseract-ocr tesseract-ocr-deu tesseract-ocr-equ \
	 imagemagick unoconv poppler-utils
RUN apt-get install -y calibre-bin
RUN apt-get install -y a2ps

# Either use git
RUN apt-get -y install git 
RUN apt-get -y install libjson-perl
RUN git clone https://github.com/thilo-hub/documentix

# OR git-zip file
# ADD https://github.com/thilo-hub/documentix/archive/master.zip

# OR local directory
# ADD . documentix

WORKDIR /documentix
ENV DOCUMENTIX_CONF=/documentix/db/config.json

LABEL version="0.9"
LABEL description="documentix provides a document management system\
 connect the port 80 of this docker to any port you want \
 Add persistent volume for the database and the documents, optionally the upload folder can be mounted elsewhere"


RUN ./run_local.sh install/install.sh  ;\
	 ./conf_op.pl server_listen_if 0.0.0.0:80 ;\
	 ./conf_op.pl cgi_enabled 1 ;\
	 ./conf_op.pl "index_html" "index3.html"
ENTRYPOINT ./run_local.sh install/install.sh start

VOLUME Documents:/documentix/Documents
VOLUME incomming:/documentix/Documents/incomming
VOLUME database:/documentix/db

# popfile management interface
EXPOSE 18080  
  # Main GUI interface
EXPOSE 80

