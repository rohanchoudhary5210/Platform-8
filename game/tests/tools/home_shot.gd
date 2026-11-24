extends SceneTree
## Dev tool: renders the title screen with a sample save to user://shots/home.png. Run without --headless.
func _initialize() -> void:
	var s := SaveData.new()
	s.path = "user://shot_save.cfg"
	for d in AnomalyCatalog.ALL.slice(0, 9):
		s.found[String(d.id)] = true
	s.best_station = 6
	s.clears = 2
	s.best_time = 431.0
	s.write()
	var home: Node = load("res://game/scenes/Home/Home.tscn").instantiate()
	home.save_path = s.path
	root.add_child(home)
	home.build_lost_and_found(SaveData.open(s.path))  # no ServiceRegistry here, so _on_ready never runs
	for i in 5:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	root.get_viewport().get_texture().get_image().save_png("user://shots/home.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	quit()
