#!/bin/sh

EXITSTATUS=0

cleanup() {
    EXIT=$?
    kill $SERVER1
    if [ $EXIT -ne 0 ]; then
        printf "\nOutput of privsepd log: \n"
        cat $log1
    fi
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
dotest publicget 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (\$a->publicget !== TRUE) {
    echo "unreached";
    exit(1);
}
?>
EOF

dotest unimplget 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (\$a->unimplget !== NULL) {
    echo "unreached";
    exit(1);
}
?>
EOF

# These should fail with undefined property
dotest privateget 255 'Cannot access private property attribute::$privateget' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->privateget;
?>
EOF

dotest unavailpubget 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailpubget in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->unavailpubget;
EOF

dotest unavailprivateget 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailprivateget in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->unavailprivateget;
EOF

dotest unavailunimplget 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailunimplget in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->unavailunimplget;
EOF

## Test public sets
# This should succeed
dotest publicset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (\$a->publicset === TRUE) {
    echo "unreached";
    exit(1);
}
\$a->publicset = TRUE;
if (\$a->publicset !== TRUE) {
    echo "unreached";
    exit(1);
}
EOF

dotest unimpset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (\$a->unimplset !== NULL) {
    echo "unreached";
    exit(1);
}
\$a->unimplset = TRUE;
if (\$a->unimplset !== TRUE) {
    echo "unreached";
    exit(1);
}
EOF

# These should fail
dotest privateset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$privateset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->privateset = TRUE;
EOF

dotest unavailpubset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailpubset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->unavailpubset = TRUE;
?>
EOF

dotest unavailprivateset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailprivateset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->unavailprivateset = TRUE;
?>
EOF

dotest unavailunimplset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailunimplset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
\$a->unavailunimplset = TRUE;
?>
EOF

## Test issets
dotest publicissettrue 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->publicissettrue) !== true) {
    echo "unreached";
    exit(1);
}
?>
EOF

dotest publicissetfalse 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->publicissetfalse) !== false) {
    echo "unreached";
    exit(1);
}
?>
EOF

dotest privateisset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->privateisset) !== false) {
    echo "unreached";
    exit(1);
}
EOF

dotest unimplisset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->unimplisset) !== false) {
    echo "unreached";
    exit(1);
}
EOF

dotest unavailpublicissettrue 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->unavailpublicissettrue) !== false) {
    echo "unreached";
    exit(1);
}
EOF

dotest unavailpublicissetfalse 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->unavailpublicissetfalse) !== false) {
    echo "unreached";
    exit(1);
}
EOF

dotest unavailprivateisset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->unavailprivateisset) !== false) {
    echo "unreached";
    exit(1);
}
EOF

dotest unavailunimplisset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->unavailunimplisset) !== false) {
    echo "unreached";
    exit(1);
}
EOF

dotest publicunset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
if (isset(\$a->publicunset) === false) {
    echo "unreached";
    exit(1);
}
unset(\$a->publicunset);
if (isset(\$a->publicunset) === true) {
    echo "unreached";
    exit(1);
}
EOF

dotest privateunset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$privateunset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
unset(\$a->privateunset);
EOF

dotest unimplunset 0 '' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
unset(\$a->unimplunset);
EOF

dotest unavailpublicunset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailpublicunset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
unset(\$a->unavailpublicunset);
EOF

dotest unavailprivateunset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailprivateunset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
unset(\$a->unavailprivateunset);
EOF

dotest unavailunset 255 'Fatal error: Uncaught Error: Cannot access private property attribute::$unavailunimplunset in' << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");

class attribute extends \\Rootnet\\Privsep\\Remote {
}
attribute::\$remote = "unix:///tmp/server1.sock";

\$a = new attribute;
unset(\$a->unavailunimplunset);
EOF


exit $EXITSTATUS
