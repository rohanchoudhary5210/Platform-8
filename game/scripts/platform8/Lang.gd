class_name Lang
extends RefCounted

## UI language: English or Hindi (Devanagari). Covers the HUD hints, rules board, pause menu, end screen
## and home screen. The PA stays bilingual like a real Delhi Metro announcement.
# shortcut: Devanagari renders through the default font's system fallback (Nirmala UI on Windows);
# bundle a Noto Sans Devanagari font if a platform shows boxes.

const CODES := ["en", "hi"]

static var code := "en"

const TEXT := {
	"en": {
		"language": "Language: English",
		"decision_train": "DECISION: TRAIN   ·   nothing wrong → FORWARD (right)   ·   anomaly → OPPOSITE (left)",
		"decision_escalator": "DECISION: ESCALATOR BOTTOM   ·   nothing wrong → walk on to the platform   ·   anomaly → ride back up",
		"decision_gates": "DECISION: AFC GATES   ·   nothing wrong → go through   ·   anomaly → turn back",
		"exit_open": "EXIT IS OPEN   ·   turn around",
		"rules": "Yatri kripya dhyan dein.\nLook carefully as you walk.\nNothing unusual: go FORWARD.\nSomething unusual: turn BACK.\nChoose at the yellow sticker.\nWrong choice: back to the start.\nThe exit opens at STATION 8.",
		"notice": "PASSENGER NOTICE",
		"rule_back": "Something unusual: turn BACK.",
		"rule_lie": "Something unusual: go FORWARD.",
		"paused": "PAUSED",
		"resume": "Resume",
		"restart": "Restart run",
		"hardcore_on": "Hardcore (no HUD): ON",
		"hardcore_off": "Hardcore (no HUD): OFF",
		"quit": "Quit to home",
		"end_title": "YOU MADE IT OUT",
		"end_stats": "time  %s     ·     wrong calls  %d",
		"end_found": "anomalies found this run  %d     ·     Lost & Found  %d / %d",
		"end_seed": "seed %d\n\nPress Enter",
		"home": "No anomaly: go FORWARD.  Anomaly: turn BACK.\nReach station 8 to get out.\n\nPress Enter   ·   L: language",
	},
	"hi": {
		"language": "भाषा: हिंदी",
		"decision_train": "फ़ैसला: ट्रेन   ·   सब ठीक → आगे (दाएँ)   ·   कुछ अजीब → उल्टी दिशा (बाएँ)",
		"decision_escalator": "फ़ैसला: एस्केलेटर के नीचे   ·   सब ठीक → प्लेटफ़ॉर्म पर चलें   ·   कुछ अजीब → वापस ऊपर जाएँ",
		"decision_gates": "फ़ैसला: AFC गेट   ·   सब ठीक → गेट से निकलें   ·   कुछ अजीब → वापस मुड़ें",
		"exit_open": "निकास खुला है   ·   पीछे मुड़ें",
		"rules": "यात्री कृपया ध्यान दें।\nचलते हुए ध्यान से देखें।\nकुछ अजीब नहीं: आगे बढ़ें।\nकुछ अजीब: वापस मुड़ें।\nपीले स्टिकर पर फ़ैसला करें।\nगलत फ़ैसला: शुरुआत में वापस।\nस्टेशन 8 पर निकास खुलेगा।",
		"notice": "यात्री सूचना",
		"rule_back": "कुछ अजीब: वापस मुड़ें।",
		"rule_lie": "कुछ अजीब: आगे बढ़ें।",
		"paused": "रुका हुआ",
		"resume": "जारी रखें",
		"restart": "फिर से शुरू करें",
		"hardcore_on": "हार्डकोर (HUD नहीं): चालू",
		"hardcore_off": "हार्डकोर (HUD नहीं): बंद",
		"quit": "होम पर जाएँ",
		"end_title": "आप बाहर निकल आए",
		"end_stats": "समय  %s     ·     गलत फ़ैसले  %d",
		"end_found": "इस बार मिली गड़बड़ियाँ  %d     ·     Lost & Found  %d / %d",
		"end_seed": "seed %d\n\nEnter दबाएँ",
		"home": "कुछ अजीब नहीं: आगे बढ़ें।  कुछ अजीब: वापस मुड़ें।\nबाहर निकलने के लिए स्टेशन 8 तक पहुँचें।\n\nEnter दबाएँ   ·   L: भाषा",
	},
}

static func t(key: String) -> String:
	return TEXT[code][key]

## Next language in CODES (the toggle in the pause menu and on the home screen).
static func next(c: String) -> String:
	return CODES[(CODES.find(c) + 1) % CODES.size()]
