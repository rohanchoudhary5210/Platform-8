extends Anomaly
## #1 The concourse poster is mirrored left-right.

var _scale: Vector3

func apply(slot: Node) -> void:
	_scale = slot.scale
	slot.scale.x = -_scale.x

func revert(slot: Node) -> void:
	slot.scale = _scale
