extends Anomaly
## #23 The token machine won't stop dispensing: a token every 0.3 s, until they spill over the floor.
## Slot: Props/TokenMachine.

var _tween: Tween

func apply(slot: Node) -> void:
	var tvm: TokenMachine = slot
	tvm.dispense()
	_tween = tvm.create_tween().set_loops()
	_tween.tween_interval(0.3)
	_tween.tween_callback(tvm.dispense)

func revert(slot: Node) -> void:
	_tween.kill()
	(slot as TokenMachine).clear_tokens()
