extends Anomaly
## Danger: the guard stands in the middle of the walkway in front of the gates, facing you. Come within
## a few metres and he charges. That arms the gates decision: back off towards the spawn (back choice)
## before he reaches you, or you're caught (a wrong call). Gates decision only. Slot: Props/People/Guard.
## params (all optional) make other chasers: start (Vector3), trigger_z (charge once you walk past this z
## instead of coming close), run (m/s). #41 the passage runner uses them.

const BLOCK := Vector3(0, 0, -13)  # in front of the gates, on the walking line
const TRIGGER := 3.5  # metres from the guard
const NOTICE := 0.5  # seconds he stands and stares before moving
const RUN := 3.6  # m/s, faster than the player (2.8): you can't wait it out
const REACH := 1.0  # caught at this distance

var _home: Transform3D
var _tick: Callable
var _chasing := -1.0  # seconds since the chase started, -1 = not yet
var _caught := false

func apply(slot: Node) -> void:
	var guard: Node3D = slot
	_home = guard.transform
	var run: float = data.params.get("run", RUN) if data else RUN
	guard.position = data.params.get("start", BLOCK) if data else BLOCK
	guard.rotation = Vector3.ZERO  # model faces +Z: towards the spawn
	_tick = func():
		var player: Node3D = guard.get_tree().get_first_node_in_group(&"player")
		if player == null or _caught:
			return
		var to := player.global_position - guard.global_position
		to.y = 0.0
		if _chasing < 0.0:
			var far := to.length() > TRIGGER
			if data and data.params.has("trigger_z"):
				far = player.global_position.z > data.params.trigger_z
			if far:
				return
			_chasing = 0.0
			var station := station_of(guard)
			if station:
				station.arm()
		_chasing += guard.get_process_delta_time()
		if to.length() > 0.01:
			guard.look_at(guard.global_position + to, Vector3.UP, true)
		if _chasing < NOTICE:
			return
		guard.position += to.normalized() * minf(run * guard.get_process_delta_time(), maxf(to.length() - REACH, 0.0))
		_set_anim(guard, &"Run", run / RUN)  # Run cycle (art/build_people.py) is paced for RUN
		if to.length() <= REACH + 0.05:
			_caught = true
			_set_anim(guard, &"Idle", 1.0)
			caught(guard)
	guard.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	slot.transform = _home
	_set_anim(slot, &"Idle", 1.0)

static func _set_anim(who: Node, anim: StringName, speed: float) -> void:
	NpcWalker.play(who, anim)
	for ap: AnimationPlayer in who.find_children("*", "AnimationPlayer", true, false):
		ap.speed_scale = speed
