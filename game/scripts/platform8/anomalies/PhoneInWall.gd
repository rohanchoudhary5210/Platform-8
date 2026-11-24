extends Anomaly
## #16 A phone rings from inside the passage wall. Caption for players without sound.

const CAPTION := "[ a phone is ringing inside the wall ]"
var _ring: AudioStreamPlayer3D
var _caption: Label
var _old_caption := ""

func apply(slot: Node) -> void:
	_ring = AudioStreamPlayer3D.new()
	_ring.stream = SynthAudio.ring()
	_ring.bus = Atmosphere.BUS
	_ring.unit_size = 4.0
	slot.add_child(_ring)
	_ring.play()
	_caption = hud_label(slot, "Caption")
	if _caption:
		_old_caption = _caption.text
		_caption.text = CAPTION

func revert(slot: Node) -> void:
	slot.remove_child(_ring)
	_ring.free()
	if _caption:
		_caption.text = _old_caption
