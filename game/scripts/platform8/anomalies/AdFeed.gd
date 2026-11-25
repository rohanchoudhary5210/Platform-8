extends Anomaly
## The ad screen shows a live camera view of you from behind: a dark figure standing where you stand,
## looking at the screen. Slot: Props/AdScreen.

const FIGURE_LAYER := 1 << 19  # only the feed camera renders it, so you never see your own body
const BEHIND := 2.0
const ABOVE := 1.4  # above the player's origin (about 0.9 m off the floor)

var _view: SubViewport
var _screen: MeshInstance3D
var _figure: MeshInstance3D
var _mask := 0
var _tick: Callable

func apply(slot: Node) -> void:
	var p := player_of(slot)
	slot.get_node("Ad").visible = false
	_view = SubViewport.new()
	_view.size = Vector2i(384, 216)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = 60.0
	_view.add_child(cam)
	slot.add_child(_view)
	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.56, 0.86)
	_screen.mesh = quad
	_screen.position.z = 0.035
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _view.get_texture()
	mat.albedo_color = Color(0.75, 0.95, 0.8)  # CCTV green
	_screen.material_override = mat
	slot.add_child(_screen)
	if p:
		_figure = MeshInstance3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.25
		body.height = 1.75
		_figure.mesh = body
		_figure.layers = FIGURE_LAYER
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.05, 0.05, 0.06)
		_figure.material_override = dark
		p.add_child(_figure)
		_mask = p.camera.cull_mask
		p.camera.cull_mask &= ~FIGURE_LAYER
	_tick = func():
		if p == null:
			return
		var back := p.camera.global_basis.z
		back.y = 0.0
		cam.global_position = p.global_position + back.normalized() * BEHIND + Vector3.UP * ABOVE
		cam.look_at(p.global_position + Vector3.UP * 0.6)
	_tick.call()
	slot.get_tree().process_frame.connect(_tick)

func revert(slot: Node) -> void:
	slot.get_tree().process_frame.disconnect(_tick)
	if _figure:
		player_of(slot).camera.cull_mask = _mask
		_figure.free()
	_screen.free()
	_view.free()
	slot.get_node("Ad").visible = true
