#!/bin/bash
log_name=`date --rfc-3339=seconds | sed 's/ /T/'`
cd ~/workspace/mysql-monitor/load/
exec /nfs/software/ensembl/latest/pyenv/versions/compara3.7/bin/python get_mysql_load.py > cron_ebi/log/${log_name}.out 2> cron_ebi/log/${log_name}.err
