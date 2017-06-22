<?php
require_once(__DIR__."/../src/Remote.php");
require_once(__DIR__."/../src/Client.php");
require_once(__DIR__."/../src/Error/RemoteError.php");

use Rootnet\Privsep\Remote;

class wife extends Remote {
}
class daughter extends Remote {
}
Remote::$spath = "unix:///tmp/family.sock";

$wife = new wife;
var_dump($wife->age);
var_dump($wife->shop());
var_dump($wife->dinner());
$daughter = $wife->reproduce();
var_dump($daughter->teach());
var_dump($daughter->shop());
var_dump($daughter->intercourse());
?>
