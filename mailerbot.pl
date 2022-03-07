#!/usr/bin/perl -w
###########################################################################
#
# Perl source file for project mailerbot 
# Purpose: Mail customers with specified message.
# Method: API.
#
# Mails customers based on input file and matching message file.
#    Copyright (C) 2014  Andrew Nisbet
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
# Created: Mon Feb 24 13:19:28 MST 2014
# Rev: 
#          0.4_U_03 - Mail for Red Hat's version of mailx. 
#          0.4_U_02 - Improve output for gmail. 
#          0.4_U_01 - Improve usage and comments, add html handling. 
#          0.3.07 - Suppress error message if the exclude file is not found. 
#          0.3.06 - Allow for bar codes to be from 10 - 14 digits. 
#          0.3.05 - Fix mail not being sent to valid customer. 
#          0.3.04 - Removed 'o' from input opts. 
#          0.3.03 - Fixed test for empty message concatenation warning. 
#          0.3.02 - Fixed warnings about empty footers. 
#          0.3.01 - Fixed documentation. 
#          0.3 - Fix so that messages can be included on exceptions lists too. 
#          0.2 - Fixed so it doesn't use ssh. 
#          0.1 - Dev. 
#
##############################################################################

use strict;
chomp($ENV{'HOME'} = `. ~/.bashrc; echo ~`);
open(my $IN, "<", "$ENV{'HOME'}/Unicorn/Config/environ") or die "$0: $! $ENV{'HOME'}/Unicorn/Config/environ\n";
while(<$IN>)
{
    chomp;
    my ($key, $value) = split(/=/, $_);
    $ENV{$key} = "$value";
}
close($IN);
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
# $ENV{'PATH'}  = qq{:/software/EDPL/Unicorn/Bincustom:/software/EDPL/Unicorn/Bin:/usr/bin:/usr/sbin};
# $ENV{'UPATH'} = qq{/software/EDPL/Unicorn/Config/upath};
###############################################
my $VERSION           = qq{0.4_U_03};
my $CUSTOMERS         = qq{};
my $EXCLUDE_CUSTOMERS = qq{};
my $NOTICE            = qq{};
my $SUBJECT_SENTINAL  = qq{subject: };
my $FOOTER_SENTINAL   = qq{footer: };

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [-hx] [-c'customer.lst' -n'notice.txt'] [-e'exclude_customer.lst]
Usage notes for mailerbot.pl.
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
    subject: Missing items

    On April 30 you borrowed 'Room with a view'.
    We found the case and not the disk.

    Signed, your friends at EPL.
--snip--

 -D: Set debug flag; all messages sent to STDERR.
 -c: Name of customer file, customers (one per line) will be notified if possible.
 -e: Name of exclude customer file list, customers (one per line) will NOT be notified.
 -h: Send message as HTML.
 -n: Name of notice file whose contents will be sent to users.
 -x: This (help) message.

example: $0 -c'customers.lst' -n'notice.txt' -e'do_not_mail.lst' -D
Version: $VERSION
EOF
    exit;
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'c:De:hn:x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	$CUSTOMERS = $opt{'c'} if ( $opt{'c'} );
	$NOTICE    = $opt{'n'} if ( $opt{'n'} );
	$EXCLUDE_CUSTOMERS = $opt{'e'} if ( $opt{'e'} );
	if ( $CUSTOMERS eq "" ) 
	{
		print STDERR "**Error: customer file not mentioned.\n";
		usage();
	}
	if ( -z $CUSTOMERS )
	{
		print STDERR "**Error: customer file empty.\n";
		usage();
	}
	if ( $NOTICE eq "" )
	{
		print STDERR "**Error: notice file not mentioned.\n";
		usage();
	}
	if ( -z $NOTICE )
	{
		print STDERR "**Error: notice file empty.\n";
		usage();
	}
}

# This function returns two strings, the first which may be empty is 
# the message's subject, the second is the body of the message.
# param:  The fully qualified path to the expected message file.
# return: (subject, message) string tuple.
sub getMessage( $ )
{
	my ($subject, $message, $footer) = "";
	my $fileRoot                     = shift;
	# open the the message file 
	open MESSAGE, "<$fileRoot" or die "***Error, couldn't open message file, exiting before anything bad happens: $!\n";
	while (<MESSAGE>)
	{
		# Ignore lines that start with a comment.
		next if ( m/^#/ );
		# Grab the subject it starts with 'subject: '.
		if ( m/^subject:\s+/ )
		{
			my $s = $';
			chomp $s;
			$subject = $s;
			next;
		}
		if ( m/^footer:\s+/ )
		{
			my $s = $';
			chomp($s);
			$footer = $s;
			next;
		}
		# The rest of the file is message including blank lines.
		$message .= $_;
	}
	close MESSAGE;
	# Test if we got a message and exit if none.
	if ( ! $message )
	{
		# Stop the script if the message file was empty, I mean what's the point?
		print STDERR "***Error: no message to send found in $fileRoot. Exiting.\n";
		exit 2;
	}
	# test if we have a subject but warn if none.
	if ( ! $subject )
	{
		# Warn if the subject is empty.
		print STDERR "***Warning: no subject to send found in $fileRoot.\n";
	}
	# Don't test for footer.
	return ($subject, $message, $footer);
}

# ==> incomplete_item_customers.lst <==
# 21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB
# ==> complete_item_customers.lst <==
# 21221012345678|Cats / by Jim Pipe|insert / booklet missing|31221096645630|ABB
# Reads the contents of a file into a hash reference with barcode->message|message|.
# param:  file name string - path to the customers to mail, or exclude from mailing file.
# param:  0 to not warn of missing or empty file, ie: exclude customer files, and 1 otherwise.
# return: hash reference - table data.
sub readMessageTable( $$ )
{
	my ( $fileName ) = shift;
	my $warnMe       = shift; 
	my $table        = {};
	if ( ! -e $fileName )
	{
		printf STDERR "'%s' not found or is empty\n", $fileName if ( $warnMe );
		return $table;
	}
	open TABLE, "<$fileName" or die "Serialization error reading '$fileName' $!\n";
	while ( <TABLE> )
	{
		chomp;
		my @fields = split( '\|' );
		print STDERR "* DEBUG: fields '".@fields."' empty\n" if ( $opt{'D'} );
		my $key = shift @fields;
		$table->{ $key } = join '|', @fields;
		printf STDERR "* DEBUG: '%s'->{'%s'}='%s'\n", $table, $key, $table->{ $key } if ( $opt{'D'} );
	}
	close TABLE;
	return $table;
}

# Removes bar codes from the mail list explicitly mentioned in exclude list.
# param:  customer barcode hash.
# param:  customers to be removed.
# return: 
sub removeExcludeCustomers( $$ )
{
	my ( $keepHash, $removeHash ) = @_;
	for my $rmCustomer ( sort keys %$removeHash ) 
	{
        if ( defined $keepHash->{$rmCustomer} )
		{
			delete $keepHash->{$rmCustomer};
			printf STDERR "removing: '%14s'\n", $rmCustomer if ( $opt{'D'} );
		}
    }
}

# Searches ILS for all email addresses for the barcodes in the argument hash.
# param:  customer barcode message hash.
# return: hash of emails to messages (if any).
sub getEmailableCustomers( $ )
{
	my $fullHash  = shift;
	my $emailHash = {};
	LINE: while( my ($k, $messages) = each %$fullHash ) 
	{
		# echo 21221012345678 | seluser -iB -oX.9007.
		# my $result = `ssh sirsi\@edpl.sirsidynix.net 'echo $k | seluser -iB -oX.9007.' 2>/dev/null`;
		my $result = "";
		if ( $k =~ m/^\d{10,14}/ ) # Allow for 13 and smaller digit bar codes.
		{
			$result = `echo $k | seluser -iB -oX.9007. 2>/dev/null`;
		}
		elsif ( $k =~ m/^\d{3,7}/ ) # user key.
		{
			$result = `echo $k | seluser -iU -oX.9007. 2>/dev/null`;
		}
		else
		{
			print STDERR "**ignoring unrecognized user identifier '$k'\n";
			next LINE;
		}
		my @addrs = split '\|', $result;
		if ( defined $addrs[0] and $addrs[0] )
		{
			# Take the first address if many.
			$emailHash->{$addrs[0]} = $messages;
			# print STDERR "key: $addrs[0], value: $messages.\n";
		}
		else # No email address so print the bar code.
		{
			# TODO: Optionally print to file for -o
			print "$k|$messages|\n";
		}
	}
	return $emailHash;
}

#
# Sends recipients messages via email.
# param:  subject string
# param:  recipents emails string
# param:  message string
# param:  hash of customer email addresses and optional messages string
# return:
#
sub sendMail( $$$$ )
{
	my ($subject, $globalMessage, $footer, $customerHash) = @_;
	while( my ($recipient, $messages) = each %$customerHash ) 
	{
		my $entireMessage = $globalMessage."\n";
		my @myMessages = split '\|', $messages;
		foreach my $message ( @myMessages )
		{
			# Multiple white space causes script to output without new line (???)
			$message =~ s/\s{2,}/ /g;
			$entireMessage .= $message."\n" if ( $message );
		}
		$entireMessage .= "\n$footer\n" if ( defined $footer and $footer );
        `echo "$entireMessage" | /usr/bin/mailx -s '$subject' $recipient`;
		$entireMessage = "";
	}
}

#
# Sends recipients HTML messages via email.
# param:  subject string
# param:  recipents emails string
# param:  message string
# param:  hash of customer email addresses and optional messages string
# return:
#
sub sendHTMLMail( $$$$ )
{
	my ($subject, $globalMessage, $footer, $customerHash) = @_;
	while( my ($recipient, $messages) = each %$customerHash ) 
	{
		my $entireMessage = $globalMessage."\n";
		open( MAILER, " | /usr/sbin/sendmail -t" ) or die "Unable to email because: $!\n";
		my @myMessages = split '\|', $messages;
		foreach my $message ( @myMessages )
		{
			# Multiple white space causes script to output without new line (???)
			$message =~ s/\s{2,}/ /g;
			$entireMessage .= $message."\n" if ( $message );
		}
		$entireMessage .= "\n$footer\n" if ( defined $footer and $footer );
		# my $headers = "To: $recipient\n";
		# $headers .= "Subject: $subject\n";
		# $headers .= "MIME-Version: 1.0\n";
		# $headers .= "Content-type: text/html\n\n";
		# $headers .= "$entireMessage\n";
		# print MAILER << "EOF";
# $headers
# EOF
		print MAILER << "EOF";
To: $recipient
Subject: $subject
Content-type: text/html

$entireMessage
EOF
		close MAILER;
	}
}

init();

# Find test and load subject and message.
my ($subject, $message, $footer) = getMessage( $NOTICE );
printf STDERR "* DEBUG: NOTICE file '%s':\n subject:'%s'\n message:'%s'\n footer:'%s'\n", $NOTICE, $subject, $message, $footer if ( $opt{'D'} );
# This step normalizes the list against the exclude list.
printf STDERR "* DEBUG: customer file: '%s'\n", $CUSTOMERS if ( $opt{'D'} );
printf STDERR "* DEBUG: exclude customer file: '%s'\n", $EXCLUDE_CUSTOMERS if ( $opt{'D'} and $opt{'e'} );
my $idHash   = readMessageTable( $CUSTOMERS, 1 );
print STDERR "* DEBUG: read users and messages " . keys( %$idHash ) . "\n" if ( $opt{'D'} );
my $idRmHash = readMessageTable( $EXCLUDE_CUSTOMERS, 0 );
print STDERR "* DEBUG: read users and messages " . keys( %$idRmHash ) . "\n" if ( $opt{'D'} );
removeExcludeCustomers( $idHash, $idRmHash ) if ( scalar( keys ( %$idRmHash ) ) > 0 );
# This next step returns a hash of email->"message one|message two
my $emailableCustomerHash = getEmailableCustomers( $idHash );
print STDERR "* DEBUG: final list size: " . keys( %$emailableCustomerHash ) . "\n" if ( $opt{'D'} );
# lastly, email users.
if ( $opt{'h'} )
{
	sendHTMLMail( $subject, $message, $footer, $emailableCustomerHash );
}
else
{
	sendMail( $subject, $message, $footer, $emailableCustomerHash );
}
my $count = 0;
$count += keys %$emailableCustomerHash;
print STDERR "Total customers mailed: $count\n";
# EOF
