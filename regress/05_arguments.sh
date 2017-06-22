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
ERROR=${ERROR:-../src/Error/RemoteError.php}

${PHP} ${PRIVSEPD:=../privsepd.php} -dc ./server1.conf > $log1 2>&1 &
SERVER1=$!

# Should be more than enough time for the daemon to start up
sleep 0.1

## Test public gets
# This should succeed

dotest argcount 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (
    \$a->count() !== 0 ||
    \$a->count(1) !== 1 ||
    \$a->count(1, 2) !== 2
) {
    echo "unreached";
    exit(1);
}
EOF

dotest argstring 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::string() must be of the type string, integer given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->string("string") !== true) {
    echo "unreached";
    exit(1);
}
\$a->string(1);
EOF

dotest argint 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::int() must be of the type integer, float given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->int(1) !== true) {
    echo "unreached";
    exit(1);
}
\$a->int(1.0);
EOF

dotest argfloat 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::float() must be of the type float, boolean given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->float(1.0) !== true) {
    echo "unreached";
    exit(1);
}
\$a->float(true);
EOF

dotest argbool 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::bool() must be of the type boolean, array given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->bool(true) !== true) {
    echo "unreached";
    exit(1);
}
\$a->bool([]);
EOF

dotest argcallable 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::callable() must be callable, array given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->callable(function(){}) !== true) {
    echo "unreached";
    exit(1);
}
\$a->callable([]);
EOF

dotest argarray 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::array() must be of the type array, object given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->array([]) !== true) {
    echo "unreached";
    exit(1);
}
\$a->array(new StdClass);
EOF

dotest argobject 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::callable() must be callable, string given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
if (\$a->object(new stdClass) !== true) {
    echo "unreached";
    exit(1);
}
\$a->callable("string");
EOF

dotest argresource 255 "Fatal error: Uncaught TypeError: Transferring resources not supported in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
\$a->resource(stream_socket_client("unix:///tmp/server1.sock"));
EOF

dotest argallownull 255 "Fatal error: Uncaught TypeError: Argument 1 passed to arguments::allownull() must be of the type string or null, integer given, called in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
\$a->allownull("string");
\$a->allownull(NULL);
\$a->allownull();
\$a->allownull(1);
EOF

dotest argreference 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
public function reference(&...\$arguments) {
    return self::call(__FUNCTION__, \$arguments, \$this);
}
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
\$s = "FOO";
\$a->reference(\$s);
if (\$s !== "BAR") {
    echo "unreached";
    exit(1);
}
EOF

dotest argreference2 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
    public function reference2(&...\$arguments) {
        self::call(__FUNCTION__, \$arguments, \$this);
    }
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
\$s[0] = "FOO";
\$a->reference2(\$s);
if (\$s[0] !== "BAR") {
    echo "unreached";
    exit(1);
}
EOF

dotest argmin 255 "Fatal error: Uncaught ArgumentCountError: Too few arguments to function arguments::list(), 1 passed in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class arguments extends \\Rootnet\\Privsep\\Remote {
}
arguments::\$spath = "unix:///tmp/server1.sock";

\$a = new arguments;
\$a->list("1", 2, 3.0, true);
\$a->list("1", 2, 3.0);
\$a->list("1", 2);
\$a->list("1");
EOF

exit $EXITSTATUS
