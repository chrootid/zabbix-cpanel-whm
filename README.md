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
- install zabbix_sender
- install zabbix_agent2
- Set crontab:
*/5 * * * * root /root/scripts/zabbix-cpanel-whm.sh
