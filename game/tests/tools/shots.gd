extends SceneTree
## Dev tool: renders a few views of the station to user://shots/. Run without --headless.
func _initialize() -> void:
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.loop.decision = &"gates"
	game.station.set_decision(&"gates")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var views := {
		"spawn": [Vector3(0, 1, -3), 0.0], "back_exit": [Vector3(0, 1, -6), PI],
		"poster": [Vector3(-4, 1, -9), PI / 2], "passage": [Vector3(0, 1, -22), 0.0],
		"escalator": [Vector3(0, 1, -38), 0.0], "platform": [Vector3(0, -9, -62), 0.0],
		"doors": [Vector3(0, -9, -85), -PI / 2],
		"right_wall": [Vector3(4, 1, -11), -PI / 2], "front_wall": [Vector3(-3, 1, -10), 0.0],
		"esc_bottom": [Vector3(0, -9, -57), PI],
	}
	for k in views:
		game.player.place(Transform3D(Basis(Vector3.UP, views[k][1]), views[k][0]))
		game.player.active = false
		for i in 5:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % k)
	game.train.ride("Roshanpura", 100.0)
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://shots/train.png")
	print(ProjectSettings.globalize_path("user://shots"))
	quit()
