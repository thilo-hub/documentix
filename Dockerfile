FROM ubuntu:latest
MAINTAINER thilo-hub@nispuk.com
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update &&  apt-get install -y sqlite3 libdbd-sqlite3-perl  \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 imagemagick unoconv poppler-utils
RUN apt-get install -y calibre-bin
RUN apt-get install -y a2ps libjson-perl
RUN apt-get install -y zbar-tools libgd-barcode-perl  exiftool qpdf
RUN apt-get install -y unzip
RUN apt-get install -y  libjs-popper.js libmojolicious-perl libminion-perl libmojo-sqlite-perl libminion-backend-sqlite-perl
RUN apt-get install -y  tesseract-ocr tesseract-ocr-deu  tesseract-ocr-eng

#fix minion??
RUN rm -f  /usr/share/javascript/popper.js
RUN cp /usr/share/nodejs/popper.js/dist/umd/popper.js /usr/share/javascript/popper.js
WORKDIR /build
COPY build_local.sh .
RUN apt-get install -y git make gcc wget
RUN  sh build_local.sh /
RUN apt-get remove  -y git make gcc wget
RUN rm -r /build

##TJ 
##TJ # Either use git
##TJ RUN apt-get -y install git
##TJ ADD https://api.github.com/repos/thilo-hub/documentix/git/refs/heads/master version.json
##TJ RUN git clone --depth 1 https://github.com/thilo-hub/documentix
##TJ 
##TJ # OR git-zip file
##TJ # ADD https://github.com/thilo-hub/documentix/archive/master.zip
##TJ 
##TJ # OR local directory
WORKDIR /documentix
ADD . /documentix
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
