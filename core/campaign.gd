## Campaign progress for three profile slots: unlocks, best trophies, items,
## boosts, achievements, outfits, tutorials. Pure data, serialisable via to_dict().
class_name Campaign
extends RefCounted

const SLOTS := 3
const TROPHY_RANK := {"": 0, "bronze": 1, "silver": 2, "gold": 3}

var _c: Content
var _profiles: Array = [null, null, null]
var _active := -1


static func create(content: Content, data := {}) -> Campaign:
	var c := Campaign.new()
	c._c = content
	if data.has("profiles"):
		c._profiles = data.profiles.duplicate(true)
		c._active = data.get("active", -1)
	return c


func to_dict() -> Dictionary:
	return {"profiles": _profiles.duplicate(true), "active": _active}


# ---------------------------------------------------------------- profiles

func create_profile(slot: int, name: String, outfit: Dictionary) -> bool:
	if slot < 0 or slot >= SLOTS or _profiles[slot] != null or name.strip_edges() == "":
		return false
	_profiles[slot] = {
		"name": name.strip_edges(),
		"outfit": _default_outfit().merged(outfit, true),
		"best": {},           # level id -> trophy
		"items": {},
		"prepared_boosts": [],
		"stats": {"collected": {}},
		"achievements": [],
		"tutorials": [],
	}
	return true


func delete_profile(slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or _profiles[slot] == null:
		return false
	_profiles[slot] = null
	if _active == slot:
		_active = -1
	return true


func select_profile(slot: int) -> bool:
	if slot < 0 or slot >= SLOTS or _profiles[slot] == null:
		return false
	_active = slot
	return true


func active_slot() -> int:
	return _active


## Read-only copy of a profile, or null if the slot is empty.
func profile(slot: int):
	if slot < 0 or slot >= SLOTS or _profiles[slot] == null:
		return null
	return _profiles[slot].duplicate(true)


func _p() -> Dictionary:
	assert(_active >= 0, "no profile selected")
	return _profiles[_active]


# ---------------------------------------------------------------- progress

func is_level_unlocked(level_id: String) -> bool:
	var i := _c.level_order.find(level_id)
	if i < 0:
		return false
	if i == 0:
		return true
	return _p().best.has(_c.level_order[i - 1])


func is_world_unlocked(world_id: String) -> bool:
	for i in _c.worlds.size():
		if _c.worlds[i].id != world_id:
			continue
		if i == 0:
			return true
		var prev: Array = _c.world_levels[_c.worlds[i - 1].id]
		return not prev.is_empty() and _p().best.has(prev[-1])
	return false


func best_trophy(level_id: String) -> String:
	return _p().best.get(level_id, "")


## Applies a finished level's result. Returns {new_achievements, items_gained}.
func apply_result(result: Dictionary) -> Dictionary:
	var out := {"new_achievements": [], "items_gained": {}}
	if not result.won:
		return out
	var p := _p()
	var old: String = p.best.get(result.level_id, "")
	if TROPHY_RANK[result.trophy] > TROPHY_RANK[old]:
		p.best[result.level_id] = result.trophy
		var before: Dictionary = _c.trophy_rewards.get(old, {}) if old != "" else {}
		var now: Dictionary = _c.trophy_rewards[result.trophy]
		for item in now:
			var gain: int = now[item] - before.get(item, 0)
			if gain > 0:
				out.items_gained[item] = gain
				p.items[item] = p.items.get(item, 0) + gain
	_merge_stats(p.stats, result.get("stats", {}))
	_derive_stats(p)
	for a in _c.achievements:
		if p.achievements.has(a.id):
			continue
		if _stat(p.stats, a.stat) >= a.gte:
			p.achievements.append(a.id)
			out.new_achievements.append(a.id)
	return out


func _merge_stats(into: Dictionary, add: Dictionary) -> void:
	for k in add:
		if add[k] is Dictionary:
			if not into.has(k):
				into[k] = {}
			_merge_stats(into[k], add[k])
		else:
			into[k] = into.get(k, 0) + add[k]


func _derive_stats(p: Dictionary) -> void:
	p.stats.levels_won = p.best.size()
	var gold: Array = p.best.values().filter(func(t): return t == "gold")
	p.stats.gold_trophies = gold.size()
	for w in _c.worlds:
		p.stats["gold_trophies_" + w.id] = _c.world_levels[w.id].filter(func(l): return p.best.get(l, "") == "gold").size()


static func _stat(stats: Dictionary, path: String) -> int:
	var v = stats
	for part in path.split("."):
		if not (v is Dictionary) or not v.has(part):
			return 0
		v = v[part]
	return v if typeof(v) == TYPE_INT else 0


func achievements() -> Array:
	var p := _p()
	return _c.achievements.map(func(a): return {"id": a.id, "stat": a.stat, "gte": a.gte,
		"progress": mini(_stat(p.stats, a.stat), a.gte), "unlocked": p.achievements.has(a.id)})


# ---------------------------------------------------------------- items & boosts

func items() -> Dictionary:
	return _p().items.duplicate()


func prepare_boost(boost_id: String) -> bool:
	var b = _c.boosts.get(boost_id)
	var p := _p()
	if b == null or p.prepared_boosts.has(boost_id):
		return false
	for i in b.cost:
		if p.items.get(i, 0) < b.cost[i]:
			return false
	for i in b.cost:
		p.items[i] -= b.cost[i]
	p.prepared_boosts.append(boost_id)
	return true


func prepared_boosts() -> Array:
	return _p().prepared_boosts.duplicate()


## Boosts are consumed when a level starts.
func take_prepared_boosts() -> Array:
	var p := _p()
	var b: Array = p.prepared_boosts
	p.prepared_boosts = []
	return b


# ---------------------------------------------------------------- outfit & tutorials

func is_outfit_unlocked(slot_id: String, option_id: String) -> bool:
	for slot in _c.outfits:
		if slot.id != slot_id:
			continue
		for o in slot.options:
			if o.id == option_id:
				return o.unlock == "" or (_active >= 0 and _p().achievements.has(o.unlock))
	return false


func set_outfit(slot_id: String, option_id: String) -> bool:
	if not is_outfit_unlocked(slot_id, option_id):
		return false
	_p().outfit[slot_id] = option_id
	return true


func _default_outfit() -> Dictionary:
	var d := {}
	for slot in _c.outfits:
		d[slot.id] = slot.options[0].id
	return d


func is_tutorial_done(id: String) -> bool:
	return _p().tutorials.has(id)


func mark_tutorial_done(id: String) -> void:
	if not _p().tutorials.has(id):
		_p().tutorials.append(id)
