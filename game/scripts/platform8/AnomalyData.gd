class_name AnomalyData
extends Resource

## One anomaly's definition. The behaviour lives in the script at script_path (an Anomaly subclass).

@export var id: StringName
@export var display_name: String
## Same category is never picked twice in a row.
@export var category: StringName
## 1 = Subtle (count 0–3), 2 = Creepy (4–6), 3 = Intense (7–8).
@export_range(1, 3) var tier: int = 1
## Can it be the only anomaly in a loop (all Week 1 anomalies are).
@export var solo_ok: bool = true
## Route section where the player sees it: concourse / passage / escalator / platform.
@export var visible_on: StringName
@export_file("*.gd") var script_path: String
## Node inside Station that apply()/revert() receive.
@export var slot_name: NodePath
