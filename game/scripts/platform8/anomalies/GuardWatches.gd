extends Anomaly
## #19 The guard turns to watch you and drifts after you, never closer than 3 m. Slot: Props/People/Guard.

const SPEED := 0.5
const KEEP_AWAY := 3.0
const AREA := Rect2(-9.0, -15.0, 18.0, 14.0)  # concourse floor (x, z), so he never leaves it

var _home: Transform3D
var _tick: Callable

func apply(slot: Node) -> void:
	var guard: Node3D = slot
	_home = guard.transform
	_tick = func():
		var player: Node3D = guard.get_tree().get_first_node_in_group(&"player")
		if player == null:
			return
		var to := player.global_position - guard.global_position
		to.y = 0.0
		if to.length() < 0.01:
			return
		guard.look_at(guard.global_position + to, Vector3.UP, true)  # true: the model's front is +Z
		if to.length() > KEEP_AWAY:
			var step := to.normalized() * SPEED * guard.get_process_delta_time()
			var p := guard.position + step
			if AREA.has_point(Vector2(p.x, p.z)):
				guard.position = p
	_tick.call()  # turn at once
	guard.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	slot.transform = _home
