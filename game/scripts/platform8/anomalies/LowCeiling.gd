extends Anomaly
## #37 The passage ceiling (and its light) has dropped; the tube nearly touches your head. Slot: the Station.

const DROP := 0.45
var _ceiling: Node3D
var _light: Node3D

func apply(slot: Node) -> void:
	_ceiling = slot.get_node("Props/PassageCeiling")
	_light = slot.get_node("Lights/L2")
	_ceiling.position.y -= DROP
	_light.position.y -= DROP

func revert(_slot: Node) -> void:
	_ceiling.position.y += DROP
	_light.position.y += DROP
