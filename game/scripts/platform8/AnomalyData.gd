class_name AnomalyData
extends Resource

## One anomaly's definition. The behaviour lives in the script at script_path (an Anomaly subclass).

## Route order. An anomaly can only be picked if its location comes before the loop's decision point.
const ROUTE: Array[StringName] = [&"concourse", &"passage", &"escalator", &"platform"]

@export var id: StringName
@export var display_name: String
## One of the GDD's 12 categories. Same category is never picked twice in a row.
@export var category: StringName
## 1 = Subtle (count 0–3), 2 = Creepy (4–6), 3 = Intense (7–8).
@export_range(1, 3) var tier: int = 1
## Can it be the only anomaly in a loop (all solo anomalies are).
@export var solo_ok: bool = true
## first_person / cctv / both (co-op). Solo uses "both" only.
@export var visible_on: StringName = &"both"
## Route section where the player first sees it (see ROUTE).
@export var location: StringName = &"concourse"
@export_file("*.gd") var script_path: String
## Node inside Station that apply()/revert() receive ("." = the Station, "../HUD/X" = a HUD label).
@export var slot_name: NodePath
## Extra settings for data-driven scripts like SetProperty.
@export var params: Dictionary = {}

func route_index() -> int:
	return ROUTE.find(location)
