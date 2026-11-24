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

## took_opposite: true if the player boarded the opposite train. Returns whether it was right.
func resolve(took_opposite: bool) -> bool:
	var correct := took_opposite == (current != null)
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
