<?php
class mistress extends female {
    public function __construct() {
        $this->age = 18;
    }
    public function hide() {
        $this->age += 1;
        return "Ow snap, the wife";
    }
}
?>
