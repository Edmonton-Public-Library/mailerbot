####################################################
# Makefile for project mailerbot 
# Created: Mon Feb 24 13:19:28 MST 2014
#
# Distributes script to appropriate directories depending on server.
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
# Written by Andrew Nisbet at Edmonton Public Library
# Rev:
#      0.3 - Add templates for Customer Activity Notification (cron) report.
#      0.2 - Add mailerbothtml.sh and templates.
#      0.1 - Modified target to point to Bincustom, added .PHONY. rule. 
#      0.0 - Dev. 
####################################################
# Change comment below for appropriate server.
PRODUCTION_SERVER=edpl.sirsidynix.net
TEST_SERVER=edpltest.sirsidynix.net
USER=sirsi
BIN_CUSTOM=~/Unicorn/Bincustom
# BIN_CUSTOM=/software/EDPL/Unicorn/EPLwork/anisbet/EPL4Life/EmailTemplate/
LOCAL=~/projects/mailerbot
HTML_APP=mailerbothtml.sh
NOTICE_DIR=/software/EDPL/Unicorn/Notices

.PHONY: production html test

test:
	scp ${LOCAL}/${HTML_APP} ${USER}@${TEST_SERVER}:${BIN_CUSTOM}
	- scp ${LOCAL}/CustomerActivityNotification.html ${USER}@${TEST_SERVER}:${NOTICE_DIR}

production:
	scp ${LOCAL}/${HTML_APP} ${USER}@${PRODUCTION_SERVER}:${BIN_CUSTOM}

html:
	scp ${LOCAL}/*.html ${USER}@${PRODUCTION_SERVER}:${NOTICE_DIR}
	