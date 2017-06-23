# Privsepd
**The daemon for privilege separating php code**

privsepd is an RPC daemon for PHP.  It is connection oriented and designed to
provide an as near native interface for the client as possible through the
remote interface.  Every connection is run in it's own process to ensure
that multiple connections don't interfere.

Code made available through the daemon needs to be self-contained and is loaded
through the autoload directive in the configuration file.  This autoload file
is loaded at every connection, allowing code updates without server reloads.
Besides regular calls (both functions and methods) the interface supports
closures, arguments by reference, remote objects, and cascading throwables.
Incoming function-, method- and attributerequests and returning throwables
originating are subject to a whitelist check before returning.

# Installation
The installation is divided into two parts, the daemon installation and the
composer package containing the code that connects to the daemon.

## Daemon installation
You can install the daemon by cloning the Privsepd git-repository and running
make install
``` bash
$ git clone https://github.com/rootnet/privsep.git
$ cd privsep
$ make
$ sudo make install
```
Optional run the tests
Test require root because of testing privilege revocation
``` bash
$ sudo make test
```
Uninstall the daemon
``` bash
$ sudo make uninstall
```

Clean up after yourself
``` bash
$ make clean
```
## Application installation
You can install the application package into your project using
[Composer](https://getcomposer.org).
``` bash
composer require rootnet/privsep
```
# Usage
For a detailed description of the usage for both the daemon and application see
the included man pages.
``` bash
man privsepd
man privsepd.conf
man remote
```

# License
See [License](LICENSE.md)
