  n=1 ; 
  for f in `cat data.out/list.txt ` ; do 
	  for res in 300 400 600 ; do
	  BSE=data.out/a.$res.$n.0
	  TIF=$BSE.tif
		  convert -density $res ${f}[0] -normalize -median 1 -contrast-stretch 27%,76% -monochrome \
		  -depth 8 tif:$TIF  ;  
		  echo done $n:$f;  
		  (tesseract $TIF $BSE -l deu+eng hocr 
		  hunspell -i utf-8 -H -d de_DE,en_EN  -G $BSE.html  | wc  | sed s,^,$BSE.html,
		  )
		  n=$((n+1)); 
	  done
  done
