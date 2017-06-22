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
    local OUTPUT
    local EXITCODE

    echo -n "Now running test $TESTNAME: " >&2

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

dotest pubmethod 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->pubmethod();
EOF

dotest privatemethod 255 "Fatal error: Uncaught Error: Call to private method method::privatemethod() from context 'Rootnet\Privsep\Client' in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->privatemethod();
EOF

dotest unimplmethod 255 "Fatal error: Uncaught Error: Call to undefined method method::unimplmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->unimplmethod();
EOF

dotest unavailpubmethod 255 "Fatal error: Uncaught Error: Call to private method method::unavailpubmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->unavailpubmethod();
EOF

dotest unavailprivatemethod 255 "Fatal error: Uncaught Error: Call to private method method::unavailprivatemethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->unavailprivatemethod();
EOF

dotest unavailunimplmethod 255 "Fatal error: Uncaught Error: Call to private method method::unavailunimplmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->unavailunimplmethod();
EOF

dotest pubstatmethod 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::pubstatmethod();
EOF

dotest privatestatmethod 255 "Fatal error: Uncaught Error: Call to private method method::privatestatmethod() from context 'Rootnet\Privsep\Client' in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::privatestatmethod();
EOF

dotest statunimplmethod 255 "Fatal error: Uncaught Error: Call to private method method::statunimplmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::statunimplmethod();
EOF

dotest unavailpubstatmethod 255 "Fatal error: Uncaught Error: Call to private method method::unavailpubstatmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::unavailpubstatmethod();
EOF

dotest unavailprivatestatmethod 255 "Fatal error: Uncaught Error: Call to private method method::unavailprivatestatmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::unavailprivatestatmethod();
EOF

dotest unavailstatunimplmethod 255 "Fatal error: Uncaught Error: Call to private method method::unavailstatunimplmethod() in" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::unavailstatunimplmethod();
EOF

dotest static_as_nonstatic 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

\$m = new method;
\$m->pubstatmethod();
EOF

dotest nonstatic_as_static 0 << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class method extends \\Rootnet\\Privsep\\Remote {
}
method::\$spath = "unix:///tmp/server1.sock";

method::pubmethod();
EOF

exit $EXITSTATUS
