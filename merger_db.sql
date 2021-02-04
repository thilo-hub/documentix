CREATE VIEW qrview as
select idx,mt.value "mt",qr.value "qr",pg.value "pg" from metadata mt join metadata pg using (idx) join metadata qr using(idx) where qr.tag='QR' and mt.tag="mtime" and pg.tag="pages"
/* qrview(idx,mt,qr,pg) */;
CREATE VIEW joindocs as
with mee(idx,pages,mtime,qr) as (select idx,p.value pages,m.value mtime,q.value qr  from metadata p join metadata m using(idx) join metadata q using(idx) where p.tag='pages' and m.tag='mtime' and q.tag='QR' and idx not in (select idx from tags where tagid = (select tagid from tagname where tagname = 'deleted')  )) select fr.idx odd,bk.idx even, fr.qr oddqr,bk.qr evenqr, max(fr.mtime,bk.mtime) mtime   from mee fr,mee bk where fr.pages=bk.pages and fr.qr like '%Front Page%' and bk.qr like '%Back Page%' and fr.mtime-bk.mtime between -1000 and 1000
/* joindocs(odd,even,oddqr,evenqr,mtime) */;
