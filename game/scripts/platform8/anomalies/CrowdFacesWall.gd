extends Anomaly
## #20 Everyone in the station stands facing the same blank wall. Slot: Props/People.

const WALL_YAW := PI / 2  # facing +X, the right-hand wall

var _yaws := {}

func apply(slot: Node) -> void:
	for p: Node3D in slot.get_children():
		_yaws[p] = p.rotation.y
		p.rotation.y = WALL_YAW

func revert(_slot: Node) -> void:
	for p: Node3D in _yaws:
		p.rotation.y = _yaws[p]
	_yaws.clear()
