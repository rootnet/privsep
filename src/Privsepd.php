<?php
/**
 * Copyright (c) 2017 Martijn van Duren (Rootnet) <m.vanduren@rootnet.nl>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

namespace Rootnet\Privsep;


use Rootnet\Privsep\Whitelist\Privsepd as PrivsepdWhitelist;

final class Privsepd
{
    private $clients = [];
    private $client;
    private $logfd;
    private $lsock;
    private $name;

    public function __construct()
    {
/* Always do logging. If you don't like errors, fix your bugs. */
        error_reporting(E_ALL);
/* Disable display_errors by default, this is handled by log_errors */
        ini_set("display_errors", "0");
        ini_set("html_errors", "0");
        ini_set("xmlrpc_errors", "0");
        ini_set("log_errors", "1");
        ini_set("error_log", "");
        ini_set("log_errors_max_len", "0");

        $this->setErrorHandler();
    }

    public function run(): void
    {
        $daemonize = true;
/*
 * c: config file
 * C: chroot dir
 * d: don't daemonize
 * g: group
 * s: socket path
 * u: user
 */
        $opts = getopt("c:C:dg:s:u:");
        if (!isset($opts["c"])) {
            $this->usage();
        }
        $config = Config::get_instance($opts["c"]);
        unset($opts["c"]);
        foreach ($opts as $flag => $value) {
            switch ($flag) {
                case 'C':
                    $config->set("chroot", $value);
                    break;
                case 'd':
                    $daemonize = false;
                    break;
                case 'g':
                    $config->set("group", $value);
                    break;
                case 's':
                    $config->set("socket.path", $value);
                    break;
                case 'u':
                    $config->set("user", $value);
                    break;
                default:
                    $this->usage();
            }
        }

        if ($config->get("timeout") == null) {
            $config->set("timeout", 30);
        }

        $this->name = $config->get("name");
        if (empty($this->name) || !is_string($this->name)) {
            $this->name = "privsepd";
        }
        cli_set_process_title($this->name . " (master)");

        if ($config->get("autoload") === null) {
            trigger_error("Missing autoload in config", E_USER_ERROR);
        }

        $socket = $config->get("socket");
        if (!is_array($socket) || !is_string($socket["path"])) {
            trigger_error("No valid socket.path set", E_USER_ERROR);
        }
        $this->lsock = $this->socket($socket);

        if ($daemonize) {
            $log = $this->prepareLog();
        }

        $this->lockdown();

        if (($testfd = fopen($config->get("autoload"), "r")) === false) {
            trigger_error("Unable to open autoload", E_USER_ERROR);
        }
        fclose($testfd);

        if ($daemonize) {
            $this->daemonize($log);
        }

        trigger_error("Ready", E_USER_NOTICE);
        $this->manage();
    }

/*
 * This function should be called after initialization
 * and pushes the daemon to the background
 *
 * No trigger_error with E_USER_ERROR should be called in the main process after
 * this function
 */
    private function daemonize($log = null): void
    {
        switch (pcntl_fork()) {
            case -1:
                trigger_error("pcntl_fork", E_USER_ERROR);
            case 0:
                break;
            default:
                exit(0);
        }

        if (isset($log)) {
            $this->logfd = $log;
        } else {
            openlog($this->name, LOG_PID | LOG_ODELAY, LOG_DAEMON);
            ini_set("error_log", "syslog");
            unset($this->logfd);

        }
    }

    private function handleSockets(Array $sockets): void
    {
        foreach ($sockets as $sock) {
/*
 * Right now client sockets are only used to track the lifetime of the children,
 * so the only data is the closing of a socket.
 * This may change in the future
 */
            if (isset($this->lsock) && $sock === $this->lsock) {
                if (($client = $this->newClient($sock)) !== null) {
                    $this->clients[$client["pid"]] = $client;
                }
            } else {
                foreach ($this->clients as $client) {
                    if ($client["sock"] === $sock) {
// Clean up finished clients
                        pcntl_waitpid($client["pid"], $status);
                        trigger_error(
                            "process " . $client["pid"] . " exited with status" .
                            " code " . pcntl_wexitstatus($status),
                            E_USER_NOTICE
                        );
                        unset($this->clients[$client["pid"]]);
                    }
                }
            }
        }
    }

    private function installSignalHandler(): void
    {
/*
 * private functions aren't accessible and we don't want a signal handler to be
 * public, so make it a closure.
 */
        $signalHandler = function ($signo) {
            pcntl_sigprocmask(SIG_BLOCK, [SIGINT, SIGTERM]);
            fclose($this->lsock);

            if (!empty($this->clients)) {
                trigger_error("Exiting: terminating clients", E_USER_NOTICE);
/*
 * Install signal handler so we wake up from time_nanosleep. This handler can't
 * be called from this context, so might as well be empty.
 */
                pcntl_signal(SIGCHLD, function () {
                });

                foreach ($this->clients as $client) {
                    $this->killChild($client["pid"], SIGINT);
                }
                $rest = ["seconds" => 1, "nanoseconds" => 0];
                while (
                    !empty($this->clients) &&
                    is_array($rest = time_nanosleep(
                        $rest["seconds"],
                        $rest["nanoseconds"]
                    ))
                ) {
                    $status = null;
                    while (($pid = pcntl_wait($status, WNOHANG)) > 0) {
                        unset($this->clients[$pid]);
                    }
                }
                foreach ($this->clients as $client) {
                    $this->killChild($client["pid"], SIGKILL);
                }
                while (
                    !empty($this->clients) &&
                    ($pid = pcntl_wait($status)) > 0
                ) {
                    unset($this->clients[$pid]);
                }
            }
            trigger_error("Exiting", E_USER_NOTICE);
            exit(0);
        };
        pcntl_signal(SIGINT, $signalHandler);
        pcntl_signal(SIGTERM, function($signo) {
            trigger_error("Exiting: waiting for clients", E_USER_NOTICE);
            fclose($this->lsock);
            unset($this->lsock);
        });
    }

    private function killChild(int $client, int $signal): void
    {
        assert(isset($this->clients[$client]));
        assert($signal === SIGINT || $signal === SIGKILL);
        trigger_error("Sending " .
            ($signal === SIGINT ? "SIGINT" : "SIGKILL") .
            " to " . $client,
            E_USER_NOTICE
        );
        if (!posix_kill($client, $signal)) {
            trigger_error(
                "posix_kill (" . $client . "): " . posix_strerror(
                    posix_get_last_error()
                ),
                E_USER_WARNING
            );
        }
    }

    private function killTimeout(): void
    {
        $timeout = Config::get_instance()->get("timeout");
        if ($timeout === 0) {
            return;
        }

        $ctime = time();
// Handle long running sessions
        foreach ($this->clients as $client) {
            if (
                $ctime - $client["start"] >= $timeout || (
                    isset($client["kill"]) &&
                    $client["kill"] <= $ctime
                )
            ) {
                $this->killChild(
                    $client["pid"],
                    isset($client["kill"]) ? SIGKILL : SIGINT
                );
// Don't make it a hailstorm of SIGKILL. Just sent the next one in a second.
                $this->clients[$client["pid"]]["kill"] = $ctime + 1;
                $this->clients[$client["pid"]]["start"] = $ctime;
            }
        }
    }

    private function lockdown(): void
    {
        $config = Config::get_instance();
        $uid = $config->get("user");
        $gid = $config->get("group");
        $chroot = $config->get("chroot");
        if (isset($uid) && !is_numeric($uid)) {
            if (($passwd = posix_getpwnam($uid)) === false) {
                trigger_error("posix_getpwnam", E_USER_ERROR);
            }
            $uid = $passwd["uid"];
        }
        if (isset($gid) && !is_numeric($gid)) {
            if (($group = posix_getgrnam($gid)) === false) {
                trigger_error("posix_getgrnam", E_USER_ERROR);
            }
            $gid = $group["gid"];
        }

        if (!empty($chroot) && chroot($chroot) === false) {
            trigger_error("chroot", E_USER_ERROR);
        }

        if (!empty($gid) && posix_setgid($gid) === false) {
            trigger_error("posix_setgid", E_USER_ERROR);
        }

        if (!empty($uid) && posix_setuid($uid) === false) {
            trigger_error("posix_setuid", E_USER_ERROR);
        }
    }

    private function log(string $str): void {
        $prefix = date("M m H:i:s") . " " . $this->name;
        if (isset($this->client)) {
            $prefix .= "[" . $this->client->getLid() . "]: ";
        } else {
            $prefix .= "[" . posix_getpid() . "]: ";
        }

        fwrite($this->logfd, $prefix . $str . "\n");
    }

    private function manage(): void
    {
        $n = null;

        $this->installSignalHandler();
        while (isset($this->lsock) || !empty($this->clients)) {
            $read = [];
            if (isset($this->lsock)) {
                $read[] = $this->lsock;
            }
            foreach ($this->clients as $client) {
                $read[] = $client["sock"];
            }

            $nstream = @stream_select($read, $n, $n, $this->selectTimeout());
            pcntl_signal_dispatch();
            if ($nstream === false) {
                continue;
            }

            $this->killTimeout();
            $this->handleSockets($read);
        }
        trigger_error("Exiting", E_USER_NOTICE);
    }

/*
 * Accept new incoming connections and isolate it in it's own process.
 * Child doesn't return.
 * Parent returns pid array.
 */
    private function newClient($lsock): ?array
    {
        $sp = stream_socket_pair(STREAM_PF_UNIX, STREAM_SOCK_STREAM, 0);
        if ($sp === false) {
            return null;
        }

        if (($cc = stream_socket_accept($lsock)) === false) {
            fclose($sp[0]);
            fclose($sp[1]);
            return null;
        }
        switch (($pid = pcntl_fork())) {
            case -1:
                trigger_error(
                    "pcntl_fork: " . pcntl_strerror(pcntl_get_last_error()),
                    E_USER_WARNING
                );
                fclose($sp[0]);
                fclose($sp[1]);
                fclose($cc);
                return null;
            case 0:
                $this->name .= "(client)";
                if (!isset($this->logfd)) {
                    openlog($this->name, LOG_PID | LOG_ODELAY, LOG_DAEMON);
                }
                pcntl_signal(SIGINT, SIG_DFL);
                pcntl_signal(SIGTERM, SIG_DFL);
                unset($this->clients);
                cli_set_process_title($this->name);
                $conf = Config::get_instance();
                require_once($conf->get("autoload"));
                fclose($sp[0]);
                fclose($lsock);
                try {
                    $this->client = new Client(
                        $cc,
                        new PrivsepdWhitelist($conf->get("callable")),
                        true
                    );
                } catch (\Error $e) {
                    trigger_error($e->getMessage(), E_USER_ERROR);
                    exit(1);
                }
                $this->client->trace = $conf->get("trace");
                try {
                    while (Client::waitInput() !== false) {
                        /* EMPTY */
                    }
                } catch (\Error $e) {
                    trigger_error($e->getMessage(), E_USER_ERROR);
                    exit(1);
                }
                exit(0);
            default:
                trigger_error(
                    "New connection: cpid (" . $pid . "), socketid (" .
                    (int)$cc . ")",
                    E_USER_NOTICE
                );
                fclose($sp[1]);
                fclose($cc);
                $client["pid"] = $pid;
                $client["start"] = time();
                $client["sock"] = $sp[0];
                return $client;
        }
    }

/*
 * In a perfect world this function would be part of daemonize.
 * Unfortunately inside a chroot we don't always have /dev/null.
 * Even if we pre-opened /dev/null it's impossible to tell on which fd it's
 * opened, so we can't rely on fopen("php://fd/" . (int) $devnull, "w");
 * Our best option is to open the /dev/null fd's before chrooting and setting up
 * the logger inside the daemonize function.
 * Also open the log, so it's not limited to the chroot.
 *
 * After this function echo, var_dump and friends won't work anymore.
 * Only writing directly to $this->logfd directly or via
 * trigger_error/throwables will work.
 */
    private function prepareLog()
    {
        static $STDIN, $STDOUT, $STDERR;

        @fclose(STDIN);
        @fclose(STDOUT);
        @fclose(STDERR);
/*
 * Open 3 new null descriptors, this to prevent new sockets to open on STDIN,
 * STDOUT, and STDERR. This could cause havoc if a function decides that these
 * descriptors could be usable targets.
 */
        if (($STDIN = fopen("/dev/null", "r")) === false ||
            ($STDOUT = fopen("/dev/null", "a")) === false ||
            ($STDERR = fopen("/dev/null", "a")) === false
        ) {
            trigger_error("Unable to open /dev/null", E_USER_ERROR);
        }

        $config = Config::get_instance();
        $log = $config->get("log");
        if (!isset($log)) {
            return null;
        }

        if (isset($log)) {
            $mask = umask(0777);
            if (($logfd = fopen($log["path"], "a")) === false) {
                trigger_error("fopen: " . $log["path"], E_USER_ERROR);
            }
            umask($mask);
            if (isset($log["owner"])) {
                if (!chown($log["path"], $log["owner"])) {
                    trigger_error("chown", E_USER_ERROR);
                }
            }
            if (isset($log["group"])) {
                if (!chgrp($log["path"], $log["group"])) {
                    trigger_error("chgrp", E_USER_ERROR);
                }
            }
            $log["perm"] = $log["perm"] ?? 0640;
            if (!chmod($log["path"], $log["perm"])) {
                trigger_error("chmod", E_USER_ERROR);
            }
            return $logfd;
        }
    }

    private function selectTimeout(): ?int
    {
        $sleep = $timeout = Config::get_instance()->get("timeout");

        if (empty($this->clients) || $timeout === 0) {
            return null;
        }

        $ctime = time();
/*
 * Let the sockets do the wackups for us and only continue if a client needs to
 * be killed
 */
        foreach ($this->clients as $client) {
            if (isset($sleep)) {
                if (isset($client["kill"])) {
                    if ($sleep > $client["kill"] - $ctime) {
                        $sleep = $client["kill"] - $ctime;
                    }
                } else {
                    if ($ctime - $client["start"] + $timeout < $sleep) {
                        $sleep = $ctime - $client["start"] + $timeout;
                    }
                }
            }
        }
        return $sleep > 0 ? $sleep : 0;
    }

    private function setErrorHandler()
    {
// Safeguard our stderr fd, so still write to it after fd 2 has been closed.
        $this->logfd = fopen("php://stderr", "w");
        $handler = function(int $errno, string $str, string $file, int $line) {
            if (error_reporting() === 0) {
                return;
            }
            if (!isset($this->logfd)) {
                return false;
            }
            $prefix = $suffix = "";

            $err = E_ERROR | E_CORE_ERROR | E_COMPILE_ERROR | E_USER_ERROR;
            $err |= E_RECOVERABLE_ERROR;
            $warn = E_WARNING | E_CORE_WARNING;
            $warn |= E_COMPILE_WARNING | E_USER_WARNING;
// User notices are reserved for informational purposes
            $notice = E_NOTICE | E_STRICT;
            $deprecated = E_DEPRECATED | E_USER_DEPRECATED;
            if ($errno & $err) {
                $prefix .= "PHP Fatal error: ";
                $suffix = " in " . $file . " on line ".$line;
            } elseif ($errno & $warn) {
                $prefix .= "PHP Warning: ";
                $suffix = " in " . $file . " on line ".$line;
            } elseif ($errno & $notice) {
                $prefix .= "PHP Notice: ";
                $suffix = " in " . $file . " on line ".$line;
            } elseif ($errno & $deprecated) {
                $prefix .= "PHP Deprecated: ";
                $suffix = " in " . $file . " on line ".$line;
            }

            $this->log($prefix . $str . $suffix);
            if ($errno & $err) {
                exit(255);
            }
        };
        set_error_handler($handler);
        set_exception_handler(function($t) {
            if (!isset($this->logfd)) {
                throw $t;
            }
            $this->log(
                "PHP Fatal Error: Uncaught " . get_class($t) . ": " .
                $t->getMessage() . " in " . $t->getFile() . ":" .
                $t->getLine() . "\n" .
                "Stack trace:\n" .
                $t->getTraceAsString()
            );
            exit(255);
        });
    }

// We can't use resource as a return type
    private function socket(array $socket)
    {
        $config = Config::get_instance();
        $path = explode(':', $socket["path"], 2);
        switch ($path[0]) {
            case "unix":
// Remove leading 2 slashes
                $path[1] = substr($path[1], 2);
// Don't accept relative paths
                if ($path[1][0] !== "/") {
                    trigger_error(
                        "Socket path " . $socket["path"] . " relative",
                        E_USER_ERROR
                    );
                }
                @unlink($path[1]);
// Disable permissions, so we don't allow connections before permissions are set
                $mask = umask(0777);
                $stream = stream_socket_server(
                    $socket["path"],
                    $errno,
                    $errstr
                );
                umask($mask);
                if ($stream === false) {
                    trigger_error(
                        "stream_socket_server: " . $errstr,
                        E_USER_ERROR
                    );
                }
                $user = $socket["owner"] ??  $config->get("user");
                $group = $socket["group"] ?? $config->get("group");
// If no socket.perm is set, respect the original umask
                $perm = $socket["perm"] ?? $mask ^ 0777;

                if (isset($user) && !chown($path[1], $user)) {
                    trigger_error("chown", E_USER_ERROR);
                }
                if (isset($group) && !chgrp($path[1], $group)) {
                    trigger_error("chgrp", E_USER_ERROR);
                }
                if (!chmod($path[1], $perm)) {
                    trigger_error("chmod", E_USER_ERROR);
                }
                break;
            case "tcp":
                $stream = stream_socket_server(
                    $socket["path"],
                    $errno,
                    $errstr
                );
                if ($stream === false) {
                    trigger_error(
                        "stream_socket_server: " . $errstr,
                        E_USER_ERROR
                    );
                }
                break;
            default:
                trigger_error(
                    "No valid listening socket: " . $path[0],
                    E_USER_ERROR
                );
        }
        return $stream;
    }

    private function usage()
    {
        fprintf(STDERR, "usage: privsepd [-d] [-C chroot] [-g group] " .
            "[-s socket] [-u user] -c config\n");
        exit(1);
    }
}
