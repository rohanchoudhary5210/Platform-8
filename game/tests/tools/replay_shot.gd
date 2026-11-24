extends SceneTree
## Dev tool: fakes a walk past the mirrored poster, triggers the replay, saves a frame to user://shots/replay.png.
func _initialize() -> void:
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var data: AnomalyData = load("res://game/data/anomalies/mirrored_poster.tres")
	var slot: Node = game.station.get_node(data.slot_name)
	var a := Anomaly.create(data)
	a.apply(slot)
	game.replay.clear()
	for i in 300:  # walk from spawn towards the gates, glancing left
		var xf := Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 1.6, -3 - i * 0.04))
		game.replay.record(xf, 1.0 / 60.0)
	game.player.active = false
	game.replay.play(data, slot, 68.0)
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://shots/replay.png")
	quit()
