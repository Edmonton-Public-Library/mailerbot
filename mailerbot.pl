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
#          0.3.03 - Fixed test for empty message concatenation warning. 
#          0.3.02 - Fixed warnings about empty footers. 
#          0.3.01 - Fixed documentation. 
#          0.3 - Fix so that messages can be included on exceptions lists too. 
#          0.2 - Fixed so it doesn't use ssh. 
#          0.1 - Dev. 
#
##############################################################################

use strict;
use warnings;
use vars qw/ %opt /;
use Getopt::Std;

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
$ENV{'PATH'}  = qq{:/s/sirsi/Unicorn/Bincustom:/s/sirsi/Unicorn/Bin:/usr/bin:/usr/sbin};
$ENV{'UPATH'} = qq{/s/sirsi/Unicorn/Config/upath};
###############################################
my $VERSION           = qq{0.3.03};
my $WORKING_DIR       = qq{.};
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

	usage: $0 [-x]
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
    Subject: Missing items

    On April 30 you borrowed 'Room with a view'.
    We found the case and not the disk.

    Signed, your friends at EPL.
--snip--

 -c: Name of customer file, customers (one per line) will be notified if possible.
 -e: Name of exclude customer file list, customers (one per line) will NOT be notified.
 -n: Name of notice file whose contents will be sent to users.
 -x: This (help) message.

example: $0 -x
Version: $VERSION
EOF
    exit;
}

# Kicks off the setting of various switches.
# param:  
# return: 
sub init
{
    my $opt_string = 'c:e:n:o:x';
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
	my $fileRoot            = shift;
	# open the the message file 
	open MESSAGE, "<$fileRoot" or die "***Error, couldn't open message file, exiting before anything bad happens: $!\n";
	while (<MESSAGE>)
	{
		# Ignore lines that start with a comment.
		next if (m/^#/);
		# Grab the subject it starts with 'subject: '.
		if (m/^($SUBJECT_SENTINAL)/)
		{
			my $s = $';
			chomp($s);
			$subject .= $s;
			next;
		}
		if (m/^($FOOTER_SENTINAL)/)
		{
			my $s = $';
			chomp($s);
			$footer .= $s;
			next;
		}
		# The rest of the file is message including blank lines.
		$message .= $_;
	}
	close MESSAGE;
	# Test if we got a message and exit if none.
	if ( $message eq "" )
	{
		# Stop the script if the message file was empty, I mean what's the point?
		print STDERR "***Error: no message to send found in $fileRoot. Exiting.\n";
		exit 2;
	}
	# test if we have a subject but warn if none.
	if ( $subject eq "" )
	{
		# Warn if the subject is empty.
		print STDERR "***Warning: no subject to send found in $fileRoot.\n";
	}
	# Don't test for footer.
	return ($subject, $message, $footer);
}

# Reads the contents of a file into a hash reference with barcode->message|message|.
# param:  file name string - path of file to write to.
# return: hash reference - table data.
sub readMessageTable( $ )
{
	my ( $fileName ) = shift;
	my $table        = {};
	return $table if ( -z $fileName );
	if ( -e $fileName )
	{
		open TABLE, "<$fileName" or die "Serialization error reading '$fileName' $!\n";
		while ( <TABLE> )
		{
			chomp;
			my @fields = split( '\|' );
			my $key = shift @fields;
			$table->{ $key } = join '|', @fields;
		}
		close TABLE;
	}
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
			print STDERR "removing: $rmCustomer\n";
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
		# my $result = `ssh sirsi\@eplapp.library.ualberta.ca 'echo $k | seluser -iB -oX.9007.' 2>/dev/null`;
		my $result = "";
		if ( $k =~ m/^\d{14}/ )
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
		open( MAILER, "| /usr/bin/mailx -s '$subject' $recipient" ) or die "Unable to email because: $!\n";
		my @myMessages = split '\|', $messages;
		foreach my $message ( @myMessages )
		{
			# Multiple white space causes script to output without new line (???)
			$message =~ s/\s{2,}/ /g;
			$entireMessage .= $message."\n" if ( $message );
		}
		$entireMessage .= "\n$footer\n" if ( defined $footer and $footer );
		print MAILER $entireMessage;
		close( MAILER );
		$entireMessage = "";
	}
}

init();

# Find test and load subject and message.
my ($subject, $message, $footer) = getMessage( $NOTICE );
# This step normalizes the list against the exclude list.
my $idHash   = readMessageTable( $CUSTOMERS );
my $idRmHash = readMessageTable( $EXCLUDE_CUSTOMERS );
removeExcludeCustomers( $idHash, $idRmHash );
# This next step returns a hash of email->"message one|message two
my $emailableCustomerHash = getEmailableCustomers( $idHash );
# lastly, email users.
sendMail( $subject, $message, $footer, $emailableCustomerHash );
my $count = 0;
$count += keys %$emailableCustomerHash;
print STDERR "Total customers mailed: $count\n";
# EOF
