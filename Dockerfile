FROM ubuntu:latest
MAINTAINER thilo-hub@nispuk.com
RUN DEBIAN_FRONTEND=noninteractive apt-get update &&  apt-get install -y sqlite3 libdbd-sqlite3-perl  \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 imagemagick unoconv poppler-utils
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y calibre-bin
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y a2ps libjson-perl
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y zbar-tools libgd-barcode-perl  exiftool qpdf

#uncomment if you have a locally compiled tesseract version
#COPY locals/tess_bin.tar.gz /
RUN test -f /tess_bin.tar.gz && tar xf /tess_bin.tar.gz -C /usr  && rm /tess_bin.tar.gz || true

RUN which tesseract || apt-get install -y  tesseract-ocr tesseract-ocr-deu  tesseract-ocr-eng

# Either use git
RUN apt-get -y install git
ADD https://api.github.com/repos/thilo-hub/documentix/git/refs/heads/master version.json
RUN git clone --depth 1 https://github.com/thilo-hub/documentix

# OR git-zip file
# ADD https://github.com/thilo-hub/documentix/archive/master.zip

# OR local directory
# ADD . documentix

LABEL version="0.92"
LABEL description="documentix provides a document management system\
 connect the port 80 of this docker to any port you want \
 Add persistent volume for the database and the documents, optionally the upload folder can be mounted elsewhere"



WORKDIR /volumes
ENV PERL5LIB=/documentix
RUN /documentix/conf_op.pl server_listen_if "0.0.0.0:80" ;\
 /documentix/conf_op.pl cgi_enabled 1 ;\
 /documentix/conf_op.pl debug 2 ;\
 /documentix/conf_op.pl number_ocr_threads 4 ;\
 /documentix/conf_op.pl number_server_threads 4
RUN /documentix/documentix.sh
ENV DOCUMENTIX_CONF=/volumes/db/config.js
RUN mv Docconf.js $DOCUMENTIX_CONF

VOLUME Database:/volumes/db
VOLUME incomming:/volumes/Documents/incomming
VOLUME Documents:/volumes/Documents

EXPOSE 18080
# Main GUI interface
EXPOSE 80
ENTRYPOINT /documentix/documentix.sh

