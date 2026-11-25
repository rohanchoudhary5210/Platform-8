extends Anomaly
## #34 The stairs down to the subway have more steps than usual: same drop, same length, cut finer.
## Swaps the stairs model for stairs_extra (art/build_props.py). Slot: Props/Stairs.

func apply(slot: Node) -> void:
	slot.get_node("Normal").visible = false
	slot.get_node("Extra").visible = true

func revert(slot: Node) -> void:
	slot.get_node("Normal").visible = true
	slot.get_node("Extra").visible = false
