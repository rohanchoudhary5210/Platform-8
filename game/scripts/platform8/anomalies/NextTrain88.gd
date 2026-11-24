extends Anomaly
## #44 The platform board says the next train is 88 minutes away.

var _text: String

func apply(slot: Node) -> void:
	_text = slot.text
	slot.text = "NEXT TRAIN  88 MIN"

func revert(slot: Node) -> void:
	slot.text = _text
