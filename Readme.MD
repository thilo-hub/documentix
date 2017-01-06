
#Purpose

This program presents a web-page that servers as a front-end to a "docuemnt-db"  (sqlite)

The page allows to search, classify and view the documents ( IMPORTANT: simple and fast )

It also allows to drag & drop new documents to add to the db


# more in depth....

It is a perl based server implementation (standalone)   
  --- there are probably a few left-over cgi files from a previous apache based version.
  ---- but this has been abandoned because "important" documents are not always on "some" server,
  ---- and I want it to be run almost stand-alone

# Installation:

Typically from the main directory run the script:

sh install/install.sh 
 --- it is currently at a minimum functionality
 and only create the database and a drop-direcotry

YOU WILL NEED lots of packages, unfortunatly it is currently a trial-and-error to find all you need
A complete list for a ubuntu is in the Dockerfile


The trial-and error or

# HOW TO RUN the tool:

sh install/install.sh start


  -- starts popfile and server
  --  waits for ^C to terminate both

-- Navigate to:
    http://localhost:28080      <- Search page
    http://localhost:18080      <- Popfile manager

Connect to the server with the browser (Chrome & Safari are tested)


Drag some pdf or word or ppt to the "drop-box"

....

Manually load a file into the database:
perl test_index_pdf.pl {file(s)}


