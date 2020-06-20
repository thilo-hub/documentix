--.timer on
--.echo on
attach "db.old/doc_db.db" as old;
create temporary table missing as select idx,md5 from old.hash;
begin transaction;
create temporary table export_data  as select md5,tag,value from  missing natural join old.metadata;
create temporary table export_files as select md5,file from  missing natural join old.file;
select count(*) export_data from export_data;
select count(*) export_files from export_files;
create index ex_i1 on export_data(md5);
create index ex_i2 on export_files(md5);
end transaction;
detach old;

pragma journal_mode=wal;
.read SQL/db_schema.sql


.once trigger.create.sql
select sql ||";" from sqlite_master where type = "trigger";
.once trigger.delete.sql
select "drop trigger '"||name||"';" from sqlite_master where type = "trigger";
.read trigger.delete.sql

.header on

insert into file (md5,file,host)  select md5,file,"import"  from export_files;
insert into hash (md5,refcnt) select md5,count(*) refcnt  from file group by md5;

insert into metadata (idx,tag,value) select idx,tag,value from (select distinct(md5) md5 from export_files )  
               natural join hash natural join export_data;

INSERT INTO "text"(rowid,docid, content) select rowid,idx, value from metadata where tag = "Text";
insert into mtime (idx,mtime) select idx,cast(value as integer) from metadata where tag = "mtime";

insert or ignore into tagname (tagname) select distinct(value) from export_data where tag="Class";
insert or ignore into tags (tagid,idx) select tagid,idx from export_data natural join hash join tagname on (value == tagname);

.read trigger.create.sql


select count(md5) from hash;
select count(file) from file;
select tag,count(tag) from metadata group by tag;
select count(tagname) from tagname;
