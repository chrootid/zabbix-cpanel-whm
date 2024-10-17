# zabbix-cpanel-whm
cPanel Account Monitoring Template for Zabbix
Features
- Total cPanel Account
- Total cPanel Account Backup
- Total cPanel Active Account
- Total cPanel Suspended Account
- Total cPanel Reseller Account

Requirement
- cPanel Active License
- jq
- whmapi1
- zabbix_agent2
- zabbix_sender

How to
- install jq
```
# yum install jq
```
or
```
sudo apt install jq
```
- install zabbix_sender
```
# yum install zabbix_sender
```
or
```
sudo apt install zabbix_sender
```
- install zabbix_agent2
```
# yum install zabbix_agent2
```
or
```
sudo apt install zabbix_agent2
```
- Set crontab:
```
*/5 * * * * root /root/scripts/zabbix-cpanel-whm.sh
```
- backup status checker script
```
[root@server ~]# ./backupstatus.sh
cPanel Account           : 364
cPanel Account Backup    : 362
cPanel Account No Backup : 2
===== Backup List Status =====
2024-10-06 = 360/364 (MISSED)
2024-10-13 = 362/364 (MISSED)

1. cPanel Account No Backup Lists
  +------+------------+---------+--------------------------------+--------------+-----------+-----------+-----------------+
  |  NO  |  USERNAME  |  OWNER  |  SETUP DATE                    |  DISK USAGE  |  SUSPEND  |  BACKUP   |  STATUS         |
  +------+------------+---------+--------------------------------+--------------+-----------+-----------+-----------------+
  |  1   |  user0001  |  root   |  Tue Oct 15 09:46:01 WIB 2024  |  1M          |  Active   |  Enabled  |  has_no_backup  |
  |  2   |  user0002  |  root   |  Fri Nov  2 09:50:56 WIB 2018  |  3111M       |  Active   |  Enabled  |  has_no_backup  |
  +------+------------+---------+--------------------------------+--------------+-----------+-----------+-----------------+

2. How to resolve
   /scripts/pkgacct --backup [USERNAME] [BACKUPDIR]
   /scripts/backups_create_metadata --user=[USERNAME]
```
