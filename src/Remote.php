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

declare(strict_types=1);

namespace Rootnet\Privsep;


use Rootnet\Privsep\Client;

abstract class Remote
{
    private $client;
    private $orig;

    public static $spath;

    final public function __construct(&...$arguments)
    {
/*
 * With this combination of arguments, assume we're being initialized from
 * \Rootnet\Privsep\Client. This is not 100% safe, but client shouldn't be used
 * directly from anywhere, so it's a fair bet.
 */
        if (count($arguments) === 1 && $arguments[0] instanceof Client) {
            $this->client = $arguments[0];
            return;
        }
        if (!isset($this->client)) {
            $this->client = self::getClient();
        }
        self::call(__FUNCTION__, $arguments, $this);
        if (extension_loaded("Weakref")) {
            $this->orig = new \Weakref($this);
        } else {
            $this->orig = $this;
        }
    }

    final public function __destruct()
    {
        $arguments = [];
        self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __clone()
    {
        if (extension_loaded("Weakref")) {
            $arguments = [$this->orig->get()];
        } else {
            $arguments = [$this->orig];
        }
        self::call(__FUNCTION__, $arguments, $this);
        if (extension_loaded("Weakref")) {
            $this->orig = new \Weakref($this);
        } else {
            $this->orig = $this;
        }
    }

    final public function __get($key)
    {
        $arguments = [$key];
        return self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __set($key, $value)
    {
        $arguments = [$key, $value];
        self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __isset($key)
    {
        $arguments = [$key];
        return self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __unset($key)
    {
        $arguments = [$key];
        self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __sleep()
    {
        throw new \Error("Unable to serialize remote object");
    }

    final public function __wakeup()
    {
        throw new \Error("Unable to unserialize remote object");
    }

    final public function __tostring()
    {
        $arguments = [];
        return self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __invoke(...$arguments)
    {
        return self::call(__FUNCTION__, $arguments, $this);
    }

    final static public function __set_state()
    {
        throw new \Error("Never play with matches or eval");
    }

    final public function __debugInfo()
    {
        $arguments = [];
        return self::call(__FUNCTION__, $arguments, $this);
    }

    final public function __call($method, $arguments)
    {
        $origArguments = $arguments;
        $return = self::call($method, $arguments, $this);
        if (self::arrayDiff($arguments, $origArguments) === false) {
            throw new \Error("'" . get_called_class() . "::" . $method . "' has " .
                "parameters by reference. Please implement it in '\\" .
                get_called_class() . "' as:\n" .
                "public function " . $method . "(&...\$arguments) {\n" .
                "    return self::call(__FUNCTION__, \$arguments, \$this);\n" .
                "}\n",
                E_USER_WARNING
            );
        }
        return $return;
    }

    final public static function __callStatic($method, $arguments)
    {
        $origArguments = $arguments;
        $return = self::call($method, $arguments, get_called_class());
        if (self::arrayDiff($arguments, $origArguments) === false) {
            throw new \Error("'" . get_called_class() . "::" . $method . "' has " .
                "parameters by reference. Please implement it in '\\" .
                get_called_class() . "' as:\n" .
                "public static function " . $method . "(&...\$arguments) {\n" .
                "    return self::call(__FUNCTION__, \$arguments, \$this);\n" .
                "}\n",
                E_USER_WARNING
            );
        }
        return $return;
    }

    final private static function arrayDiff(array $array1, array $array2): bool
    {
        if (!empty(array_diff_key($array1, $array2)) ||
            !empty(array_diff_key($array2, $array1))
        ) {
            return false;
        }

        foreach ($array1 as $key => $value) {
            if (is_array($value) && is_array($array2[$key]) &&
                !self::arraydiff($value, $array2[$key])
            ) {
                return false;
            } elseif ($value !== $array2[$key]) {
                return false;
            }
        }
        return true;
    }

    final protected static function call($method, &$arguments, $class)
    {
        self::verifyArguments($arguments, $class);
        if (!is_object($class)) {
            return self::getClient()->call($method, $arguments, $class);
        }
        return self::getClient($class)->call($method, $arguments, $class);
    }

    final private static function getClient(self $inst = null)
    {
        static $clients = [];

        if (isset($inst)) {
            return $inst->client;
        }

        $path = get_called_class()::$spath;
        if (!is_string($path)) {
            throw new \Error(
                get_called_class() . "::\$path: expecting string, " .
                gettype($path) . " given."
            );
        }
        if (!isset($clients[$path])) {
            $errno = null;
            $errstr = null;
            $sock = stream_socket_client($path, $errno, $errstr);
            if ($sock === false) {
                throw new \Error("stream_socket_client: " . $errstr);
            }
            $clients[$path] = new Client($sock);
        }
        return $clients[$path];
    }

    /*
     * This checks if objects are not proxied to other backends
     */
    final private static function verifyArguments($arguments, $inst): void
    {
        if (is_array($arguments)) {
            foreach ($arguments as $argument) {
                self::verifyArguments($argument, $inst);
            }
        } elseif ($arguments instanceof Remote) {
            if ($arguments->client !== self::getClient(
                    is_string($inst) ? null : $inst)
            ) {
                throw new \Error("Can't mix backends");
            }
        }
    }
}
