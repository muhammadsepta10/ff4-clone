## GameCore: the only seam between the headless game rules and everything else
## (view, bot, validator, tests). Pure GDScript, no Nodes (ADR 0005).
class_name GameCore
extends RefCounted

var _content: Content


static func from_content_dir(dir: String) -> GameCore:
	var g := GameCore.new()
	g._content = Content.load_dir(dir)
	return g


func content_errors() -> Array[String]:
	return _content.errors


## Read-only catalogs (products, animals, workshops, farm, boosts, ...).
func catalog() -> Content:
	return _content


func all_level_ids() -> Array:
	return _content.level_order.duplicate()


func level_ids_in_world(world_id: String) -> Array:
	return _content.world_levels.get(world_id, []).duplicate()


func get_level(level_id: String) -> Dictionary:
	return _content.levels[level_id].duplicate(true)


func worlds() -> Array:
	return _content.worlds.duplicate(true)


func start_session(level: Dictionary, seed: int, boost_ids: Array = []) -> LevelSession:
	return LevelSession.create(_content, level, seed, boost_ids)


func start_level(level_id: String, seed: int, boost_ids: Array = []) -> LevelSession:
	return start_session(get_level(level_id), seed, boost_ids)


func restore_session(snapshot: Dictionary) -> LevelSession:
	return LevelSession.restore(_content, snapshot)


func new_campaign() -> Campaign:
	return Campaign.create(_content)


func load_campaign(data: Dictionary) -> Campaign:
	return Campaign.create(_content, data)
