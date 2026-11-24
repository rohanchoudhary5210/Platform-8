extends SceneTree

## Headless tests. Run from the project folder:
##   Godot_v4.7-stable_win64_console.exe --headless -s res://game/tests/test_platform8.gd

var _fails := 0

func _initialize() -> void:
	_test_loop_manager()
	_test_director_rules()
	_test_director_seeded()
	await _test_anomalies_revert()
	await _test_playthrough()
	await _test_walk()
	print("FAILED: %d" % _fails if _fails else "ALL TESTS PASSED")
	quit(1 if _fails else 0)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + what)

func _test_loop_manager() -> void:
	var lm := LoopManager.new()
	var a := AnomalyData.new()
	lm.current = null
	_check(lm.resolve(false), "no anomaly + forward is right")
	_check(lm.count == 1 and lm.station_name == LoopManager.STATION_NAMES[1], "right call advances")
	lm.current = a
	var name_before := lm.station_name
	_check(not lm.resolve(false), "anomaly + forward is wrong")
	_check(lm.count == 0 and lm.station_name == name_before, "wrong call resets count, same station")
	lm.current = a
	_check(lm.resolve(true), "anomaly + opposite is right")
	for i in 7:
		lm.current = null
		lm.resolve(false)
	_check(lm.is_complete() and lm.count == 8, "8 right calls completes")

func _test_director_rules() -> void:
	for seed_i in range(1, 301):
		var d := AnomalyDirector.new(AnomalyCatalog.ALL, seed_i)
		var streak := 0
		var last_cat := &""
		var since_reset := {}
		for loop_i in 60:
			var a := d.pick(loop_i % 9)
			if loop_i == 0:
				_check(a == null, "seed %d: first loop is empty" % seed_i)
			if a == null:
				streak += 1
				_check(streak <= AnomalyDirector.MAX_EMPTY_STREAK, "seed %d: >2 empty loops in a row" % seed_i)
				continue
			streak = 0
			_check(a.category != last_cat, "seed %d: category %s twice in a row" % [seed_i, a.category])
			last_cat = a.category
			if since_reset.has(a.id):
				# Only allowed once the pool is exhausted (shortcut in AnomalyDirector).
				_check(d.seen.size() <= 1, "seed %d: %s repeated before pool ran dry" % [seed_i, a.id])
				since_reset.clear()
			since_reset[a.id] = true
	# Empty ratio ~30% (GDD); the streak cap and pool exhaustion pull it around a little.
	var empties := 0
	var total := 0
	for seed_i in range(1, 201):
		var d := AnomalyDirector.new(AnomalyCatalog.ALL, seed_i)
		d.pick(0)
		for i in 40:
			total += 1
			empties += 1 if d.pick(i % 9) == null else 0
	var ratio := float(empties) / total
	_check(ratio > 0.2 and ratio < 0.4, "empty ratio %.2f not ~0.3" % ratio)

func _test_director_seeded() -> void:
	var a := AnomalyDirector.new(AnomalyCatalog.ALL, 42)
	var b := AnomalyDirector.new(AnomalyCatalog.ALL, 42)
	for i in 30:
		var x := a.pick(i % 9)
		var y := b.pick(i % 9)
		_check((x.id if x else &"") == (y.id if y else &""), "same seed gives same run")
	_check(AnomalyDirector.tier_for(3) == 1 and AnomalyDirector.tier_for(4) == 2 and AnomalyDirector.tier_for(7) == 3, "tiers")

func _test_anomalies_revert() -> void:
	var station: Station = load("res://game/scenes/gameplay/Station.tscn").instantiate()
	root.add_child(station)
	await process_frame  # _ready() has not run yet inside _initialize
	station.show_station("Test Nagar", 3, Color.RED)
	_check(AnomalyCatalog.ALL.size() == 5, "5 anomalies in catalog")
	for data: AnomalyData in AnomalyCatalog.ALL:
		var slot := station.get_node_or_null(data.slot_name)
		_check(slot != null, "%s: slot %s exists" % [data.id, data.slot_name])
		if slot == null:
			continue
		var before := station.snapshot()
		var anomaly: Anomaly = load(data.script_path).new()
		anomaly.apply(slot)
		_check(station.snapshot() != before, "%s: apply() changes the station" % data.id)
		anomaly.revert(slot)
		_check(station.snapshot() == before, "%s: revert() restores the station" % data.id)
	station.free()

## Week 1 "done when": a wrong train returns you to the same station; 8 right calls open the exit.
func _test_playthrough() -> void:
	Engine.time_scale = 60.0  # train rides are 10–15 s
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var first_station: String = game.loop.station_name
	game.station.boarded.emit(true)  # first loop is always empty, so opposite is wrong
	await _until_ridden(game)
	_check(game.loop.count == 0 and game.loop.station_name == first_station, "wrong train: same station, count 0")
	var guard := 0
	while not game.loop.is_complete() and guard < 40:
		guard += 1
		var anomaly: AnomalyData = game.loop.current
		if anomaly:
			_check(game.station.get_node(anomaly.slot_name) != null, "active anomaly slot present")
		game.station.boarded.emit(anomaly != null)
		await _until_ridden(game)
	_check(game.loop.is_complete(), "cleared 8 stations")
	_check(not game.station._exit_barrier.visible, "exit opens at station 8")
	game.station.exit_reached.emit()
	_check(game._ended, "ending plays")
	Engine.time_scale = 1.0
	game.free()

func _until_ridden(game: Node) -> void:
	while game._riding:
		await process_frame

## Real physics walk: hold W (a real key event) and steer along the route to each train door.
## Proves the gates, passage, escalator and platform doors are walkable.
const ROUTE := [
	Vector2(0.75, -14), Vector2(0.75, -18), Vector2(0, -22), Vector2(0, -39),  # concourse, AFC gap, passage
	Vector2(0, -62), Vector2(0, -85),                                         # escalator, platform
]

func _test_walk() -> void:
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var boards := []
	game.station.boarded.connect(func(opp): boards.append(opp))
	# Walk 1: forward train (right door). First loop is empty, so it's the right call.
	var ok := await _walk(game.player, ROUTE + [Vector2(5.0, -85)])
	_check(ok and boards == [false], "walk 1 reaches the FORWARD door (boards=%s)" % [boards])
	_check(game.player.global_position.y < -8.5, "walk 1 got down the escalator")
	await _finish_ride(game)
	_check(game.loop.count == 1, "walk 1 counted")
	# Walk 2: opposite train (left door).
	ok = await _walk(game.player, ROUTE + [Vector2(-5.0, -85)])
	_check(ok and boards == [false, true], "walk 2 reaches the OPPOSITE door (boards=%s)" % [boards])
	await _finish_ride(game)
	game.free()

func _walk(player: StationPlayer, points: Array) -> bool:
	_hold_w(true)
	for p: Vector2 in points:
		var t := 0.0
		while player.active:
			var pos := Vector2(player.global_position.x, player.global_position.z)
			var d := p - pos
			if d.length() < 0.35:
				break
			player.rotation.y = atan2(-d.x, -d.y)
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if t > 12.0:
				printerr("stuck at %s heading for %s" % [player.global_position, p])
				_hold_w(false)
				return false
		if not player.active:  # boarded a train
			break
	_hold_w(false)
	return not player.active

func _finish_ride(game: Node) -> void:
	Engine.time_scale = 60.0
	while game._riding:
		await process_frame
	Engine.time_scale = 1.0

func _hold_w(down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_W
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
