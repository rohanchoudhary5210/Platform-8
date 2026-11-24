extends Node3D

## Composition root for a run: station loop → decision point → ride / transition → next loop.

const RIDE_MIN := 10.0
const RIDE_MAX := 15.0
const TRANSITION_SECONDS := 4.0  # escalator ride / dark passage after a non-train choice
const PA_SECONDS := 6.0
const DECISION_HINTS := {
	&"train": "DECISION: TRAIN   ·   nothing wrong → FORWARD (right)   ·   anomaly → OPPOSITE (left)",
	&"escalator": "DECISION: ESCALATOR BOTTOM   ·   nothing wrong → walk on to the platform   ·   anomaly → ride back up",
	&"gates": "DECISION: AFC GATES   ·   nothing wrong → go through   ·   anomaly → turn back",
}

@onready var station: Station = $Station
@onready var train: TrainInterior = $TrainInterior
@onready var player: StationPlayer = $Player
@onready var atmosphere: Atmosphere = $Atmosphere

var loop := LoopManager.new()
var director := AnomalyDirector.new(AnomalyCatalog.ALL)
var replay := Replay.new()

var _active: Anomaly
var _riding := false
var _ended := false
var _game: GameManager
var _logger: Node
var _hud: CanvasLayer
var _fade: ColorRect

## Auto-wired by SceneManager after the scene loads.
func inject_services(registry: Node) -> void:
	_game = registry.get_service(&"game") as GameManager
	_logger = registry.get_service(&"logger")
	if _game:
		_game.reset()
		_game.start()
	_log("Run started", {"seed": director.seed_value})

func _ready() -> void:
	loop.seed_decisions(director.seed_value + 1)
	_build_hud()
	add_child(replay)
	station.decided.connect(_on_decided)
	station.exit_reached.connect(_on_exit)
	_start_loop("")

func _physics_process(delta: float) -> void:
	if player.active:
		replay.record(player.camera.global_transform, delta)

func hud(label: String) -> Label:
	return _hud.get_node(label)

func _start_loop(pa: String) -> void:
	if _active:
		_active.revert(station.get_node(loop.current.slot_name))
		_active = null
	var done := loop.is_complete()
	replay.clear()
	station.show_station(loop.station_name, loop.count, loop.line_colour(), loop.next_station_name())
	station.set_exit_open(done)
	var dp: StringName = &"none" if done else loop.pick_decision()
	station.set_decision(dp)
	hud("Station").text = "%s   ·   %d / %d" % [loop.station_name.to_upper(), loop.count, LoopManager.GOAL]
	hud("Decision").text = DECISION_HINTS.get(dp, "EXIT IS OPEN   ·   turn around")
	_say(pa if not pa.is_empty() else "Yeh %s station hai.  This is %s." % [loop.station_name, loop.station_name])
	# Anomaly last, so it can change what the HUD and PA just showed.
	loop.current = null if done else director.pick(loop.count, LoopManager.DECISION_REACH[dp])
	if loop.current:
		_active = Anomaly.create(loop.current)
		_active.apply(station.get_node(loop.current.slot_name))
	_log("Loop", {"count": loop.count, "decision": dp, "anomaly": loop.current.id if loop.current else "none"})
	player.place(station.spawn.global_transform)
	player.active = true
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)

func _on_decided(took_back: bool) -> void:
	if _riding or loop.is_complete():
		return
	_riding = true
	player.active = false
	var dp := loop.decision
	var anomaly := loop.current
	var correct := loop.resolve(took_back)
	if correct and anomaly:
		director.mark_found(anomaly.id)
	if not correct:
		await replay.play(anomaly, station.get_node_or_null(anomaly.slot_name) if anomaly else null, player.camera.fov)
	atmosphere.riding = true
	if dp == &"train":
		await train.ride(loop.station_name, randf_range(RIDE_MIN, RIDE_MAX))
	else:
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.8)
		t.tween_interval(TRANSITION_SECONDS)
		await t.finished
	atmosphere.riding = false
	_riding = false
	var pa := "" if correct else "Yeh station %s hai." % loop.station_name
	if loop.is_complete():
		pa = "Antim station. Exit khul gaya hai."
	_start_loop(pa)

func _on_exit() -> void:
	if _ended:
		return
	_ended = true
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud("End").text = "You made it out.\n\nseed %d" % director.seed_value
	hud("End").visible = true
	if _game:
		_game.game_over("escaped")

func _say(text: String) -> void:
	var pa := hud("PA")
	pa.text = text
	if text.is_empty():
		return
	atmosphere.chime()
	await get_tree().create_timer(PA_SECONDS).timeout
	if pa.text == text:
		pa.text = ""

func _log(msg: String, ctx: Dictionary) -> void:
	if _logger:
		_logger.info(msg, ctx)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	add_child(_hud)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_fade)
	_label("Station", 20, Control.PRESET_TOP_LEFT, Vector2(24, 18))
	_label("Decision", 16, Control.PRESET_CENTER_TOP, Vector2(0, 18))
	_label("PA", 26, Control.PRESET_CENTER_BOTTOM, Vector2(0, -110))
	_label("Caption", 20, Control.PRESET_CENTER_BOTTOM, Vector2(0, -50))
	var end := _label("End", 40, Control.PRESET_FULL_RECT, Vector2.ZERO)
	end.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end.visible = false

func _label(n: String, size: int, preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var l := Label.new()
	l.name = n
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_END if preset == Control.PRESET_TOP_LEFT else Control.GROW_DIRECTION_BOTH
	l.position += offset
	if preset == Control.PRESET_TOP_LEFT:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud.add_child(l)
	return l
