extends Anomaly
## #39 The sweeper only moves when you're not looking: each time he leaves your screen he is a step
## closer when you look back, standing still and facing you. Slot: Props/People/Sweeper.

const STEP := 1.5  # metres per look-away
const KEEP_AWAY := 2.0
const AREA := Rect2(-7.8, -15.0, 16.8, 14.0)  # concourse floor (x, z), clear of the stairwell

var moves := 0  # for tests
var _home: Transform3D
var _seen := true  # must be seen again after each move: one step per look-away
var _tick: Callable

func apply(slot: Node) -> void:
	var who: Node3D = slot
	_home = who.transform
	_tick = func():
		var p := player_of(who)
		if p == null:
			return
		if in_view(who, who.global_position + Vector3.UP * 1.2):
			_seen = true
			return
		if not _seen:
			return
		var to := p.global_position - who.global_position
		to.y = 0.0
		if to.length() <= KEEP_AWAY:
			return
		var next := who.position + to.normalized() * minf(STEP, to.length() - KEEP_AWAY)
		if not AREA.has_point(Vector2(next.x, next.z)):
			return
		who.position = next
		who.look_at(who.global_position + to, Vector3.UP, true)  # true: the model's front is +Z
		_seen = false
		moves += 1
	who.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	slot.transform = _home
