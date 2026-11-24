extends Anomaly
## #46 The HUD station counter flickers to 8 / 8, then back. Slot: the HUD station label.

var _tween: Tween
var _old := ""

func apply(slot: Node) -> void:
	_old = slot.text
	var jumped := _old.substr(0, _old.rfind("·") + 1) + "   8 / 8"
	slot.text = jumped
	_tween = slot.create_tween().set_loops()
	_tween.tween_interval(0.3)
	_tween.tween_callback(func(): slot.text = _old)
	_tween.tween_interval(3.5)
	_tween.tween_callback(func(): slot.text = jumped)

func revert(slot: Node) -> void:
	_tween.kill()
	slot.text = _old
