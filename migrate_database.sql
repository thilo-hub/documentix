# Migrate database and clean up 
.load fts5stemmer

.bail on
-- .echo on
.mode box

create temporary view db_stat(Value,'Table')  as
    select value "-" , 'DB Version' tab  from config where var = 'dbversion' union all
    select count(*) cnt,'Metdata' tab from metadata union all
	select count(*) ,'Files' from file union all
	--select format('%3.3f',(sum(length(content)))/1e6), 'Mb Text' from m_text union all
	select count(*) ,'hash' from hash union all
	select count(*) ,'Tags' from tagname union all
	select count(*) ,'Dates' from dates union all
	select count(*),'config' R from config union all
	select count(*),'classes' R from classes union all
	select count(*),'tags' R from tags union all
	select count(*),'dates' R from dates union all
	select count(*),'doclabel' R from doclabel union all
	select count(*),'mtime' R from mtime union all
	select count(*),'mylog' R from mylog union all
	select count(*),'cache_q' R from cache_q union all
	select count(*),'cache_lst' R from cache_lst;

create temporary view odb_stat(Value,'Table')  as
    select value "-" , 'DB Version' tab  from other.config where var = 'dbversion' union all
        select count(*) cnt,'Metdata' tab from other. metadata union all
	select count(*) ,'Files' from other. file union all
	select format('%3.3f',(sum(length(content)))/1e6), 'Mb Text' from m_text union all
	select count(*) ,'hash' from other. hash union all
	select count(*) ,'Tags' from other. tagname union all
	select count(*) ,'Dates' from other. dates union all
	select count(*),'config' R from other. config union all
	select count(*),'classes' R from other. classes union all
	select count(*),'tags' R from other. tags union all
	select count(*),'dates' R from other. dates union all
	select count(*),'doclabel' R from other. doclabel union all
	select count(*),'mtime' R from other. mtime union all
	select count(*),'mylog' R from other. mylog union all
	select count(*),'cache_q' R from other. cache_q union all
	select count(*),'cache_lst' R from other. cache_lst;

.print "Other:"
select * from odb_stat;


--.echo on
PRAGMA trusted_schema=1;
.print "Import data"

begin transaction;
insert into main.config select * from other.config;

insert into main.file(md5,file) select md5,file from other.file;
insert into main.tagname(tagid,tagname) select tagid,tagname from other.tagname;
insert into main.metadata(idx,tag,value) select h.idx,tag,value from other.hash oh natural join other.metadata join hash h using (md5) group by h.idx,tag ;
insert into main.dates(idx,mtext,date) select h.idx,mtext,date from other.hash oh natural join other.dates join hash h using (md5);
insert into main.tags(idx,tagid) select h.idx,tagid from other.hash oh natural join other.tags join hash h using (md5);
insert into main.config(var,value) values('DB Updgrade','1');
update main.config set value = value+1 where var = 'dbversion';
commit;
.print "New:"
select "Table",a.Value,b.Value,iif(a.Value = b.Value,'=','<>') OK  from db_stat a join odb_stat b using("Table");

.quit

