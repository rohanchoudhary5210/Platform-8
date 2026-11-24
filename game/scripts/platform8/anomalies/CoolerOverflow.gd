extends Anomaly
## #26 The water cooler is overflowing; a puddle spreads across the concourse floor.

var _tween: Tween

func apply(slot: Node) -> void:
	slot.visible = true
	slot.scale = Vector3(1.5, 1, 1.5)
	_tween = slot.create_tween()
	_tween.tween_property(slot, "scale", Vector3(5, 1, 5), 25.0)

func revert(slot: Node) -> void:
	_tween.kill()
	slot.visible = false
	slot.scale = Vector3.ONE
