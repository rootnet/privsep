<?php
class destruct {
    private $end = false;
    public function __destruct()
    {
        echo "DESTROY";
        if ($this->end) {
            echo "\n";
        }
    }

    public function identifier() {
        echo "SPLIT";
    }

    public function end() {
        $this->end = true;
    }
}
?>
