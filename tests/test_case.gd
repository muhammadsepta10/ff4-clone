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
		"scene": "grand_farm",
		"giver": "sari",
		"story_key": "story_l1",
		"start_money": 1000,
		"start_animals": [],
		"available_animals": ["chicken", "pig", "sheep", "cow", "cat", "dog"],
		"well_level": 1,
		"warehouse_level": 1,
		"slots": [[{"type": "mixer", "level": 0}], [{"type": "bakery", "level": 0}, {"type": "butchery", "level": 0}], [], [], [], []],
		"truck": true,
		"plane": true,
		"max_level": {"well": 4, "warehouse": 4, "truck": 4, "plane": 4, "mixer": 4, "bakery": 4, "butchery": 4},
		"goals": [{"type": "collect", "product": "egg", "count": 999}],
		"predators": [],
		"hidden_items": [],
		"trophy": {"gold_ticks": 1000, "silver_ticks": 2000},
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


## Buys goods by plane and stores them; returns after the plane is back.
func fly_in(s: LevelSession, product: String, n: int) -> void:
	for i in n:
		s.apply(Cmd.order_plane(product, 1))
	s.apply(Cmd.send_plane())
	s.advance(s.state().plane.trip_ticks)
	for g in s.state().ground:
		s.apply(Cmd.collect(g.uid))


func events_of(evts: Array, type: String) -> Array:
	return evts.filter(func(e): return e.type == type)
