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
#   1.03.01 - Create -l argument log file if it doesn't exist.
#
#################################################################
HOST=$(hostname)
[[ "$HOST" == "ubuntu-node" ]] && DEV=true || DEV=false
if [ "$DEV" == true ]; then
    WORKING_DIR=/home/anisbet/Dev/mailerbothtml
else
    . ~/.bashrc
    WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/Mailerbot
fi
VERSION="1.03.01"
APP=$(basename -s .sh $0)
DEBUG=false
LOG=$WORKING_DIR/$APP.log
CALLER_LOG="/dev/null"
CUSTOMER_FILE=""
HTML_TEMPLATE=""
LINE_NO=0
NOTICE_DATE=$(date +'%a %d %h %Y')
FILE_DATE=$(date +'%Y%m%d')
UNMAILABLE_CUSTOMERS=$WORKING_DIR/unmailable_customers.txt
SUBJECT="EPL notice"
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $APP [-option]
Prepares and mails HTML notices to customers. 
How dynamic injection happens depends on the HTML template file, as $APP
will do its best to fill in all [[template_variable]] values. 
For example the minimum customer file contains a column of user IDs. 
That is required to find the user's email and can be used to get the user's first name
if the template defines a [[firstName]] variable. 

Template variables that $APP understands (in no particular order):
# [[noticeDate]]
# [[firstName]]
# [[title]]
# [[itemId]]
# [[librDesc]]

And the template need not define all, or even any of these. If it does however, 
$APP uses the following information from the customer file to dynamically 
generate and inject information into any of the above variables that may 
be defined in the HTML template.

== Customer File Format ==
Each line represents one customer and can have from one to five fields of pipe-delimited information. 
# '''User_ID''' - Required. Used to look up the customer email, and first name if HTML template 
  defines [[firstName]].
# '''Title''' - Optional. Typically used to fill [[title]] if the HTML template defines it. 
  If other fields below are required, this one can be blank.
# '''Description''' - Optional. Typically appended to [[title]] if the HTML template defines it. 
  If other fields below are required, this one can be blank. If the 'Title' column was blank any 
  [[title]] will be filled with the 'Description'.
# '''Item ID''' - Optional. Used to file [[itemId]] if defined.
# '''Branch code''' - Optional. Used to fill [[librDesc]] by using getpol to look up the full 
  branch name from the 3-character branch code.

This is an example of a full, well-formed customer record.
 21221012345678|Treasure Island / R.L. Stevenson - 1989|Missing features disc|31221012345678|ABB
This is a example of a minimal customer record.
 21221012345678|
An example where the HTML template only defines [[itemId]].
 21221012345678|||31221012345678|

== How Variables are Satisfied ==
# [[noticeDate]]: Generated dynamically by $APP at runtime.
# [[firstName]]: The first field in a customer list is the users' ID which $APP 
  uses to look up the users' first name and email.
# [[title]]: Title / Author - pub date, what-have-you and description are concatenated 
  in the outgoing message.
# [[itemId]]: Used as is from column 3. A hack could be to put some other data in this 
  column then use [[itemId]] where you want the text to go.
# [[librDesc]]: $APP will dynamically look up the full branch name given a 
  three character branch code. The lookup is done through getpol.

Once the user's information is queried, the terms in double-square brackets are substituted. 
If a variable is not defined in the HTML template, no text is injected, even if it is defined 
in the customer.lst file. If a variable is defined, but is not available in the customer 
file the [[variable]] is replaced with an empty string.

 -c, --customers={customer.lst}: Required. Text file of customer and item information shown above.
 -d, --debug turn on debug logging. The email content is written to the $LOG 
     file but no email is sent.
 -h, --help: display usage message and exit.
 -l, --log_file={/foo/bar.log}: Log transactions to an additional log, like the caller's log file.
     After this is set, all additional messages from $APP will ALSO be written to \$CALLER_LOG which
     is $CALLER_LOG by default.
 -s, --subject{Subject string}: Replace the default email subject line '$SUBJECT'.
 -t, --template={template.html}: Required. HTML template file to use.
 -v, --version: display application version and exit.
 -V, --VARS: Display all set variables.
 -x, --xhelp: display usage message and exit.

Examples:
# Run $APP on production but don't actually mail the customer(s)
$0 --customers=/foo/bar/test_customers.lst --template=/foo/bar/notice_template.html --debug --VARS

# Run $APP in production environment.
$0 --customers=/foo/bar/customers.lst --template=/foo/bar/notice_template.html

# Run $APP but change the log.
$0 --log_file=/foo/bar/avincomplete.log --customers=/foo/bar/customers.lst --template=/foo/bar/notice_template.html

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
    # If run from an interactive shell message STDOUT and LOG.
    echo -e "[$time] $message" | tee -a $LOG -a $CALLER_LOG
}
# Logs messages with special error prefix.
logerr()
{
    local message="$1"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] **error: $message" | tee -a $LOG -a $CALLER_LOG
}

# Emails customer an html notice.
# Currently, the only applications that email customers are as follows.
#   notify_customers.sh
#   notifycancelholds.sh
# Both applications use similar formatted data, but notifycancelholds.sh 
# uses only the customer name and title in it's template text. No matter.
# If the librDesc, itemId are missing, as they are in data from notifycancelholds.sh 
# $APP will be ignored.
email_customer()
{
    [[ -z "$1" ]] && return
    local noticeDate=$NOTICE_DATE
    local customer="$1"
    local customer_id=$(echo $customer | awk -F "|" '{print $1}')
    [[ -z "$customer_id" ]] && { logit "customer id missing on line $LINE_NO"; return; }
    local notice_file=${customer_id}.${FILE_DATE}.html
    local firstName=""
    local title=$(echo $customer | awk -F "|" '{print $2}')
    # The $3 item is additional info about the item. In AVI it is a description of the missing piece. It may be empty in other message types.
    local description=$(echo $customer | awk -F "|" '{print $3}')
    # These next two values may be empty, and are not used if run by notifycancelholds.sh
    local itemId=$(echo $customer | awk -F "|" '{print $4}')
    # Lookup branch code.  
    local branch=$(echo $customer | awk -F "|" '{print $5}')
    local librDesc=""
    local email=""
    if [ "$DEV" == true ]; then
        firstName="Balzac"
        email="example@domain.com"
        librDesc="$branch (library code in DEV mode)"
    else
        # Reference the API for customer's first name and email, and remove trailing pipe delimiter.
        firstName=$(echo $customer_id | seluser -iB -o--first_name | awk -F "|" '{print $1}')
        email=$(echo $customer_id | seluser -iB -oX.9007. | awk -F "|" '{print $1}')
        # Lookup branch name from branch code codes.
        librDesc=$(getpol -tLIBR | grep $branch | awk -F "|" '{print $22}')
    fi
    # Log if the customer is unmailable.
    if [ -z "$email" ]; then
        logit "No email for customer: $customer"
        DATE_TIME=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$DATE_TIME] $customer" >>$UNMAILABLE_CUSTOMERS
        return
    fi

    # Read in the template file and replace templates with the customer's data.
    awk -v "noticeDate=$noticeDate" -v "firstName=$firstName" -v "title=$title" -v "itemId=$itemId" -v "librDesc=$librDesc" -v "subject=$SUBJECT" -v "email=$email" -v "description=$description" 'BEGIN{
        printf "To: %s\n", email;
        printf "Subject: %s\n", subject;
        printf "Content-type: text/html\n\n";
    }{
        gsub(/\[\[noticeDate\]\]/, noticeDate);
        gsub(/\[\[firstName\]\]/, firstName);
        # For some strange reason "&" gets replaced with the regex search string.
        # A dumb fix: replace it in the URL with "__AMP__", and after substitution of [[title]]
        # change it back to an "&" - double-escaped. This works, is not ideal, but I have to get this to production.
        gsub(/[&]/, "__AMP__", title);
        gsub(/\[\[title\]\]/, title);
        gsub(/__AMP__/, "\\&", $0);
        gsub(/\[\[missingPiece\]\]/, description);
        gsub(/\[\[itemId\]\]/, itemId);
        gsub(/\[\[librDesc\]\]/, librDesc);
        print;
    }' $HTML_TEMPLATE >$notice_file
    # Don't mail if we are on dev server.
    if [ "$DEV" == true ]; then
        logit "DEV: $notice_file created."
    elif [ "$DEBUG" == true ]; then
        if [ -s "$notice_file" ]; then
            logit "DEBUG: customer $customer_id mailed about item: $itemId, $title using ${HTML_TEMPLATE}."
            logit "==snip=="
            cat $notice_file >>$LOG
            logit "==snip=="
        else
            logerr "DEBUG: failed to create $notice_file for customer ${customer_id}."
        fi
    else
        # Mail the customer. The headers are prepended to the html notice above.
        cat $notice_file | sendmail -t
        if [ "$?" ]; then
            logit "customer $customer_id mailed about item: $itemId, $title using ${HTML_TEMPLATE}."
        else
            logerr "sendmail failed. Unable to notify customer ${customer_id}."
            # The failed_notices.tar file needs to exist to be updated. The failed notices are discarded otherwise.
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
options=$(getopt -l "customers:,debug,help,log_file:,subject:,template:,VARS,version,xhelp" -o "c:dhl:s:t:Vvx" -a -- "$@")
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
    -l|--log_file)
		shift
        logit "adding logging to '$1'"
        if [ -f "$1" ]; then
		    APP_LOG="$1"
        else
            # Doesn't exist but try to create it.
            if touch $1; then
                logit "$1 added as a logging destination."
                APP_LOG="$1"
            else # Otherwise just keep settings as they are and report issue.
                logerr "file '$1' not found, and failed to create it. Logging unchanged."
            fi
        fi
		;;
    -s|--subject)
		shift
        logit "changeing subject to '$1'."
		SUBJECT="$1"
		;;
    -t|--template)
		shift
        logit "using template $1"
		HTML_TEMPLATE=$1
		;;
    -V|--VARS)
        [[ "$DEV" == true ]] && echo -e "\$HOST=$HOST\n\$DEV=$DEV\n\$WORKING_DIR=$WORKING_DIR\n\$UNMAILABLE_CUSTOMERS=$UNMAILABLE_CUSTOMERS\n\$VERSION=$VERSION\n\$APP=$APP\n\$DEBUG=$DEBUG\n\$LOG=$LOG\n\$CUSTOMER_FILE=$CUSTOMER_FILE\n\$HTML_FILE=$HTML_FILE\n\$SUBJECT=$SUBJECT\n"
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
