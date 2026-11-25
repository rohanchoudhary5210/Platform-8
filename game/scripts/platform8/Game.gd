extends Node3D

## Composition root for a run: station loop → decision point → ride / transition → next loop.

const RIDE_MIN := 10.0
const RIDE_MAX := 15.0
const TRANSITION_SECONDS := 4.0  # escalator ride / dark passage after a non-train choice
const PA_SECONDS := 6.0
const HOME_SCENE := "res://game/scenes/Home/Home.tscn"
const GAME_SCENE := "res://game/scenes/gameplay/Game.tscn"
## Anomalies that only show on the HUD counter, which hardcore mode hides.
const HUD_ONLY: Array[StringName] = [&"hud_counter_jump"]

@onready var station: Station = $Station
@onready var train: TrainInterior = $TrainInterior
@onready var player: StationPlayer = $Player
@onready var atmosphere: Atmosphere = $Atmosphere

var loop := LoopManager.new()
var director := AnomalyDirector.new(AnomalyCatalog.ALL)
var replay := Replay.new()
var save: SaveData
## Tests point this at a scratch file so they never touch the player's save.
var save_path := SaveData.PATH

var _active: Anomaly
var _riding := false
var _ended := false
var _game: GameManager
var _logger: Node
var _scene: SceneManager
var _run_time := 0.0
var _wrong_calls := 0
var _found_this_run := 0
var _hud: CanvasLayer
var _fade: ColorRect
var _debug_index := -1  # position in AnomalyCatalog.ALL of the last forced anomaly
var _debug_used := false
var _pause: CanvasLayer
var _leaving := false  # Restart / Quit started: the scene is loading, no more pausing

## Auto-wired by SceneManager after the scene loads.
func inject_services(registry: Node) -> void:
	_game = registry.get_service(&"game") as GameManager
	_logger = registry.get_service(&"logger")
	_scene = registry.get_service(&"scene") as SceneManager
	if _game:
		_game.reset()
		_game.start()
	_log("Run started", {"seed": director.seed_value})

func _ready() -> void:
	loop.seed_decisions(director.seed_value + 1)
	save = SaveData.open(save_path)
	player.sensitivity_scale = save.mouse_sensitivity
	AudioServer.set_bus_volume_db(0, save.volume_db)
	Lang.code = save.language
	_build_hud()
	_build_pause()
	set_hardcore(save.hardcore)
	add_child(replay)
	station.decided.connect(_on_decided)
	station.exit_reached.connect(_on_exit)
	_start_loop("")

func _process(delta: float) -> void:
	if not _ended:
		_run_time += delta

func _unhandled_input(event: InputEvent) -> void:
	if _ended and hud("End").visible and event.is_action_pressed("ui_accept") and _scene:
		_scene.go_to(HOME_SCENE)
	# Debug builds only (editor F5): F1/F2 = previous/next anomaly, F3 = clean loop.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: debug_force(maxi(_debug_index, 0) - 1)  # first press goes to the last one
			KEY_F2: debug_force(_debug_index + 1)
			KEY_F3: debug_force(_debug_index, true)
			KEY_F4: debug_next_station()

## Jump straight to the next station, as if this loop was called right (no ride, no replay).
## At station 8 the exit opens, like a real clear. The run stops saving once this is used.
func debug_next_station() -> void:
	if _riding or _ended or loop.is_complete():
		return
	_debug_used = true
	loop.count += 1
	loop.station_name = LoopManager.STATION_NAMES[loop.count]
	_start_loop("Antim station. Exit khul gaya hai." if loop.is_complete() else "")
	hud("Debug").text = "DEBUG  skipped to station %d   ·   F1 prev  F2 next  F3 clean  F4 next station" % loop.count

## Restart this loop at the spawn with catalog anomaly i (wraps), or a clean loop.
## Picks a decision point the anomaly is fair with. The run stops saving once this is used.
func debug_force(i: int, clean := false) -> void:
	if _riding or _ended or loop.is_complete():
		return
	_debug_used = true
	if _active:
		_active.revert(station.get_node(loop.current.slot_name))
		_active = null
	var data: AnomalyData = null
	if not clean:
		_debug_index = wrapi(i, 0, AnomalyCatalog.ALL.size())
		data = AnomalyCatalog.ALL[_debug_index]
	var dp: StringName = &"train"
	if data:  # the furthest decision point this anomaly is fair with
		for d: StringName in [&"train", &"escalator", &"gates"]:
			if LoopManager.DECISION_REACH[d] <= data.max_decision_reach:
				dp = d
				break
	loop.decision = dp
	station.set_decision(dp)
	hud("Decision").text = decision_hint(dp)
	hud("Station").text = "%s   ·   %d / %d" % [loop.station_name.to_upper(), loop.count, LoopManager.GOAL]
	_say("Yeh %s station hai.  This is %s." % [loop.station_name, loop.station_name])
	loop.current = data
	if data:
		director.seen[data.id] = true  # so the picker doesn't show it again later this run
		_active = Anomaly.create(data)
		_active.apply(station.get_node(data.slot_name))
	hud("Debug").text = "DEBUG  %d/%d  %s  [%s, %s]   ·   F1 prev  F2 next  F3 clean  F4 next station" % [
		_debug_index + 1, AnomalyCatalog.ALL.size(), data.display_name, data.location, dp] if data \
		else "DEBUG  clean loop (no anomaly)   ·   F1 prev  F2 next  F3 clean  F4 next station"
	_log("Debug force", {"anomaly": data.id if data else &"none", "decision": dp})
	player.place(station.spawn.global_transform)
	player.active = true

func _physics_process(delta: float) -> void:
	if player.active:
		replay.record(player.camera.global_transform, delta)
	var thing := player.interactable()
	hud("Prompt").text = thing.prompt() if thing else ""
	hud("Tokens").text = "TOKEN  × %d" % player.tokens if player.tokens > 0 else ""

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
	hud("Decision").text = decision_hint(dp)
	station.set_rules(Lang.t("rules"))
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
		save.found[String(anomaly.id)] = true
		_found_this_run += 1
	if not correct:
		_wrong_calls += 1
	save.best_station = maxi(save.best_station, loop.count)
	_write_save()
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
	save.record_clear(_run_time)
	_write_save()
	if _game:
		_game.game_over("escaped")
	_log("Run cleared", {"seconds": _run_time, "wrong_calls": _wrong_calls, "seed": director.seed_value})
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 2.0)
	await t.finished
	for n in ["Station", "Decision", "PA", "Caption", "Debug"]:
		hud(n).visible = false
	hud("End").text = ending_text()
	hud("End").visible = true

func ending_text() -> String:
	return Lang.t("end_title") + "\n\n" \
		+ Lang.t("end_stats") % [SaveData.format_time(_run_time), _wrong_calls] + "\n" \
		+ Lang.t("end_found") % [_found_this_run, save.found_count(), AnomalyCatalog.ALL.size()] + "\n\n" \
		+ Lang.t("end_seed") % director.seed_value

func decision_hint(dp: StringName) -> String:
	return Lang.t("decision_" + dp) if dp in [&"train", &"escalator", &"gates"] else Lang.t("exit_open")

## Hardcore: no station counter (HUD or the in-world sign) and no decision hint. Saved as a setting.
func set_hardcore(on: bool) -> void:
	save.hardcore = on
	for n in ["Station", "Decision"]:
		hud(n).visible = not on and not _ended
	station.set_counter_visible(not on)
	director.excluded.clear()
	if on:
		for id in HUD_ONLY:
			director.excluded[id] = true

func set_language(c: String) -> void:
	save.language = c
	Lang.code = c
	hud("Decision").text = decision_hint(&"none" if loop.is_complete() else loop.decision)
	if _active == null or loop.current.slot_name != ^"Props/RulesBoard/Text":
		station.set_rules(Lang.t("rules"))  # an active rules anomaly keeps its text until the next loop
	_refresh_pause()

func is_paused() -> bool:
	return _pause.visible

## Pauses through GameManager (state + GameBus events, docs/DEVELOPER_CHEATSHEET.md section 7).
func set_paused(on: bool) -> void:
	if on and (_ended or _leaving):
		return
	_pause.visible = on
	if _game:
		if on:
			_game.pause()
		else:
			_game.resume()
	get_tree().paused = on  # also without GameManager (tests), or if its state was not PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		_refresh_pause()
		_pause.get_node("Box/Resume").grab_focus.call_deferred()  # gamepad / arrow keys work at once

func _go(scene: String) -> void:
	set_paused(false)
	_leaving = true
	if _scene:
		_scene.go_to(scene)
	else:
		get_tree().change_scene_to_file(scene)

func _write_save() -> void:
	if _debug_used:
		return  # a run with forced anomalies must not fill Lost & Found or set records
	var err := save.write()
	if err != OK and _logger:
		_logger.warn("Save failed", {"path": save.path, "error": error_string(err)})

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

## Pause menu (Esc / Start). Runs while the tree is paused; settings changes are saved straight away.
func _build_pause() -> void:
	_pause = CanvasLayer.new()
	_pause.name = "Pause"
	_pause.layer = 10
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.visible = false
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var actions := {
		"Resume": func(): set_paused(false),
		"Restart": func(): _go(GAME_SCENE),
		"Hardcore": func():
			set_hardcore(not save.hardcore)
			_refresh_pause()
			_write_settings(),
		"Language": func():
			set_language(Lang.next(save.language))
			_write_settings(),
		"Quit": func(): _go(HOME_SCENE),
	}
	for n: String in actions:
		var b := Button.new()
		b.name = n
		b.custom_minimum_size = Vector2(380, 44)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(actions[n])
		box.add_child(b)
	var input := PauseInput.new()
	input.game = self
	_pause.add_child(input)

func _refresh_pause() -> void:
	var box := _pause.get_node("Box")
	box.get_node("Title").text = Lang.t("paused")
	box.get_node("Resume").text = Lang.t("resume")
	box.get_node("Restart").text = Lang.t("restart")
	box.get_node("Hardcore").text = Lang.t("hardcore_on" if save.hardcore else "hardcore_off")
	box.get_node("Language").text = Lang.t("language")
	box.get_node("Quit").text = Lang.t("quit")

## Settings are saved even in a debug run; only progress is held back there.
func _write_settings() -> void:
	if not _debug_used:
		save.write()
		return
	var on_disk := SaveData.open(save.path)
	on_disk.hardcore = save.hardcore
	on_disk.language = save.language
	on_disk.write()

## Esc / gamepad Start toggles the pause menu. A separate node because Game itself stops while paused.
class PauseInput extends Node:
	var game: Node

	func _unhandled_input(event: InputEvent) -> void:
		var start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
		if start or event.is_action_pressed("ui_cancel"):
			game.set_paused(not game.is_paused())
			get_viewport().set_input_as_handled()

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
	_label("Prompt", 18, Control.PRESET_CENTER, Vector2(0, 60))
	_label("Tokens", 16, Control.PRESET_TOP_LEFT, Vector2(24, 50))
	var dbg := _label("Debug", 14, Control.PRESET_TOP_LEFT, Vector2(24, 80))
	dbg.modulate = Color(1, 0.55, 0.2)
	dbg.text = "DEBUG   ·   F1 prev  F2 next  F3 clean  F4 next station" if OS.is_debug_build() else ""
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
