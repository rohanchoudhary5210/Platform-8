extends Anomaly
## Data-driven anomaly: sets one property on the slot.
## data.params = {"property": "text" | "visible" | "position:x" | "material:albedo_color" | "metadata/x", "value": ...}

var _old: Variant

func apply(slot: Node) -> void:
	_old = slot.get_indexed(data.params.property)
	slot.set_indexed(data.params.property, data.params.value)

func revert(slot: Node) -> void:
	slot.set_indexed(data.params.property, _old)
