extends SceneTree
## Dev tool: renders a few views of the station to user://shots/. Run without --headless.
func _initialize() -> void:
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._pause.get_child(-1).set_process_unhandled_input(false)  # a stray Esc while the window pops up must not pause the shots
	game.loop.decision = &"gates"
	game.station.set_decision(&"gates")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var views := {
		"spawn": [Vector3(0, 1, -3), 0.0], "rules": [Vector3(-0.6, 1, -4.5), 0.35], "back_exit": [Vector3(0, 1, -6), PI],
		"poster": [Vector3(-4, 1, -9), PI / 2], "ad_screen": [Vector3(4, 1, -16), 0.0], "passage": [Vector3(0, 1, -22), 0.0],
		"escalator": [Vector3(0, 1, -38), 0.0], "platform": [Vector3(0, -9, -62), 0.0],
		"doors": [Vector3(0, -9, -85), -PI / 2],
		"right_wall": [Vector3(4, 1, -11), -PI / 2], "front_wall": [Vector3(-3, 1, -10), 0.0],
		"guard": [Vector3(2, 1, -9), -0.45], "walker": [Vector3(3.0, 1, -9.5), -2.44], "guard_close": [Vector3(4.6, 1, -12.4), -0.35], "commuters": [Vector3(0.5, -9, -77), 0.25],
		"street": [Vector3(0, 1, 3), PI], "street_out": [Vector3(0, 1, 9), PI],
		"esc_bottom": [Vector3(0, -9, -57), PI], "platform_side": [Vector3(3.0, -8.4, -63), -0.35],
	}
	for k in views:
		game.player.place(Transform3D(Basis(Vector3.UP, views[k][1]), views[k][0]))
		game.player.active = false
		for i in 5:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % k)
	# Token machine: normal (prompt showing), then the flood anomaly.
	game.player.place(Transform3D(Basis(Vector3.UP, PI / 2 - 0.3), Vector3(-7.7, 1.0, -4.8)))
	game.player.head.rotation.x = -0.35
	game.player.active = true
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://shots/token_machine.png")
	var flood := Anomaly.create(load("res://game/data/anomalies/token_flood.tres"))
	flood.apply(game.station.get_node("Props/TokenMachine"))
	await create_timer(6.0).timeout
	root.get_viewport().get_texture().get_image().save_png("user://shots/token_flood.png")
	flood.revert(game.station.get_node("Props/TokenMachine"))
	# Reactive: the poster's eyes and the ad screen's camera feed.
	var reactive := {"poster_eyes": [Vector3(-7, 1, -6.5), PI / 2 - 0.5], "ad_camera_feed": [Vector3(4.2, 1, -15), 0.0], "passage_runner": [Vector3(0, 1, -8), 0.0]}
	for k in reactive:
		game.player.place(Transform3D(Basis(Vector3.UP, reactive[k][1]), reactive[k][0]))
		game.player.head.rotation.x = 0.15
		game.player.active = false
		var data: AnomalyData = load("res://game/data/anomalies/%s.tres" % k)
		var a := Anomaly.create(data)
		a.apply(game.station.get_node(data.slot_name))
		for i in 10:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % k)
		a.revert(game.station.get_node(data.slot_name))
	# Stairwell: from the concourse, looking down the flight (normal, then #34), and the shutter at the bottom.
	var stairs := {"stairs_top": [Vector3(-8.0, 1, -3.4), 0.25, -0.35], "stairs_down": [Vector3(-9.05, 1, -4.6), 0.0, -0.55],
		"stairs_bottom": [Vector3(-9.05, -2.6, -10.8), 0.0, 0.0], "stairs_up": [Vector3(-9.05, -2.6, -13.0), PI, 0.35]}
	var extra := Anomaly.create(load("res://game/data/anomalies/stairs_extra.tres"))
	for pass_extra in [false, true]:
		if pass_extra:
			extra.apply(game.station.get_node("Props/Stairs"))
		for k in stairs:
			game.player.place(Transform3D(Basis(Vector3.UP, stairs[k][1]), stairs[k][0]))
			game.player.head.rotation.x = stairs[k][2]
			game.player.active = false
			for i in 5:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("user://shots/%s%s.png" % [k, "_extra" if pass_extra else ""])
	extra.revert(game.station.get_node("Props/Stairs"))
	# The trains from the platform: passengers, the LED display and the driver, then the four train anomalies.
	var train_views := {"train_window": [Vector3(2.8, -9, -80), -PI / 2, 0.1], "train_display": [Vector3(3.0, -9, -79.5), -1.3, 0.05],
		"train_cab": [Vector3(3.5, -9, -106.0), -1.75, 0.0], "train_opposite": [Vector3(-2.8, -9, -80), PI / 2, 0.1]}
	for k in train_views:
		game.player.place(Transform3D(Basis(Vector3.UP, train_views[k][1]), train_views[k][0]))
		game.player.head.rotation.x = train_views[k][2]
		game.player.active = false
		for i in 5:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % k)
	var train_anoms := {"coach_empty": "train_window", "display_wrong_direction": "train_display",
		"display_same_station": "train_display", "train_no_driver": "train_cab"}
	for id in train_anoms:
		var v: Array = train_views[train_anoms[id]]
		game.player.place(Transform3D(Basis(Vector3.UP, v[1]), v[0]))
		game.player.head.rotation.x = v[2]
		var data: AnomalyData = load("res://game/data/anomalies/%s.tres" % id)
		var a := Anomaly.create(data)
		a.apply(game.station.get_node(data.slot_name))
		for i in 5:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % id)
		a.revert(game.station.get_node(data.slot_name))
	# Hindi: the rules board and the pause menu.
	game.set_language("hi")
	game.player.place(Transform3D(Basis(Vector3.UP, 0.35), Vector3(-1.2, 1, -4.8)))
	for i in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://shots/rules_hindi.png")
	game.set_paused(true)
	for i in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://shots/pause_hindi.png")
	game.set_paused(false)
	game.set_language("en")
	game.player.active = false
	game.train.ride("Roshanpura", 100.0)
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://shots/train.png")
	print(ProjectSettings.globalize_path("user://shots"))
	quit()
