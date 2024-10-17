#!/bin/bash
function _init_vars {
        TMPLISTACCT=$(mktemp)
        ZABBIX_SENDER=/usr/bin/zabbix_sender
        ZABBIX_CONF=/etc/zabbix/zabbix_agent2.conf
        WHMAPI1=/usr/sbin/whmapi1
        JQ=/usr/bin/jq
}

function _get_listaccts {
        "$WHMAPI1" --output=jsonpretty listaccts > $TMPLISTACCT
}
function _parsing_listaccts {
        CPACCOUNT=$($JQ -r '.data.acct[].user' $TMPLISTACCT|wc -l)
        CPACTIVE=$($JQ -r '.data.acct[]|select(.suspended=='0').user' $TMPLISTACCT|wc -l)
        CPRESELLER=$($JQ -r '.data.acct[].owner' $TMPLISTACCT|grep -Ev root|sort|uniq|wc -l)
        CPSUSPENDED=$($JQ -r '.data.acct[]|select(.suspended=='1').user' $TMPLISTACCT|wc -l)
        CPACCTBACKUP=$($JQ -r '.data.acct[]|select(.has_backup=='1')|.user' $TMPLISTACCT|wc -l)
}
function _zabbix_send {
        "$ZABBIX_SENDER" -c "$ZABBIX_CONF" -k cpaccount -o "$CPACCOUNT"
        "$ZABBIX_SENDER" -c "$ZABBIX_CONF" -k cpactive -o "$CPACTIVE"
        "$ZABBIX_SENDER" -c "$ZABBIX_CONF" -k cpreseller -o "$CPRESELLER"
        "$ZABBIX_SENDER" -c "$ZABBIX_CONF" -k cpsuspended -o "$CPSUSPENDED"
        "$ZABBIX_SENDER" -c "$ZABBIX_CONF" -k cpacctbackup -o "$CPACCTBACKUP"
}

function _clear_tmp {
        rm -f $TMPLISTACCT
}

_init_vars
_get_listaccts
_parsing_listaccts
_zabbix_send
_clear_tmp
