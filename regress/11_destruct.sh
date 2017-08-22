#!/bin/sh

EXITSTATUS=0

cleanup() {
    if [ $? -ne 0 ]; then
        printf "\nOutput of privsepd log: \n"
        cat $log1
    fi
    kill $SERVER1
    rm -f $log1
}

dotest() {
    local TESTNAME="$1"
    local RESULT="$2"
    local SKIP="$3"
    local OUTPUT
    local EXITCODE

    echo -n "Now running test $TESTNAME: " >&2
    if [ "$SKIP" = "yes" ]; then
        echo SKIP >&2
        return 0;
    fi

    OUTPUT="`${PHP} >/dev/null 2>&1`"
    EXITCODE=$?

    if [ $EXITCODE -ne 0 ]; then
        echo FAILED >&2
        echo "EXITED WITH CODE '$EXITCODE'"
        echo "OUTPUT:"
        printf "%s\n" "${OUTPUT}"
        EXITSTATUS=1
        return 1
    fi

# Make sure the log is consistently written
# hashtag ugly
    sleep 0.1
    kill $SERVER1
    wait $SERVER1
    if ! grep -qE "^$RESULT$" $log1; then
        echo FAILED >&2
        echo "COULDN'T FIND: $RESULT"
        EXITSTATUS=1
        ${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
        SERVER1=$!
        return 1
    fi
    ${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
    SERVER1=$!
    echo PASS >&2
}

trap cleanup EXIT

log1=`mktemp /tmp/server1.log.XXXXXX`
PHP=${PHP:-`which php`}
REMOTE=${REMOTE:-../src/Remote.php}
CLIENT=${CLIENT:-../src/Client.php}
ERROR=${ERROR:-../src/Throwable/RemoteError.php}

${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
SERVER1=$!

# Should be more than enough time for the daemon to start up
sleep 0.1

## Test public gets
# This should succeed

# Do we have Weakref
SKIP=`php -r 'echo extension_loaded("Weakref") ? "no\n" : "yes\n";'`

dotest Weakref "DESTROYSPLITDESTROYSPLITDESTROY" $SKIP << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class destruct extends \\Rootnet\\Privsep\\Remote {
}
destruct::\$remote = "unix:///tmp/server1.sock";

\$d = new destruct;
\$d = new destruct;
\$d->identifier();
\$d = new destruct;
\$d->identifier();
\$d->end();
unset(\$d);
EOF
