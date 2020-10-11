.echo off
.bail on

.load "fts5stemmer.so"
.output "upgrade_snowball.tmp.sql"
select "create temporary table saved_text (docid primary key,content text);";
select "insert or replace into saved_text select docid,content from vtext where docid is not null;";
select "begin transaction;";
select "drop "||type|| " "||name||";" from sqlite_master where type != "table" and sql not null;
select "drop table text;";
select "CREATE VIEW 'vtext' as select idx docid,value content from metadata where tag = 'Text';";
#select "CREATE VIRTUAL TABLE text using fts5(docid UNINDEXED,content,  content='vtext', content_rowid='docid', tokenize = 'snowball german english');";
select "CREATE VIRTUAL TABLE text using fts5(docid UNINDEXED,content,  content='vtext', content_rowid='docid', tokenize = 'snowball german english');";
select sql||";"  from sqlite_master where type != "table" and sql not null and name != "vtext";;
-- weird bug in sqlite and snowball stemmer, if all are loaded at once, it trashes the DB
select "insert into text(rowid,content) select docid,content from saved_text where docid >= 0 and docid < 3000; ";
select "insert into text(rowid,content) select docid,content from saved_text where docid >= 3000 and docid < 6000; ";
select "insert into text(rowid,content) select docid,content from saved_text where docid >= 6000 and docid < 9000; ";
select "insert into text(rowid,content) select docid,content from saved_text where docid >= 9000 and docid < 12000; ";
select "insert into text(rowid,content) select docid,content from saved_text where docid >= 12000 and docid < 15000; ";
select "commit;";
-- Check that bug did not happen
create temporary table q1 as select docid snippet from text b where text match "thilo"; drop table if exists q1;
.output
.echo on
.read "upgrade_snowball.tmp.sql"


