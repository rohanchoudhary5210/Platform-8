extends SceneTree
## Dev tool: escalator views (top, riding, from the bottom) to user://shots/esc_*.png. Run without --headless.
func _initialize() -> void:
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	game.save_path = "user://shot_save.cfg"
	root.add_child(game)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var views := {  # position, yaw, pitch
		"esc_top": [Vector3(0.95, 1, -38.6), 0.0, -0.4], "esc_ride": [Vector3(0.95, -3.0, -46.5), 0.15, -0.3],
		"esc_side": [Vector3(-0.95, -2.2, -45.5), -0.9, -0.25], "esc_up": [Vector3(0.95, -9, -63.5), PI, 0.35],
	}
	for k in views:
		game.player.place(Transform3D(Basis(Vector3.UP, views[k][1]), views[k][0]))
		game.player.head.rotation.x = views[k][2]
		game.player.active = false
		for i in 8:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % k)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_save.cfg"))
	quit()
