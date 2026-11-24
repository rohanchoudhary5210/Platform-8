extends Anomaly
## #28 The passage tube flickers in a perfectly steady rhythm (unlike the random flicker at the doors).

var _tween: Tween

func apply(slot: Node) -> void:
	slot.visible = false
	_tween = slot.create_tween().set_loops()
	_tween.tween_interval(0.4)
	_tween.tween_callback(func(): slot.visible = true)
	_tween.tween_interval(0.4)
	_tween.tween_callback(func(): slot.visible = false)

func revert(slot: Node) -> void:
	_tween.kill()
	slot.visible = true
