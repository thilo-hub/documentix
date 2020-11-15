select 'mkdir -p "'||dir||'" ; cp "'||file||'" "'||dir||'/.";' '# export' 
     from (
	select md5,"ExportDocs/"||group_concat(tagname,"/") dir,file   
        	from ( 
			select distinct(idx) from tags where idx not in (select idx from tags where tagid=(select tagid from tagname where tagname = "deleted")) 
		) 
		natural join tags natural join tagname natural join hash natural join file 
	        group by idx  order by tagname  
	);
