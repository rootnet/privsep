<?php
class callbacks {
    private $cb;

    public function instantcb(callable $cb)
    {
        $cb();
    }

    public function addcb(callable $cb)
    {
        $this->cb = $cb;
    }

    public function doublecb(callable $cb)
    {
        $cb();
        ($this->cb)();
    }

    public function returncb(callable $cb)
    {
        return $cb();
    }

    public function returndoublecb(callable $cb)
    {
        $ret[] = $cb();
        $ret[] = ($this->cb)();
        return $ret;
    }

    public function argcb(callable $cb)
    {
        $arg = 2;
        $cb($arg);
    }
}
?>
