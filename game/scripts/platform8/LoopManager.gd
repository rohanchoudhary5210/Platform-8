class_name LoopManager
extends RefCounted

## Station count and the train decision. Right call: count + 1 and the next station.
## Wrong call: count back to 0 and the player comes back to the same station.

const GOAL := 8
## Fictional line, index = count. No real metro names.
const STATION_NAMES := [
	"Kalindi Bagh", "Roshanpura", "Neel Chowk", "Sitara Nagar", "Purana Ghat",
	"Chandni Marg", "Lal Kuan Vihar", "Taramandal", "Antim Dwar",
]
const LINE_COLOURS := [
	Color("d6336c"), Color("f08c00"), Color("2f9e44"), Color("1971c2"), Color("7048e8"),
	Color("0c8599"), Color("e8590c"), Color("c2255c"), Color("f5f5f5"),
]

var count := 0
var station_name: String = STATION_NAMES[0]
var current: AnomalyData = null

## took_back: true if the player took the back choice (opposite train, up the escalator, back from the gates).
func resolve(took_back: bool) -> bool:
	var correct := took_back == (current != null)
	if correct:
		count += 1
		station_name = STATION_NAMES[count]
	else:
		count = 0  # station_name stays: same station again
	return correct

func line_colour() -> Color:
	return LINE_COLOURS[count]

func is_complete() -> bool:
	return count >= GOAL

## Decision points and the station count they unlock at (GDD). Passage junction (5) isn't built yet.
const DECISIONS := {&"train": 0, &"escalator": 2, &"gates": 3}
## Furthest AnomalyData.ROUTE index the player passes before reaching each decision point.
const DECISION_REACH := {&"train": 3, &"escalator": 2, &"gates": 0}

var decision: StringName = &"train"
var _rng := RandomNumberGenerator.new()

func seed_decisions(s: int) -> void:
	_rng.seed = s

func pick_decision() -> StringName:
	var open := DECISIONS.keys().filter(func(k): return count >= DECISIONS[k])
	decision = open[_rng.randi_range(0, open.size() - 1)]
	return decision

func next_station_name() -> String:
	return STATION_NAMES[mini(count + 1, GOAL)]
