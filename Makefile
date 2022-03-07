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
APP=mailerbot.pl
HTML_APP=mailerbothtml.sh
AVI_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/Mailerbot/AVIncomplete
ON_ORDER_CANCEL_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/Notifycancelholds
ARGS=-x
.PHONY: test_it put production html

html:
	scp ${LOCAL}/${HTML_APP} ${USER}@${PRODUCTION_SERVER}:${BIN_CUSTOM}
	- scp ${LOCAL}/AVIncomplete* ${USER}@${PRODUCTION_SERVER}:${AVI_DIR}
	- scp ${LOCAL}/OnOrderCancelHoldNotice.html ${USER}@${PRODUCTION_SERVER}:${ON_ORDER_CANCEL_DIR}

put: test_it
	scp ${LOCAL}/${APP} ${USER}@${TEST_SERVER}:${BIN_CUSTOM}
	ssh ${USER}@${TEST_SERVER} '${BIN_CUSTOM}/${APP} ${ARGS}'
	
test_it:
	perl -c ${APP}

production: test_it
	scp ${LOCAL}/${APP} ${USER}@${PRODUCTION_SERVER}:${BIN_CUSTOM}
