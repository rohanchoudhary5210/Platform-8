extends Anomaly
## #42 Danger: once you step off the escalator, dark water fills the track pits and climbs the platform.
## Reach the back (left) train door before it gets to your waist, or you're caught: a wrong call.
## Slot: Props/Flood.

const TRIGGER_Z := -62.0  # just past the escalator bottom
const PLATFORM_Y := -Station.ESC_DROP
const PIT_RISE := 0.5  # m/s while the track pits fill (~3 s)
const RISE := 0.07  # m/s up the platform: ~13 s from ankle to waist; the left door is ~8 s' walk away
const CATCH_Y := PLATFORM_Y + 0.9

var _home: Transform3D
var _tick: Callable
var _rush: AudioStreamPlayer
var _started := false
var _caught := false

func apply(slot: Node) -> void:
	var water: Node3D = slot
	_home = water.transform
	water.visible = true
	_rush = AudioStreamPlayer.new()
	_rush.stream = SynthAudio.rush()
	_rush.bus = Atmosphere.BUS
	water.add_child(_rush)
	_tick = func():
		var player: Node3D = water.get_tree().get_first_node_in_group(&"player")
		if player == null:
			return
		var on_platform := player.global_position.y < PLATFORM_Y + 2.0
		if not _started:
			if not on_platform or player.global_position.z > TRIGGER_Z:
				return
			_started = true
			_rush.play()
		var y := water.global_position.y
		water.global_position.y = minf(y + (PIT_RISE if y < PLATFORM_Y else RISE) * water.get_process_delta_time(), CATCH_Y + 0.3)
		_rush.volume_db = lerpf(-24.0, -4.0, clampf(inverse_lerp(PLATFORM_Y - 1.5, CATCH_Y, y), 0.0, 1.0))
		if not _caught and y >= CATCH_Y and on_platform:
			_caught = true
			caught(water)
	water.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	slot.remove_child(_rush)
	_rush.free()
	slot.transform = _home
	slot.visible = false
