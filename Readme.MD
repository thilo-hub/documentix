
#Purpose

This program presents a web-page that servers as a front-end to a "docuemnt-db"  (sqlite)

The page allows to search, classify and view the documents ( IMPORTANT: simple and fast )

It also allows to drag & drop new documents to add to the db


# more in depth....

It is a perl based server implementation (standalone)   
  --- there are probably a few left-over cgi files from a previous apache based version.
  ---- but this has been abandoned because "important" documents are not always on "some" server,
  ---- and I want it to be run almost stand-alone

Installation:

Typically from the main directory run the script:

sh install/install.sh
 --- it is currently at a minimum functionality
 and only create the database and a drop-direcotry

YOU WILL NEED lots of packages, unfortunatly it is currently a trial-and-error to find all you need


The trial-and error or

HOW TO RUN the tool:

#Start popfile -- it is needed for classification

 ./run_local.sh perl start_pop.pl $PWD


# Before adding files you must (manually) create at least one bucket in popfile
connect with the browser to localhost:18080
 navigate to Buckets
and add one


# Then start the server:
# Start it listening on all interfaces on port 8080
 ./run_local.sh perl client_srv.pl 0.0.0.0:8080


Alternatively it is possible to

install/install.sh start    --- which installs and starts popfile and the client_server on port 28080



Connect to the server with the browser (Chrome & Safari are tested)


Drag some pdf or word or ppt to the "drop-box"

....

