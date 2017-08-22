<?php
require_once(__DIR__."/../src/Remote.php");
require_once(__DIR__."/../src/Client.php");
require_once(__DIR__."/../src/Throwable/RemoteError.php");

use Rootnet\Privsep\Remote;

class wife extends Remote {
    public static $remote = "unix:///tmp/family.sock";
}
class daughter extends Remote {
}
daughter::$remote = "unix:///tmp/family.sock";

$wife = new wife;
var_dump($wife->age);
var_dump($wife->shop());
var_dump($wife->dinner());
$daughter = $wife->reproduce();
var_dump($daughter);
var_dump($daughter->teach());
?>
