<?php
class cthrow {
    public function throwAccept()
    {
        throw new \Exception("Exception");
    }

    public function throwIndirectAccept()
    {
        throw new \ErrorException("Error exception");
    }

    public function throwDeny()
    {
        throw new \Exception("Unseen exception");
    }

    public function throwIndirectDeny()
    {
        throw new \Error("Unseen error");
    }

    public function filterLast()
    {
        $e = new \Error("Unseen error");
        throw new \Exception("Seen exception", 0, $e);
    }

    public function filterFirst()
    {
        $e = new \Error("Seen error");
        throw new \Exception("Unseen exception", 0, $e);
    }

    public function filterMiddle()
    {
        $t = new \TypeError("Seen type error");
        $e = new \Exception("Unseen exception", 0, $t);
        throw new \Error("Seen error", 0, $e);
    }
}
?>
