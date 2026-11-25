extends Anomaly
## #14 Your footsteps echo late: someone a few metres behind you takes a step just after each of yours,
## and stops when you stop. Turn round and nobody is there. Slot: Props.

const BEHIND := 3.0  # metres
const LATE := 0.3  # seconds after your step

var steps := 0  # echoes played, for tests
var _sound: AudioStreamPlayer3D
var _tick: Callable
var _last := Vector3.INF
var _walked := 0.0
var _clock := 0.0
var _due: Array[float] = []

func apply(slot: Node) -> void:
	_sound = AudioStreamPlayer3D.new()
	_sound.name = "EchoSteps"
	_sound.stream = SynthAudio.footstep()
	_sound.bus = Atmosphere.BUS
	slot.add_child(_sound)
	_tick = func():
		var p := player_of(slot)
		if p == null:
			return
		_clock += slot.get_process_delta_time()
		var at := p.global_position
		if _last != Vector3.INF:
			_walked += Vector2(at.x - _last.x, at.z - _last.z).length()
		_last = at
		if _walked >= StationPlayer.STRIDE:
			_walked = fmod(_walked, StationPlayer.STRIDE)
			_due.append(_clock + LATE)
		if not _due.is_empty() and _clock >= _due[0]:
			_due.pop_front()
			var back := p.camera.global_basis.z
			back.y = 0.0
			_sound.global_position = at + back.normalized() * BEHIND
			_sound.pitch_scale = randf_range(0.7, 0.8)  # heavier than yours
			_sound.play()
			steps += 1
	slot.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	_sound.free()
