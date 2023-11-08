FROM ubuntu:22.04
MAINTAINER thilo-hub@nispuk.com
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update --fix-missing
RUN apt-get update --fix-missing
RUN  apt-get install -y \
	git \
	make \
	gcc \
	wget \
	libhtml-template-perl \
	libdigest-md5-file-perl \
	libxmlrpc-lite-perl \
	libjson-perl \
	libfile-libmagic-perl \
	libgd-barcode-perl \
	libjs-bootstrap4 \
	libjs-popper.js \
	libpdf-api2-perl \
	a2ps \
	imagemagick \
	poppler-utils \
	calibre-bin \
	zbar-tools \
	exiftool \
	unzip \
	qpdf \
	tesseract-ocr \
	tesseract-ocr-deu \
	tesseract-ocr-eng \
	pandoc \
	wkhtmltopdf \
	sqlite3 

ENV LC_CTYPE=C.UTF-8
RUN  cpan  -T Archive::Libarchive::Extract DBD::SQLite  Minion::Backend::SQLite

RUN apt-get install -y  pip
RUN apt-get install -y  ure-java libreoffice-nogui
RUN pip3 install unoserver
RUN apt-get update --fix-missing

##- 
WORKDIR /documentix
RUN git clone --shallow-submodules --depth 1 -b playLayout https://github.com/thilo-hub/documentix /documentix
# ADD . /documentix
ADD ./build_local.sh .
RUN sh ./build_local.sh /usr

ADD https://api.github.com/repos/thilo-hub/documentix/git/refs/heads/mojofw /version.json

ADD ./migrate_database.sql .
LABEL version="0.94"
LABEL description="documentix provides a document management system\
connect the port 18080 of this docker to any port you want \
Add persistent volume for the database and the documents, optionally the upload folder can be mounted elsewhere"

WORKDIR /volumes
RUN cp /documentix/documentix.conf.tmpl documentix.conf
RUN chown 1000:1000 /.
VOLUME Database:/volumes/db
VOLUME Documents:/volumes/Docs
# Main GUI interface
EXPOSE 80
ENV HOME=/volumes/Docs
##TJ ENTRYPOINT /documentix/documentix.sh
ENTRYPOINT test -r Docs/documentix.conf && cp Docs/documentix.conf . ; perl /documentix/script/documentix daemon -l http://*:18080
