#!/bin/bash

cd ~/workspace/disk/cron/
log_name=`date --rfc-3339=seconds | sed 's/ /T/'`
(
	for i in ../*.json
	do
		perl ../servers_disk.pl $i
		scp -p *png *html ensweb-1-15:/ensemblweb/admin/public-plugins/admin/htdocs/disk_usage/
	done
	#perl ../servers_disk.pl ../*.json
	#scp -p *png *html ensweb-1-15:/ensemblweb/admin/public-plugins/admin/htdocs/disk_usage/
) > log/$log_name.out 2> log/$log_name.err

