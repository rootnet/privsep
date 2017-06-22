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


namespace Rootnet\Privsep\Whitelist;


class Privsepd implements WhitelistInterface
{
    private $whitelist;

    public function __construct(array $whitelist)
    {
        $this->whitelist = $whitelist;
    }

    public function publicAttributes($class): array
    {
        assert(is_object($class));
        if (
            isset($this->whitelist[get_class($class)]["__get"]) &&
            is_array($this->whitelist[get_class($class)]["__get"])
        ) {
            return array_keys($this->whitelist[get_class($class)]["__get"]);
        }
        return [];
    }

    public function verifyCall(
        $function,
        array $arguments,
        $class = null
    ): array {
        $catch = ["Throwable*"];
        if (!isset($class)) {
            if (
                !is_callable($function) &&
                !isset($this->whitelist[""][$function])
            ) {
                return [
                    "allow" => false,
                    "throw" => new \Error("Call to undefined function " .
                        $function . "()")
                ];
            }
        } else {
// Right now there's no instance-based whitelisting
            if (is_object($class)) {
                $class = get_class($class);
            }
            if (!isset($this->whitelist[$class])) {
                return [
                    "allow" => false,
                    "throw" => new \Error("Class '" . $class . "' not found")
                ];
            }
            switch ($function) {
                case "__destruct":
// Always allow destruction
                    break;
                case "__get":
                case "__unset":
                    assert(count($arguments) === 1 && is_string($arguments[0]));
                    $key = $arguments[0];
                    $this->testMagicArray($class, $function);
                    if (!isset($this->whitelist[$class][$function][$key])) {
                        return [
                            "allow" => false,
                            "throw" => new \Error(
                                "Cannot access private property " .
                                $class . "::\$" . $arguments[0]
                            )
                        ];
                    }
                    break;
                case "__isset":
                    assert(count($arguments) === 1 && is_string($arguments[0]));
                    $key = $arguments[0];
                    $this->testMagicArray($class, $function);
                    if (!isset($this->whitelist[$class][$function][$key])) {
                        return [
                            "allow" => false,
                            "return" => false
                        ];
                    }
                    break;
                case "__set":
                    assert(count($arguments) === 2 && is_string($arguments[0]));
                    $key = $arguments[0];
                    $this->testMagicArray($class, $function);
                    if (!isset($this->whitelist[$class][$function][$key])) {
                        return [
                            "allow" => false,
                            "throw" => new \Error(
                                "Cannot access private property " .
                                $class . "::\$" . $arguments[0]
                            )
                        ];
                    }
                    break;
                case "__debugInfo":
                    return [
                        "allow" => true,
// This shouldn't go wrong, else it's an internal error that
// shouldn't be made public
                        "catch" => []
                    ];
                default:
                    if (!isset($this->whitelist[$class][$function])) {
                        return [
                            "allow" => false,
                            "throw" => new \Error(
                                "Call to private method " .
                                $class . "::" . $function . "()"
                            )
                        ];
                    }
                    if (isset($this->whitelist[$class][$function]["catch"])) {
                        $catch = $this->whitelist[$class][$function]["catch"];
                    }
            }
        }
        return [
            "allow" => true,
            "catch" => $catch
        ];
    }

    private function testMagicArray(string $class, string $function): void {
        if (
            isset($this->whitelist[$class][$function]) &&
            !is_array($this->whitelist[$class][$function])
        ) {
            throw new \Error(
                "callable[${class}][${function}] not an array"
            );
        }
    }
}
