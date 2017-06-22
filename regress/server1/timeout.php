<?php

function test ($sig) {
    echo "bla\n";
}
class timeout {
    public function remotetimeout()
    {
        sleep(10);
    }

    public function privsepdtimeout()
    {
        sleep(1);
    }

    public function privsepdkill()
    {
        pcntl_sigprocmask(SIG_BLOCK, [SIGINT]);
        sleep(100);
    }
}
?>
