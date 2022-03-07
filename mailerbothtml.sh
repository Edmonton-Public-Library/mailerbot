#!/bin/bash
#################################################################
#
# Rotate the log file and back up the database for AV incomplete.
#    Copyright (C) 2022  Andrew Nisbet, Edmonton Public Library.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Dependencies: 
# Version:
#   
#   0.1 - Initial release on ILS (edpl.sirsidynix.net)
#
#################################################################
# ==> incomplete_item_customers.lst <==
# 21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB
# ==> complete_item_customers.lst <==
# 21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB
HOST=$(hostname)
[[ "$HOST" == "ubuntu-node" ]] && DEV=true || DEV=false
if [ "$DEV" == true ]; then
    WORKING_DIR=/home/anisbet/Dev/mailerHTML
else
    . ~/.bashrc
    WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/Mailerbot/AVIncomplete
fi
VERSION="0.00.01"
APP=$(basename -s .sh $0)
DEBUG=false
LOG=$WORKING_DIR/$APP.log
CUSTOMER_FILE=""
HTML_TEMPLATE=""
LINE_NO=0
NOTICE_DATE=$(date +'%a %d %h %Y')
FILE_DATE=$(date +'%Y%m%d')
SUBJECT="EPL notice, item returned incomplete"
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $APP [-option]
  Prepares and mails HTML notices to customers.

  The customer file is expected to follow the following format.
  User ID       | Title            | Additional infomation  | Item ID      | Branch
  21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB

  These terms are translated into values found in double-square brackets as follows.

  AVIncompleteIsComplete.hmtl and AVIncompleteNotice.html
  [[noticeDate]],[[firstName]],[[title]],[[itemId]],[[librDesc]]

  noticeDate | firstName       | title            ,                         | itemId       | librDesc
  2022-03-04 |Billy Balzac     |Cats / by Jim Pipe, insert / booklet missing|31221096645630|ABB

  -c, --customers={customer.lst}: Required. Text file of customer and item information shown above.
  -d, --debug turn on debug logging.
  -h, --help: display usage message and exit.
  -s, --subject{Subject string}: Replace the default email subject line '$SUBJECT'.
  -t, --template={template.html}: Required. HTML template file to use.
  -v, --version: display application version and exit.
  -V, --VARS: Display all set variables.
  -x, --xhelp: display usage message and exit.

  Version: $VERSION
EOFU!
	exit 1
}
# Logs messages to STDOUT and $LOG file.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local message="$1"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -t 0 ]; then
        # If run from an interactive shell message STDOUT and LOG.
        echo -e "[$time] $message" | tee -a $LOG
    else
        # If run from cron do write to log.
        echo -e "[$time] $message" >>$LOG
    fi
}
# Logs messages as an error and exits with status code '1'.
logerr()
{
    local message="$1 exiting!"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -t 0 ]; then
        # If run from an interactive shell message STDOUT and LOG.
        echo -e "[$time] **error: $message" | tee -a $LOG
    else
        # If run from cron do write to log.
        echo -e "[$time] **error: $message" >>$LOG
    fi
}

email_customer()
{
    [[ -z "$1" ]] && return
    local noticeDate=$NOTICE_DATE
    local customer="$1"
    local customer_id=$(echo $customer | awk -F "|" '{print $1}')
    [[ -z "$customer_id" ]] && { logit "customer id missing on line $LINE_NO"; return; }
    local notice_file=${customer_id}.${FILE_DATE}.html
    local firstName=""
    local title=$(echo $customer | awk -F "|" '{print $2 $3}')
    local itemId=$(echo $customer | awk -F "|" '{print $4}')
    local librDesc=$(echo $customer | awk -F "|" '{print $5}')
    local email=""
    if [ "$DEV" == true ]; then
        firstName="Balzac"
        email="example@domain.com"
    else
        # TODO: Check this is the flag for seluser.
        firstName=$(echo $customer_id | seluser -iB -o--first_name)
        email=$(echo $customer_id | seluser -iB -oX.9007.)
    fi
    # Log if the customer is unmailable.
    if [ -z "$email" ]; then
        logit "No email for customer: $customer"
        return
    fi
    # Read in the template file and replace templates with the customer's data.
    awk -v "noticeDate=$noticeDate" -v "firstName=$firstName" -v "title=$title" -v "itemId=$itemId" -v "librDesc=$librDesc" '{
        gsub(/\[\[noticeDate\]\]/, noticeDate);
        gsub(/\[\[firstName\]\]/, firstName);
        gsub(/\[\[title\]\]/, title);
        gsub(/\[\[itemId\]\]/, itemId);
        gsub(/\[\[librDesc\]\]/, librDesc);
        print;
    }' $HTML_TEMPLATE >$notice_file
    # Don't mail if we are on dev server.
    if [ "$DEV" == true ]; then
        logit "DEBUG: $notice_file created."
    else
        # TODO: check edpl's mailx client for the correct flag to append a file.
        if mailx -s "$SUBJECT" -a $notice_file $email; then
            logit "customer $customer_id mailed about item: $itemId, $title, borrowed from $librDesc using $HTML_TEMPLATE"
        else
            logerr "mailx failed. Unable to notify customer ${customer_id}."
            tar uvf failed_notices.tar $notice_file
        fi
        rm $notice_file
    fi
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "customers:,debug,help,subject:,template:,VARS,version,xhelp" -o "c:dhs:t:Vvx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--customers)
		shift
        logit "Using customer file $1"
		CUSTOMER_FILE=$1
		;;
    -d|--debug)
        logit "turning on debugging"
		DEBUG=true
		;;
    -h|--help)
        usage
        exit 0
        ;;
    -s|--subject)
		shift
        logit "Changeing subject to '$1'"
		SUBJECT="$1"
		;;
    -t|--template)
		shift
        logit "Using template $1"
		HTML_TEMPLATE=$1
		;;
    -V|--VARS)
        [[ "$DEV" == true ]] && echo -e "\$HOST=$HOST\n\$DEV=$DEV\n\$WORKING_DIR=$WORKING_DIR\n\$VERSION=$VERSION\n\$APP=$APP\n\$DEBUG=$DEBUG\n\$LOG=$LOG\n\$CUSTOMER_FILE=$CUSTOMER_FILE\n\$HTML_FILE=$HTML_FILE\n\$SUBJECT=$SUBJECT\n"
        ;;
    -v|--version)
        echo "$0 version: $VERSION"
        exit 0
        ;;
    -x|--xhelp)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
logit "== starting $APP version: $VERSION"
[[ "$DEBUG" == true ]] && logit "variables set:\n\$HOST=$HOST\n\$DEV=$DEV\n\$WORKING_DIR=$WORKING_DIR\n\$VERSION=$VERSION\n\$APP=$APP\n\$DEBUG=$DEBUG\n\$LOG=$LOG\n\$CUSTOMER_FILE=$CUSTOMER_FILE\n\$HTML_FILE=$HTML_FILE\n\$SUBJECT=$SUBJECT\n"
: ${CUSTOMER_FILE:?Missing -c,--customers} ${HTML_TEMPLATE:?Missing -t,--template}
[ -s "$CUSTOMER_FILE" ] || { logerr "customer file not found or empty."; exit 1; }
cd $WORKING_DIR
# Parse the customer information and get the user's name from the UserId
while read -r customer; do 
    (( LINE_NO++ ))
    email_customer "$customer"
done < $CUSTOMER_FILE
