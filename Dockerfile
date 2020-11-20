FROM ubuntu:latest
MAINTAINER thilo-hub@nispuk.com
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update 
RUN  apt-get install -y sqlite3 \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 imagemagick unoconv poppler-utils \
	calibre-bin \
	a2ps libjson-perl \
	zbar-tools libgd-barcode-perl  exiftool qpdf \
	unzip \
	libjs-bootstrap4 libjs-popper.js libmojolicious-perl libminion-perl libmojo-sqlite-perl libminion-backend-sqlite-perl \
	tesseract-ocr tesseract-ocr-deu  tesseract-ocr-eng

#fix minion??
RUN rm -f  /usr/share/javascript/popper.js
#RUN cp /usr/share/nodejs/popper.js/dist/umd/popper.js /usr/share/javascript/popper.js
WORKDIR /build
RUN apt-get install -y git make gcc wget

ADD https://api.github.com/repos/thilo-hub/documentix/git/refs/heads/mojofw version.json
#ADD . /documentix
RUN git clone --depth 1 -b mojofw https://github.com/thilo-hub/documentix /documentix
WORKDIR /documentix
RUN  sh build_local.sh /
#RUN apt-get remove  -y git make gcc wget
RUN rm -r /build
LABEL version="0.93"
LABEL description="documentix provides a document management system\
 connect the port 80 of this docker to any port you want \
 Add persistent volume for the database and the documents, optionally the upload folder can be mounted elsewhere"


WORKDIR /volumes
RUN cp /documentix/documentix.conf.tmpl documentix.conf
VOLUME Database:/volumes/db
VOLUME Documents:/volumes/Docs
#EXPOSE 18080
# Main GUI interface
EXPOSE 80
##TJ ENTRYPOINT /documentix/documentix.sh
##TJ 
ENTRYPOINT perl /documentix/script/documentix daemon -l http://*:80
