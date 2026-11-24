extends Anomaly
## #11 Every station name sign reads backwards.

var _texts: Dictionary = {}

func apply(slot: Node) -> void:
	for sign in slot.get_children():
		_texts[sign] = sign.text
		sign.text = sign.text.reverse()

func revert(_slot: Node) -> void:
	for sign in _texts:
		sign.text = _texts[sign]
	_texts.clear()
