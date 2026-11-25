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
var excluded: Dictionary = {}  # id -> true, never picked (e.g. HUD anomalies in hardcore mode)

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

## max_location: furthest ROUTE index the player passes before this loop's decision point.
func pick(count: int, max_location: int = AnomalyData.ROUTE.size() - 1) -> AnomalyData:
	_picks += 1
	if _picks == 1:
		return _empty()
	var candidates := _candidates(count, max_location)
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

func _candidates(count: int, max_location: int) -> Array:
	var c := _filter(count, max_location)
	# This tier (and the ones below) is used up: borrow an unshown one from the nearest tier above.
	var t := tier_for(count) + 1
	while c.is_empty() and t <= 3:
		c = _pool.filter(func(a): return a.tier == t and _fits(a, max_location, false))
		t += 1
	if c.is_empty():
		# Everything that fits this loop (any tier, location, decision) was shown already: only those may
		# come back. The rest stay seen, so nothing repeats while an unshown one could still be picked.
		c = _filter(count, max_location, true)
		for a: AnomalyData in c:
			seen.erase(a.id)
	return c

func _filter(count: int, max_location: int, allow_seen := false) -> Array:
	var tier := tier_for(count)
	var exact := _pool.filter(func(a): return a.tier == tier and _fits(a, max_location, allow_seen))
	if not exact.is_empty():
		return exact
	return _pool.filter(func(a): return a.tier < tier and _fits(a, max_location, allow_seen))

func _fits(a: AnomalyData, max_location: int, allow_seen: bool) -> bool:
	return (allow_seen or not seen.has(a.id)) and not excluded.has(a.id) and a.category != _last_category and a.solo_ok \
			and a.route_index() <= max_location and max_location <= a.max_decision_reach
