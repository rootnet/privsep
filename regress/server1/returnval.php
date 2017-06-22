<?php

class returnval {
    public function string()
    {
        return "1";
    }
        public function int()
    {
        return 1;
    }

    public function float()
    {
        return 1.0;
    }

    public function bool()
    {
        return true;
    }

    public function array()
    {
        return [];
    }

    public function callable()
    {
        return function ()
        {
        };
    }

    public function object()
    {
        return $this;
    }

    public function resource()
    {
        return stream_socket_client("unix:///tmp/server1.sock");
    }
}
