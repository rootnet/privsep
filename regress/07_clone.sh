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
    local EXPEXITCODE="$2"
    local EXPOUTPUT="$3"
    local SKIP="$4"
    local OUTPUT
    local EXITCODE

    echo -n "Now running test $TESTNAME: " >&2
    if [ "$SKIP" = "yes" ]; then
        echo SKIP >&2
        return 0;
    fi

    OUTPUT="`${PHP} 2>&1`"
    EXITCODE=$?
    OUTPUT="`echo $OUTPUT | sed 's/  / /g'`"

    if [ $EXITCODE -ne $EXPEXITCODE ]; then
        echo FAILED >&2
        echo "EXITED WITH CODE '$EXITCODE' EXPECTING '$EXPEXITCODE'"
        echo "OUTPUT:"
        printf "%s\n" "${OUTPUT}"
        EXITSTATUS=1
        return 1
    fi
    if [ -n "${EXPOUTPUT}" ] && ! printf "%s" "${OUTPUT}" | grep -qF "${EXPOUTPUT}"; then
        echo FAILED >&2
        echo "OUTPUT:"
        printf "%s\n" "${OUTPUT}"
        echo "EXPECTED OUTPUT:"
        printf "%s\n" "${EXPOUTPUT}"
        EXITSTATUS=1
        return 1
    fi

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

dotest clone 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cclone extends \\Rootnet\\Privsep\\Remote {
}
cclone::\$remote = "unix:///tmp/server1.sock";

\$c1 = new cclone;
\$c2 = clone \$c1;
\$c3 = clone \$c2;
\$c4 = clone \$c1;
if (
    \$c1->id !== 0 ||
    \$c2->id !== 1 ||
    \$c3->id !== 2 ||
    \$c4->id !== 1
) {
    echo "unreached";
    exit(1);
}
EOF

dotest call__clone 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cclone extends \\Rootnet\\Privsep\\Remote {
}
cclone::\$remote = "unix:///tmp/server1.sock";

\$c = new cclone;
if (\$c->id !== 0) {
    echo "unreached";
    exit(1);
}
\$c->__clone();
if (\$c->id !== 1) {
    echo "unreached";
    exit(1);
}
EOF

exit $EXITSTATUS
