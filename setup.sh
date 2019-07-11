#!/bin/bash

dst_files="cgi-bin/awkpasswd.dst cgi-bin/awki.conf.dst resources/site_logo.png.dst"

for file in $dst_files ; do
	dst_name=`echo $file | sed 's/.dst$//'`
	echo "[+] Copying $file into $dst_name"
	cp $file $dst_name
done

if awk -F= '/^ID_LIKE=/ {exit($2 == "debian" ? 0 : 1)}'; then
	echo "[+] Installing dependencies"
	sudo apt-get install gawk groff ps2eps pdf2svg python3-pygments
	cd /tmp
	wget http://mirrors.ctan.org/support/epstopdf.zip
	unzip epstopdf.zip
	sudo mv epstopdf/epstopdf.pl /usr/bin/epstopdf
else
	echo "[+] Skipping installation of dependencies"
fi

