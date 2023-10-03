CREATE TABLE metadata ( idx integer, tag text, value text, unique ( idx,tag) );
CREATE TABLE classes (class text primary key unique, count integer);
CREATE TABLE mtime ( idx integer primary key, mtime integer);
CREATE TABLE tags (tagid integer,idx integer,constraint tagid unique (tagid,idx));
CREATE TABLE data ( idx integer primary key , thumb text, ico text, html text);
CREATE TABLE ocr ( idx integer, text text);
CREATE TABLE cache_lst ( qidx integer primary key autoincrement,
			query text unique, nresults integer, last_used integer );
CREATE TABLE cache_q ( qidx integer, idx integer, snippet text, unique(qidx,idx));
CREATE TABLE config (var primary key unique,value);
CREATE TABLE tagname (tagid integer primary key autoincrement, tagname text unique);
CREATE TABLE IF NOT EXISTS "dates"(date DATE, mtext TEXT, idx INTEGER,unique(date,idx));
CREATE TABLE file ( md5 text ,file blob unique, host text);
CREATE TABLE hash ( idx integer primary key autoincrement, md5 text unique, refcnt integer default 0);
CREATE INDEX mtime_i on mtime(mtime);
CREATE INDEX tagsi on tags(tagid);
CREATE INDEX cache_qi on cache_q(qidx);
CREATE VIEW ftime as select idx,value mtime  from metadata where tag='mtime'
/* ftime(idx,mtime) */
/* ftime(idx,mtime) */
/* ftime(idx,mtime) */;
CREATE VIEW content as select idx,value Content from metadata where tag='Content'
/* content(idx,Content) */
/* content(idx,Content) */
/* content(idx,Content) */;
CREATE VIEW pdfinfo  as select idx,value pdfinfo from metadata where tag='pdfinfo'
/* pdfinfo(idx,pdfinfo) */
/* pdfinfo(idx,pdfinfo) */
/* pdfinfo(idx,pdfinfo) */;
CREATE INDEX tagsii on tags(idx);
CREATE VIEW taglist as  select idx,group_concat(tagname) tags from tags natural join tagname group by idx
/* taglist(idx,tags) */
/* taglist(idx,tags) */
/* taglist(idx,tags) */;
CREATE INDEX file_i1 on file(md5);
CREATE INDEX metadata_i on metadata(idx);
CREATE VIEW fileinfo as
select idx,md5,mtime,pdfinfo,file,group_concat(tagname) tags from "hash" natural join "file" natural join ftime natural join pdfinfo natural left join ( select idx,tagname from tags natural join tagname) group by idx
/* fileinfo(idx,md5,mtime,pdfinfo,file,tags) */
/* fileinfo(idx,md5,mtime,pdfinfo,file,tags) */
/* fileinfo(idx,md5,mtime,pdfinfo,file,tags) */;
CREATE INDEX tags_i on metadata(tag);
CREATE VIEW class as select idx,value class from metadata where tag = 'Class'
/* class(idx,class) */
/* class(idx,class) */;
CREATE TRIGGER cache_del before delete on cache_lst begin delete
			from cache_q where cache_q.qidx = old.qidx ;
		end;
CREATE TRIGGER file_ins after insert  on file begin
insert or ignore into hash (md5,refcnt) values(new.md5,0);
update hash set idx= case when refcnt = 0 then hash.rowid else idx end ,refcnt=refcnt+1  where hash.md5=new.md5;
end;
CREATE TRIGGER file_del before delete on file begin
update hash set refcnt=refcnt-1 where hash.md5=old.md5;
end;
CREATE TRIGGER file_del2 after delete on file begin
delete from hash where hash.md5 = old.md5 and refcnt = 0;
end;
CREATE TRIGGER metadata_au AFTER UPDATE ON metadata when old.tag = 'Text' BEGIN
			INSERT INTO "text"('text', rowid, content) VALUES('delete', old.idx,old.value);
			INSERT INTO "text"(rowid,content) values(new.idx,new.value);
		END;
CREATE TRIGGER metadata_ad AFTER DELETE ON metadata when old.tag = 'Text' BEGIN
			INSERT INTO "text"('text', rowid, content) VALUES('delete', old.idx,old.value);
		end;
CREATE TRIGGER metadata_ai AFTER INSERT ON metadata when new.tag = 'Text' BEGIN
			INSERT INTO "text"(rowid,content) values(new.idx,new.value);
		end;
CREATE TRIGGER mtime_del after delete on metadata when old.tag = 'mtime' begin
	delete from mtime where mtime.idx=old.idx;
    end;
CREATE TRIGGER mtime_ins after insert on metadata when new.tag = 'mtime' begin
	insert into mtime (idx,mtime) values (new.idx,new.value);
    end;
CREATE VIRTUAL TABLE text using fts5(docid,content,  content='vtext', content_rowid='docid', tokenize = 'snowball german english');
CREATE VIEW 'vtext'(docid,content)  as select idx ,value from metadata where tag = 'Text';
CREATE VIEW vtags as select idx,group_concat(tagname,",") tags from tags natural join tagname
/* vtags(idx,tags) */;
CREATE VIEW m_tags(idx,tags) as
select idx,group_concat(tagname)  from tags join tagname using (tagid) where idx=11804
/* m_tags(idx,tags) */;
CREATE VIEW m_pdfinfo as select idx, value pdfinfo from metadata where tag = 'pdfinfo'
/* m_pdfinfo(idx,pdfinfo) */;
CREATE VIEW m_content  as select idx, value content from metadata where tag = 'Content'
/* m_content(idx,content) */;
CREATE VIRTUAL TABLE text_tmp using fts5(docid UNINDEXED,content, tokenize = 'snowball german english');
CREATE VIEW m_archive as select idx,value archive from metadata where tag='archive'
CREATE TABLE IF NOT EXISTS doclabel (idx INT, doclabel primary key unique);
/* m_archive(idx,archive) */;
CREATE TRIGGER hash_del after delete on hash begin
                                        delete from file where file.md5 = old.md5;
delete from metadata where metadata.idx=old.idx;
delete from mtime where mtime.idx=old.idx;
delete from data where data.idx = old.idx;
end;
