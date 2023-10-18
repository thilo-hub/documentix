.load fts5stemmer

-- cleanup of previous views/triggers....
DROP VIEW if exists m_pdfinfo;
DROP VIEW if exists m_size;
DROP VIEW if exists m_mime;
DROP VIEW if exists m_pages;
DROP VIEW if exists m_qr;
DROP VIEW if exists m_class;
DROP VIEW if exists m_content;
DROP VIEW if exists m_text;
DROP VIEW if exists m_archive;
DROP VIEW if exists idxfile;
DROP VIEW if exists taglist;
DROP VIEW if exists content;
DROP VIEW if exists pdfinfo;
DROP VIEW if exists mylog_cache_lst;
DROP VIEW if exists cache_q_stat;

DROP trigger if exists file_del;
DROP trigger if exists file_ins;
DROP trigger if exists hash_filerm;
DROP trigger if exists hash_hashrm;
DROP trigger if exists hash_hashrm2;
DROP trigger if exists metadata_au;
DROP trigger if exists metadata_ad;
DROP trigger if exists metadata_ai;
DROP trigger if exists mtime_del;
DROP trigger if exists mtime_ins;
DROP trigger if exists cache_del;
DROP trigger if exists cache_new;
DROP trigger if exists cache_hit;
DROP trigger if exists cache_fill;

CREATE TABLE if not exists config (var primary key unique,value);
CREATE TABLE if not exists file ( md5 text ,file blob unique, host text);
CREATE TABLE if not exists hash ( idx integer primary key autoincrement, md5 text unique, refcnt integer default 0);
CREATE TABLE if not exists metadata ( idx integer, tag text, value text, unique ( tag,idx) );
CREATE TABLE if not exists classes (class text primary key unique, count integer);
CREATE TABLE if not exists tags (tagid integer,idx integer,constraint tagid unique (tagid,idx));
CREATE TABLE if not exists tagname (tagid integer primary key autoincrement, tagname text unique);
CREATE TABLE if not exists dates (date DATE, mtext TEXT, idx INTEGER,unique(date,idx));
CREATE TABLE if not exists doclabel (idx INT, doclabel primary key unique);
CREATE TABLE if not exists mtime (idx INT,mtime INT);

CREATE INDEX if not exists tagsi on tags(tagid);
CREATE INDEX if not exists tagsii on tags(idx);
CREATE INDEX if not exists metadata_i on metadata(idx);
CREATE INDEX if not exists tags_i on metadata(tag);
CREATE INDEX if not exists flst on file(md5);
CREATE INDEX if not exists mtim1 on mtime(mtime);

CREATE VIEW m_pdfinfo              as select idx, value pdfinfo        from metadata where tag = 'pdfinfo' /* m_pdfinfo(idx,pdfinfo) */;
CREATE VIEW m_size(idx,size)       as select idx,cast(value as int)    from metadata where tag="size" /* m_size(idx,size) */;
CREATE VIEW m_mime                 as select idx,value mime            from metadata where tag='Mime' /* m_mime(idx,mime) */;
CREATE VIEW m_pages                as select idx,value pages           from metadata where tag='pages' /* m_pages(idx,pages) */;
CREATE VIEW m_qr                   as select idx,value QR              from metadata where tag='QR' /* m_qr(idx,QR) */;
CREATE VIEW m_class                as select idx,value class           from metadata where tag = 'Class' /* m_class(idx,class) */;
CREATE VIEW m_content              as select idx,value Content         from metadata where tag='Content' /* m_content(idx,Content) */;
CREATE VIEW m_archive              as select idx,value archive         from metadata where tag='archive';
CREATE VIEW m_text(docid,content)  as select idx ,value                from metadata where tag = 'Text' /* m_text(docid,content) */;
CREATE VIEW idxfile(idx,md5,file)  as select idx,md5,file              from hash natural join file /* idxfile(idx,md5,file) */;

CREATE VIEW taglist(idx,tags)      as select idx,group_concat(tagname) from tags natural join tagname group by idx /* taglist(idx,tags) */;

-- drop and recreate fts search
drop table if exists text;
CREATE VIRTUAL TABLE text using fts5(docid unindexed,content,  content='m_text', content_rowid='docid', tokenize = 'porter');
INSERT into text(text) values('rebuild');

-- Logging for debugging etc 
CREATE TABLE if not exists mylog (idx,md5,refcnt,time default CURRENT_TIMESTAMP);

-- trigger
CREATE TRIGGER file_del before delete on file begin update hash set refcnt=refcnt-1 where hash.md5=old.md5; end;
CREATE TRIGGER file_ins after insert  on file 
			begin insert or ignore into hash (md5,refcnt) values(new.md5,0); 
				update hash set idx= case when refcnt = 0 then hash.rowid else idx end ,
							refcnt=refcnt+1  where hash.md5=new.md5; 
			end;

CREATE TRIGGER hash_filerm after update of refcnt  on hash when new.refcnt = 0 begin delete from hash where idx=new.idx; end;
CREATE TRIGGER hash_hashrm after delete on hash 
			begin insert into mylog(idx,md5,refcnt,time) values( old.idx,old.md5,old.refcnt,datetime('now')); 
				delete from tags where idx=old.idx; 
				delete from metadata where idx=old.idx; 
			end;
CREATE TRIGGER hash_hashrm2 after delete on hash begin delete from doclabel where idx=old.idx; end;


CREATE TRIGGER metadata_au AFTER UPDATE ON metadata when old.tag = 'Text' BEGIN
			INSERT INTO "text"("text", rowid, content) VALUES('delete', old.idx,old.value);
			INSERT INTO "text"(rowid,content) values(new.idx,new.value);
			END;
CREATE TRIGGER metadata_ad AFTER DELETE ON metadata when old.tag = 'Text' BEGIN
			INSERT INTO "text"("text", rowid, content) VALUES('delete', old.idx,old.value);
			end;
CREATE TRIGGER metadata_ai AFTER INSERT ON metadata when new.tag = 'Text' BEGIN
			INSERT INTO "text"(rowid,content) values(new.idx,new.value);
			insert into cache_q (qidx,idx,snippet,rank) 
				select qidx,docid,snippet(text,1,'<b>','</b>','...',6) snip,rank   
					from cache_lst,text where text match query and docid = new.idx; 
			end;

CREATE TRIGGER mtime_del    after delete on metadata when old.tag = "mtime" begin delete from mtime where mtime.idx=old.idx; end;
CREATE TRIGGER mtime_ins    after insert on metadata when new.tag = "mtime" begin insert into mtime (idx,mtime) values (new.idx,new.value); end;

CREATE VIEW content as select * from m_content /* content(idx,Content) */;
CREATE VIEW pdfinfo as select * from m_pdfinfo /* pdfinfo(idx,pdfinfo) */;

-- Search result cache
CREATE TABLE if not exists cache_q ( qidx integer, idx integer, snippet text, rank float, primary key (qidx,idx));
CREATE TABLE if not exists cache_lst ( qidx integer primary key autoincrement,
                              query text unique, nresults integer, hits integer, last_used integer DEFAULT (unixepoch()));

CREATE VIEW mylog_cache_lst as
	select mylog.* from cache_lst join mylog on(idx='q'||qidx) order by mylog.rowid /* mylog_cache_lst(idx,md5,refcnt,time) */;

CREATE TRIGGER cache_del before delete on cache_lst begin delete from cache_q where cache_q.qidx = old.qidx ; end;

CREATE VIEW cache_q_stat(qidx,hits,nresults) as select qidx,count(*),sum(iif(snippet is null,0,1)) from cache_q group by qidx /* cache_q_stat(qidx,hits,nresults) */;

CREATE TRIGGER cache_new after insert on cache_lst when new.nresults is not null begin
	insert into mylog(idx,md5,refcnt) values('q'||new.qidx,'cache_new: ' || new.nresults,0);
	update cache_lst set hits = -1  where qidx = new.qidx;
end;
CREATE TRIGGER cache_hit  after update of hits on cache_lst when  not new.hits >= 0 begin
	insert into mylog(idx,md5) values('q'||new.qidx,'cache_hits '||ifnull(old.hits,"NULL")|| ' -> ' || new.hits);
	insert or replace into cache_q(qidx,idx,rank) select new.qidx,docid,rank from text where text match new.query;
	update cache_lst set hits=hit,nresults = -1  from (select nresults nr,hits hit from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
end;
CREATE TRIGGER cache_fill after update of nresults on cache_lst when new.nresults < 0 or (new.nresults > old.nresults and new.hits > old.nresults) begin
        insert into mylog(idx,md5) values('q'||new.qidx,'cache_fill: '||ifnull(old.nresults,"NULL")|| ' -> ' || new.nresults);
        update cache_q set snippet=snip2 from (
                select idx idx2,snippet(text,1,'<b>','</b>','...',5) snip2  
			from (select qidx,idx from cache_q where qidx=new.qidx and snippet is null
                                           order by rank
                                           limit iif(new.nresults < 0,old.nresults,new.nresults-old.nresults)
			)  join text on(docid=idx)
                where text match new.query
                ) where qidx=new.qidx and idx2 = idx;
        update cache_lst set nresults=nr from (select nresults nr from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
end;

