extends Anomaly
## #13 The arrival announcement says the player's name. Slot: the HUD PA subtitle.

var _old := ""

func apply(slot: Node) -> void:
	_old = slot.text
	var who := OS.get_environment("USERNAME").capitalize()
	if who.is_empty():
		who = "Yatri"
	slot.text = (_old + "\n" if not _old.is_empty() else "") + "%s, aap yahin rahenge." % who

func revert(slot: Node) -> void:
	slot.text = _old
