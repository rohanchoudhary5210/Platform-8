extends Anomaly
## #27 The lift doors open and close by themselves, dinging every time.

var _tween: Tween
var _ding: AudioStreamPlayer3D
var _closed: Array

func apply(slot: Node) -> void:
	var l: Node3D = slot.find_child("Door_L", true, false)
	var r: Node3D = slot.find_child("Door_R", true, false)
	_closed = [l.position, r.position]
	_ding = AudioStreamPlayer3D.new()
	_ding.stream = SynthAudio.chime()
	_ding.bus = Atmosphere.BUS
	slot.add_child(_ding)
	var open_l: Vector3 = _closed[0] + Vector3(-0.55, 0, 0)
	var open_r: Vector3 = _closed[1] + Vector3(0.55, 0, 0)
	l.position = open_l
	r.position = open_r
	_ding.play()
	_tween = slot.create_tween().set_loops()
	_tween.tween_interval(1.5)
	_tween.tween_property(l, "position", _closed[0], 0.8)
	_tween.parallel().tween_property(r, "position", _closed[1], 0.8)
	_tween.tween_interval(2.0)
	_tween.tween_callback(_ding.play)
	_tween.tween_property(l, "position", open_l, 0.8)
	_tween.parallel().tween_property(r, "position", open_r, 0.8)

func revert(slot: Node) -> void:
	_tween.kill()
	slot.find_child("Door_L", true, false).position = _closed[0]
	slot.find_child("Door_R", true, false).position = _closed[1]
	slot.remove_child(_ding)
	_ding.free()
