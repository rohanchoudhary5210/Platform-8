class_name Replay
extends Node

## Wrong-call replay (GDD): records the camera every physics frame of a loop. After a wrong call it replays
## the 3 seconds around the moment you were closest to the anomaly, with it circled.
## On an empty loop it just says "There was no anomaly."

const LENGTH := 3.0
const LEAD := 2.0  # seconds shown before the closest moment
const CIRCLE := Color(1.0, 0.15, 0.1)

var playing := false

var _samples: Array = []  # [time, Transform3D]
var _t := 0.0
var _cam := Camera3D.new()
var _overlay := Control.new()
var _title := Label.new()
var _target: Variant = null  # Vector3 (world), Control (HUD) or null (everywhere)

func _ready() -> void:
	add_child(_cam)
	var layer := CanvasLayer.new()
	layer.layer = 5  # above HUD and vignette
	add_child(layer)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	layer.add_child(_overlay)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.position.y += 70
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", CIRCLE)
	_overlay.add_child(_title)
	_overlay.visible = false

func clear() -> void:
	_samples.clear()
	_t = 0.0

func record(view: Transform3D, delta: float) -> void:
	_t += delta
	_samples.append([_t, view])

## Where to circle: a world point, a HUD Control, or null for station-wide anomalies (lights, ceiling).
static func focus_of(slot: Node) -> Variant:
	if slot is Control:
		return slot
	if not (slot is Node3D) or slot is Station or slot.name == "Lights":
		return null
	var n: Node3D = slot
	if n.global_position.length() > 0.01:
		return n.global_position
	# A container at the origin (e.g. Props/Signs): use its first placed part.
	for c in n.find_children("*", "Node3D", true, false):
		if c.global_position.length() > 0.01:
			return c.global_position
	return null

## Start time of the 3 s window: LEAD seconds before the closest pass, kept inside the recording.
func window_start(target: Variant) -> float:
	if _samples.is_empty():
		return 0.0
	var best_t := 0.0
	if target is Vector3:
		var best := INF
		for s in _samples:
			var d: float = s[1].origin.distance_to(target)
			if d < best:
				best = d
				best_t = s[0]
	return clampf(best_t - LEAD, 0.0, maxf(0.0, _t - LENGTH))

## Plays the replay; await it. anomaly == null means the loop was empty.
func play(anomaly: AnomalyData, slot: Node, fov: float) -> void:
	playing = true
	_overlay.visible = true
	if anomaly == null:
		_target = null
		_title.text = "There was no anomaly."
		_overlay.queue_redraw()
		await get_tree().create_timer(LENGTH).timeout
	else:
		_target = focus_of(slot)
		_title.text = "REPLAY   ·   you missed: %s" % anomaly.display_name
		if not _samples.is_empty():
			_cam.fov = fov
			_cam.make_current()
		var t := window_start(_target)
		var end := t + LENGTH
		while t < end:
			if not _samples.is_empty():
				_cam.global_transform = _sample_at(t)
			_overlay.queue_redraw()
			await get_tree().process_frame
			t += get_process_delta_time()
	_overlay.visible = false
	playing = false

func _sample_at(t: float) -> Transform3D:
	for i in range(1, _samples.size()):
		if _samples[i][0] >= t:
			var a: Array = _samples[i - 1]
			var b: Array = _samples[i]
			return a[1].interpolate_with(b[1], inverse_lerp(a[0], b[0], t))
	return _samples[-1][1]

func _draw_overlay() -> void:
	_overlay.draw_rect(Rect2(Vector2.ZERO, _overlay.size), Color(0, 0, 0, 0.15))
	if _target is Control:
		_overlay.draw_rect(_target.get_global_rect().grow(10), CIRCLE, false, 4.0)
	elif _target is Vector3 and _cam.is_current() and not _cam.is_position_behind(_target):
		var r := clampf(500.0 / _cam.global_position.distance_to(_target), 35.0, 160.0)
		_overlay.draw_arc(_cam.unproject_position(_target), r, 0, TAU, 48, CIRCLE, 5.0)
