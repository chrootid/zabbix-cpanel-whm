#!/bin/bash
function _init_vars {
        TOTALCPUSER=$(cut -d: -f1 /etc/trueuserowners |wc -l)
        DATECOMMAND=$(which date)
        WHMAPI1=$(which whmapi1)
        TMPLISTACCT=$(mktemp)
        JQ=$(which jq)
}

function _clear_tmp {
        rm -f "$TMPLISTACCT"

}

function _jq_check {
        if [[ -z $(which jq 2>/dev/null) ]];then
                printf "jq command not found : installing... "
                yum install jq -y >/dev/null 2>&1
                if [[ -z $(which jq 2>/dev/null) ]];then
                        printf "%s Failed\n" "$(which jq)"
                        exit
                else
                printf "%s Done\n" "$(which jq)"
        fi
fi
}

function _get_listaccts {
        "$WHMAPI1" --output=jsonpretty listaccts > "$TMPLISTACCT"
}

function _parsing_cp_summary {
        CPACCOUNT=$($JQ -r '.data.acct[].user' "$TMPLISTACCT"|wc -l)
        CPACCTBACKUP=$($JQ -r '.data.acct[]|select(.has_backup=='"1"')|.user' "$TMPLISTACCT"|wc -l)
        CPACCTNOBACKUP=$($JQ -r '.data.acct[]|select(.has_backup=='"0"')|.user' "$TMPLISTACCT"|wc -l)

        echo "cPanel Account           : $CPACCOUNT"
        echo "cPanel Account Backup    : $CPACCTBACKUP"
        echo "cPanel Account No Backup : $CPACCTNOBACKUP"
}

function _parsing_cpacct_no_backup {
        TOTALCPACCT=$($JQ -r '.data.acct[].user' "$TMPLISTACCT"|wc -l)
        TOTALCPBACKUP=$($JQ -r '.data.acct[]|select(.has_backup=='"1"')|.user' "$TMPLISTACCT"|wc -l)

        if [[ "$TOTALCPBACKUP" -lt "$TOTALCPACCT" ]];then
                echo ""
                echo "1. cPanel Account No Backup Lists"
                printTable ',' "$(_fetch_has_no_backup_acct)"
                echo ""
                _how_to_resolve
                #_fetch_has_no_backup_acct
        fi
}

function _suspend_status {
        SUSPENDSTAT=$(echo "$CPACCT"|awk '{print $3}')
        if [[ "$SUSPENDSTAT" -eq 0 ]];then
                echo "Active"
        elif [[ "$SUSPENDSTAT" -eq 1 ]];then
                echo "Suspended"
        fi
}

function _backup_user_selection_status {
        BACKUPSTAT=$(echo "$CPACCT"|awk '{print $4}')
        if [[ "$BACKUPSTAT" -eq 0 ]];then
                echo "Disabled"
        elif [[ "$BACKUPSTAT" -eq 1 ]];then
                echo "Enabled"
        fi
}

function _has_backup_status {
        HAS_BACKUP_STAT=$(echo "$CPACCT"|awk '{print $5}')
        if [[ "$HAS_BACKUP_STAT" -eq 0 ]];then
                echo "has_no_backup"
        elif [[ "$HAS_BACKUP_STAT" -eq 1 ]];then
                echo "has_backup"
        fi
}

function _unix_epoc_converter {
        UNIXEPOC=$(echo "$CPACCT"|awk '{print $7}')
        "$DATECOMMAND" -d @"$UNIXEPOC"

}

function _fetch_has_no_backup_acct {
        NO=1
        echo "NO,USERNAME,OWNER,SETUP DATE,DISK USAGE,SUSPEND,BACKUP,STATUS"
        "$JQ" -r '.data.acct[]|select(.has_backup=='"0"')|"\(.user) \(.owner) \(.suspended) \(.backup) \(.has_backup) \(.diskused) \(.unix_startdate)"' "$TMPLISTACCT"|sort|while read -r CPACCT;do
                CPUSER=$(echo "$CPACCT"|awk '{print $1}')
                OWNER=$(echo "$CPACCT"|awk '{print $2}')
                DISKUSAGE=$(echo "$CPACCT"|awk '{print $6}')
                echo "$NO,$CPUSER,$OWNER,$(_unix_epoc_converter),$DISKUSAGE,$(_suspend_status),$(_backup_user_selection_status),$(_has_backup_status)"
                NO=$(( NO + 1 ));
        done
}

function _backup_status_summary {
        echo "===== Backup List Status ====="

        "$WHMAPI1" --output=jsonpretty backup_date_list|"$JQ" -r '.data.backup_set[]'|sort|while read -r BACKUPDIR;do
                TOTALCPACCTBACKUP=$("$WHMAPI1" --output=jsonpretty backup_user_list restore_point="$BACKUPDIR"|"$JQ" -r '.data.user[]|select(.status=="active").status'|wc -l)
                if [[ $TOTALCPACCTBACKUP -eq $TOTALCPUSER ]];then
                        echo "$BACKUPDIR = $TOTALCPACCTBACKUP/$TOTALCPUSER (COMPLETED)";
                elif [[ $TOTALCPACCTBACKUP -lt $TOTALCPUSER ]] && [[ $TOTALCPACCTBACKUP -ge 1 ]];then
                        echo "$BACKUPDIR = $TOTALCPACCTBACKUP/$TOTALCPUSER (MISSED)";
                elif [[ $TOTALCPACCTBACKUP -eq 0 ]];then
                        echo "$BACKUPDIR = $TOTALCPACCTBACKUP/$TOTALCPUSER (FAILED)";
                fi;
        done
}

function _how_to_resolve {
        echo "2. How to resolve"
        echo "   /scripts/pkgacct --backup [USERNAME] [BACKUPDIR]"
        echo "   /scripts/backups_create_metadata --user=[USERNAME]"
        echo ""
}

#################################
# table function
function printTable()
{
    local -r delimiter="${1}"
    local -r tableData="$(removeEmptyLines "${2}")"
    local -r colorHeader="${3}"
    local -r displayTotalCount="${4}"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${tableData}")" = 'false' ]]
    then
        local -r numberOfLines="$(trimString "$(wc -l <<< "${tableData}")")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${tableData}")"

                local numberOfColumns=0
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                # Add Header Or Body

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#|  %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                # Add Line Delimiter

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                local output=''
                output="$(echo -e "${table}" | column -s '#' -t | awk '/^ *\+/{gsub(" ", "-", $0)}1' | sed 's/^--\|^  /  /g')"

                if [[ "${colorHeader}" = 'true' ]]
                then
                    echo -e "\033[1;32m$(head -n 3 <<< "${output}")\033[0m"
                    tail -n +4 <<< "${output}"
                else
                    echo "${output}"
                fi
            fi
        fi

        if [[ "${displayTotalCount}" = 'true' && "${numberOfLines}" -ge '0' ]]
        then
            if [[ "${colorHeader}" = 'true' ]]
            then
                echo -e "\n\033[1;36mTOTAL ROWS : $((numberOfLines - 1))\033[0m"
            else
                echo -e "\nTOTAL ROWS : $((numberOfLines - 1))"
            fi
        fi
    fi
}
function removeEmptyLines()
{
    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString()
{
    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "$(isPositiveInteger "${numberToRepeat}")" = 'true' ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function replaceString()
{
    local -r content="${1}"
    local -r oldValue="$(escapeSearchPattern "${2}")"
    local -r newValue="$(escapeSearchPattern "${3}")"
    sed "s@${oldValue}@${newValue}@g" <<< "${content}"
}

function trimString()
{
    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

function isEmptyString()
{
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function checkPositiveInteger()
{
    local -r string="${1}"
    local -r errorMessage="${2}"

    if [[ "$(isPositiveInteger "${string}")" = 'false' ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal '\nFATAL : not positive number detected'
        fi

        fatal "\nFATAL : ${errorMessage}"
    fi
}

function isPositiveInteger()
{
    local -r string="${1}"

    if [[ "${string}" =~ ^[1-9][0-9]*$ ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}
#################################

_init_vars
_jq_check
_get_listaccts
_parsing_cp_summary
_backup_status_summary
_parsing_cpacct_no_backup
_clear_tmp
