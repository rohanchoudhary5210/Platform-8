class_name Station
extends Node3D

## Greybox station, same layout every loop: concourse → AFC gates → passage → escalator → platform.
## Only identity (name, number, line colour) changes. Anomalies change nodes under Props/, Lights/ and ../HUD.
## Player walks -Z. Right train (+X) = forward, left train (-X) = opposite.

## took_back: the player took the "back" choice (opposite train, back up the escalator, back from the gates).
signal decided(took_back: bool)
signal exit_reached

const WALL := Color(0.5, 0.5, 0.46)
const FLOOR := Color(0.32, 0.32, 0.34)
const DARK := Color(0.12, 0.12, 0.13)
const CEILING := Color(0.45, 0.45, 0.44)
const CONCRETE := Color(0.2, 0.2, 0.2)
const STEEL := Color(0.7, 0.72, 0.75)
const YELLOW := Color(0.85, 0.7, 0.1)
const LIGHT_COLOUR := Color(0.82, 1.0, 0.86)  # tired fluorescent tubes
const ESC_DROP := 10.0
const ESC_RUN := 20.0
const ESC_STEPS := 16
const GATE_OPEN_DISTANCE := 2.0
const STAIRS_X := -9.05  # stairwell down the left concourse wall (art/build_props.py stairs: 3.5 m drop, 6 m run)
const STAIRS_TOP_Z := -5.2
const STAIRS_DROP := 3.5
const STAIRS_RUN := 6.0
const FLICKER_LIGHT := "L5"  # the tube over the train doors
const MODELS :="res://game/assets/models/%s.gltf"  # built by art/build_props.py
## Tiled surfaces (art/build_textures.py): colour -> [texture, tint]. Each texture covers 1.2 m, mapped world-space.
const SURFACES := {
	WALL: ["wall_tile", Color(0.8, 0.8, 0.76)],
	FLOOR: ["floor_tile", Color(0.75, 0.75, 0.75)],
	CEILING: ["ceiling", Color(0.7, 0.7, 0.7)],
	CONCRETE: ["concrete", Color(0.8, 0.8, 0.8)],
}
const TILE_METRES := 1.2

var spawn: Marker3D
var props: Node3D
var lights: Node3D
var decision: StringName = &"train"
var current_name := ""  # this loop's station, for anomalies that need it

var _line_mat := StandardMaterial3D.new()
var _number: Label3D
var _exit_barrier: CSGBox3D
var _exit_label: Label3D
var _flicker_wait := 0.0
var _armed := false
var _stickers := {}  # decision -> Node3D
var _door_fill: Array[CSGBox3D] = []
var _esc_offset := 0.0
var _player: Node3D
var _second_hand: Node3D
var _surface_mats := {}

func _ready() -> void:
	props = _node("Props", self)
	lights = _node("Lights", self)
	_build_concourse()
	_build_passage()
	_build_escalator()
	_build_platform()
	_build_props()
	_build_lights()
	_build_train_insides()
	_build_decisions()

## Called at the start of every loop, before an anomaly is applied.
func show_station(station_name: String, count: int, line_colour: Color, next_name: String) -> void:
	for sign in props.get_node("Signs").get_children():
		sign.text = station_name.to_upper()
	_number.text = "STATION %d / 8" % count
	_line_mat.albedo_color = line_colour
	props.get_node("TrainBoards/Forward").text = "▶  " + next_name.to_upper()
	current_name = station_name
	for led in props.get_node("CoachDisplays/Forward").find_children("Display*", "Label3D", false, false):
		led.text = "AGLA STATION\n%s  ▶" % next_name.to_upper()
	for led in props.get_node("CoachDisplays/Opposite").find_children("Display*", "Label3D", false, false):
		led.text = "AGLA STATION\n◀  TERMINUS"
	props.get_node("TokenMachine").set_route(station_name, next_name)

func set_exit_open(open: bool) -> void:
	_exit_barrier.use_collision = not open
	_exit_barrier.visible = not open
	_exit_label.text = "EXIT" if open else "EXIT CLOSED"

## Rules notice text (Lang). Game sets it every loop before the anomaly, so #46 lies in the current language.
func set_rules(text: String) -> void:
	props.get_node("RulesBoard/Text").text = text
	props.get_node("RulesBoard/Header").text = Lang.t("notice")

## The "STATION n / 8" sign over the passage. Hidden in hardcore mode.
func set_counter_visible(v: bool) -> void:
	_number.visible = v

## Which decision point is live this loop: &"train", &"escalator" or &"gates".
func set_decision(dp: StringName) -> void:
	decision = dp
	_armed = dp == &"train"  # the train doors are the choice itself; the others arm when you reach them
	for k in _stickers:
		_stickers[k].visible = k == dp
	for f in _door_fill:
		f.visible = dp != &"train"
		f.use_collision = dp != &"train"

## A danger anomaly that starts before the sticker counts as reaching the decision point.
func arm() -> void:
	_armed = true

## State of everything an anomaly may touch. Used by tests to prove revert() is exact.
func snapshot() -> Dictionary:
	var s := {}
	var nodes: Array = props.find_children("*", "", true, false) + lights.get_children() + [props, lights, self]
	var hud := get_node_or_null("../HUD")
	if hud:
		nodes += hud.get_children()
	for n in nodes:
		var k := str(n.get_path())
		for m in n.get_meta_list():
			s[k + ":meta:" + m] = n.get_meta(m)
		if n is Node3D or n is CanvasItem:
			s[k + ":visible"] = n.visible
		if n is Node3D:
			s[k + ":xf"] = n.transform
		if n is Label3D or n is Label:
			s[k + ":text"] = n.text
			s[k + ":modulate"] = n.modulate
		if n is OmniLight3D:
			s[k + ":light"] = [n.light_color, n.light_energy]
		if n is CSGShape3D and n.material:
			s[k + ":albedo"] = n.material.albedo_color
		if n is MeshInstance3D and n.material_override:
			s[k + ":albedo"] = n.material_override.albedo_color
	return s

func _process(delta: float) -> void:
	_flicker(delta)
	# Clock second hand: clockwise unless an anomaly sets dir to -1.
	var clock := props.get_node("Clock")
	_second_hand.rotation.z -= clock.get_meta("dir") * TAU / 60.0 * delta
	# Escalator step lines run down (positive speed) or up.
	var steps := props.get_node("EscalatorSteps")
	_esc_offset = fposmod(_esc_offset + steps.get_meta("speed") * delta, _esc_length())
	for i in steps.get_child_count():
		steps.get_child(i).position = _esc_point(fposmod(i * _esc_length() / ESC_STEPS + _esc_offset, _esc_length()))
	# AFC flaps retract when the player is near, or always when an anomaly says so.
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player")
	var flaps := props.get_node("GateFlaps")
	for gate in flaps.get_children():
		var near: bool = _player != null and _player.global_position.distance_to(gate.global_position) < GATE_OPEN_DISTANCE
		gate.visible = not (near or flaps.get_meta("always_open"))

func _flicker(delta: float) -> void:
	_flicker_wait -= delta
	if _flicker_wait > 0.0 or not lights.get_meta("flicker"):
		return
	var l: OmniLight3D = lights.get_node(FLICKER_LIGHT)
	l.visible = not l.visible
	# Mostly on, with short bursts of dropouts.
	_flicker_wait = randf_range(0.03, 0.12) if not l.visible or randf() < 0.4 else randf_range(1.5, 5.0)

# ── Layout ────────────────────────────────────────────────────────────────

func _build_concourse() -> void:
	var g := _node("Concourse", self)
	_build_stairs(_box(g, Vector3(20, 0.5, 20), Vector3(0, -0.25, -10), FLOOR))
	_box(g, Vector3(20, 0.5, 20), Vector3(0, 3.65, -10), CEILING)
	_box(g, Vector3(0.5, 4.5, 20), Vector3(-10.25, 2, -10), WALL)
	_box(g, Vector3(0.5, 4.5, 20), Vector3(10.25, 2, -10), WALL)
	# Back wall with the exit gap behind the spawn.
	_box(g, Vector3(8.5, 4.5, 0.5), Vector3(-5.75, 2, 0.25), WALL)
	_box(g, Vector3(8.5, 4.5, 0.5), Vector3(5.75, 2, 0.25), WALL)
	_exit_barrier = _box(g, Vector3(3, 4.5, 0.5), Vector3(0, 2, 0.25), DARK)
	_exit_label = _label(g, "EXIT CLOSED", Vector3(0, 2.9, -0.05), PI, 64)
	_build_street()
	# Front wall with the passage opening.
	_box(g, Vector3(8, 4.5, 0.5), Vector3(-6, 2, -20.25), WALL)
	_box(g, Vector3(8, 4.5, 0.5), Vector3(6, 2, -20.25), WALL)
	_box(g, Vector3(4, 1, 0.5), Vector3(0, 2.95, -20.25), WALL)
	# Line colour stripe.
	for x in [-9.98, 9.98]:
		var stripe := _box(g, Vector3(0.05, 0.3, 20), Vector3(x, 1.2, -10), Color.WHITE, false)
		stripe.material = _line_mat
	# AFC gates: cabinets with gaps, railings either side. Flaps live in Props/GateFlaps.
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		var gate := _model("afc_gate", g, "Gate", Vector3(x, 0, -16), PI, Vector3(0.3, 1.0, 1.4))
		for flap in ["Flap_L", "Flap_R"]:
			gate.find_child(flap).visible = false  # the moving flaps are Props/GateFlaps
	_box(g, Vector3(6.4, 1.0, 0.1), Vector3(-6.7, 0.5, -16), DARK)
	_box(g, Vector3(6.4, 1.0, 0.1), Vector3(6.7, 0.5, -16), DARK)
	# CCTV mounts stay even when a camera goes missing.
	for x in [-5.0, 5.0]:
		_box(g, Vector3(0.08, 0.2, 0.08), Vector3(x, 3.3, -17), DARK, false)
	spawn = Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 1.0, -3)
	add_child(spawn)

## A flight of stairs down the left wall to a shuttered subway (#34 swaps in a flight with more steps).
## The steps are art/build_props.py's stairs model; walking uses a plain ramp under them.
func _build_stairs(floor: CSGBox3D) -> void:
	var g := _node("Stairwell", self)
	var top := Vector3(STAIRS_X, 0, STAIRS_TOP_Z)
	var bottom_z := STAIRS_TOP_Z - STAIRS_RUN
	var end_z := bottom_z - 2.3
	var mid_z := (STAIRS_TOP_Z + end_z) / 2.0
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(1.7, 0.6, STAIRS_TOP_Z - end_z)
	hole.position = Vector3(STAIRS_X, -0.25, mid_z) - floor.position
	floor.add_child(hole)
	for x in [STAIRS_X - 0.95, STAIRS_X + 0.95]:
		_box(g, Vector3(0.2, 4.0, STAIRS_TOP_Z - end_z), Vector3(x, -2.0, mid_z), WALL)
	_box(g, Vector3(1.7, 0.5, 2.3), Vector3(STAIRS_X, -STAIRS_DROP - 0.25, bottom_z - 1.15), FLOOR)
	_box(g, Vector3(2.1, 4.0, 0.2), Vector3(STAIRS_X, -2.0, end_z - 0.1), WALL)
	# Rolling shutter at the bottom: why the stairs lead nowhere.
	_box(g, Vector3(1.5, 2.6, 0.05), Vector3(STAIRS_X, -STAIRS_DROP + 1.3, end_z + 0.03), Color(0.55, 0.56, 0.58), false)
	for i in 12:
		_box(g, Vector3(1.5, 0.02, 0.02), Vector3(STAIRS_X, -STAIRS_DROP + 0.2 + i * 0.2, end_z + 0.06), DARK, false)
	_label(g, "SUBWAY CLOSED
Subway band hai", Vector3(STAIRS_X, -STAIRS_DROP + 2.85, end_z + 0.05), 0, 28).modulate = Color(1.0, 0.8, 0.3)
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var tilt := -atan2(STAIRS_DROP, STAIRS_RUN)
	box.size = Vector3(1.6, 0.2, Vector2(STAIRS_RUN, STAIRS_DROP).length() + 0.1)
	shape.shape = box
	shape.rotation.x = tilt
	shape.position = Vector3(STAIRS_X, -STAIRS_DROP / 2.0, STAIRS_TOP_Z - STAIRS_RUN / 2.0) 			- Vector3(0, cos(tilt), sin(tilt)) * 0.1  # top face on the step nosings
	ramp.add_child(shape)
	# Railing round the hole on the concourse side; the collider stops you stepping off the edge.
	var rail_x := STAIRS_X + 0.85
	for r: Array in [[Vector3(rail_x, 0, mid_z), Vector3(0.05, 0, STAIRS_TOP_Z - end_z)],
			[Vector3(STAIRS_X, 0, end_z), Vector3(1.7, 0, 0.05)]]:
		_box(g, r[1] + Vector3(0, 0.05, 0), r[0] + Vector3(0, 1.0, 0), STEEL, false)
		var guard := CollisionShape3D.new()
		var gb := BoxShape3D.new()
		gb.size = r[1] + Vector3(0, 1.2, 0)
		guard.shape = gb
		guard.position = r[0] + Vector3(0, 0.6, 0)
		ramp.add_child(guard)
	for z in range(0, 5):
		_box(g, Vector3(0.05, 1.0, 0.05), Vector3(rail_x, 0.5, STAIRS_TOP_Z - z * (STAIRS_TOP_Z - end_z) / 4.0), STEEL, false)
	g.add_child(ramp)
	_box(self, Vector3(0.05, 0.36, 1.3), Vector3(-9.97, 2.6, STAIRS_TOP_Z - 0.8), DARK, false)
	_label(self, "SUBWAY  ↓", Vector3(-9.94, 2.6, STAIRS_TOP_Z - 0.8), PI / 2, 40).modulate = Color(1.0, 0.85, 0.3)
	var lamp := OmniLight3D.new()  # not in Lights/: the light anomalies leave the stairwell alone, like the street
	lamp.position = Vector3(STAIRS_X, -1.0, bottom_z - 1.0)
	lamp.omni_range = 4.5
	lamp.light_energy = 0.6
	lamp.light_color = LIGHT_COLOUR
	g.add_child(lamp)
	# Props/Stairs holds both flights; Extra stays hidden unless anomaly #34 swaps it in.
	var stairs := _node("Stairs", props)
	stairs.position = top
	_model("stairs", stairs, "Normal", Vector3.ZERO)
	_model("stairs_extra", stairs, "Extra", Vector3.ZERO).visible = false

## Inside the two parked trains, seen through the glass screen doors and the coach windows:
## Props/Passengers/<Forward|Opposite> (rush hour), Props/Drivers/<...> (in the front cab of each train),
## Props/CoachDisplays/<...> (destination LED in each coach's middle window). Forward runs -Z, opposite +Z.
func _build_train_insides() -> void:
	var y := -ESC_DROP
	var crowd := _node("Passengers", props)
	var drivers := _node("Drivers", props)
	var displays := _node("CoachDisplays", props)
	var models := ["npc_commuter_a", "npc_commuter_b"]
	# Standing spots in a coach (x across, z along) and which way each faces.
	var spots := [[-0.45, -4.2, 0.4], [0.5, -0.9, 2.6], [-0.3, 1.4, -1.2], [0.4, 5.3, PI]]
	for side in [1, -1]:
		var n := "Forward" if side == 1 else "Opposite"
		var group := _node(n, crowd)
		var screens := _node(n, displays)
		for c in 2:
			var cz: float = [-77.5, -97.8][c]
			for i in spots.size():
				var who := _model(models[(i + c + (1 if side < 0 else 0)) % 2], group, "P%d_%d" % [c, i],
					Vector3(side * 7 + spots[i][0], y, cz + spots[i][1] * side), spots[i][2])
				NpcWalker.play(who, &"Idle", (i * 0.9 + c) * (1.0 if side > 0 else 1.7))
			var lamp := OmniLight3D.new()  # coach lighting; not in Lights/, so the light anomalies leave it alone
			lamp.position = Vector3(side * 7, y + 2.3, cz)
			lamp.omni_range = 7.0
			lamp.light_energy = 0.7
			lamp.light_color = Color(1.0, 0.97, 0.9)
			add_child(lamp)
			# Destination LED board in the top of the middle window on the platform side, facing out.
			_box(screens, Vector3(0.03, 0.3, 1.3), Vector3(side * 5.58, y + 1.58, cz), Color(0.02, 0.02, 0.025), false)
			var led := _label(screens, "", Vector3(side * 5.555, y + 1.58, cz), -PI / 2 if side == 1 else PI / 2, 22)
			led.name = "Display%d" % c
			led.modulate = Color(1.0, 0.35, 0.15)
		# Front cab: a partition with a window, a console and the driver looking ahead.
		var front: float = -107.8 if side == 1 else -67.5
		var cab := _node(n + "Cab", self)
		var wall_z: float = front + 1.6 * side
		for x in [-1.05, 1.05]:
			_box(cab, Vector3(0.9, 2.5, 0.06), Vector3(side * 7 + x, y + 1.25, wall_z), Color(0.75, 0.76, 0.78), false)
		_box(cab, Vector3(1.2, 0.9, 0.06), Vector3(side * 7, y + 2.05, wall_z), Color(0.75, 0.76, 0.78), false)
		_box(cab, Vector3(1.2, 1.0, 0.06), Vector3(side * 7, y + 0.5, wall_z), Color(0.75, 0.76, 0.78), false)
		_box(cab, Vector3(2.4, 1.0, 0.5), Vector3(side * 7, y + 0.5, front + 0.35 * side), DARK, false)
		var cab_lamp := OmniLight3D.new()
		cab_lamp.position = Vector3(side * 7, y + 2.2, front + 0.9 * side)
		cab_lamp.omni_range = 3.0
		cab_lamp.light_energy = 0.9
		cab.add_child(cab_lamp)
		var driver := _node(n, drivers)
		_model("npc_guard", driver, "Model", Vector3(side * 7 + 0.4, y, front + 0.95 * side), 0.0 if side == -1 else PI)
		NpcWalker.play(driver, &"Idle", 0.7)

func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.68, 0.72, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	return m

## Behind the exit gate: a corridor out to a night street. Its lights are not in Lights/, so anomalies leave it alone.
func _build_street() -> void:
	var g := _node("Street", self)
	_box(g, Vector3(3, 0.5, 10), Vector3(0, -0.25, 5.5), FLOOR)
	_box(g, Vector3(3, 0.5, 10), Vector3(0, 3.25, 5.5), CEILING)
	for x in [-1.75, 1.75]:
		_box(g, Vector3(0.5, 3.5, 10), Vector3(x, 1.5, 5.5), WALL)
	var tube := OmniLight3D.new()
	tube.position = Vector3(0, 2.7, 6)
	tube.omni_range = 5
	tube.light_color = LIGHT_COLOUR
	g.add_child(tube)
	_label(g, "EXIT 8  ▶  STREET", Vector3(0, 2.6, 0.6), PI, 40).modulate = Color(0.4, 1.0, 0.5)
	# The street: road, footpath, a sodium lamp, dark buildings with a few lit windows.
	_box(g, Vector3(40, 0.5, 30), Vector3(0, -0.35, 25), Color(0.08, 0.08, 0.09))
	_box(g, Vector3(40, 0.15, 3), Vector3(0, -0.02, 12), Color(0.3, 0.3, 0.3))
	_box(g, Vector3(0.15, 5, 0.15), Vector3(3.5, 2.5, 12.5), DARK)
	_box(g, Vector3(1.2, 0.12, 0.3), Vector3(3.0, 5.0, 12.5), DARK, false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(2.6, 4.8, 12.5)
	lamp.omni_range = 11  # stops short of the concourse: no shadows in Compatibility, so it would shine through the wall
	lamp.light_energy = 2.0
	lamp.light_color = Color(1.0, 0.62, 0.25)
	g.add_child(lamp)
	var night := OmniLight3D.new()  # dim city glow so the buildings read against the sky
	night.position = Vector3(0, 7, 24)
	night.omni_range = 20
	night.light_energy = 0.7
	night.light_color = Color(0.55, 0.6, 0.85)
	g.add_child(night)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.75, 0.4)
	for i in 6:
		var x := -16.0 + i * 6.5
		var h := 8.0 + (i * 5 % 7)
		_box(g, Vector3(5.5, h, 4), Vector3(x, h / 2.0, 30), Color(0.22, 0.21, 0.2), false)
		for j in 3:
			var w := _box(g, Vector3(0.8, 0.9, 0.05), Vector3(x - 1.5 + j * 1.5, 2.5 + (i + j) % 3 * 2.2, 27.97), Color.WHITE, false)
			w.material = glow
	# The whole street width, right at the corridor mouth, so you can't walk around it.
	var out := _area(g, Vector3(40, 3, 1), Vector3(0, 1, 11))
	out.body_entered.connect(func(b): if b is StationPlayer: exit_reached.emit())

func _build_passage() -> void:
	var g := _node("Passage", self)
	_box(g, Vector3(4, 0.5, 20), Vector3(0, -0.25, -30), FLOOR)
	_box(props, Vector3(4, 0.5, 20), Vector3(0, 2.75, -30), CEILING).name = "PassageCeiling"
	_box(g, Vector3(0.5, 3.5, 20), Vector3(-2.25, 1.5, -30), WALL)
	_box(g, Vector3(0.5, 3.5, 20), Vector3(2.25, 1.5, -30), WALL)

func _build_escalator() -> void:
	var g := _node("Escalator", self)
	var tilt := _esc_tilt()
	var mid := Vector3(0, -ESC_DROP / 2.0, -40 - ESC_RUN / 2.0)
	_box(g, Vector3(4, 0.5, _esc_length()), mid + Vector3(0, -0.25, 0), Color(0.45, 0.45, 0.47)).rotation.x = tilt
	_box(g, Vector3(4, 0.5, _esc_length()), mid + Vector3(0, 3.0, 0), CEILING).rotation.x = tilt
	for x in [-2.25, 2.25]:
		_box(g, Vector3(0.5, 4.5, _esc_length()), mid + Vector3(x, 1.75, 0), WALL).rotation.x = tilt
	_box(g, Vector3(6, 3.5, 0.5), Vector3(0, 4.25, -40.25), WALL)  # seals passage/escalator ceiling seam

func _build_platform() -> void:
	var g := _node("Platform", self)
	var y := -ESC_DROP
	_box(g, Vector3(8, 0.5, 50), Vector3(0, y - 0.25, -85), FLOOR)
	_box(g, Vector3(20, 0.5, 50), Vector3(0, y + 3.75, -85), CEILING)
	_box(g, Vector3(20, 6, 0.5), Vector3(0, y + 2, -110.25), WALL)
	_box(g, Vector3(8, 6, 0.5), Vector3(-6, y + 2, -59.75), WALL)
	_box(g, Vector3(8, 6, 0.5), Vector3(6, y + 2, -59.75), WALL)
	_box(g, Vector3(4, 1.5, 0.5), Vector3(0, y + 3.25, -59.75), WALL)
	for z in [-95.0, -104.0]:
		_model("bench", g, "Bench", Vector3(0, y, z), PI / 2, Vector3(0.45, 0.8, 1.7))
	for side in [-1, 1]:
		_box(g, Vector3(6, 0.5, 50), Vector3(side * 7, y - 1.75, -85), CONCRETE)
		for rail in [-0.75, 0.75]:
			_box(g, Vector3(0.08, 0.35, 50), Vector3(side * 7 + rail, y - 1.325, -85), STEEL, false)  # top at coach wheel level
		_box(g, Vector3(0.5, 7, 50), Vector3(side * 10.25, y + 1.5, -85), WALL)
		var stripe := _box(g, Vector3(0.05, 0.4, 50), Vector3(side * 9.98, y + 2.5, -85), Color.WHITE, false)
		stripe.material = _line_mat
		# Glass platform screen doors with one door at z = -85, closed unless the train is the decision point.
		# Glass so you can look into the coaches (passengers, display, driver) before you choose.
		for z in [-71.5, -98.5]:
			_box(g, Vector3(0.12, 2.2, 23), Vector3(side * 4.1, y + 1.1, z), STEEL).material = _glass()
			_box(g, Vector3(0.2, 0.25, 23), Vector3(side * 4.1, y + 0.125, z), STEEL, false)  # kick plate
			_box(g, Vector3(0.2, 0.12, 23), Vector3(side * 4.1, y + 2.2, z), STEEL, false)  # header
			for k in 6:
				_box(g, Vector3(0.14, 2.2, 0.08), Vector3(side * 4.1, y + 1.1, z - 11.5 + k * 4.6), STEEL, false)
		var fill := _box(g, Vector3(0.1, 2.2, 4), Vector3(side * 4.1, y + 1.1, -85), STEEL)
		fill.material = _glass()
		_door_fill.append(fill)
		_box(g, Vector3(1.4, 0.5, 4), Vector3(side * 4.8, y - 0.25, -85), FLOOR)
		# Two coaches (visual only; the choice fires as soon as you step through the door).
		# Coach origin is rail top, floor 1.15 m above it = platform level; a coach door lines up with z = -85.
		for z in [-77.5, -97.8]:
			var coach := _model("train_coach", g, "Coach", Vector3(side * 7, y - 1.15, z))
			for band in coach.find_children("Stripe*", "MeshInstance3D", true, false):
				band.material_override = _line_mat
		for z in [-70.0, -100.0]:
			var pillar := _model("pillar", g, "Pillar", Vector3(side * 2.6, y, z), 0.0, Vector3(0.7, 3.4, 0.7))
			pillar.scale.y = 3.5 / 3.4  # platform ceiling is a touch higher than the concourse
		var forward: bool = side == 1
		_label(g, "FORWARD  ▶" if forward else "◀  OPPOSITE", Vector3(side * 3.95, y + 2.7, -85),
			-PI / 2 if forward else PI / 2, 48)

func _build_props() -> void:
	var signs := _node("Signs", props)
	_label(signs, "", Vector3(0, 3.05, -19.95), 0, 90).name = "ConcourseSign"
	_label(signs, "", Vector3(0, -7.1, -109.95), 0, 110).name = "PlatformSign"
	_number = _label(self, "", Vector3(0, 2.65, -19.95), 0, 40)

	var poster := _node("Poster", props)
	poster.position = Vector3(-9.95, 1.9, -9)
	poster.rotation.y = PI / 2
	_box(poster, Vector3(1.4, 1.9, 0.04), Vector3.ZERO, Color(0.95, 0.9, 0.75), false)
	_box(poster, Vector3(0.3, 0.3, 0.05), Vector3(-0.45, 0.65, 0.01), Color(0.8, 0.1, 0.1), false)
	_label(poster, "SAFE TRAVEL →\nKEEP LEFT\nMIND THE GAP", Vector3(0, -0.2, 0.04), 0, 36).modulate = Color.BLACK
	# The ad model's face. Normally gazing up and to the right; #38 makes the eyes follow you.
	var poster_face := _node("Face", poster)
	poster_face.position = Vector3(0.2, 0.55, 0.022)
	_disc(poster_face, 0.28, Vector3.ZERO, Color(0.82, 0.62, 0.48))
	for x in [-0.1, 0.1]:
		_disc(poster_face, 0.075, Vector3(x, 0.06, 0.004), Color.WHITE)
		var pupil := _disc(poster_face, 0.036, Vector3(x + 0.025, 0.085, 0.008), Color(0.08, 0.06, 0.05))
		pupil.name = "PupilL" if x < 0 else "PupilR"
		pupil.set_meta("centre", Vector3(x, 0.06, 0.008))
	_box(poster_face, Vector3(0.16, 0.025, 0.01), Vector3(0, -0.12, 0.004), Color(0.6, 0.15, 0.15), false)

	# Ad screen on the front wall, right of the passage. The camera-feed anomaly shows you on it instead.
	var ad := _node("AdScreen", props)
	ad.position = Vector3(5.0, 2.2, -19.94)
	_box(ad, Vector3(1.7, 1.0, 0.06), Vector3.ZERO, DARK, false)
	var ad_panel := _node("Ad", ad)
	var glow := _box(ad_panel, Vector3(1.56, 0.86, 0.02), Vector3(0, 0, 0.035), Color(0.1, 0.3, 0.6), false)
	glow.material.emission_enabled = true  # a lit screen, not paper
	glow.material.emission = Color(0.1, 0.3, 0.6)
	_label(ad_panel, "METRO SMART CARD\nRecharge karo · 10% bachao", Vector3(0, 0, 0.05), 0, 22)

	# Rules notice on a stand just ahead of the spawn, angled towards the walking line: teaches loop 1.
	var rules := _node("RulesBoard", props)
	rules.position = Vector3(-2.3, 0, -6.5)
	rules.rotation.y = 0.35
	for x in [-0.7, 0.7]:
		_box(rules, Vector3(0.06, 1.0, 0.06), Vector3(x, 0.5, 0), STEEL)
	_box(rules, Vector3(1.6, 1.3, 0.05), Vector3(0, 1.6, 0), Color(0.95, 0.94, 0.9))
	_box(rules, Vector3(1.6, 0.3, 0.06), Vector3(0, 2.4, 0), Color(0.1, 0.2, 0.45), false)
	_label(rules, Lang.t("notice"), Vector3(0, 2.4, 0.04), 0, 30).name = "Header"
	var text := _label(rules, Lang.t("rules"), Vector3(0, 1.58, 0.03), 0, 18)
	text.name = "Text"
	text.modulate = Color(0.08, 0.08, 0.1)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.width = 1.45 / text.pixel_size  # keep inside the 1.6 m panel

	var ext := _model("fire_extinguisher", props, "FireExtinguisher", Vector3(1.84, 0.35, -28), -PI / 2)
	# Body and dome share one material, so recolouring Body (anomaly #5) recolours both.
	var red: StandardMaterial3D = ext.find_child("Body").get_active_material(0).duplicate()
	for part in ["Body", "Dome"]:
		ext.find_child(part).material_override = red
	_label(self, "FIRE", Vector3(1.99, 1.4, -28), -PI / 2, 32).modulate = Color(0.85, 0.08, 0.08)

	_box(self, Vector3(3.6, 0.7, 0.1), Vector3(0, -7.3, -64.05), DARK, false)
	var board := _label(props, "NEXT TRAIN   2 MIN", Vector3(0, -7.3, -63.98), 0, 48)
	board.name = "NextTrainBoard"
	board.modulate = Color(1.0, 0.7, 0.1)

	# Tactile paving from the spawn to the gates. The middle stretch shares one material.
	var strip := _node("TactileStrip", props)
	var stretch := _node("Stretch", strip)
	var stretch_mat := _mat(YELLOW)
	for i in 12:
		var seg := _box(stretch if i >= 4 and i < 8 else strip, Vector3(0.4, 0.02, 0.9), Vector3(0.75, 0.01, -2.5 - i), YELLOW, false)
		if i >= 4 and i < 8:
			seg.material = stretch_mat
			seg.name = "S%d" % (i - 4)

	var cctv := _node("CCTV", props)
	for i in 2:
		_model("cctv_camera", cctv, "Cam%d" % (i + 1), Vector3(-5.0 + 10.0 * i, 3.4, -17))

	# People (art/build_people.py): rigged, breathing in Idle. Models face +Z; yaw turns them. Off the walking route.
	var people := _node("People", props)
	var body := Vector3(0.5, 1.7, 0.4)
	var spots := [["npc_guard", "Guard", Vector3(5.5, 0, -14.4), 0.0],
		["npc_sweeper", "Sweeper", Vector3(-6.0, 0, -11.0), 0.6],
		["npc_commuter_a", "CommuterA", Vector3(-2.2, -ESC_DROP, -80.0), -PI / 2],
		["npc_commuter_b", "CommuterB", Vector3(2.0, -ESC_DROP, -91.0), PI]]
	for i in spots.size():
		var who := _model(spots[i][0], people, spots[i][1], spots[i][2], spots[i][3], body)
		NpcWalker.play(who, &"Idle", i * 1.3)  # out of step with each other
	# A commuter pacing the right side of the concourse.
	var walker := NpcWalker.new()
	walker.name = "Walker"
	props.add_child(walker)
	_model("npc_commuter_a", walker, "Model", Vector3.ZERO, 0.0, body)
	walker.setup(Vector3(7.2, 0, -2.5), Vector3(7.2, 0, -12.5))
	_model("dustbin", props, "Dustbin", Vector3(8.6, 0, -7), -PI / 2, Vector3(0.6, 0.9, 0.6))
	var tvm := TokenMachine.new()
	tvm.name = "TokenMachine"
	tvm.position = Vector3(-9.65, 0, -4)
	tvm.rotation.y = PI / 2
	props.add_child(tvm)
	_model("token_machine", tvm, "Model", Vector3.ZERO, 0.0, Vector3(0.8, 1.8, 0.6))
	tvm.dim_screen()

	_box(self, Vector3(2.6, 0.32, 0.05), Vector3(0, 2.2, -36.05), DARK, false)
	var plat := _label(props, "PLATFORM 1 & 2  ↓", Vector3(0, 2.2, -36.0), 0, 36)
	plat.name = "PlatformNumber"
	plat.modulate = Color(1.0, 0.85, 0.3)

	_box(self, Vector3(0.05, 0.4, 1.6), Vector3(9.97, 2.2, -10), Color(0.05, 0.25, 0.1), false)
	var exit_arrow := _label(props, "EXIT  →", Vector3(9.93, 2.2, -10), -PI / 2, 48)
	exit_arrow.name = "ExitArrow"
	exit_arrow.modulate = Color(0.4, 1.0, 0.5)

	var cooler := _node("WaterCooler", props)
	cooler.position = Vector3(-9.6, 0, -14)
	_model("water_cooler", cooler, "Model", Vector3.ZERO, PI / 2, Vector3(0.45, 1.05, 0.5))
	var puddle := CSGCylinder3D.new()
	puddle.name = "Puddle"
	puddle.radius = 0.5
	puddle.height = 0.01
	puddle.position = Vector3(0.6, 0.01, 0)
	puddle.material = _mat(Color(0.25, 0.4, 0.6))
	puddle.visible = false
	cooler.add_child(puddle)
	# Flood water (#42): hidden at the bottom of the track pits until the anomaly raises it.
	var flood := _box(props, Vector3(20, 0.05, 50), Vector3(0, -ESC_DROP - 1.45, -85), Color(0.07, 0.09, 0.08), false)
	flood.name = "Flood"
	flood.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flood.material.albedo_color.a = 0.85
	flood.material.roughness = 0.05
	flood.visible = false

	var clock := _node("Clock", props)
	clock.position = Vector3(-4.5, 2.3, -19.97)
	clock.set_meta("dir", 1.0)
	var face := _model("wall_clock", clock, "Model", Vector3.ZERO)
	face.find_child("Hand_Hour").rotation.z = -TAU * (10.0 + 8.0 / 60.0) / 12.0  # 10:08
	face.find_child("Hand_Minute").rotation.z = -TAU * 8.0 / 60.0
	_second_hand = face.find_child("Hand_Second")

	var gap := _node("MindTheGap", props)
	gap.position = Vector3(3.35, -9.99, -81)
	_box(gap, Vector3(1.1, 0.01, 0.35), Vector3.ZERO, YELLOW, false)
	var gap_text := _label(gap, "MIND THE GAP", Vector3(0, 0.01, 0), 0, 24)
	gap_text.rotation.x = -PI / 2
	gap_text.modulate = Color.BLACK

	var lift := _node("Lift", props)
	lift.position = Vector3(9.9, 0, -14)
	_model("lift_doors", lift, "Model", Vector3.ZERO, -PI / 2)
	_label(lift, "LIFT", Vector3(-0.1, 2.6, 0), -PI / 2, 36)

	var phone := _node("PhoneSpot", props)
	phone.position = Vector3(-1.95, 1.2, -31)

	var door := _node("StaffDoor", props)
	door.position = Vector3(-1.97, 0, -34)
	door.visible = false
	_box(door, Vector3(0.06, 2.1, 1.0), Vector3(0, 1.05, 0), Color(0.3, 0.2, 0.12), false)
	_box(door, Vector3(0.04, 0.05, 0.12), Vector3(0.05, 1.0, 0.35), STEEL, false)

	var steps := _node("EscalatorSteps", props)
	steps.set_meta("speed", 0.6)
	for i in ESC_STEPS:
		var s := _box(steps, Vector3(3.6, 0.03, 0.1), Vector3.ZERO, Color(0.2, 0.2, 0.2), false)
		s.rotation.x = _esc_tilt()

	var boards := _node("TrainBoards", props)
	var fwd := _label(boards, "", Vector3(5.47, -8.3, -85), -PI / 2, 40)
	fwd.name = "Forward"
	fwd.modulate = Color(1.0, 0.55, 0.1)
	var opp := _label(boards, "TERMINUS  ◀", Vector3(-5.47, -8.3, -85), PI / 2, 40)
	opp.name = "Opposite"
	opp.modulate = Color(1.0, 0.55, 0.1)

	var flaps := _node("GateFlaps", props)
	flaps.set_meta("always_open", false)
	for x in [-2.25, -0.75, 0.75, 2.25]:
		var gate := _node("Gate", flaps)
		gate.position = Vector3(x, 0, -16)
		for side in [-1, 1]:
			_box(gate, Vector3(0.45, 0.5, 0.04), Vector3(side * 0.3, 0.75, 0), Color(0.75, 0.15, 0.15), false)

func _build_lights() -> void:
	lights.set_meta("flicker", true)
	var spots := [Vector3(0, 3.2, -5), Vector3(0, 3.2, -14), Vector3(0, 2.3, -30), Vector3(0, -2.6, -50),
			Vector3(0, -6.8, -68), Vector3(0, -6.8, -85), Vector3(0, -6.8, -102),
			Vector3(-8.8, 2.9, -9), Vector3(8.8, 2.9, -11)]  # L7 lights the poster, L8 the lift wall
	for i in spots.size():
		var l := OmniLight3D.new()
		l.name = "L%d" % i
		l.position = spots[i]
		l.omni_range = 9
		l.light_energy = 1.0
		l.light_color = LIGHT_COLOUR
		lights.add_child(l)

## Each decision point: a yellow floor sticker where it arms, then "forward" and "back" trigger zones.
func _build_decisions() -> void:
	var y := -ESC_DROP
	# Train: the doors are the choice (forward = right door).
	_stickers[&"train"] = _sticker(Vector3(0, y + 0.01, -85), Vector3(7.8, 0.01, 1.2))
	for side in [-1, 1]:
		_dp_area(&"train", &"forward" if side == 1 else &"back", Vector3(1.0, 2, 3.6), Vector3(side * 4.9, y + 1, -85))
	# Gates: reach the gates, then go through (forward) or turn back to the concourse.
	_stickers[&"gates"] = _sticker(Vector3(0, 0.01, -14.4), Vector3(19.5, 0.01, 1.0))
	_dp_area(&"gates", &"arm", Vector3(20, 2, 1.5), Vector3(0, 1, -14.5))
	_dp_area(&"gates", &"forward", Vector3(20, 2, 1), Vector3(0, 1, -18.5))
	# Walking forward through the gates with a token in hand: the reader takes it.
	var reader := _area(self, Vector3(6, 2, 0.6), Vector3(0, 1, -16))
	var beep := AudioStreamPlayer3D.new()
	beep.stream = SynthAudio.chime()
	beep.bus = Atmosphere.BUS
	beep.pitch_scale = 2.5  # short reader beep, not the PA chime
	reader.add_child(beep)
	reader.body_entered.connect(func(b):
		if b is StationPlayer and b.tokens > 0 and b.velocity.z < 0.0:
			b.tokens -= 1
			beep.play())
	_dp_area(&"gates", &"back", Vector3(20, 2, 1), Vector3(0, 1, -9))
	# Escalator: at the bottom, walk on to the platform (forward) or ride back up.
	_stickers[&"escalator"] = _sticker(Vector3(0, y + 0.01, -61.2), Vector3(3.9, 0.01, 1.0))
	_dp_area(&"escalator", &"arm", Vector3(4, 2, 1.5), Vector3(0, y + 1, -61.2))
	_dp_area(&"escalator", &"forward", Vector3(8, 2, 1), Vector3(0, y + 1, -66))
	_dp_area(&"escalator", &"back", Vector3(4, 4, 1), Vector3(0, -5.5, -51))
	set_decision(&"train")

func _dp_area(dp: StringName, role: StringName, size: Vector3, pos: Vector3) -> void:
	var a := _area(self, size, pos)
	a.body_entered.connect(func(b):
		if not (b is StationPlayer) or decision != dp:
			return
		if role == &"arm":
			_armed = true
		elif _armed:
			_armed = false
			decided.emit(role == &"back"))

func _sticker(pos: Vector3, size: Vector3) -> Node3D:
	var s := _node("Sticker", self)
	s.position = pos
	_box(s, size, Vector3.ZERO, YELLOW, false)
	var t := _label(s, "DECISION POINT", Vector3(0, 0.01, 0), 0, 48)
	t.rotation.x = -PI / 2
	t.modulate = Color.BLACK
	return s

# ── Helpers ───────────────────────────────────────────────────────────────

func _esc_length() -> float:
	return Vector2(ESC_RUN, ESC_DROP).length()

func _esc_tilt() -> float:
	return -atan2(ESC_DROP, ESC_RUN)

## Point on the escalator surface, s metres down from the top.
func _esc_point(s: float) -> Vector3:
	var down := Vector3(0, -ESC_DROP, -ESC_RUN).normalized()
	return Vector3(0, 0.03, -40) + down * s

## Instance a prop from art/build_props.py. solid = optional box collider (size, sitting on the floor).
func _model(file: String, parent: Node, n: String, pos: Vector3, yaw := 0.0, solid := Vector3.ZERO) -> Node3D:
	var m: Node3D = load(MODELS % file).instantiate()
	m.name = n
	m.position = pos
	m.rotation.y = yaw
	parent.add_child(m)
	if solid != Vector3.ZERO:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = solid
		shape.shape = box
		shape.position.y = solid.y / 2.0
		body.add_child(shape)
		m.add_child(body)
	return m

func _node(n: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node

func _mat(c: Color) -> StandardMaterial3D:
	if SURFACES.has(c):
		return _surface(c)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

## One shared, world-space tiled material per surface type, so walls line up across separate boxes.
func _surface(c: Color) -> StandardMaterial3D:
	if not _surface_mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://game/assets/textures/%s.png" % SURFACES[c][0])
		m.albedo_color = SURFACES[c][1]
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / TILE_METRES
		m.roughness = 0.6 if c == FLOOR else 0.85
		_surface_mats[c] = m
	return _surface_mats[c]

func _box(parent: Node, size: Vector3, pos: Vector3, c: Color, collide := true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.use_collision = collide
	b.material = _mat(c)
	parent.add_child(b)
	return b

## Flat disc facing +Z (posters).
func _disc(parent: Node, radius: float, pos: Vector3, c: Color) -> CSGCylinder3D:
	var d := CSGCylinder3D.new()
	d.radius = radius
	d.height = 0.004
	d.sides = 24
	d.position = pos
	d.rotation.x = PI / 2
	d.material = _mat(c)
	parent.add_child(d)
	return d

func _label(parent: Node, text: String, pos: Vector3, yaw: float, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation.y = yaw
	l.font_size = size
	l.outline_size = 0
	parent.add_child(l)
	return l

func _area(parent: Node, size: Vector3, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	a.add_child(shape)
	parent.add_child(a)
	return a
