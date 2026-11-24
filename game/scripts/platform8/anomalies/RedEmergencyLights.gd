extends Anomaly
## #31 Station lights switch to dim red emergency lighting.

var _state: Dictionary = {}

func apply(slot: Node) -> void:
	for l in slot.get_children():
		if l is OmniLight3D:
			_state[l] = [l.light_color, l.light_energy]
			l.light_color = Color(1.0, 0.08, 0.05)
			l.light_energy = l.light_energy * 0.7

func revert(_slot: Node) -> void:
	for l in _state:
		l.light_color = _state[l][0]
		l.light_energy = _state[l][1]
	_state.clear()
