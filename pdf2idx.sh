#!/bin/sh
f=$1
N=`pdfinfo $f | awk '/Pages:/{print $2}'`

TMP=/tmp/$$.tmp
mkdir $TMP
O=

i=0;
while [ $i -lt $N ] ;do
	convert -density 300 ${f}[$i] -normalize -median 1 -contrast-stretch 27%,76% -monochrome \
		-depth 1 tif:$TMP/page-$i.tiff  ;  
	tesseract $TMP/page-$i.tiff  $TMP/page-$i  -l deu+eng hocr  &
	O="$O page-$i.tiff"
	i=$((i + 1))
done
wait
(cd $TMP; pdfbeads $O )>out.pdf
rm -r $TMP
