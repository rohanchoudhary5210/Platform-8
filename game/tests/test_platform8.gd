extends SceneTree

## Headless tests. Run from the project folder:
##   Godot_v4.7-stable_win64_console.exe --headless -s res://game/tests/test_platform8.gd

var _fails := 0

func _initialize() -> void:
	Lang.code = "en"
	_test_loop_manager()
	_test_director_rules()
	_test_director_seeded()
	_test_director_partial_recycle()
	_test_decisions()
	_test_save_data()
	await _test_replay()
	await _test_anomalies_revert()
	await _test_reactive()
	await _test_spatial()
	await _test_playthrough()
	await _test_walk()
	await _test_walk_decisions()
	await _test_token_machine()
	await _test_debug_keys()
	await _test_stairs()
	await _test_escalator_ride()
	await _test_menus()
	await _test_train_insides()
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
	_check(not r.hardcore and r.language == "en", "hardcore off and English by default")
	r.hardcore = true
	r.language = "hi"
	r.write()
	var h := SaveData.open(TEST_SAVE)
	_check(h.hardcore and h.language == "hi", "hardcore and language round-trip")
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
	var rules: Label3D = station.get_node_or_null("Props/RulesBoard/Text")
	_check(rules != null and rules.text.contains("FORWARD") and rules.text.contains("BACK"), "rules notice by the spawn")
	_check(AnomalyCatalog.ALL.size() == 45, "45 anomalies in catalog (got %d)" % AnomalyCatalog.ALL.size())
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
		if not data.id in WAIT_FOR_PLAYER:  # these change only once the player looks / looks away (_test_reactive)
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
	# The walker paces; #45 freezes him mid-step and revert lets him walk on.
	var walker: Node3D = station.get_node("Props/Walker")
	var was := walker.position
	await create_timer(0.5).timeout
	_check(walker.position != was, "walker walks")
	var freeze := Anomaly.create(load("res://game/data/anomalies/crowd_freezes.tres"))
	freeze.apply(walker)
	was = walker.position
	await create_timer(0.5).timeout
	_check(walker.position == was, "frozen walker stays put")
	freeze.revert(walker)
	await create_timer(2.0).timeout  # may be in his end-of-path pause
	_check(walker.position != was, "walker walks on after revert")
	for c in per_category:
		_check(per_category[c] <= ceili(AnomalyCatalog.ALL.size() * 0.2), "category %s over 20%% of the pool" % c)
	# Guard chase: he waits in front of the gates, charges when you come close (arming the gates
	# decision), and reaching you is a wrong call.
	var chase_data: AnomalyData = load("res://game/data/anomalies/guard_chase.tres")
	var chase := Anomaly.create(chase_data)
	chase.apply(guard)
	await create_timer(0.5).timeout
	_check(guard.position == Vector3(0, 0, -13), "guard waits in front of the gates while you're far away")
	game.loop.current = chase_data
	station.set_decision(&"gates")
	var chase_calls := []
	var on_chase := func(b): chase_calls.append(b)
	station.decided.connect(on_chase)
	game.player.place(Transform3D(Basis(), Vector3(0, 1, -10)))
	await create_timer(0.3).timeout
	_check(station._armed and chase_calls.is_empty(), "guard charges and arms the gates decision")
	await create_timer(1.5).timeout
	_check(chase_calls == [false], "guard catches you as a wrong call (got %s)" % [chase_calls])
	Engine.time_scale = 30.0
	await _until_ridden(game)
	Engine.time_scale = 1.0
	station.decided.disconnect(on_chase)
	chase.revert(guard)
	_check(guard.transform == home, "guard back at his post after the chase")
	# #42 The flood waits until you're on the platform, then rises and catches you: a wrong call.
	var flood_data: AnomalyData = load("res://game/data/anomalies/platform_floods.tres")
	var water: Node3D = station.get_node(flood_data.slot_name)
	var low := water.global_position.y
	var calls := []
	station.decided.connect(func(b): calls.append(b))
	var flood := Anomaly.create(flood_data)
	flood.apply(water)
	await create_timer(0.5).timeout
	_check(water.global_position.y == low, "flood waits while you're in the concourse")
	game.loop.current = flood_data
	game.player.place(Transform3D(Basis(), Vector3(0, -9, -75)))
	Engine.time_scale = 30.0
	await create_timer(12.0).timeout
	_check(calls.is_empty() and water.global_position.y > -10.0, "water climbs the platform, you still have time")
	await create_timer(10.0).timeout
	_check(calls == [false], "flood catches you as a wrong call (got %s)" % [calls])
	await _until_ridden(game)
	Engine.time_scale = 1.0
	_check(game.loop.count == 0, "caught: count back to 0")
	flood.revert(water)
	_check(not water.visible and water.global_position.y == low, "flood drains on revert")
	game.free()

const WAIT_FOR_PLAYER := [&"commuter_looks", &"sweeper_creeps", &"endless_escalator", &"longer_passage"]

func _reactive(file: String, station: Station) -> Array:
	var data: AnomalyData = load("res://game/data/anomalies/%s.tres" % file)
	var slot := station.get_node(data.slot_name)
	var a := Anomaly.create(data)
	a.apply(slot)
	return [a, slot]

## Player standing at pos, looking at target.
func _stand(game: Node, pos: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x, pos.y, target.z)
	game.player.place(Transform3D(Basis(), pos).looking_at(flat))
	game.player.head.look_at(target)

func _test_reactive() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var station: Station = game.station
	# #38 The pupils point towards you, wherever you stand.
	var pupil: Node3D = station.get_node("Props/Poster/Face/PupilL")
	var gaze := pupil.position
	var eyes := _reactive("poster_eyes", station)
	_stand(game, Vector3(-5, 1, -4), Vector3(-9, 2, -9))
	await process_frame
	var near_spawn := pupil.position
	_stand(game, Vector3(-5, 1, -14), Vector3(-9, 2, -9))
	await process_frame
	_check(pupil.position.x > near_spawn.x + 0.02, "poster eyes follow you along the wall")
	eyes[0].revert(eyes[1])
	_check(pupil.position == gaze, "poster eyes revert")
	# #14 An echo step follows each of yours a moment later, and stops when you stop.
	var echo := _reactive("footsteps_behind", station)
	_stand(game, Vector3(0, 1, 0), Vector3(0, 1, -10))
	game.player.active = false
	for i in 30:
		game.player.global_position.z -= 0.1
		await process_frame
	await create_timer(0.5).timeout
	var heard: int = echo[0].steps
	_check(heard >= 3, "echo steps follow yours (got %d)" % heard)
	await create_timer(1.0).timeout
	_check(echo[0].steps == heard, "echo stops when you stop")
	echo[0].revert(echo[1])
	game.player.active = true
	# Camera feed: the screen shows a feed, your body is hidden from your own camera; revert undoes it.
	var feed := _reactive("ad_camera_feed", station)
	_check(not station.get_node("Props/AdScreen/Ad").visible and feed[1].find_children("*", "SubViewport", false, false).size() == 1,
		"ad screen shows the camera feed")
	_check(game.player.camera.cull_mask & (1 << 19) == 0, "you never see your own figure")
	feed[0].revert(feed[1])
	_check(game.player.camera.cull_mask & (1 << 19) != 0, "camera mask restored")
	# #39 The sweeper only moves while off screen, one step per look-away.
	var sweeper: Node3D = station.get_node("Props/People/Sweeper")
	var home := sweeper.transform
	_stand(game, Vector3(0, 1, 0), sweeper.global_position + Vector3.UP)
	var creep := _reactive("sweeper_creeps", station)
	await create_timer(0.3).timeout
	_check(creep[0].moves == 0, "sweeper stays put while you watch")
	var gap := sweeper.global_position.distance_to(game.player.global_position)
	_stand(game, Vector3(0, 1, 0), Vector3(0, 1, 10))
	await create_timer(0.3).timeout
	_check(creep[0].moves == 1, "sweeper takes one step while you look away (got %d)" % creep[0].moves)
	_check(sweeper.global_position.distance_to(game.player.global_position) < gap - 1.0, "sweeper is closer")
	_stand(game, Vector3(0, 1, 0), sweeper.global_position + Vector3.UP)
	await process_frame
	_stand(game, Vector3(0, 1, 0), Vector3(0, 1, 10))
	await process_frame
	await process_frame
	_check(creep[0].moves == 2, "and another after the next glance")
	creep[0].revert(creep[1])
	_check(sweeper.transform == home, "sweeper back on revert")
	# #40 The commuter turns to you only while you look straight at him.
	var man: Node3D = station.get_node("Props/People/CommuterA")
	var post := man.transform
	var looks := _reactive("commuter_looks", station)
	_stand(game, Vector3(1.5, -9, -78), man.global_position + Vector3.UP * 1.5)
	await create_timer(1.0).timeout
	_check(not man.transform.is_equal_approx(post), "commuter turns when you look at him")
	_stand(game, Vector3(1.5, -9, -78), Vector3(1.5, -9, -100))
	await process_frame
	await process_frame
	_check(man.transform == post, "commuter faces away again when you look elsewhere")
	looks[0].revert(looks[1])
	var ad: Node3D = station.get_node("Props/AdScreen")
	_check(ad.get_child_count() == 2 and ad.get_node("Ad").visible and station.get_node_or_null("Props/EchoSteps") == null,
		"no feed or echo left behind")
	game.free()

## #33 longer passage, #35 endless escalator (real physics walks), #41 passage runner.
func _test_spatial() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var station: Station = game.station
	var choices := []
	station.decided.connect(func(b): choices.append(b))
	# #33 Near the end of the passage you're put back 8 m once; the walk still gets there.
	game.loop.decision = &"train"
	station.set_decision(&"train")
	var longer := _reactive("longer_passage", station)
	await _walk(game.player, ROUTE.slice(0, 4))  # true only when it ends on a train
	_check(longer[0].done and game.player.global_position.z < -38.5, "longer passage: put back once and still walkable")
	longer[0].revert(longer[1])
	# #35 The foot of the escalator never comes; riding back up is the back choice.
	game.loop.decision = &"escalator"
	station.set_decision(&"escalator")
	game.player.place(station.spawn.global_transform)
	var endless := _reactive("endless_escalator", station)
	await _walk(game.player, ROUTE.slice(0, 4) + [Vector2(0.95, -56)])
	game.player.rotation.y = 0.0  # facing down the escalator
	_hold_w(true)
	await create_timer(4.0).timeout
	_hold_w(false)
	_check(endless[0].loops >= 2 and game.player.global_position.z > -59.0,
		"escalator never reaches the bottom (loops %d, z %.1f)" % [endless[0].loops, game.player.global_position.z])
	_check(station._armed and choices.is_empty(), "endless escalator arms the escalator decision")
	await _walk(game.player, [Vector2(0.95, -49)])
	_check(choices == [true], "riding back up is the back choice (got %s)" % [choices])
	endless[0].revert(endless[1])
	await _finish_ride(game)
	# Debug F-keys give it its own decision point.
	game.debug_force(AnomalyCatalog.ALL.find(load("res://game/data/anomalies/endless_escalator.tres")))
	_check(game.loop.decision == &"escalator", "debug force picks the escalator decision for it")
	game.debug_force(0, true)
	# #41 The runner waits deep in the passage and charges once you're near the gates: a wrong call if he reaches you.
	choices.clear()
	var runner: Node3D = station.get_node("Props/People/CommuterB")
	var home := runner.transform
	var run_data: AnomalyData = load("res://game/data/anomalies/passage_runner.tres")
	game.loop.current = run_data
	game.loop.decision = &"gates"
	station.set_decision(&"gates")
	game.player.place(Transform3D(Basis(), Vector3(0, 1, -5)))
	var run := Anomaly.create(run_data)
	run.apply(runner)
	await create_timer(0.5).timeout
	_check(runner.position == Vector3(0, 0, -30) and not station._armed, "runner waits in the passage")
	game.player.place(Transform3D(Basis(), Vector3(0, 1, -11)))
	await create_timer(1.5).timeout
	_check(station._armed and runner.position.z > -26.0 and choices.is_empty(), "runner charges and arms the gates")
	await create_timer(4.0).timeout
	_check(choices == [false], "runner catches you as a wrong call (got %s)" % [choices])
	await _finish_ride(game)
	run.revert(runner)
	_check(runner.transform == home, "runner back on the platform after revert")
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
			_check(a == null or reach <= a.max_decision_reach, "seed %d: %s picked with a decision point too far away" % [seed_i, a.id if a else &""])

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
	Vector2(0.75, -14), Vector2(0.75, -18), Vector2(0, -22), Vector2(0.95, -39.2),  # concourse, AFC gap, passage
	Vector2(0.95, -62), Vector2(0, -85),                                             # down escalator (right lane), platform
]

func _test_walk() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var boards := []
	game.station.decided.connect(func(opp): boards.append(opp))
	# Walk 1: forward train (right door). First loop is empty, so it's the right call.
	game.player.tokens = 1
	var ok := await _walk(game.player, ROUTE + [Vector2(5.0, -85)])
	_check(game.player.tokens == 0, "the AFC gate takes your token")
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
		[&"escalator", ROUTE.slice(0, 5) + [Vector2(-0.95, -62.5), Vector2(-0.95, -50)], true],  # take the up escalator back
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
	# Pick it up: aim at the token in the tray and press E again.
	var token: Node3D = tvm.tokens.get_child(0)
	await create_timer(0.4).timeout  # let it land in the tray
	game.player.place(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-8.6, 1.0, token.global_position.z)))
	for i in 3:
		await physics_frame
	var cam: Vector3 = game.player.camera.global_position
	game.player.head.rotation.x = -atan2(cam.y - token.global_position.y, cam.x - token.global_position.x)  # look down at it
	for i in 3:
		await physics_frame
	_check(game.player.interactable() == token, "looking at the token in the tray")
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	Input.parse_input_event(up)
	await process_frame
	var again := InputEventKey.new()
	again.physical_keycode = KEY_E
	again.pressed = true
	Input.parse_input_event(again)
	await process_frame
	_check(game.player.tokens == 1 and tvm.tokens.get_child_count() == 0, "E picks the token up")
	for i in 2:  # physics_frame fires before nodes' _physics_process
		await physics_frame
	_check(game.hud("Tokens").text.contains("1"), "HUD shows the token")
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

## Debug keys: F2/F1 step through the catalog and force that anomaly, F3 gives a clean loop.
func _test_debug_keys() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var n := AnomalyCatalog.ALL.size()
	game._unhandled_input(_key_event(KEY_F2))
	_check(game.loop.current == AnomalyCatalog.ALL[0] and game._active != null, "F2 forces the first anomaly")
	_check(game.hud("Debug").text.contains(AnomalyCatalog.ALL[0].display_name), "debug label names it")
	game._unhandled_input(_key_event(KEY_F1))
	_check(game.loop.current == AnomalyCatalog.ALL[n - 1], "F1 wraps to the last anomaly")
	var chase: AnomalyData = load("res://game/data/anomalies/guard_chase.tres")
	game.debug_force(AnomalyCatalog.ALL.find(chase))
	_check(game.loop.decision == &"gates" and game.station.decision == &"gates", "guard chase is forced with the gates decision")
	game._unhandled_input(_key_event(KEY_F3))
	_check(game.loop.current == null and game._active == null, "F3 gives a clean loop")
	_check(game.station.get_node("Props/People/Guard").position != Vector3(0, 0, -13), "previous anomaly reverted")
	_check(game._debug_used, "a debug run stops saving")
	_check(game.director.seen.has(chase.id), "a forced anomaly counts as seen, so it isn't picked again")
	var start: int = game.loop.count
	game._unhandled_input(_key_event(KEY_F4))
	_check(game.loop.count == start + 1 and game.loop.station_name == LoopManager.STATION_NAMES[start + 1], "F4 jumps to the next station")
	for i in 10:
		game._unhandled_input(_key_event(KEY_F4))
	_check(game.loop.count == LoopManager.GOAL and not game.station._exit_barrier.visible, "F4 stops at station 8 with the exit open")
	game.free()

## The stairwell is walkable down to the shutter and back; #34 swaps in a flight with more steps.
## Standing still on the escalator: the down lane carries you down, the up lane up, at the steps' speed.
## The wrong-way anomaly makes the down lane carry you up.
func _test_escalator_ride() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var p: StationPlayer = game.player
	var ride := func(lane: float) -> float:  # metres along the slope moved in 2 s, + = down
		p.place(Transform3D(Basis(), Vector3(lane, -4.0 + 1.0, -48)))  # mid-escalator, just above the nosing line
		for i in 20:
			await physics_frame  # settle on the ramp
		var z0 := p.global_position.z
		await create_timer(2.0).timeout
		return (z0 - p.global_position.z) / cos(atan2(Station.ESC_DROP, Station.ESC_RUN))
	var down: float = await ride.call(Station.ESC_LANES[1])
	_check(absf(down - 1.2) < 0.25, "down escalator carries you down at 0.6 m/s (moved %.2f m)" % down)
	var up: float = await ride.call(Station.ESC_LANES[0])
	_check(absf(up + 1.2) < 0.25, "up escalator carries you up (moved %.2f m)" % up)
	var wrong := Anomaly.create(load("res://game/data/anomalies/escalator_wrong_way.tres"))
	wrong.apply(game.station.get_node("Props/EscalatorSteps"))
	var rev: float = await ride.call(Station.ESC_LANES[1])
	_check(rev < -0.9, "wrong-way escalator carries you up (moved %.2f m)" % rev)
	wrong.revert(game.station.get_node("Props/EscalatorSteps"))
	game.free()

func _test_stairs() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var stairs: Node3D = game.station.get_node("Props/Stairs")
	var steps := func(n: Node) -> int: return n.find_children("Step*", "MeshInstance3D", true, false).size()
	_check(stairs.get_node("Normal").visible and not stairs.get_node("Extra").visible, "normal stairs shown")
	_check(steps.call(stairs.get_node("Normal")) == 20 and steps.call(stairs.get_node("Extra")) == 28,
		"stairs have 20 steps, the anomaly's 28 (%d, %d)" % [steps.call(stairs.get_node("Normal")), steps.call(stairs.get_node("Extra"))])
	var x := Station.STAIRS_X
	game.player.place(Transform3D(Basis(), Vector3(x, 1.0, -4.0)))
	await _walk(game.player, [Vector2(x, -12.6)])
	_check(game.player.global_position.y < -2.4, "walked down to the bottom of the stairs (y %.2f)" % game.player.global_position.y)
	await _walk(game.player, [Vector2(x, -4.6)])
	_check(game.player.global_position.y > 0.7, "and back up (y %.2f)" % game.player.global_position.y)
	game.player.place(Transform3D(Basis(), Vector3(-6.5, 1.0, -9.0)))
	game.player.rotation.y = PI / 2  # facing -X, at the railing
	_hold_w(true)
	await create_timer(1.8).timeout
	_hold_w(false)
	_check(game.player.global_position.y > 0.7, "railing stops you stepping into the stairwell")
	var extra := _reactive("stairs_extra", game.station)
	_check(stairs.get_node("Extra").visible and not stairs.get_node("Normal").visible, "anomaly shows the longer flight")
	extra[0].revert(extra[1])
	_check(stairs.get_node("Normal").visible and not stairs.get_node("Extra").visible, "and puts the normal one back")
	game.free()

## Pause menu, hardcore mode, language, gamepad and the guard's run cycle.
func _test_menus() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var box: Node = game._pause.get_node("Box")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	game._pause.get_child(game._pause.get_child_count() - 1)._unhandled_input(esc)
	_check(paused and game.is_paused() and game._pause.visible, "Esc pauses the game")
	box.get_node("Hardcore").pressed.emit()
	_check(game.save.hardcore and not game.hud("Station").visible and not game.hud("Decision").visible
		and not game.station._number.visible, "hardcore hides the counter and the hints")
	_check(game.director.excluded.has(&"hud_counter_jump"), "hardcore never picks the HUD anomaly")
	_check(SaveData.open(TEST_SAVE).hardcore, "hardcore is saved")
	box.get_node("Hardcore").pressed.emit()
	_check(game.hud("Station").visible and game.station._number.visible and game.director.excluded.is_empty(), "hardcore off again")
	box.get_node("Language").pressed.emit()
	var rules: Label3D = game.station.get_node("Props/RulesBoard/Text")
	_check(Lang.code == "hi" and box.get_node("Resume").text == "जारी रखें" and rules.text.begins_with("यात्री"),
		"language switches the menu and the rules board to Hindi")
	_check(game.hud("Decision").text.begins_with("फ़ैसला"), "decision hint in Hindi")
	_check(SaveData.open(TEST_SAVE).language == "hi", "language is saved")
	var lie := _reactive("rules_changed", game.station)
	_check(rules.text.contains(Lang.t("rule_lie")) and not rules.text.contains(Lang.t("rule_back")), "rules anomaly lies in Hindi too")
	lie[0].revert(lie[1])
	box.get_node("Language").pressed.emit()
	_check(Lang.code == "en" and rules.text.contains("turn BACK"), "back to English")
	game._pause.get_child(game._pause.get_child_count() - 1)._unhandled_input(esc)
	_check(not paused and not game.is_paused(), "Esc again resumes")
	# The pause menu stops the train ride (its timers must not run while paused).
	game.train.ride("Pause Test", 1.0)
	game.set_paused(true)
	await create_timer(1.6).timeout
	_check(game.train.visible, "ride does not finish while paused")
	game.set_paused(false)
	await create_timer(1.6).timeout
	_check(not game.train.visible, "ride finishes after resuming")
	game.player.camera.make_current()
	# Once Restart / Quit has started loading, Esc must not pause (the next scene would open paused).
	game._leaving = true
	game.set_paused(true)
	_check(not paused and not game.is_paused(), "no pausing while leaving the scene")
	game._leaving = false
	# Gamepad: left stick forward walks, right stick turns, A uses the token machine.
	game.player.place(station_spawn(game))
	var z: float = game.player.global_position.z
	var yaw: float = game.player.rotation.y
	_stick_event(JOY_AXIS_LEFT_Y, -1.0)
	_stick_event(JOY_AXIS_RIGHT_X, 1.0)
	await create_timer(0.5).timeout
	_stick_event(JOY_AXIS_LEFT_Y, 0.0)
	_stick_event(JOY_AXIS_RIGHT_X, 0.0)
	_check(game.player.global_position.z < z - 0.5 and game.player.rotation.y < yaw - 0.5, "gamepad sticks walk and look")
	_stand(game, Vector3(-8.6, 1.0, -4.0), Vector3(-9.6, 1.3, -4.0))
	await physics_frame
	await physics_frame
	var tray: Node3D = game.station.get_node("Props/TokenMachine").tokens
	var dropped := tray.get_child_count()
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	game.player._unhandled_input(a)
	await create_timer(0.3).timeout
	_check(tray.get_child_count() == dropped + 1, "gamepad A uses the token machine")
	# The guard runs, not a fast walk.
	var guard: Node3D = game.station.get_node("Props/People/Guard")
	var chase := Anomaly.create(load("res://game/data/anomalies/guard_chase.tres"))
	chase.apply(guard)
	game.player.place(Transform3D(Basis(), Vector3(0, 1, -9.7)))
	await create_timer(0.8).timeout  # running, not yet caught
	var ap: AnimationPlayer = guard.find_children("*", "AnimationPlayer", true, false)[0]
	_check(ap.current_animation == "Run", "guard chase plays the Run cycle (got %s)" % ap.current_animation)
	chase.revert(guard)
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

## The parked trains show passengers, a driver and destination LEDs; the four train anomalies change them.
func _test_train_insides() -> void:
	var game: Node = _new_game()
	root.add_child(game)
	await process_frame
	var st: Station = game.station
	var leds: Array = st.get_node("Props/CoachDisplays/Forward").find_children("Display*", "Label3D", false, false)
	var next: String = game.loop.next_station_name().to_upper()
	_check(leds.size() == 2 and leds.all(func(l): return l.text.contains(next)), "forward LEDs show the next station")
	_check(st.get_node("Props/Drivers/Forward").visible and st.get_node("Props/Passengers/Forward").get_child_count() == 8,
		"forward train has a driver and passengers")
	var same := _reactive("display_same_station", st)
	_check(leds.all(func(l): return l.text.contains(game.loop.station_name.to_upper())), "same-station LED names this station")
	same[0].revert(same[1])
	var wrong := _reactive("display_wrong_direction", st)
	_check(leds.all(func(l): return l.text.contains("TERMINUS")), "wrong-direction LED shows the opposite train's text")
	wrong[0].revert(wrong[1])
	_check(leds.all(func(l): return l.text.contains(next)), "LEDs back after revert")
	for id in ["train_no_driver", "coach_empty"]:
		var data: AnomalyData = load("res://game/data/anomalies/%s.tres" % id)
		_check(data.route_index() == 3, "%s only with the train decision" % id)
	game.free()

func station_spawn(game: Node) -> Transform3D:
	return game.station.spawn.global_transform

func _stick_event(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _key_event(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e

## When nothing that fits this loop is left, only those come back; anomalies shown elsewhere stay seen.
func _test_director_partial_recycle() -> void:
	var mk := func(id: StringName, cat: StringName, loc: StringName) -> AnomalyData:
		var x := AnomalyData.new()
		x.id = id
		x.category = cat
		x.location = loc
		return x
	var a: AnomalyData = mk.call(&"a", &"x", &"concourse")
	var b: AnomalyData = mk.call(&"b", &"y", &"platform")
	var up: AnomalyData = mk.call(&"up", &"z", &"concourse")
	up.tier = 2
	var d := AnomalyDirector.new([a, b, up], 1)
	d.seen = {&"a": true, &"b": true}
	_check(d._candidates(0, 0) == [up], "tier used up: borrows an unshown one from the next tier")
	d.seen[&"up"] = true
	_check(d._candidates(0, 0) == [a] and d.seen.has(&"b"), "a dry gates loop only lets concourse anomalies repeat")
