extends SceneTree
func _initialize() -> void:
	for n in ["fire_extinguisher", "afc_gate", "cctv_camera", "water_cooler"]:
		var s: Node = load("res://game/assets/models/%s.gltf" % n).instantiate()
		_dump(s, "")
		s.free()
	quit()
func _dump(n: Node, ind: String) -> void:
	var extra := ""
	if n is MeshInstance3D:
		extra = " mat=" + str(n.mesh.surface_get_material(0).resource_name) + " pos=" + str(n.position)
	print(ind, n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_dump(c, ind + "  ")
