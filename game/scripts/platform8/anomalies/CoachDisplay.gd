extends Anomaly
## The forward train's destination LEDs (in each coach's middle window) are wrong. Slot: Props/CoachDisplays/Forward.
## params.mode: "wrong_direction" shows the opposite train's text (◀ TERMINUS);
## "same_station" says the next stop is this station.

var _old := {}

func apply(slot: Node) -> void:
	var here: String = station_of(slot).current_name.to_upper()
	for led: Label3D in slot.find_children("Display*", "Label3D", false, false):
		_old[led] = led.text
		led.text = "AGLA STATION\n◀  TERMINUS" if data.params.mode == "wrong_direction" else "AGLA STATION\n%s  ▶" % here

func revert(_slot: Node) -> void:
	for led: Label3D in _old:
		led.text = _old[led]
