extends Anomaly
## #46 The rules notice by the spawn has one rule changed: "Something unusual: go FORWARD."
## Obeying it is the trap. Works in either UI language (Lang). Slot: Props/RulesBoard/Text.

var _old := ""

func apply(slot: Node) -> void:
	_old = slot.text
	slot.text = _old.replace(Lang.t("rule_back"), Lang.t("rule_lie"))

func revert(slot: Node) -> void:
	slot.text = _old
