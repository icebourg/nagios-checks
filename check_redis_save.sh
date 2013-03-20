#!/bin/bash

# check_redis_save.sh
# Nagios checker for alerting when Redis hasn't recently saved its contents
# to disk.
# Author: AJ Bourg (aj@sendgrid.com)

#
# Based on the example from Chris Lamb
# https://chris-lamb.co.uk/posts/monitoring-redis-check-last-save-time
#
# This does the same thing but entirely within bash without Python dependencies
#

usage()
{
cat << EOF
Usage:
  $0 -s [socket] -w [warning] -c [critical]
    
    Connect to redis via socket. Warn on warning, critical on critical.
    
  $0 -i [redis ip] -p [port] -w [warning] -c [critical]
  
    Connect to redis via ip/host and port.
    
  $0 -h
  
    This help.

This script is intended to be called by nagios to check redis. We connect to 
redis and check rdb_last_save_time and alert based on warning/critical values.

IP defaults to 127.0.0.1, port defaults to 6379, warning to 3600, 
critical to 7200. Specify whatever you\'d like to override.

redis-cli must be in your path.

EOF
}

SOCKET=
WARNING=3600
CRITICAL=7200
REDIS_IP=127.0.0.1
REDIS_PORT=6379


# Options

while getopts "s:i:p:w:c:h" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    s)
      SOCKET=$OPTARG
      ;;
    i)
      REDIS_IP=$OPTARG
      ;;
    p)
      REDIS_PORT=$OPTARG
      ;;
    w)
      WARNING=$OPTARG
      ;;
    c)
      CRITICAL=$OPTARG
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

if [[ "$SOCKET" ]]
then
  CONNECT_STRING="-s $SOCKET "
else
  CONNECT_STRING="-h $REDIS_IP -p $REDIS_PORT "
fi

# see if we can even connect, or throw up a critical error
redis-cli $CONNECT_STRING PING &> /dev/null

if [[ $? -ne 0 ]]
then
  echo "CRITICAL: Unable to connect to Redis."
  exit 2
fi

LAST_SAVE=$(redis-cli $CONNECT_STRING INFO | grep '^rdb_last_save_time' | cut -d':' -f2 | tr -d '\r\n')
CURRENT_TIME=$(date +%s)
DIFFERENCE=$(($CURRENT_TIME-$LAST_SAVE))

# critical time difference?
if [[ $DIFFERENCE -gt $CRITICAL ]]
then
  echo "CRITICAL: Last save was $DIFFERENCE seconds ago, above threshold $CRITICAL."
  exit 2
fi

# warning time difference?
if [[ $DIFFERENCE -gt $WARNING ]]
then
  echo "WARNING: Last save was $DIFFERENCE seconds ago, above threshold $WARNING. Goes critical at $CRITICAL seconds."
  exit 1
fi

# If we made it this far, it's an acceptable time difference so report ok
echo "OK: Last save was $DIFFERENCE seconds ago. Warns at $WARNING seconds."
exit 0
