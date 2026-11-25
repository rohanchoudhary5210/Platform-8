extends Anomaly
## #33 The passage is a few metres longer: near its end you're quietly put back 8 m, once, so the walk
## takes longer and the PLATFORM sign comes round twice. Slot: Props/PassageCeiling.
# shortcut: a teleport in a plain stretch, not new geometry; build a real longer passage if it reads badly.

const AT := -37.5  # z, just past the PLATFORM sign
const BACK := 8.0

var done := false  # for tests
var _last_z := INF
var _tick: Callable

func apply(slot: Node) -> void:
	_tick = func():
		var p := player_of(slot)
		if p == null or done:
			return
		var at := p.global_position
		if _last_z >= AT and at.z < AT and at.z > -40.0 and at.y > -1.0:
			p.global_position.z += BACK
			done = true
		_last_z = p.global_position.z
	slot.get_tree().physics_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().physics_frame.disconnect(_tick)
