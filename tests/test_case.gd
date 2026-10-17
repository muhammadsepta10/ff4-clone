## Base class for headless tests. Tests only talk to GameCore (see PRD, Testing Decisions).
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var current_test := ""


func check(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%s: %s" % [current_test, msg if msg != "" else "expected true"])


func check_eq(actual, expected, msg := "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		failures.append("%s: %s expected %s (%s) got %s (%s)" % [current_test, msg, expected, type_string(typeof(expected)), actual, type_string(typeof(actual))])
	elif actual != expected:
		failures.append("%s: %s expected %s got %s" % [current_test, msg, expected, actual])


func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Shared helpers: real catalogs, tiny test levels.
static var _core_cache: GameCore


func core() -> GameCore:
	if _core_cache == null:
		_core_cache = GameCore.from_content_dir("res://content")
		assert(_core_cache.content_errors().is_empty(), str(_core_cache.content_errors()))
	return _core_cache


func level(overrides := {}) -> Dictionary:
	var base := {
		"id": "test_level",
		"world": "w1",
		"start_money": 1000,
		"start_animals": [],
		"available_animals": ["chicken", "cow", "sheep"],
		"available_workshops": ["bakery", "dairy", "loom", "creamery"],
		"workshop_slots": 3,
		"allow_hybrids": false,
		"goals": [{"type": "collect", "product": "egg", "count": 999}],
		"predators": [],
		"hidden_items": [],
		"trophy": {"gold_ticks": 1000, "silver_ticks": 2000},
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


func events_of(evts: Array, type: String) -> Array:
	return evts.filter(func(e): return e.type == type)
