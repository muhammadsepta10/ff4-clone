extends TestCase


func _campaign() -> Campaign:
	var c := core().new_campaign()
	c.create_profile(0, "Ana", {"hat": "straw", "shirt": "plaid", "color": "red"})
	c.select_profile(0)
	return c


func _win(level_id: String, trophy: String, stats := {}) -> Dictionary:
	var ticks: int = {"gold": 100, "silver": 1500, "bronze": 5000}[trophy]
	return {"level_id": level_id, "won": true, "ticks": ticks, "trophy": trophy, "money": 500, "stats": stats}


func test_first_level_unlocked_and_win_unlocks_next() -> void:
	var c := _campaign()
	check(c.is_level_unlocked("w1_l1"))
	check(not c.is_level_unlocked("w1_l2"))
	c.apply_result(_win("w1_l1", "bronze"))
	check(c.is_level_unlocked("w1_l2"))
	check_eq(c.best_trophy("w1_l1"), "bronze")


func test_world_unlocks_after_last_level_of_previous_world() -> void:
	var c := _campaign()
	check(c.is_world_unlocked("w1"))
	check(not c.is_world_unlocked("w2"))
	for i in range(1, 6):
		c.apply_result(_win("w1_l%d" % i, "silver"))
	check(c.is_world_unlocked("w2"))


func test_best_trophy_never_drops_on_replay() -> void:
	var c := _campaign()
	c.apply_result(_win("w1_l1", "gold"))
	c.apply_result(_win("w1_l1", "bronze"))
	check_eq(c.best_trophy("w1_l1"), "gold")


func test_trophy_improvement_awards_items_once() -> void:
	var c := _campaign()
	var r := c.apply_result(_win("w1_l1", "silver"))
	check_eq(r.items_gained, {"clover": 1})
	r = c.apply_result(_win("w1_l1", "silver"))
	check_eq(r.items_gained, {})
	r = c.apply_result(_win("w1_l1", "gold"))
	check_eq(r.items_gained, {"clover": 1, "acorn": 1}, "only the difference")
	check_eq(c.items(), {"clover": 2, "acorn": 1})


func test_items_exchanged_for_boost() -> void:
	var c := _campaign()
	check(not c.prepare_boost("start_money"), "no items")
	c.apply_result(_win("w1_l1", "gold"))
	check(c.prepare_boost("start_money"))
	check(c.prepare_boost("big_warehouse"))
	check(not c.prepare_boost("fast_workshops"), "acorn used up")
	check_eq(c.take_prepared_boosts(), ["start_money", "big_warehouse"])
	check_eq(c.take_prepared_boosts(), [])
	check_eq(c.items(), {"clover": 0, "acorn": 0})


func test_achievement_unlocks_once() -> void:
	var c := _campaign()
	var r := c.apply_result(_win("w1_l1", "bronze", {"collected": {"egg": 30}}))
	check(r.new_achievements.has("ach_win_1"))
	check(r.new_achievements.has("ach_egg_25"))
	r = c.apply_result(_win("w1_l1", "bronze"))
	check(not r.new_achievements.has("ach_win_1"))
	var status := c.achievements()
	check_eq(status.size(), 40)
	check(status.filter(func(a): return a.unlocked).size() >= 2)


func test_lost_or_abandoned_result_changes_nothing() -> void:
	var c := _campaign()
	c.apply_result({"level_id": "w1_l1", "won": false, "ticks": 10, "trophy": "", "money": 0, "stats": {}})
	check(not c.is_level_unlocked("w1_l2"))


func test_three_profiles_are_isolated() -> void:
	var c := _campaign()
	c.apply_result(_win("w1_l1", "gold"))
	c.create_profile(1, "Budi", {"hat": "cap", "shirt": "overall", "color": "blue"})
	c.select_profile(1)
	check(not c.is_level_unlocked("w1_l2"))
	check_eq(c.items(), {})
	check(not c.create_profile(3, "X", {}), "only three slots")
	c.select_profile(0)
	check(c.is_level_unlocked("w1_l2"))


func test_delete_profile_frees_slot() -> void:
	var c := _campaign()
	check(c.delete_profile(0))
	check(c.profile(0) == null)
	check(c.create_profile(0, "Citra", {"hat": "straw", "shirt": "plaid", "color": "red"}))


func test_outfit_change_respects_unlocks() -> void:
	var c := _campaign()
	check(c.set_outfit("hat", "cap"))
	check(not c.set_outfit("hat", "crown"), "locked")
	check(not c.set_outfit("hat", "nope"))
	check_eq(c.profile(0).outfit.hat, "cap")


func test_tutorial_marked_done_stays_done() -> void:
	var c := _campaign()
	check(not c.is_tutorial_done("plant_grass"))
	c.mark_tutorial_done("plant_grass")
	check(c.is_tutorial_done("plant_grass"))


func test_campaign_round_trips_through_dict() -> void:
	var c := _campaign()
	c.apply_result(_win("w1_l1", "gold"))
	c.mark_tutorial_done("collect")
	var d := core().load_campaign(str_to_var(var_to_str(c.to_dict())))
	check(d.is_level_unlocked("w1_l2"))
	check(d.is_tutorial_done("collect"))
	check_eq(d.best_trophy("w1_l1"), "gold")
