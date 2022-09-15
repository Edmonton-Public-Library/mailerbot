# Mailerbot 
Mailerbot is not two projects, the original mailerbot.pl which can still be used,
and a new application called mailerbothtml.sh. This new script allows the sendning
of HTML messages with customized text throughout. The templates are specified as 
a command line argument but should reside in the standard Symphony notices directory `~/Unicorn/Notices`.

The following is a list of projects that rely on mailerbot.
* AV Incomplete (for complete and incomplete notifications)
* `notifiy_customers.sh`
* `notifycancelholds.sh`
* `customeractivitynotification.sh`

## mailerbothtml.sh
Prepares and mails HTML notices to customers. Consider using this instead of `mailerbot.pl` which still works well for text based messages but not for HTML notices.

  The customer file is expected to follow the following format.  
  ```User ID       | Title            | Additional infomation  | Item ID      | Branch```  
  ```21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB```

  Not all the fields are required but there must be five (5) columns in the input or 
  mailerbot will get confused about what data is in which column. So minimally
  ```21221012345678||||```


  The script will automatically search for the user first name and their email. 
  If the email is not found it is reported to the $UNMAILABLE_CUSTOMERS customers file.
  
  Once the user's information is queried, the terms in double-square brackets 
  are substituted. The following template values can be found in the current version 
  of the html templates for AV Incomplete (AVIncompleteIsComplete.html and AVIncompleteNotice.html)
  
  The data sent from AV Incomplete is as follows.
  ```21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB```  

  This script uses seluser API to look up the customer's first name and email.  
  ```noticeDate | firstName  | title            | missing piece           | itemId       | librDesc```  
  ```2022-03-04 | Balzac     |Cats / by Jim Pipe| insert / booklet missing|31221096645630|ABB```  

  Cancelled on-order item html template (OnOrderCancelHoldNotice.html) has fewer html template strings, 
  but are handled with the same logic.
  The data from notify_customers.sh is as follows.   
  ```21221012345678|<a href="https://epl.biblio...">Cats / by Jim Pipe</a><br/>||```

  This scripts needs the following.   
  ```[[noticeDate]],[[firstName]],[[title]]```

  So a lookup is done and the values used to populate the html template text.   
  ```noticeDate | firstName | title (and search link)```                        
  ```2022-03-04 | Balzac    |<a href="https://epl.biblio...">Cats / by Jim Pipe</a><br/>||```

### Flags
```
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
```

### Mon Feb 24 13:19:28 MST 2014 

Mailerbot is a perl script that emails customers customisable messages.

It will mail all the customers whose bar codes are listed in the input file -c.
It removes the customer bar codes found in -e (optional). The -e file is a 
black list, user IDs (or user keys) for customers that you don't want it to mail. 
This is useful if you want to set up a regular email job, but don't want customers
to be spammed each time it runs. Once the mailerbot is done, append the IDs 
from the -c list to the file that is the input for -e.

Mailerbot searches for customer emails and mails those it has addresses for
and prints those it can't to stdout.

Mailerbot can send custom messages to customers. Each line of the message must
appear between '|' characters in the -c file like so:
21221012345678|On April 30 you borrowed 'Room with a view'.|We found the case and not the disk.|

You can set a subject line for the mail you are sending by starting a line anywhere in the file
with 'subject:' like so:
subject: Missing items

You can also add a footer as a signature i.e.:
footer: Signed, your friends at EPL.

The output message in the above examples would look like
--snip--
    Subject: Missing items

    On April 30 you borrowed 'Room with a view'.
    We found the case and not the disk.

    Signed, your friends at EPL.
--snip--


## Danger level 
This script can email all customers if you want so care should be taken to ensure that you have messaging right before mailing and your list is correct or customers will report spam. Also keep consistency. The script looks for pipe delimited input for all input files. If you use ```user_keys``` for customer IDs use them in all files. Failing to do so will result in the script not excluding customers because no matches will be found between ```user_ids``` and ```user_keys```.

## Usage 
This script can be run manually or run by [[cron]]

## Flags
```console
 -c: Name of customer file, customers (one per line) will be notified if possible.
 -e: Name of exclude customer file list, customers (one per line) will NOT be notified.
 -n: Name of notice file whose contents will be sent to users.
 -x: This (help) message.
```

## Example 

 ```mailerbot.pl -c customer.lst -n notice.txt -e exclude.lst >unmailed_customers.lst```

## Input file examples
#### Example: customer.txt
```console
head customer.lst
21221012345678|Can you check if still have the disk for 'Room with a view'|
21221011111111|Did you forget to return 'Ironman II'?|
21221011111112|Did you forget to return 'Senna'?|
21221011111113|Did you forget to return 'The Mummy Returns'?|
116455|Did you forget to return 'Batman'?|
```

#### Example: AV Incomplete Customer Files
```console
==> incomplete_item_customers.lst # This is the exact file name produced by AVI.
21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB
==> complete_item_customers.lst   # This is the exact file name produced by AVI.
21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB
```

#### Example: notice.txt
```console
head notice.txt
subject:Missing items
Just a friendly reminder. We notice that you returned an item today but part of it was missing.
footer:Your friends at EPL!
```

#### Example: exlcude.lst
```console
head exlcude.lst
21221000000007
21221000000006
1237
```
#### Example: unmailed_customers.lst
```console
head unmailed_customers.lst
21221000000007||
21221000000006||
1237||
21221011111113|| 
```

### Notes on Notices 
Notices follow these rules:
1) If the notice is missing the script exits.
2) If the notice is empty the script exits.
3) If the message body of a notice is empty the script exits.
4) Both footer and subject may be empty but a warning will be issued if the subject is empty.

In general customer files can use formatting like this:
 ```console
 subject: HOLD Cancellation Notice.
 Greetings!
 This is a message to let you know that the following holds have been cancelled.
 # A comment can be put in the file like this. The line must start with a '#' or it will be sent too.
 footer: Signed EPL (we share)
 ```
but the ```footer: ``` and ```subject: ``` tags can appear in any line order but must appear at the beginning of a line.

### Customer files 
The following is an example of a well formed customer file. All lines listed below are legal formats. Consecutive white space causes
formatting errors and is so is removed during processing, and does not appear in out-going messages.
```console
21221012345678|message one|message two|
21221020902471|message|
21221011111111
21221019003992|The big sleep  Tom Wild Date 2014-05-05 | Phil Collins P.Collins April 21, 2014|
```

### Exclude files 
Are used to exclude customers from the mailing process. Customer IDs or user keys must appear one-per-line, but may 
include additional information after the first pipe, it will be ignored.
 ```21221011111111| data_1| data_2| ...| data_n |```

## Current status 
* mailerbothtml.sh version 1.03.04
* mailerbot.pl version 0.4_U_03

## Location 
`/software/EDPL/Unicorn/Bincustom`


### Product Description:
Perl and bash script written by Andrew Nisbet for Edmonton Public Library, distributable by the enclosed license.

### Repository Information:
This product is under version control using Git, and can be found here: https://github.com/Edmonton-Public-Library/mailerbot

### Dependencies:
* seluser - for look ups of customer first name and email address.

### Known Issues:
None
