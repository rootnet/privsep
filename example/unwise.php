<?php
require_once(__DIR__."/../src/Remote.php");
require_once(__DIR__."/../src/Client.php");
require_once(__DIR__."/../src/Throwable/RemoteError.php");

use Rootnet\Privsep\Remote;

class wife extends Remote {
}
class daughter extends Remote {
}
Remote::$remote = "unix:///tmp/family.sock";

class mistress extends Remote {
    public static $remote = "unix:///tmp/mistress.sock";
}

$wife = new wife;
$daughter = $wife->reproduce();

var_dump($wife->shop());
var_dump($daughter->shop());

$mistress = new mistress;
var_dump($mistress->intercourse());
?>
