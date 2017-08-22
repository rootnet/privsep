#!/bin/sh

EXITSTATUS=0

cleanup() {
    if [ $? -ne 0 ]; then
        echo "log1:"
        cat $log1
        echo "log2:"
        cat $log2
    fi
    kill $SERVER1
    kill $SERVER2
    rm -f $log1
    rm -f $log2
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
log2=`mktemp /tmp/server2.log.XXXXXX`
PHP=${PHP:-`which php`}
REMOTE=${REMOTE:-../src/Remote.php}
CLIENT=${CLIENT:-../src/Client.php}
ERROR=${ERROR:-../src/Throwable/RemoteError.php}

${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
SERVER1=$!
${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server2.conf > $log1 2>&1 &
SERVER2=$!
# Should be more than enough time for the daemon to start up
sleep 0.1

## Test public gets
# This should succeed

dotest doublebackend 0 "remote1 remote2" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class remote1 extends \\Rootnet\\Privsep\\Remote {
    public static \$remote = "unix:///tmp/server1.sock";
}

class remote2 extends \\Rootnet\\Privsep\\Remote {
    public static \$remote = "unix:///tmp/server2.sock";
}

\$r1 = new remote1;
\$r2 = new remote2;

echo \$r1->name." ".\$r2->name;
EOF

dotest crossreference 255 "Fatal error: Uncaught Error: Can't mix backends in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class remote1 extends \\Rootnet\\Privsep\\Remote {
    public static \$remote = "unix:///tmp/server1.sock";
}

class remote2 extends \\Rootnet\\Privsep\\Remote {
    public static \$remote = "unix:///tmp/server2.sock";
}

\$r1 = new remote1;
\$r2 = new remote2;

\$r2->doclass(\$r2);
\$r2->doclass(\$r1);
EOF

exit $EXITSTATUS
