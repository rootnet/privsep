<?php
class daughter extends female {
	public function teach() {
		$this->age += 0.1;
		return "Ah, I didn't know that";
	}

	public function play() {
		$this->age += 0.1;
		return "Weeeeeh";
	}

	public function diary() {
		$this->age += 0.1;
		return "Dear kitty...";
	}
}
?>
