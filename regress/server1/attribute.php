<?php
class attribute {
    public $publicget = true;
    public $unavailpubget = true;
    public $publicset = false;
    public $unavailpubset = false;
    public $publicissettrue = true;
    public $publicissetfalse;
    public $unavailpublicissettrue = true;
    public $unavailpublicissetfalse;
    public $publicunset = true;
    public $unavailpublicunset = true;
    private $privateget = true;
    private $unavailprivateget = true;
    private $privateset = false;
    private $unavailprivateset = false;
    private $privateisset;
    private $unavailprivateisset;
    private $privateunset = true;
    private $unavailprivateunset = true;
}
?>
