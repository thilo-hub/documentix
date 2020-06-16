.read b
.read db_schema.sql
.header on
insert into file (md5,file,host)  select md5,file,"import"  from export_files;
insert into metadata (idx,tag,value) select idx,tag,value from export_files natural join hash natural join export_data;
insert or ignore into tagname (tagname) select distinct(value) from export_data where tag="Class";
insert into tags (tagid,idx) select tagid,idx from export_data natural join hash join tagname on (value == tagname);
.once a
.dump
