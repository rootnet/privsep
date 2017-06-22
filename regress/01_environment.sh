#!/bin/sh

cleanup() {
    if [ $? -ne 0 ]; then
        printf "\nOutput of privsepd log: \n"
        cat $log1
    fi
    kill $SERVER1
    rm -f $log1
}

trap cleanup EXIT

[ `id -u` -ne 0 ] && echo "Not running as root" >&2 && exit 1

log1=`mktemp /tmp/server1.log.XXXXXX`

# Remove potential leftover socket
rm -f /tmp/server1.sock

PHP=${PHP:-`which php`}
${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
SERVER1=$!

# Make sure the daemon is up and running
sleep 0.1
# Test normal startup environment
[ ! -S /tmp/server1.sock ] && echo "Socket file not created" >&2 && exit 1
[ `ls -l /tmp/server1.sock | awk '{ print $3 }'` != "daemon" ] && echo "Socket not owned by daemon" >&2 && exit 1
[ `ls -l /tmp/server1.sock | awk '{ print $4 }'` != "daemon" ] && echo "Socket not group owned by daemon" >&2 && exit 1
[ `ls -l /tmp/server1.sock | awk '{ print $1 }'` != "srwxrwxrwx" ] && echo "Wrong socket permissions" >&2 && exit 1
[ `ps -o uid= -p $SERVER1` -ne `id -u nobody` ] && echo "Wrong daemon uid" >&2 && exit 1
[ `ps -o gid= -p $SERVER1` -ne `getent group nogroup | cut -d: -f3` ] && echo "Wrong daemon gid" >&2 && exit 1
# I can't find a proper way to test if the daemon is chrooted

kill $SERVER1

# Test if the daemon overwrites files
rm -f /tmp/server1.sock
touch /tmp/server1.sock

${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
SERVER1=$!
sleep 0.1

[ ! -S /tmp/server1.sock ] && echo "Socket file not overwritten" >&2 && exit 1

exit 0
