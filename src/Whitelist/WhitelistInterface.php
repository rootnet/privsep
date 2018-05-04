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


interface WhitelistInterface
{
    /**
     * @param string|object $class
     * @return array
     */
    public function publicAttributes($class): array;

    /**
     * @param string|\Closure $function
     * @param array $arguments
     * @param string|object $class
     * @return array
     */
    public function verifyCall(
        $function,
        array $arguments,
        $class = null
    ) : array;
}
