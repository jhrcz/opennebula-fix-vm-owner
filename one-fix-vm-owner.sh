#!/bin/bash -x
exit 0

sleep 1

######################################################################
#
# Changes owner of opennebula VMs to owner of vm template
#
# Script operates on all "live" VMs or on one define by argument.
# The second case is useful for use as a VM_HOOK to automagicaly
# set VM names.
#
# Requires password-less login to mysql, db opennebula and user opennebula.
# Password for db user could configured with in ~oneadmin/.my.cnf:
# [mysql]
# user=opennebula
# password=XXXX
#
######################################################################

# function for simple debugging condition
# use: qdebug && echo debug message
function qdebug
{
	if [ "$DEBUG" = "YES" ]
	then
		return 0
	else
		return 1
	fi
}

# be verbose and write detailed trace to logfile
qdebug && \
	set -x
qdebug && \
	exec 2>/tmp/debug-$$.log

######################################################################
# CONFIGURATION
######################################################################

# command to "connect" to the one db
#DB="sqlite3 /var/lib/one/one.db"
DB="mysql -N -u opennebula opennebula"

######################################################################
# END CONFIGURATION
######################################################################

# function for running db queries
# use: dbq "dome sql query;"
function dbq
{
  echo "$1" | $DB
}

( if [ -n "$1" ]
then
	echo "$1"
else
	# 6=done, 7=failed
	#dbq "select oid from vm_pool where state not in  ( 6, 7 ) and name like 'one-%';"
	dbq "select oid from vm_pool where name like '${oldname_prefix}%';"
fi )| while read oid
do
	qdebug && \
		dbq "select name from vm_pool where oid = $oid;" | sed -e "s/^/DEBUG:/"
	qdebug && \
		dbq "select body from vm_pool where oid = $oid;" | sed -e "s/^/DEBUG:/"

	templateid=$(dbq "select body from vm_pool where oid = $oid;"  | xmlstarlet fo | xmlstarlet sel -t -v '//VM/TEMPLATE/TEMPLATE_ID')
	[ -n "$templateid" ] || continue
	templateowner=$(dbq "select uid from template_pool where oid = $templateid;")

	newowner="$templateowner"

	# do not chown when template owned by oneadmin or serveradmin
	oldowner=$(dbq "select uid from vm_pool where oid = $oid;")
	case $newowner in
		0|1)
			continue
			;;
	esac

	# treat any error before new name is detected
	if [ -n "$newowner" ]
	then
		qdebug && \
			echo "DEBUG: $newowner"
		
		onevm chown $oid $newowner
	fi

done

