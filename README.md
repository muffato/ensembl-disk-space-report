# MySQL monitors

Simple web reports to look at the usage of our MySQL servers:
- Disk usage (per storage engine), with a breakdown per database
- Load and number of connections (timeline)

To use, just change the installation path in these files
- `disk_space/crontab`
- `disk_space/cron.sh`
- `disk_space/update_all_teams.sh`
- `disk_space/update_one_team.sh`
- `load/crontab`
- `load/cron.sh`

and copy the content of the relevant `crontab` into your own (e.g. by
running `crontab -e`).
