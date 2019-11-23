#!/bin/bash

dst_files="cgi-bin/awkpasswd.dst cgi-bin/awki.conf.dst resources/site_logo.png.dst"

cd "$(dirname $0)"

for file in $dst_files ; do
	dst_name=`echo $file | sed 's/.dst$//'`
	echo "[+] Copying $file into $dst_name"
	cp $file $dst_name
done

