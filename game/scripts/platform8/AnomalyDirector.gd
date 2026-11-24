class_name AnomalyDirector
extends RefCounted

## Picks 0 or 1 anomaly per loop. Rules (GDD): first loop is empty, ~30% empty loops,
## never more than 2 empty in a row, no category back to back, no repeat of seen anomalies,
## tier follows the station count. Seeded per run so a run can be replayed.

const EMPTY_CHANCE := 0.3
const MAX_EMPTY_STREAK := 2

var seed_value: int
var seen: Dictionary = {}   # id -> true
var found: Dictionary = {}  # id -> true

var _pool: Array
var _rng := RandomNumberGenerator.new()
var _picks := 0
var _empty_streak := 0
var _last_category: StringName = &""

func _init(pool: Array, p_seed: int = 0) -> void:
	_pool = pool
	seed_value = p_seed if p_seed != 0 else randi()
	_rng.seed = seed_value

static func tier_for(count: int) -> int:
	if count <= 3:
		return 1
	return 2 if count <= 6 else 3

func pick(count: int) -> AnomalyData:
	_picks += 1
	if _picks == 1:
		return _empty()
	var candidates := _candidates(count)
	var must_fill := _empty_streak >= MAX_EMPTY_STREAK
	if candidates.is_empty() or (not must_fill and _rng.randf() < EMPTY_CHANCE):
		return _empty()
	var a: AnomalyData = candidates[_rng.randi_range(0, candidates.size() - 1)]
	seen[a.id] = true
	_last_category = a.category
	_empty_streak = 0
	return a

func mark_found(id: StringName) -> void:
	found[id] = true

func _empty() -> AnomalyData:
	_empty_streak += 1
	return null

func _candidates(count: int) -> Array:
	var c := _filter(count)
	if c.is_empty():
		# shortcut: recycles seen anomalies once the pool runs dry; rare once the pool is ~50 (Week 2+).
		seen.clear()
		c = _filter(count)
	return c

func _filter(count: int) -> Array:
	var tier := tier_for(count)
	var ok := func(a: AnomalyData) -> bool:
		return not seen.has(a.id) and a.category != _last_category and a.solo_ok
	var exact := _pool.filter(func(a): return a.tier == tier and ok.call(a))
	if not exact.is_empty():
		return exact
	return _pool.filter(func(a): return a.tier < tier and ok.call(a))
