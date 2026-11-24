class_name SaveData
extends RefCounted

## The one versioned save file (GDD): found anomalies, best run, settings.
# shortcut: a plain ConfigFile instead of the template's SaveManager/DataManager (cloud sync, profiles);
# move it there if Platform 8 ever needs cloud saves.

const PATH := "user://platform8_save.cfg"
const VERSION := 1

var path := PATH
var found: Dictionary = {}  # anomaly id (String) -> true, across all runs
var best_station := 0       # highest station count reached
var clears := 0             # times the player got out
var best_time := 0.0        # fastest clear in seconds, 0 = none yet
var mouse_sensitivity := 1.0
var volume_db := 0.0

static func open(p: String = PATH) -> SaveData:
	var s := SaveData.new()
	s.path = p
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK or int(cfg.get_value("meta", "version", 0)) > VERSION:
		return s  # missing, unreadable or from a newer build: start fresh rather than misread it
	for id in cfg.get_value("progress", "found", PackedStringArray()):
		s.found[id] = true
	s.best_station = int(cfg.get_value("progress", "best_station", 0))
	s.clears = int(cfg.get_value("progress", "clears", 0))
	s.best_time = float(cfg.get_value("progress", "best_time", 0.0))
	s.mouse_sensitivity = clampf(float(cfg.get_value("settings", "mouse_sensitivity", 1.0)), 0.2, 3.0)
	s.volume_db = clampf(float(cfg.get_value("settings", "volume_db", 0.0)), -40.0, 6.0)
	return s

func write() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "found", PackedStringArray(found.keys()))
	cfg.set_value("progress", "best_station", best_station)
	cfg.set_value("progress", "clears", clears)
	cfg.set_value("progress", "best_time", best_time)
	cfg.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("settings", "volume_db", volume_db)
	return cfg.save(path)

## Found anomalies that still exist in this build (old saves may list removed ones).
func found_count() -> int:
	return AnomalyCatalog.ALL.filter(func(d): return found.has(String(d.id))).size()

func record_clear(seconds: float) -> void:
	clears += 1
	if best_time == 0.0 or seconds < best_time:
		best_time = seconds

static func format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
