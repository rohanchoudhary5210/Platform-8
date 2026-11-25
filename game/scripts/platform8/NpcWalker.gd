class_name NpcWalker
extends Node3D

## A commuter pacing between two points: walk, pause, turn, walk back. Meta "frozen" stops him mid-step
## (anomaly #45). The model is a child built by Station (art/build_people.py, front is +Z).

const SPEED := 1.15  # matches the Walk cycle's stride, so the feet don't slide
const PAUSE := 1.5

var a: Vector3
var b: Vector3

var _to_b := true
var _wait := 0.0

func _ready() -> void:
	set_meta("frozen", false)

func setup(from: Vector3, to: Vector3) -> void:
	a = from
	b = to
	position = from
	_face(to)
	NpcWalker.play(self, &"Walk")

func _process(delta: float) -> void:
	if get_meta("frozen"):
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_face(b if _to_b else a)
			NpcWalker.play(self, &"Walk")
		return
	var target := b if _to_b else a
	var step := SPEED * delta
	if position.distance_to(target) <= step:
		position = target
		_to_b = not _to_b
		_wait = PAUSE
		NpcWalker.play(self, &"Idle")
	else:
		position = position.move_toward(target, step)

func _face(target: Vector3) -> void:
	var d := target - position
	rotation.y = atan2(d.x, d.z)

## Plays a looping animation on any person model under `who` (Idle or Walk).
static func play(who: Node, anim: StringName, offset := 0.0) -> void:
	for ap: AnimationPlayer in who.find_children("*", "AnimationPlayer", true, false):
		if ap.current_animation == anim:
			continue
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim, 0.25)
		if offset > 0.0:
			ap.seek(offset, true)
