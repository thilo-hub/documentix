.bail on
.timer off
.mode box
.load fts5stemmer
drop TRIGGER if exists results_fill;
drop TRIGGER if exists new_search;
drop TRIGGER if exists cache_fetch;
drop TRIGGER if exists cache_fill;
drop TRIGGER if exists cache_new;
drop TRIGGER if exists cache_hit;
drop TRIGGER if exists cache_fill_h;
drop TRIGGER if exists cache_fill_t;
drop view if exists  cache_q_stat;
drop view if exists  mylog_cache_lst;
--drop table if exists cache_lst;

CREATE TABLE if not exists cache_lst ( qidx integer primary key autoincrement,
                              query text unique, nresults integer, hits integer, last_used integer DEFAULT (unixepoch()));
CREATE TRIGGER if not exists cache_del before delete on cache_lst begin delete from cache_q where cache_q.qidx = old.qidx ; end;

-- debug
CREATE TABLE if not exists mylog (idx,md5,refcnt,time default CURRENT_TIMESTAMP);
create view if not exists mylog_cache_lst as
	select mylog.* from cache_lst join mylog on(idx='q'||qidx) order by mylog.rowid;

-- list actual cache contents
create view cache_q_stat(qidx,hits,nresults) as select qidx,count(*),sum(iif(snippet is null,0,1)) from cache_q group by qidx;

--(a) insert new search and request no results (NULL)
--(b) insert new search and request n results (n>=0) 
--(c) update search and request n results (n>=0)

-- Disable/enable logging for debugging by commenting the mylog
CREATE TRIGGER cache_new after insert on cache_lst when new.nresults is not null begin
	insert into mylog(idx,md5,refcnt) values('q'||new.qidx,'cache_new: ' || new.nresults,0);
	update cache_lst set hits = -1  where qidx = new.qidx;
end;

-- setting the hit to -1 rebuilds the matched document cache
CREATE TRIGGER cache_hit  after update of hits on cache_lst when  not new.hits >= 0 begin
	insert into mylog(idx,md5) values('q'||new.qidx,'cache_hits '||ifnull(old.hits,"NULL")|| ' -> ' || new.hits);
	insert or replace into cache_q(qidx,idx,rank) select new.qidx,docid,rank from text where text match new.query;
	update cache_lst set hits=hit,nresults = -1  from (select nresults nr,hits hit from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
end;

-- setting the nresults to -1 reloads previous number of results ( or initially loads the results)
-- increasing  nresults fetches more snippets from documents
CREATE TRIGGER cache_fill after update of nresults on cache_lst when new.nresults < 0 or (new.nresults > old.nresults and new.hits > old.nresults) begin
	insert into mylog(idx,md5) values('q'||new.qidx,'cache_fill: '||ifnull(old.nresults,"NULL")|| ' -> ' || new.nresults);
	update cache_q set snippet=snip2 from (
		select idx idx2,snippet(text,1,'<','>','...',5) snip2  
		from (select qidx,idx from cache_q where qidx=new.qidx and snippet is null 
					   order by rank 
			                   limit iif(new.nresults < 0,old.nresults,new.nresults-old.nresults))  join text on(docid=idx) 
		where text match new.query
		) where qidx=new.qidx and idx2 = idx;
	update cache_lst set nresults=nr from (select nresults nr from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
end;




-- Auto update search cache -- maybe later
-- CREATE TRIGGER metadata_ai AFTER INSERT ON metadata when new.tag = 'Text' BEGIN
-- 	INSERT INTO "text"(rowid,content) values(new.idx,new.value);
-- 	insert or ignore into cache_q(qidx,idx,rank) select qidx,docid,rank from cache_lst,text(query)  
-- 		where docid=512692;
-- 	update cache_lst set hits=hit,nresults = nr  from (select nresults nr,hits hit from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
-- end;





-- test 
delete from cache_lst;
delete from cache_q;
.print "Initial query with 10 results"
insert into cache_lst(query,nresults) values('NEAR(der grosse klaus ,200)',10);
select * from cache_lst;
-- select * from mylog_cache_lst;
-- select * from cache_q_stat;

.print "Now load more results (25)"
update cache_lst set nresults=25;
select * from cache_lst;
-- select * from mylog_cache_lst;
-- select * from cache_q_stat;

.print "create query without results"
insert into cache_lst(query) values('NEAR(in der fernen zukunft,200)');

select * from cache_lst;
-- select * from cache_q_stat;
-- select * from mylog_cache_lst;
.print "get some (33) results"
insert or replace into cache_lst(query,nresults) values('NEAR(auf einem fernen planete,200)',33);

select * from cache_lst;
-- select * from cache_q_stat;
-- select * from mylog_cache_lst;

.print "create query without results but with number of results loaded"
insert or replace into cache_lst(query,nresults) values('NEAR(in nicht zuweiter entfernung,200)',0);

select * from cache_lst;
-- select * from cache_q_stat;
-- select * from mylog_cache_lst;

--BUG:   this does not update non fetched results it will need:
update cache_lst set hits=-1,nresults = -1  where hits is null;
.print "Fillup all non fetched results"
update cache_lst set nresults = hits;

select * from cache_lst;
-- select * from cache_q_stat;
select * from mylog_cache_lst;

.quit

