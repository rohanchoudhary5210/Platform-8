class_name HomeScene
extends UIController

## HomeScene — Default landing scene transitioned to by BootScene.

@onready var label: Label = $CenterContainer/VBoxContainer/Label
@onready var sub_label: Label = $CenterContainer/VBoxContainer/SubLabel

var _logger: Node
var _scene: SceneManager

## Convention-based auto-wiring for visually placed scenes (Pattern 2).
func inject_services(registry: Node) -> void:
	if not registry:
		return
	# 1. Base class (UIController) ke core services inject karo:
	# (_ui_manager, _audio, _game_manager, _save, _bus)
	super.inject_services(registry)
	
	# 2. HomeScene-specific extra services lo:
	_logger = registry.get_service(&"logger") as Node
	_scene = registry.get_service(&"scene") as SceneManager


##_on_ready() use 
func _on_ready() -> void:
	if _logger:
		_logger.info("HomeScene loaded successfully.")
	
	build_lost_and_found(SaveData.open(save_path))

## Tests point this at a scratch file.
var save_path := SaveData.PATH

## Lost & Found (GDD): one card per anomaly. Found ones show name and category; the rest stay "???".
func build_lost_and_found(save: SaveData) -> GridContainer:
	var box: VBoxContainer = $CenterContainer/VBoxContainer
	var head := Label.new()
	head.name = "LostFoundHeader"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	var best := SaveData.format_time(save.best_time) if save.best_time > 0.0 else "—"
	head.text = "\nLOST & FOUND   %d / %d\nbest station %d   ·   clears %d   ·   best time %s" % [
		save.found.size(), AnomalyCatalog.ALL.size(), save.best_station, save.clears, best]
	box.add_child(head)
	var grid := GridContainer.new()
	grid.name = "LostFound"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for d: AnomalyData in AnomalyCatalog.ALL:
		var got := save.found.has(String(d.id))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(170, 48)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.16, 0.2, 0.16) if got else Color(0.1, 0.1, 0.1)
		bg.set_content_margin_all(4)
		card.add_theme_stylebox_override("panel", bg)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.text = "%s\n%s" % [d.display_name, String(d.category).replace("_", " ")] if got else "?  ?  ?"
		l.modulate = Color(0.8, 1.0, 0.8) if got else Color(0.4, 0.4, 0.4)
		card.add_child(l)
		grid.add_child(card)
	return grid

const GAME_SCENE := "res://game/scenes/gameplay/Game.tscn"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _scene:
		_scene.go_to(GAME_SCENE)
