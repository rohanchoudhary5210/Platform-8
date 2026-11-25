class_name TokenMachine
extends Node3D

## Token vending machine on the concourse's left wall. Look at it and press E: a token drops into the tray.
## Model: art/build_props.py token_machine (front is local +Z). Anomaly #23 makes it dispense on its own.

const PROMPT := "[E]  Buy token  ·  ₹ 20"
const TRAY_SIZE := 5  # after this, tokens spill onto the floor
const SLOT := Vector3(0, 0.5, 0.31)
const TRAY := Vector3(0, 0.45, 0.33)
## Tokens sit on their own physics layer: the look-ray sees them, the player's body walks over them.
const TOKEN_LAYER := 1 << 7

## One dispensed token. Look at it and press E to pick it up.
class Token extends MeshInstance3D:
	func _init() -> void:
		var body := StaticBody3D.new()
		body.collision_layer = TOKEN_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.07  # bigger than the token so it's easy to aim at
		shape.shape = ball
		body.add_child(shape)
		add_child(body)

	func prompt() -> String:
		return "[E]  Take token"

	func interact(by: Node) -> void:
		by.tokens += 1
		get_parent().remove_child(self)
		queue_free()

var screen: Label3D
var tokens := Node3D.new()

var _clunk := AudioStreamPlayer3D.new()
var _mesh := CylinderMesh.new()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	tokens.name = "Tokens"
	add_child(tokens)
	screen = Label3D.new()
	screen.name = "Display"
	screen.position = Vector3(0, 1.3, 0.32)
	screen.font_size = 14
	screen.pixel_size = 0.002
	screen.modulate = Color(0.6, 0.9, 1.0)
	screen.position.z += 0.005  # just in front of the model's screen
	add_child(screen)
	_clunk.stream = SynthAudio.clunk()
	_clunk.bus = Atmosphere.BUS
	_clunk.volume_db = -8.0
	_clunk.position = SLOT
	add_child(_clunk)
	_mesh.top_radius = 0.032  # a touch oversized so a pile reads from a few metres away
	_mesh.bottom_radius = 0.032
	_mesh.height = 0.008
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.45, 0.7)  # blue plastic metro token
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = Color(0.05, 0.25, 0.45)
	_mesh.material = m
	set_route("", "")

## The model's emissive screen glows white in Compatibility; a dim panel keeps the text readable.
func dim_screen() -> void:
	var panel: MeshInstance3D = find_child("Screen", true, false)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.08, 0.12)
	m.emission_enabled = true
	m.emission = Color(0.05, 0.2, 0.3)
	panel.material_override = m

## Called on every arrival; also empties the tray (the station resets each loop).
func set_route(from: String, to: String) -> void:
	screen.text = "SELECT DESTINATION\n%s  →  %s\n₹ 20   ·   PRESS E" % [from.to_upper(), to.to_upper()]
	clear_tokens()

func interact(_by: Node) -> void:
	dispense()

func prompt() -> String:
	return PROMPT

## Drops one token: into the tray, or onto the floor once the tray is full.
func dispense() -> void:
	var t := Token.new()
	t.mesh = _mesh
	t.position = SLOT
	tokens.add_child(t)
	var n := tokens.get_child_count()
	var to := TRAY + Vector3(_rng.randf_range(-0.1, 0.1), 0.01 * n, 0)
	if n > TRAY_SIZE:
		to = Vector3(_rng.randf_range(-0.6, 0.6), 0.005, _rng.randf_range(0.4, 1.3))
	t.create_tween().tween_property(t, "position", to, 0.25 if n <= TRAY_SIZE else 0.5)
	_clunk.pitch_scale = _rng.randf_range(1.6, 2.2)  # small and plasticky, not the lights' heavy clunk
	_clunk.play()

func clear_tokens() -> void:
	for t in tokens.get_children():
		tokens.remove_child(t)
		t.free()
