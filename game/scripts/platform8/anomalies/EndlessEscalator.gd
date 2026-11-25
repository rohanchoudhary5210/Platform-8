extends Anomaly
## #35 The escalator never reaches the bottom: near the foot you're quietly put back a few steps up,
## again and again. The first loop arms the escalator decision, so riding back up is the way out.
## Escalator decision only. Slot: Props/EscalatorSteps.

const LOOP_AT := -58.0  # z near the foot; the back zone (z -51) stays above the loop
const BACK := Vector3(0, 2.4, 4.8)  # up the slope by exactly 12 steps (0.2 m x 0.4 m), so the steps match

var loops := 0  # for tests
var _last_z := INF
var _tick: Callable

func apply(slot: Node) -> void:
	_tick = func():
		var p := player_of(slot)
		if p == null:
			return
		var z := p.global_position.z
		if _last_z >= LOOP_AT and z < LOOP_AT and z > -60.5:
			p.global_position += BACK
			z += BACK.z
			loops += 1
			station_of(slot).arm()
		_last_z = z
	slot.get_tree().physics_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().physics_frame.disconnect(_tick)
