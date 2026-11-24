class_name Anomaly
extends RefCounted

## Base for every anomaly. apply() changes the slot node; revert() must put it back exactly
## (tests/test_platform8.gd checks this for every anomaly in AnomalyCatalog).

func apply(_slot: Node) -> void:
	pass

func revert(_slot: Node) -> void:
	pass
