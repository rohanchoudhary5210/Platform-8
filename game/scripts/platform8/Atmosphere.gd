class_name Atmosphere
extends Node

## Mood layer: echoing bus, fluorescent hum, tunnel rumble, distant unseen trains, PA chime, vignette + grain.

const BUS := &"Station"

var riding := false:
	set(v):
		riding = v
		if _swell:
			_swell.kill()
		_rumble.volume_db = -6.0 if v else -20.0
		_hum.volume_db = -40.0 if v else -24.0

var _hum := AudioStreamPlayer.new()
var _rumble := AudioStreamPlayer.new()
var _screech := AudioStreamPlayer.new()
var _chime := AudioStreamPlayer.new()
var _next_ghost_train := 0.0
var _swell: Tween

const VIGNETTE := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float vignette = smoothstep(0.3, 0.85, length(uv * vec2(1.25, 1.0)));
	float grain = fract(sin(dot(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * 17.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(grain * 0.12), clamp(vignette * 0.85 + grain * 0.03, 0.0, 1.0));
}
"""

func _ready() -> void:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.9
		reverb.damping = 0.3
		reverb.wet = 0.45
		AudioServer.add_bus_effect(i, reverb)
	_play(_hum, SynthAudio.hum(), -24.0)
	_play(_rumble, SynthAudio.rumble(), -20.0)
	_screech.stream = SynthAudio.screech()
	_chime.stream = SynthAudio.chime()
	for p in [_screech, _chime]:
		p.bus = BUS
		add_child(p)
	_next_ghost_train = randf_range(15.0, 30.0)

	var layer := CanvasLayer.new()
	layer.layer = 0  # under the HUD
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = VIGNETTE
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

func chime() -> void:
	_chime.play()

func _process(delta: float) -> void:
	_next_ghost_train -= delta
	if _next_ghost_train > 0.0 or riding:
		return
	# A train passes somewhere you can't see: rumble swells, wheels screech.
	_next_ghost_train = randf_range(25.0, 50.0)
	_swell = create_tween()
	_swell.tween_property(_rumble, "volume_db", -8.0, 3.0)
	_swell.tween_callback(_screech.play)
	_swell.tween_interval(2.0)
	_swell.tween_property(_rumble, "volume_db", -20.0, 4.0)

func _play(p: AudioStreamPlayer, s: AudioStream, db: float) -> void:
	p.stream = s
	p.volume_db = db
	p.bus = BUS
	add_child(p)
	p.play()
