class_name Station
extends Node3D

## Greybox station, same layout every loop: concourse → AFC gates → passage → escalator → platform.
## Only identity (name, number, line colour) changes. Anomalies change nodes under Props/ and Lights/.
## Player walks -Z. Right train (+X) = forward, left train (-X) = opposite.

signal boarded(took_opposite: bool)
signal exit_reached

const WALL := Color(0.5, 0.5, 0.46)
const FLOOR := Color(0.32, 0.32, 0.34)
const DARK := Color(0.12, 0.12, 0.13)
const LIGHT_COLOUR := Color(0.82, 1.0, 0.86)  # tired fluorescent tubes
const ESC_DROP := 10.0
const ESC_RUN := 20.0

var spawn: Marker3D
var props: Node3D
var lights: Node3D

var _line_mat := StandardMaterial3D.new()
var _number: Label3D
var _exit_barrier: CSGBox3D
var _exit_label: Label3D
var _flicker_wait := 0.0

func _ready() -> void:
	props = _node("Props", self)
	lights = _node("Lights", self)
	_build_concourse()
	_build_passage()
	_build_escalator()
	_build_platform()
	_build_props()
	_build_lights()

## Called at the start of every loop, before an anomaly is applied.
func show_station(station_name: String, count: int, line_colour: Color) -> void:
	for sign in props.get_node("Signs").get_children():
		sign.text = station_name.to_upper()
	_number.text = "STATION %d / 8" % count
	_line_mat.albedo_color = line_colour

func set_exit_open(open: bool) -> void:
	_exit_barrier.use_collision = not open
	_exit_barrier.visible = not open
	_exit_label.text = "EXIT" if open else "EXIT CLOSED"

## State of everything an anomaly may touch. Used by tests to prove revert() is exact.
func snapshot() -> Dictionary:
	var s := {}
	for n in props.find_children("*", "", true, false) + lights.get_children():
		var k := str(get_path_to(n))
		if n is Node3D:
			s[k + ":xf"] = n.transform
			s[k + ":visible"] = n.visible
		if n is Label3D:
			s[k + ":text"] = n.text
			s[k + ":modulate"] = n.modulate
		if n is OmniLight3D:
			s[k + ":light"] = [n.light_color, n.light_energy]
		if n is CSGShape3D and n.material:
			s[k + ":albedo"] = n.material.albedo_color
	return s

# ── Layout ────────────────────────────────────────────────────────────────

func _build_concourse() -> void:
	var g := _node("Concourse", self)
	_box(g, Vector3(20, 0.5, 20), Vector3(0, -0.25, -10), FLOOR)
	_box(g, Vector3(20, 0.5, 20), Vector3(0, 3.65, -10), WALL)
	_box(g, Vector3(0.5, 4.5, 20), Vector3(-10.25, 2, -10), WALL)
	_box(g, Vector3(0.5, 4.5, 20), Vector3(10.25, 2, -10), WALL)
	# Back wall with the exit gap behind the spawn.
	_box(g, Vector3(8.5, 4.5, 0.5), Vector3(-5.75, 2, 0.25), WALL)
	_box(g, Vector3(8.5, 4.5, 0.5), Vector3(5.75, 2, 0.25), WALL)
	_exit_barrier = _box(g, Vector3(3, 4.5, 0.5), Vector3(0, 2, 0.25), DARK)
	_exit_label = _label(g, "EXIT CLOSED", Vector3(0, 2.9, -0.05), PI, 64)
	_box(g, Vector3(3, 0.5, 3), Vector3(0, -0.25, 1.5), FLOOR)
	var exit_area := _area(g, Vector3(3, 2, 1), Vector3(0, 1, 2))
	exit_area.body_entered.connect(func(b): if b is StationPlayer: exit_reached.emit())
	# Front wall with the passage opening.
	_box(g, Vector3(8, 4.5, 0.5), Vector3(-6, 2, -20.25), WALL)
	_box(g, Vector3(8, 4.5, 0.5), Vector3(6, 2, -20.25), WALL)
	_box(g, Vector3(4, 1, 0.5), Vector3(0, 2.95, -20.25), WALL)
	# Line colour stripe.
	for x in [-9.98, 9.98]:
		var stripe := _box(g, Vector3(0.05, 0.3, 20), Vector3(x, 1.2, -10), Color.WHITE, false)
		stripe.material = _line_mat
	# AFC gates: cabinets with gaps, railings either side.
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		_box(g, Vector3(0.35, 1.0, 1.4), Vector3(x, 0.5, -16), Color(0.75, 0.75, 0.78))
	_box(g, Vector3(6.4, 1.0, 0.1), Vector3(-6.7, 0.5, -16), DARK)
	_box(g, Vector3(6.4, 1.0, 0.1), Vector3(6.7, 0.5, -16), DARK)
	spawn = Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 1.0, -3)
	add_child(spawn)

func _build_passage() -> void:
	var g := _node("Passage", self)
	_box(g, Vector3(4, 0.5, 20), Vector3(0, -0.25, -30), FLOOR)
	_box(g, Vector3(4, 0.5, 20), Vector3(0, 2.75, -30), WALL)
	_box(g, Vector3(0.5, 3.5, 20), Vector3(-2.25, 1.5, -30), WALL)
	_box(g, Vector3(0.5, 3.5, 20), Vector3(2.25, 1.5, -30), WALL)

func _build_escalator() -> void:
	var g := _node("Escalator", self)
	var length := Vector2(ESC_RUN, ESC_DROP).length()
	var tilt := -atan2(ESC_DROP, ESC_RUN)
	var mid := Vector3(0, -ESC_DROP / 2.0, -40 - ESC_RUN / 2.0)
	_box(g, Vector3(4, 0.5, length), mid + Vector3(0, -0.25, 0), Color(0.45, 0.45, 0.47)).rotation.x = tilt
	_box(g, Vector3(4, 0.5, length), mid + Vector3(0, 3.0, 0), WALL).rotation.x = tilt
	for x in [-2.25, 2.25]:
		_box(g, Vector3(0.5, 4.5, length), mid + Vector3(x, 1.75, 0), WALL).rotation.x = tilt
	_box(g, Vector3(6, 3.5, 0.5), Vector3(0, 4.25, -40.25), WALL)  # seals passage/escalator ceiling seam

func _build_platform() -> void:
	var g := _node("Platform", self)
	var y := -ESC_DROP
	_box(g, Vector3(8, 0.5, 50), Vector3(0, y - 0.25, -85), FLOOR)
	_box(g, Vector3(20, 0.5, 50), Vector3(0, y + 3.75, -85), WALL)
	_box(g, Vector3(20, 6, 0.5), Vector3(0, y + 2, -110.25), WALL)
	_box(g, Vector3(8, 6, 0.5), Vector3(-6, y + 2, -59.75), WALL)
	_box(g, Vector3(8, 6, 0.5), Vector3(6, y + 2, -59.75), WALL)
	_box(g, Vector3(4, 1.5, 0.5), Vector3(0, y + 3.25, -59.75), WALL)
	for side in [-1, 1]:
		_box(g, Vector3(6, 0.5, 50), Vector3(side * 7, y - 1.75, -85), DARK)
		_box(g, Vector3(0.5, 7, 50), Vector3(side * 10.25, y + 1.5, -85), WALL)
		var stripe := _box(g, Vector3(0.05, 0.4, 50), Vector3(side * 9.98, y + 2.5, -85), Color.WHITE, false)
		stripe.material = _line_mat
		# Platform screen doors with one open door at z = -85.
		_box(g, Vector3(0.2, 2.2, 23), Vector3(side * 4.1, y + 1.1, -71.5), Color(0.7, 0.75, 0.8))
		_box(g, Vector3(0.2, 2.2, 23), Vector3(side * 4.1, y + 1.1, -98.5), Color(0.7, 0.75, 0.8))
		_box(g, Vector3(1.4, 0.5, 4), Vector3(side * 4.8, y - 0.25, -85), FLOOR)
		# Train body (visual only; boarding fires as soon as you step through the door).
		_box(g, Vector3(3, 3.6, 40), Vector3(side * 7, y + 0.6, -85), Color(0.78, 0.8, 0.83), false)
		var forward: bool = side == 1
		var door := _area(g, Vector3(1.0, 2, 3.6), Vector3(side * 4.9, y + 1, -85))
		door.body_entered.connect(func(b): if b is StationPlayer: boarded.emit(not forward))
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

	var ext := CSGCylinder3D.new()
	ext.name = "FireExtinguisher"
	ext.radius = 0.13
	ext.height = 0.6
	ext.position = Vector3(1.85, 0.6, -28)
	ext.material = _mat(Color(0.85, 0.08, 0.08))
	props.add_child(ext)
	_label(self, "FIRE", Vector3(1.99, 1.4, -28), -PI / 2, 32).modulate = Color(0.85, 0.08, 0.08)

	var board_back := _box(self, Vector3(3.6, 0.7, 0.1), Vector3(0, -7.3, -64.05), DARK, false)
	board_back.name = "NextTrainBoardBack"
	var board := _label(props, "NEXT TRAIN   2 MIN", Vector3(0, -7.3, -63.98), 0, 48)
	board.name = "NextTrainBoard"
	board.modulate = Color(1.0, 0.7, 0.1)

func _build_lights() -> void:
	for p in [Vector3(0, 3.2, -5), Vector3(0, 3.2, -14), Vector3(0, 2.3, -30), Vector3(0, -2.6, -50),
			Vector3(0, -6.8, -68), Vector3(0, -6.8, -85), Vector3(0, -6.8, -102),
			Vector3(-8.8, 2.9, -9)]:  # last one lights the poster
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 9
		l.light_energy = 1.0
		l.light_color = LIGHT_COLOUR
		lights.add_child(l)

# ── Helpers ───────────────────────────────────────────────────────────────

func _node(n: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

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

## The tube over the train doors flickers every loop. Toggles visible only, so the red-light anomaly still tints it.
func _process(delta: float) -> void:
	_flicker_wait -= delta
	if _flicker_wait > 0.0:
		return
	var l: OmniLight3D = lights.get_child(5)
	l.visible = not l.visible
	# Mostly on, with short bursts of dropouts.
	_flicker_wait = randf_range(0.03, 0.12) if not l.visible or randf() < 0.4 else randf_range(1.5, 5.0)
