<?php
class arguments {
    public function count()
    {
        return func_num_args();
    }

    public function string(string $string)
    {
        return true;
    }

    public function int(int $int)
    {
        return true;
    }

    public function float(float $float)
    {
        return true;
    }

    public function bool(bool $bool)
    {
        return true;
    }

    public function array(array $array)
    {
        return true;
    }

    public function callable(callable $callable)
    {
        return true;
    }

    public function object(\Rootnet\Privsep\Remote\Fallback $object)
    {
        return true;
    }

    public function resource($resource)
    {
        return true;
    }

    public function allownull(string $string = NULL)
    {
    }

    public function reference(string &$string)
    {
        $string = "BAR";
    }

    public function reference2(array &$array)
    {
        $array[0] = "BAR";
    }

    public function list(string $arg1, int $arg2, float $arg3 = NULL, bool $arg4 = NULL)
    {
    }
}
?>
