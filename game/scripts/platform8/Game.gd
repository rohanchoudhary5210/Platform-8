extends Node3D

## Composition root for a run: station loop → train choice → ride → next loop.

const RIDE_MIN := 10.0
const RIDE_MAX := 15.0
const PA_SECONDS := 5.0

@onready var station: Station = $Station
@onready var train: TrainInterior = $TrainInterior
@onready var player: StationPlayer = $Player
@onready var atmosphere: Atmosphere = $Atmosphere

var loop := LoopManager.new()
var director := AnomalyDirector.new(AnomalyCatalog.ALL)

var _active: Anomaly
var _riding := false
var _ended := false
var _game: GameManager
var _logger: Node
var _hud_station: Label
var _hud_pa: Label
var _hud_end: Label

## Auto-wired by SceneManager after the scene loads.
func inject_services(registry: Node) -> void:
	_game = registry.get_service(&"game") as GameManager
	_logger = registry.get_service(&"logger")
	if _game:
		_game.reset()
		_game.start()
	_log("Run started", {"seed": director.seed_value})

func _ready() -> void:
	_build_hud()
	station.boarded.connect(_on_boarded)
	station.exit_reached.connect(_on_exit)
	_start_loop("")

func _start_loop(pa: String) -> void:
	if _active:
		_active.revert(station.get_node(loop.current.slot_name))
		_active = null
	station.show_station(loop.station_name, loop.count, loop.line_colour())
	station.set_exit_open(loop.is_complete())
	loop.current = null if loop.is_complete() else director.pick(loop.count)
	if loop.current:
		_active = load(loop.current.script_path).new()
		_active.apply(station.get_node(loop.current.slot_name))
	_log("Loop", {"count": loop.count, "anomaly": loop.current.id if loop.current else "none"})
	player.place(station.spawn.global_transform)
	player.active = true
	_hud_station.text = "%s   ·   %d / %d" % [loop.station_name.to_upper(), loop.count, LoopManager.GOAL]
	_say(pa)

func _on_boarded(took_opposite: bool) -> void:
	if _riding or loop.is_complete():
		return
	_riding = true
	player.active = false
	var anomaly := loop.current
	var correct := loop.resolve(took_opposite)
	if correct and anomaly:
		director.mark_found(anomaly.id)
	atmosphere.riding = true
	await train.ride(loop.station_name, randf_range(RIDE_MIN, RIDE_MAX))
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
	_hud_end.text = "You made it out.\n\nseed %d" % director.seed_value
	_hud_end.visible = true
	if _game:
		_game.game_over("escaped")

func _say(text: String) -> void:
	_hud_pa.text = text
	if text.is_empty():
		return
	atmosphere.chime()
	await get_tree().create_timer(PA_SECONDS).timeout
	if _hud_pa.text == text:
		_hud_pa.text = ""

func _log(msg: String, ctx: Dictionary) -> void:
	if _logger:
		_logger.info(msg, ctx)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_hud_station = Label.new()
	_hud_station.position = Vector2(24, 18)
	_hud_station.add_theme_font_size_override("font_size", 20)
	hud.add_child(_hud_station)
	_hud_pa = Label.new()
	_hud_pa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hud_pa.offset_top = -90
	_hud_pa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_pa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_pa.add_theme_font_size_override("font_size", 26)
	hud.add_child(_hud_pa)
	_hud_end = Label.new()
	_hud_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_end.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_end.add_theme_font_size_override("font_size", 40)
	_hud_end.visible = false
	hud.add_child(_hud_end)
