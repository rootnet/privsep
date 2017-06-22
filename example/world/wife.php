<?php
class wife extends female {
    public function __construct() {
        $this->age = 35;
    }

    public function __clone() {
        throw new Exception("Aw hell naw");
    }

    public function argue() {
        $this->age += 0.1;
        return "But you did 10 years ago ".base64_encode(random_bytes(20));
    }

    public function reproduce() {
        $this->age += 0.1;
        return new daughter;
    }

    public function shop() {
        $this->age += 0.1;
        return "Creditcard debt";
    }
}
