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

dotest instantcb 0 "123" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
\$c->instantcb(function()
{
    echo "2";
});
echo "3";
EOF

dotest outoforder 0 "1234" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
\$c->addcb(function()
{
    echo "3";
});
\$c->doublecb(function()
{
    echo "2";
});
echo "4";
EOF

dotest cascading 0 "12345" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
\$c->instantcb(function() use (\$c)
{
    echo "2";
    \$c->instantcb(function() {
        echo "3";
    });
    echo "4";
});
echo "5";
EOF

dotest cbreturn 0 "123" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
echo \$c->returncb(function()
{
    return 2;
});
echo "3";
EOF

dotest cbdoublereturn 0 "1234" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
\$c->addcb(function()
{
	return 3;
});
echo implode("", \$c->returndoublecb(function()
{
    return 2;
}));
echo "4";
EOF

dotest cbcascadereturn 0 "1234" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
echo implode("", \$c->returncb(function() use (\$c)
{
    \$ret[] = \$c->returncb(function()
    {
       return 2;
    });
    \$ret[] = 3;
    return \$ret;
}));
echo "4";
EOF

dotest cbarg 0 "123" << EOF
<?php
require_once("${REMOTE}");
require_once("${CLIENT}");
require_once("${ERROR}");

class callbacks extends \\Rootnet\\Privsep\\Remote {
    public static \$debug = false;
}
callbacks::\$remote = "unix:///tmp/server1.sock";

\$c = new callbacks;
echo "1";
echo \$c->argcb(function(\$number)
{
    echo 2;
});
echo "3";
EOF

exit $EXITSTATUS
