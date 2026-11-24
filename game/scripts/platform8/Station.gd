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
const FLICKER_LIGHT := "L5"  # the tube over the train doors
const MODELS := "res://game/assets/models/%s.gltf"  # built by art/build_props.py
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
	_build_decisions()

## Called at the start of every loop, before an anomaly is applied.
func show_station(station_name: String, count: int, line_colour: Color, next_name: String) -> void:
	for sign in props.get_node("Signs").get_children():
		sign.text = station_name.to_upper()
	_number.text = "STATION %d / 8" % count
	_line_mat.albedo_color = line_colour
	props.get_node("TrainBoards/Forward").text = "▶  " + next_name.to_upper()
	props.get_node("TokenMachine").set_route(station_name, next_name)

func set_exit_open(open: bool) -> void:
	_exit_barrier.use_collision = not open
	_exit_barrier.visible = not open
	_exit_label.text = "EXIT" if open else "EXIT CLOSED"

## Which decision point is live this loop: &"train", &"escalator" or &"gates".
func set_decision(dp: StringName) -> void:
	decision = dp
	_armed = dp == &"train"  # the train doors are the choice itself; the others arm when you reach them
	for k in _stickers:
		_stickers[k].visible = k == dp
	for f in _door_fill:
		f.visible = dp != &"train"
		f.use_collision = dp != &"train"

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
	_box(g, Vector3(20, 0.5, 20), Vector3(0, -0.25, -10), FLOOR)
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
		# Platform screen doors with one door at z = -85, closed unless the train is the decision point.
		_box(g, Vector3(0.2, 2.2, 23), Vector3(side * 4.1, y + 1.1, -71.5), STEEL)
		_box(g, Vector3(0.2, 2.2, 23), Vector3(side * 4.1, y + 1.1, -98.5), STEEL)
		_door_fill.append(_box(g, Vector3(0.12, 2.2, 4), Vector3(side * 4.1, y + 1.1, -85), Color(0.55, 0.6, 0.65)))
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

	# People (art/build_props.py NPCS). Models face +Z; yaw turns them. Kept off the walking route.
	var people := _node("People", props)
	var body := Vector3(0.5, 1.7, 0.4)
	_model("npc_guard", people, "Guard", Vector3(5.5, 0, -14.4), 0.0, body)
	_model("npc_sweeper", people, "Sweeper", Vector3(-6.0, 0, -11.0), 0.6, body)
	_model("npc_commuter_a", people, "CommuterA", Vector3(-2.2, -ESC_DROP, -80.0), -PI / 2, body)
	_model("npc_commuter_b", people, "CommuterB", Vector3(2.0, -ESC_DROP, -91.0), PI, body)
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
