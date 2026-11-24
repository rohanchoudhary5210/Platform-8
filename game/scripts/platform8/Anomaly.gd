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
	var n := slot
	while n != null and not (n is Station):
		n = n.get_parent()
	return n.get_node_or_null("../HUD/" + label) if n else null
