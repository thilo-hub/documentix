attach "/var/db/pdf/doc_db.db" as old;
attach "db/doc_db.db" as new;
create temporary table missing as select md5 from old.file where md5 not in (select md5 from new.file);
begin transaction;
create table export_data  as select md5,tag,value from  missing natural join old.hash natural join old.metadata;
create table export_files as select md5,file from  missing natural join old.file;
end transaction;
.dump
