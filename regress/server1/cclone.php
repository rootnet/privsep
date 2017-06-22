<?php
class cclone {
    public $id;
    public function __construct()
    {
        $this->id = 0;
    }

    public function __clone()
    {
        $this->id++;
    }
}
?>
