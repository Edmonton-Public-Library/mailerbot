#!/usr/bin/perl -w
#################################################### #!/s/sirsi/Unicorn/Bin/perl -w
#
# Perl source file for project mailerbot 
# Purpose: Mail customers with specified message.
# Method: API.
#
# Mails customers based on input file and matching message file.
#    Copyright (C) 2013  Andrew Nisbet
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
#          0.1 - Dev. 
#
####################################################

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
my $VERSION    = qq{0.1};
my $WORKING_DIR= qq{.};
my $CUSTOMERS  = qq{};
my $NOTICE     = qq{};
my $SUBJECT    = qq{subject: };

#
# Message about this program and how to use it.
#
sub usage()
{
    print STDERR << "EOF";

	usage: $0 [-x]
Usage notes for mailerbot.pl.
Mailerbot is a project that emails customers messages. The script itself is 
simple: run on schedule and on wake-up check the working directory for pairs 
of files. Any file that ends in '.email' must have a list of user IDs (barcodes)
one per line. The file can be named anything like 'holds_no_purchase.email'. 
Mailerbot will then look for a matching file called 'holds_no_purchase.message' file
and send that message to the users listed in the 'holds_no_purchase.email' file.

If the names do not match no message is sent. Use '#' for comments in both 
message and user key file.

Internally the script will check each user key and report those it can email and
those it can not (because the user does not have an email address), and write 
those keys to 'fail' file, and change the name of the 'holds_no_purchase.key'
to 'holds_no_purchase.sent'. Clobber file if is exists.

 -n: Name of notice file whose contents will be sent to users.
 -c: Name of customer file, customers (one per line) will be notified if possible.
 -o: Name of the file that will contain the failed customers. Default stdout.
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
    my $opt_string = 'c:n:o:x';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if ( $opt{'x'} );
	$CUSTOMERS = $opt{'c'} if ( $opt{'c'} );
	$NOTICE    = $opt{'n'} if ( $opt{'n'} );
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
	print STDERR "All good \n";
}

# This function returns two strings, the first which may be empty is 
# the message's subject, the second is the body of the message.
# param:  The fully qualified path to the expected message file.
# return: (subject, message) string tuple.
sub getMessage( $ )
{
	my ($subject, $message) = "";
	my $fileRoot            = shift;
	# open the the message file 
	open MESSAGE, "<$fileRoot" or die "***Error, couldn't open message file, exiting before anything bad happens: $!\n";
	while (<MESSAGE>)
	{
		# Ignore lines that start with a comment.
		next if (m/^#/);
		# Grab the subject it starts with 'subject: '.
		if (m/^($SUBJECT)/)
		{
			my $s = $';
			chomp($s);
			$subject .= $s;
			next;
		}
		# The rest of the file is message including blank lines.
		$message .= $_;
	}
	close MESSAGE;
	if (! defined $message or $message eq "")
	{
		# Stop the script if the message file was empty, I mean what's the point?
		print STDERR "***Warning: now message to send found in $fileRoot. Exiting.\n";
		exit 2;
	}
	return ($subject, $message);
}



init();

my ($subject, $message) = getMessage( "test/test.msg" );
print "==$subject\n==$message\n";
# EOF
