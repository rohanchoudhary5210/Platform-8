class_name Anomaly
extends RefCounted

## Base for every anomaly. apply() changes the slot node; revert() must put it back exactly
## (tests/test_platform8.gd checks this for every anomaly in AnomalyCatalog).

var data: AnomalyData

static func create(d: AnomalyData) -> Anomaly:
	var a: Anomaly = load(d.script_path).new()
	a.data = d
	return a

func apply(_slot: Node) -> void:
	pass

func revert(_slot: Node) -> void:
	pass

## A HUD label owned by Game (sibling of the Station), or null when there is no HUD.
static func hud_label(slot: Node, label: String) -> Label:
	var n := station_of(slot)
	return n.get_node_or_null("../HUD/" + label) if n else null

static func station_of(slot: Node) -> Station:
	var n := slot
	while n != null and not (n is Station):
		n = n.get_parent()
	return n

static func player_of(slot: Node) -> StationPlayer:
	return slot.get_tree().get_first_node_in_group(&"player") as StationPlayer

## True when pos is on the player's screen (walls in between are ignored).
static func in_view(slot: Node, pos: Vector3) -> bool:
	var p := player_of(slot)
	return p != null and p.camera.is_position_in_frustum(pos)

## True when the player looks almost straight at pos (within about 15 degrees).
static func looked_at(slot: Node, pos: Vector3) -> bool:
	var p := player_of(slot)
	if p == null:
		return false
	return -p.camera.global_basis.z.dot((pos - p.camera.global_position).normalized()) > 0.966

## Danger anomalies call this when the threat reaches the player: it counts as taking the forward
## choice, so a wrong call (count back to 0, replay, same station). Ignored if the player already chose.
static func caught(slot: Node) -> void:
	var s := station_of(slot)
	if s:
		s.decided.emit(false)
