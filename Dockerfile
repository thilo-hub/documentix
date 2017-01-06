From ubuntu:latest
maintainer thilo-hub@nispuk.com
RUN apt-get update &&  apt-get install -y sqlite3 libdbd-sqlite3-perl  \
	 libhtml-template-perl  libdigest-md5-file-perl \
	 libxmlrpc-lite-perl\
	 tesseract-ocr tesseract-ocr-deu tesseract-ocr-equ \
	 imagemagick unoconv poppler-utils
RUN apt-get install -y calibre-bin

# Either use git
# RUN apt-get -y install git 
# RUN git clone https://github.com/thilo-hub/documentix

# OR git-zip file
# ADD https://github.com/thilo-hub/documentix/archive/master.zip

# OR local directory
ADD . documentix

RUN  documentix/run_local.sh install/install.sh 
ENTRYPOINT documentix/run_local.sh install/install.sh start

EXPOSE 18080
EXPOSE 28080

