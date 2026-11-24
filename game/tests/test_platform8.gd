extends SceneTree

## Headless tests. Run from the project folder:
##   Godot_v4.7-stable_win64_console.exe --headless -s res://game/tests/test_platform8.gd

var _fails := 0

func _initialize() -> void:
	_test_loop_manager()
	_test_director_rules()
	_test_director_seeded()
	_test_decisions()
	_test_save_data()
	await _test_replay()
	await _test_anomalies_revert()
	await _test_playthrough()
	await _test_walk()
	await _test_walk_decisions()
	await _test_token_machine()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("FAILED: %d" % _fails if _fails else "ALL TESTS PASSED")
	quit(1 if _fails else 0)

const TEST_SAVE := "user://test_save.cfg"

## Every test game writes to a scratch save, never the player's.
func _new_game() -> Node:
	var game: Node = load("res://game/scenes/gameplay/Game.tscn").instantiate()
	game.save_path = TEST_SAVE
	return game

func _test_save_data() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var s := SaveData.open(TEST_SAVE)
	_check(s.found.is_empty() and s.clears == 0 and s.best_time == 0.0, "missing save starts fresh")
	s.found["clock_backwards"] = true
	s.best_station = 5
	s.mouse_sensitivity = 1.5
	s.record_clear(300.0)
	s.record_clear(400.0)
	_check(s.write() == OK, "save writes")
	var r := SaveData.open(TEST_SAVE)
	_check(r.found.has("clock_backwards") and r.best_station == 5 and r.clears == 2, "save round-trips progress")
	_check(r.best_time == 300.0 and r.mouse_sensitivity == 1.5, "best time keeps the fastest; settings round-trip")
	_check(SaveData.format_time(431.0) == "7:11", "time format m:ss")
	r.found["removed_in_a_later_build"] = true
	_check(r.found_count() == 1, "found count ignores ids not in the catalog")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SaveData.VERSION + 1)
	cfg.set_value("progress", "clears", 99)
	cfg.save(TEST_SAVE)
	_check(SaveData.open(TEST_SAVE).clears == 0, "save from a newer build is ignored, not misread")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

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
			var seen_before := d.seen.size()
			var a := d.pick(loop_i % 9)
			if d.seen.size() < seen_before + (1 if a else 0):  # pool ran dry and was recycled (shortcut in AnomalyDirector)
				since_reset.clear()
			if loop_i == 0:
				_check(a == null, "seed %d: first loop is empty" % seed_i)
			if a == null:
				streak += 1
				_check(streak <= AnomalyDirector.MAX_EMPTY_STREAK, "seed %d: >2 empty loops in a row" % seed_i)
				continue
			streak = 0
			_check(a.category != last_cat, "seed %d: category %s twice in a row" % [seed_i, a.category])
			last_cat = a.category
			_check(not since_reset.has(a.id), "seed %d: %s repeated before pool ran dry" % [seed_i, a.id])
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

## Week 2 "done when" (part 2): every anomaly's apply() changes the station and revert() restores it exactly.
func _test_anomalies_revert() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame  # _ready() has not run yet inside _initialize
	var station: Station = game.station
	_check(AnomalyCatalog.ALL.size() == 28, "28 anomalies in catalog (got %d)" % AnomalyCatalog.ALL.size())
	var ids := {}
	var per_category := {}
	for data: AnomalyData in AnomalyCatalog.ALL:
		_check(not ids.has(data.id), "%s: duplicate id" % data.id)
		ids[data.id] = true
		per_category[data.category] = per_category.get(data.category, 0) + 1
		_check(data.route_index() >= 0, "%s: unknown location %s" % [data.id, data.location])
		var slot := station.get_node_or_null(data.slot_name)
		_check(slot != null, "%s: slot %s exists" % [data.id, data.slot_name])
		if slot == null:
			continue
		var before := station.snapshot()
		var anomaly := Anomaly.create(data)
		anomaly.apply(slot)
		_check(station.snapshot() != before, "%s: apply() changes the station" % data.id)
		anomaly.revert(slot)
		var after := station.snapshot()
		_check(after == before, "%s: revert() restores the station" % data.id)
		if after != before:
			for k in before:
				if after.get(k) != before[k]:
					printerr("   %s: %s -> %s" % [k, before[k], after.get(k)])
	# The guard follows: after a second he is closer to the player, and revert puts him back.
	var guard: Node3D = station.get_node("Props/People/Guard")
	var home := guard.transform
	var gap := guard.global_position.distance_to(game.player.global_position)
	var watch := Anomaly.create(load("res://game/data/anomalies/guard_watches.tres"))
	watch.apply(guard)
	await create_timer(1.0).timeout
	_check(guard.global_position.distance_to(game.player.global_position) < gap - 0.2, "guard follows the player")
	watch.revert(guard)
	_check(guard.transform == home, "guard goes back to his post")
	for c in per_category:
		_check(per_category[c] <= ceili(AnomalyCatalog.ALL.size() * 0.2), "category %s over 20%% of the pool" % c)
	game.free()

func _test_decisions() -> void:
	var lm := LoopManager.new()
	lm.seed_decisions(7)
	for c in 9:
		lm.count = c
		var seen := {}
		for i in 200:
			var dp := lm.pick_decision()
			seen[dp] = true
			_check(c >= LoopManager.DECISIONS[dp], "station %d: %s used before it unlocks" % [c, dp])
		var expect := LoopManager.DECISIONS.keys().filter(func(k): return c >= LoopManager.DECISIONS[k]).size()
		_check(seen.size() == expect, "station %d: %d decision points in use, expected %d" % [c, seen.size(), expect])
	# Fairness: an anomaly is only picked if the player passes it before the decision point.
	for seed_i in range(1, 101):
		var d := AnomalyDirector.new(AnomalyCatalog.ALL, seed_i)
		for i in 30:
			var reach: int = [0, 2, 3][i % 3]
			var a := d.pick(i % 9, reach)
			_check(a == null or a.route_index() <= reach, "seed %d: %s picked past its decision point" % [seed_i, a.id if a else &""])

## Week 1 "done when": a wrong train returns you to the same station; 8 right calls open the exit.
func _test_playthrough() -> void:
	Engine.time_scale = 60.0  # train rides are 10–15 s
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var first_station: String = game.loop.station_name
	game.station.decided.emit(true)  # first loop is always empty, so opposite is wrong
	await _until_ridden(game)
	_check(game.loop.count == 0 and game.loop.station_name == first_station, "wrong train: same station, count 0")
	var guard := 0
	while not game.loop.is_complete() and guard < 40:
		guard += 1
		var anomaly: AnomalyData = game.loop.current
		if anomaly:
			_check(game.station.get_node(anomaly.slot_name) != null, "active anomaly slot present")
		game.station.decided.emit(anomaly != null)
		await _until_ridden(game)
	_check(game.loop.is_complete(), "cleared 8 stations")
	_check(not game.station._exit_barrier.visible, "exit opens at station 8")
	game.station.exit_reached.emit()
	_check(game._ended, "ending plays")
	var saved := SaveData.open(TEST_SAVE)
	_check(saved.clears == 1 and saved.best_station == 8 and saved.best_time > 0.0, "clear is saved")
	_check(saved.found.size() == game._found_this_run and saved.found.size() > 0, "found anomalies are saved")
	_check(game.ending_text().contains("YOU MADE IT OUT"), "ending screen text")
	await create_timer(3.0).timeout  # fade (2 s at 60x) then the ending shows
	_check(game.hud("End").visible and not game.hud("Station").visible, "ending screen replaces the HUD")
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
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var boards := []
	game.station.decided.connect(func(opp): boards.append(opp))
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

## Real physics walks for the escalator and gate decision points, both choices each.
func _test_walk_decisions() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var choices := []
	game.station.decided.connect(func(back): choices.append(back))
	var cases := [
		[&"gates", [Vector2(0.75, -14.6), Vector2(0.75, -8)], true],                 # turn back from the gates
		[&"gates", [Vector2(0.75, -14.6), Vector2(0.75, -19.5)], false],             # tap through
		[&"escalator", ROUTE.slice(0, 5) + [Vector2(0, -50)], true],                  # ride back up
		[&"escalator", ROUTE.slice(0, 5) + [Vector2(0, -67)], false],                 # walk on to the platform
	]
	for c in cases:
		choices.clear()
		game.loop.decision = c[0]
		game.station.set_decision(c[0])
		game.player.place(game.station.spawn.global_transform)
		var ok := await _walk(game.player, c[1])
		_check(ok and choices == [c[2]], "%s: %s choice registers (got %s)" % [c[0], "back" if c[2] else "forward", choices])
		await _finish_ride(game)
	game.free()

## Token machine: look at it, press E (a real key event), a token drops; arrival empties the tray.
func _test_token_machine() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var tvm: TokenMachine = game.station.get_node("Props/TokenMachine")
	game.player.place(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-8.3, 1.0, -4)))  # facing the machine
	for i in 3:
		await physics_frame
	_check(game.player.interactable() == tvm, "looking at the token machine")
	await process_frame
	_check(game.hud("Prompt").text == TokenMachine.PROMPT, "buy prompt shows")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	_check(tvm.tokens.get_child_count() == 1, "E dispenses one token (got %d)" % tvm.tokens.get_child_count())
	_check(tvm.screen.text.contains(game.loop.station_name.to_upper()), "screen shows this station")
	game.player.place(game.station.spawn.global_transform)
	for i in 3:
		await physics_frame
	_check(game.player.interactable() == null and game.hud("Prompt").text == "", "no prompt when looking away")
	game.station.show_station("X", 1, Color.RED, "Y")
	_check(tvm.tokens.get_child_count() == 0, "arrival empties the tray")
	game.free()

## Wrong-call replay: picks the 3 s window around the closest pass, and plays after a wrong call.
func _test_replay() -> void:
	var r := Replay.new()
	root.add_child(r)
	await process_frame
	for i in 600:  # 10 s walking straight down -Z at 3 m/s
		r.record(Transform3D(Basis(), Vector3(0, 1.6, -i * 0.05)), 1.0 / 60.0)
	var start := r.window_start(Vector3(1, 1.6, -20))  # closest at t ≈ 6.67 s
	_check(absf(start - (20.0 / 3.0 - Replay.LEAD)) < 0.1, "replay window starts 2 s before the closest pass (got %.2f)" % start)
	_check(r.window_start(Vector3(0, 1.6, 100)) == 0.0, "replay window clamps to the start")
	_check(is_equal_approx(r.window_start(Vector3(0, 1.6, -500)), r._t - Replay.LENGTH), "replay window clamps to the end")
	_check(Replay.focus_of(r) == null, "non-3D slot has no circle")
	r.free()
	# In the game: a wrong call plays the replay before the ride.
	Engine.time_scale = 60.0
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	game.station.decided.emit(true)  # first loop is empty → wrong
	_check(game.replay.playing, "wrong call starts the replay")  # checked at once: at 60x speed it ends within a frame
	await _until_ridden(game)
	_check(not game.replay.playing and game.loop.count == 0, "replay ends, then the same station")
	Engine.time_scale = 1.0
	game.free()
