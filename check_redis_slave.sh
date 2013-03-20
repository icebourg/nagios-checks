#!/bin/bash

# check_redis_slave.sh
# Nagios check to ensure that this redis server is either a master with
# connected slaves or a slave with an up master. Anything else results in an
# error.
# Author: AJ Bourg (aj <at> ajbourg dot com)


usage()
{
cat << EOF
Usage:
  $0 -s [socket]
    
    Connect to redis via socket.
    
  $0 -i [redis ip] -p [port]
  
    Connect to redis via ip/host and port.
    
  $0 -h
  
    This help.

This script is intended to be called by nagios to check redis. We connect to 
redis and check the role. If role:slave, we expect that the master has a status
of UP. If role:master, we expect connected_slaves to be >= 1. If we can\'t
connect to redis, that\'s a immediate critical warning.

redis-cli must be in your path.

EOF
}

SOCKET=
REDIS_IP=127.0.0.1
REDIS_PORT=6379

# Options

while getopts "s:i:p:h" OPTION
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

ROLE=$(redis-cli $CONNECT_STRING INFO | grep '^role' | cut -d':' -f2 | tr -d '\r\n')

# We're a slave. Our master needs to be up.
if [[ "$ROLE" == "slave" ]]
then
  # is the master up?
  STATUS=$(redis-cli $CONNECT_STRING INFO | grep '^master_link_status' | cut -d':' -f2 | tr -d '\r\n')
  
  # who is our master?
  MASTER=$(redis-cli $CONNECT_STRING INFO | grep '^master_host' | cut -d':' -f2 | tr -d '\r\n')
  
  if [[ "$STATUS" == "up" ]]
  then
    # ok
    echo "OK: master $MASTER is $STATUS."
    exit 0
  else
    # not ok
    echo "CRITICAL: master $MASTER is $STATUS."
    exit 2
  fi
fi

# We're a master. Need at least 1 client.
if [[ "$ROLE" == "master" ]]
then
  SLAVES=$(redis-cli $CONNECT_STRING INFO | grep '^connected_slaves' | cut -d':' -f2 | tr -d '\r\n')
  
  if [[ $SLAVES -gt 0 ]]
  then
    echo "OK: We have $SLAVES slaves."
    exit 0
  else
    echo "CRITICAL: We have $SLAVES slaves."
    exit 2
  fi
fi

# If we made it this far, something weird is up man... report critical
echo "CRITICAL: Role is $ROLE and I don\'t know what to do."
exit 2
