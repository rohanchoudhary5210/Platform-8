extends Anomaly
## #40 A commuter on the platform turns to face you whenever you look straight at him, and is facing
## away again the moment you look elsewhere. Slot: Props/People/CommuterA.

const TURN := 6.0  # how fast he turns towards you

var _home: Transform3D
var _tick: Callable

func apply(slot: Node) -> void:
	var who: Node3D = slot
	_home = who.transform
	_tick = func():
		var p := player_of(who)
		if p == null or not looked_at(who, who.global_position + Vector3.UP * 1.5):
			who.transform = _home
			return
		var to := p.global_position - who.global_position
		var yaw := atan2(to.x, to.z) - who.get_parent_node_3d().global_rotation.y  # model's front is +Z
		who.rotation.y = lerp_angle(who.rotation.y, yaw, minf(1.0, TURN * who.get_process_delta_time()))
	who.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	slot.transform = _home
