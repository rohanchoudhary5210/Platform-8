extends Anomaly
## #32 The lights switch off one by one, from the platform end towards you, with a heavy clunk each time.

const ORDER := ["L6", "L5", "L4", "L3", "L2", "L1", "L8", "L0", "L7"]  # far end first, spawn last
var _tween: Tween
var _clunk: AudioStreamPlayer
var _slot: Node

func apply(slot: Node) -> void:
	_slot = slot
	slot.set_meta("flicker", false)
	_clunk = AudioStreamPlayer.new()
	_clunk.stream = SynthAudio.clunk()
	_clunk.bus = Atmosphere.BUS
	slot.add_child(_clunk)
	slot.get_node(ORDER[0]).visible = false
	_tween = slot.create_tween().set_loops()
	for n in ORDER.slice(1):
		_tween.tween_interval(0.7)
		_tween.tween_callback(_off.bind(n))
	_tween.tween_interval(2.5)
	_tween.tween_callback(_all_on)
	_tween.tween_interval(2.0)
	_tween.tween_callback(_off.bind(ORDER[0]))

func revert(slot: Node) -> void:
	_tween.kill()
	_all_on()
	slot.remove_child(_clunk)
	_clunk.free()
	slot.set_meta("flicker", true)

func _off(n: String) -> void:
	_slot.get_node(n).visible = false
	_clunk.play()

func _all_on() -> void:
	for n in ORDER:
		_slot.get_node(n).visible = true
