<?php
class invoke {
    private $counter = 0;

    public function __invoke()
    {
        return $this->counter++;
    }
}
?>
