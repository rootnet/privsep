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
    local SKIP=$4
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
ERROR=${ERROR:-../src/Error/RemoteError.php}

${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
SERVER1=$!

# Should be more than enough time for the daemon to start up
sleep 0.1

## Test public gets
# This should succeed

dotest string 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (\$r->string() !== (string) "1") {
	echo "unreached";
	exit(1);
}
EOF

dotest int 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (\$r->int() !== (int) 1) {
	echo "unreached";
	exit(1);
}
EOF

dotest float 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (\$r->float() !== (float) 1.0) {
	echo "unreached";
	exit(1);
}
EOF

dotest bool 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (\$r->bool() !== (bool) true) {
	echo "unreached";
	exit(1);
}
EOF

dotest array 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (!is_array(\$r->array())) {
	echo "unreached";
	exit(1);
}
EOF

dotest callable 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (!is_callable(\$r->callable())) {
	echo "unreached";
	exit(1);
}
EOF

dotest object 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
if (!is_a(\$r->object(), "returnval")) {
	echo "unreached";
	exit(1);
}
EOF

dotest resource 255 "Fatal error: Uncaught TypeError: Transferring resources not supported in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class returnval extends \\Rootnet\\Privsep\\Remote {
}
returnval::\$spath = "unix:///tmp/server1.sock";

\$r = new returnval;
\$r->resource();
EOF

exit $EXITSTATUS
