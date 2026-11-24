extends Anomaly
## #5 The passage fire extinguisher is blue.

var _colour: Color

func apply(slot: Node) -> void:
	_colour = slot.material.albedo_color
	slot.material.albedo_color = Color(0.1, 0.3, 0.9)

func revert(slot: Node) -> void:
	slot.material.albedo_color = _colour
