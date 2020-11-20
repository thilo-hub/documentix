.header on
--	from (
--		select idx,"ExportDocs/"||group_concat(tagname,"/")||"/" dir, file 
--	) natural join 
select 'mkdir -p "'||dir||'" ; cp "'||file||'" "'||dir||'/.";' '# export' 
	--select dir,file  
	from (
		select idx,"ExportDocs/"||group_concat(tagname,"/") dir  from (
			select idx from tags where 
				tagid = (select tagid from tagname where tagname = "public" ) 
			) natural join tags natural join tagname where tagname != "public"
		group by idx order by tagname
	) natural join hash natural join file
	where 
		idx not in (select idx from tags where tagid = (select tagid from tagname where tagname = "deleted"))


--	where idx not in
--		(select idx from tags where tagid=(select tagid from tagname where tagname = "deleted" ))
--	     (select idx,"ExportDocs/"||group_concat(tagname,"/") dir,file   
--	
--	from (
--		select idx,"ExportDocs/"||group_concat(tagname,"/")||"/" dir, file 
--			from (
--				select idx from tags natural join tagname where tagname="public") natural join tag
--				where
--				idx not in ( 
--				)
--		) natural join hash natural join file 
--			group by idx order by tagname;;
--	);
