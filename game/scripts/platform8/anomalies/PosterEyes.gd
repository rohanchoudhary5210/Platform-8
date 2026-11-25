extends Anomaly
## #38 The poster model's eyes follow you. Normally they gaze up and to the right. Slot: Props/Poster/Face.

const LOOK := 0.035  # furthest a pupil moves from the middle of its eye, metres on the poster

var _home := {}  # pupil -> position
var _tick: Callable

func apply(slot: Node) -> void:
	var face: Node3D = slot
	for pupil: Node3D in face.find_children("Pupil*", "", false, false):
		_home[pupil] = pupil.position
	_tick = func():
		var p := player_of(face)
		if p == null:
			return
		var to := face.to_local(p.camera.global_position)
		var gaze := (Vector2(to.x, to.y) / maxf(to.z, 0.5)).limit_length(1.0) * LOOK
		for pupil: Node3D in _home:
			pupil.position = pupil.get_meta("centre") + Vector3(gaze.x, gaze.y, 0)
	_tick.call()
	face.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	for pupil: Node3D in _home:
		pupil.position = _home[pupil]
