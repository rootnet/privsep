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


class Config
{
    private $config;
    static private $instance;

    public function __construct(string $cpath)
    {
        $this->config = require($cpath);
    }

    static public function get_instance(string $cpath = null)
    {
        if (!isset(self::$instance)) {
            self::$instance = new self($cpath);
        }
        return self::$instance;
    }

    public function get(string $key)
    {
// Check pre-conditions
        if (!is_string($key) ||
            empty($key)
        ) {
            return null;
        }

        $config = $this->config;
        foreach (explode(".", $key) as $index) {
            if (!isset($config[$index])) {
                return null;
            }
            $config = $config[$index];
        }
        return $config;
    }

// Use set to manage default values
    public function set(string $key, $value)
    {
        if (!is_string($key) ||
            empty($key)
        ) {
            return;
        }

        $keys = explode(".", $key);
        $lindex = array_pop($keys);
        $config = &$this->config;
        foreach ($keys as $index) {
            if (!isset($config[$index])) {
                $config[$index] = array();
            }
            $config = &$config[$index];
        }
        $config[$lindex] = $value;
    }
}
