extends Anomaly
## #45 Everyone freezes mid-step: the walker stops with one foot forward, nobody breathes.
## Slot: Props/Walker (so the replay circles him); every person under Props freezes.

func apply(slot: Node) -> void:
	slot.set_meta("frozen", true)
	for ap: AnimationPlayer in slot.get_parent().find_children("*", "AnimationPlayer", true, false):
		ap.pause()

func revert(slot: Node) -> void:
	slot.set_meta("frozen", false)
	for ap: AnimationPlayer in slot.get_parent().find_children("*", "AnimationPlayer", true, false):
		ap.play()
