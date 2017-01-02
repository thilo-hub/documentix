CREATE TABLE ocr ( idx integer, text text);
CREATE TABLE metadata ( idx integer, tag text, value text, unique ( idx,tag) );
CREATE TABLE "cache_old" (item text,idx integer,data blob,date integer, unique (item,idx));
CREATE TABLE classes (class text primary key unique, count integer);
CREATE TABLE class ( idx integer primary key, class text );
CREATE TABLE mtime ( idx integer primary key, mtime integer);
CREATE TABLE sessions (
	username                  varchar(127) not null,
	address                   varchar(255),
	ticket                    varchar(255),
	point                     varchar(255)
	);
CREATE TABLE Users (
	uid                       integer primary key autoincrement,
	login                     varchar(255) not null,
	passwd                    varchar(255) not null,
	Disabled                  char(1) default '0'
	);
CREATE TABLE Groups (
    gid                       integer primary key autoincrement,
    Name                      char(31) not null
    );
CREATE TABLE UserGroups (
    gid                       int not null,
    uid                       int not null,
    accessbit                 char(1) default '0' not null,
    constraint pk_UserGroups primary key (gid,uid)
    );
CREATE TABLE hash ( idx integer primary key autoincrement, md5 text unique, refcnt integer );
CREATE TABLE file ( md5 text, file text unique, host text);
CREATE TABLE ldates ( idx integer, date text, string text,unique  (idx,date));
CREATE TABLE tagname (tagid integer primary key autoincrement, tagname text unique);
CREATE TABLE tags (tagid integer,idx integer,constraint tagid unique (tagid,idx));
CREATE TABLE meta_tag (tagv integer primary key autoincrement,tag text unique);
CREATE TABLE data ( idx integer primary key , thumb text, ico text, html text);
CREATE TABLE "db.dates"(date INT,mtext TEXT,idx TEXT);
CREATE TABLE "dates"(date INT,mtext TEXT,idx TEXT);
CREATE TABLE cache_lst ( qidx integer primary key autoincrement,
		query text unique, nresults integer, last_used integer );
CREATE TABLE cache_q ( qidx integer, idx integer, id integer, snippet text, unique(qidx,idx));
CREATE TABLE nfile1(md5 TEXT,file);
CREATE VIRTUAL TABLE "text" using fts4;
CREATE INDEX file_md5 on file(md5);
CREATE INDEX class_i on class(class);
CREATE INDEX mtime_i on mtime(mtime);
CREATE INDEX idx_sessions on sessions (username);
CREATE INDEX idx_users on Users (login);
CREATE INDEX mtag  on metadata(tag);
CREATE INDEX tags_i on metadata(tag);
CREATE INDEX mtags on metadata(tag);
CREATE VIEW pages as select id,md5, snippet docn,qidx from cache_q natural join hash;
CREATE TRIGGER text_del after delete on metadata when old.tag = "Text" begin
	delete from text where docid=old.idx; 
    end;
CREATE TRIGGER text_ins after insert on metadata when new.tag = "Text" begin
	insert into text (docid,content) values (new.idx,new.value);
    end;
CREATE TRIGGER file_del before delete on file begin
	update hash set refcnt=refcnt-1 where hash.md5=old.md5;
	delete from hash where refcnt=0; 
    end;
CREATE TRIGGER mtime_del after delete on metadata when old.tag = "mtime" begin 
	delete from mtime where mtime.idx=old.idx;
    end;
CREATE TRIGGER mtime_ins after insert on metadata when new.tag = "mtime" begin 
	insert into mtime (idx,mtime) values (new.idx,new.value); 
    end;
CREATE TRIGGER class_del after delete on metadata when old.tag = "Class" begin 
	delete from class where class.idx=old.idx; 
    end;
CREATE TRIGGER class_ins after insert on metadata when new.tag = "Class" begin 
	insert into class (idx,class) values (new.idx,new.value); 
    end;
CREATE TRIGGER inmtime after insert on metadata when 
	                    new.tag = "mtime" begin 
			    insert into mtime (idx,mtime) values (new.idx,new.value); 
		end;
CREATE TRIGGER inclass after insert on metadata when 
	                    new.tag = "Class" begin 
			    insert into class (idx,class) values (new.idx,new.value); 
		end;
CREATE TRIGGER intxt after insert on metadata when new.tag = "text" begin 
			insert into text (docid,content) values (new.idx,new.value); 
					end;
CREATE TRIGGER file_ins after insert  on file begin
	insert or ignore into hash (md5,refcnt) values(new.md5,0);
	update hash set idx= case when refcnt = 0 then new.rowid else idx end ,refcnt=refcnt+1  where hash.md5=new.md5; 
    end;
CREATE TRIGGER cache_del before delete on cache_lst begin delete 
		from cache_q where cache_q.qidx = old.qidx ; 
	end;
drop trigger if exists hash_delete1;
drop trigger if exists del2;
CREATE TRIGGER del2 before delete on hash begin
                                        delete from file where file.md5 = old.md5;
                                        delete from data where data.idx = old.idx;
                                        delete from metadata where metadata.idx=old.idx;
                                        delete from text where docid=old.idx;
                                        delete from mtime where mtime.idx=old.idx;
                                        delete from tags where tags.idx=old.idx;
                                 end;
CREATE TABLE config (var primary key unique,value);
