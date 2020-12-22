FROM ubuntu:latest
MAINTAINER thilo-hub@nispuk.com
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update --fix-missing
RUN  apt-get install -y sqlite3 \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 imagemagick unoconv poppler-utils \
	calibre-bin \
	a2ps libjson-perl \
	libfile-libmagic-perl zbar-tools libgd-barcode-perl  exiftool qpdf \
	unzip \
	libjs-bootstrap4 libjs-popper.js libmojolicious-perl libminion-perl libmojo-sqlite-perl libminion-backend-sqlite-perl \
	tesseract-ocr tesseract-ocr-deu  tesseract-ocr-eng


RUN apt-get install -y	pandoc 
#fix minion??
RUN rm -f  /usr/share/javascript/popper.js
WORKDIR /build



RUN apt-get update --fix-missing
RUN apt-get install -y git make gcc wget
RUN wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb && apt-get install -y ./*.deb
ADD https://raw.githubusercontent.com/thilo-hub/documentix/mojofw/build_local.sh build_local.sh
RUN  sh build_local.sh /
RUN rm -r /build

ADD https://api.github.com/repos/thilo-hub/documentix/git/refs/heads/mojofw /version.json
WORKDIR /build
RUN git clone https://github.com/mojolicious/minion.git .
RUN perl Makefile.PL
RUN make install
RUN rm -r /build

WORKDIR /documentix
#ADD . /documentix
RUN git clone --depth 1 -b mojofw https://github.com/thilo-hub/documentix /documentix
#RUN apt-get remove  -y git make gcc wget
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
