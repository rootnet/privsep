<?php
class female {
    public $age = 0;

    public function intercourse() {
        $this->age += 0.1;
        if (random_int(0, 100) == 1) 
            return new daughter;
        return "censored";
    }

    public function dinner() {
        $this->age += 0.1;
        return "nom";
    }

    public function shop() {
        $this->age += 0.1;
        return "yawn";
    }

    public function jabber(female $otherWoman) {
        $this->age += 0.1;
        if ($this->age < 10 || $otherWoman->age < 10)
            return "kutchy kutchy kutchy";
        return "yadayada";
    }

    private function queef() {
        $this->age += 0.1;
        return "pfffft";
    }
}
?>
