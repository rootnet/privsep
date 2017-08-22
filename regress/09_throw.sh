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

dotest throwAccept 255 "Fatal error: Uncaught Exception: Exception in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
\$t->throwAccept();
EOF

dotest throwIndirectAccept 255 'Fatal error: Uncaught ErrorException: Error exception in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
\$t->throwIndirectAccept();
EOF

dotest throwDeny 255 "Fatal error: Uncaught Exception: Untransferable in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
\$t->throwDeny();
EOF

dotest throwIndirectDeny 255 "Fatal error: Uncaught Exception: Untransferable in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
\$t->throwIndirectDeny();
EOF

dotest throwFilterLast 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
try {
    \$t->filterLast();
} catch (\\Exception \$e) {
    if (\$e->getPrevious() || \$e->getMessage() !== "Seen exception") {
        throw \$e;
    }
}
EOF

dotest throwFilterFirst 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
try {
    \$t->filterFirst();
} catch (\\Error \$e) {
    if (\$e->getPrevious() || \$e->getMessage() !== "Seen error") {
        throw \$e;
    }
}
EOF

dotest throwFilterMiddle 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class cthrow extends \\Rootnet\\Privsep\\Remote {
}
cthrow::\$remote = "unix:///tmp/server1.sock";

\$t = new cthrow;
try {
    \$t->filterMiddle();
} catch (\\Error \$e) {
    \$previous = \$e->getPrevious();
    if (!isset(\$previous) || \$e->getMessage() !== "Seen error") {
        throw \$e;
    }
    if (\$previous->getPrevious() || \$previous->getMessage() !== "Seen type error") {
        throw \$e;
    }
}
EOF

exit $EXITSTATUS
