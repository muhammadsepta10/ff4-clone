extends TestCase


func test_shipped_content_passes_schema_and_references() -> void:
	check_eq(core().content_errors(), [])


func test_world1_has_levels_and_40_achievements() -> void:
	check(core().level_ids_in_world("w1").size() >= 5)
	check_eq(core().catalog().achievements.size(), 40)


func test_broken_content_is_rejected() -> void:
	var errs := GameCore.from_content_dir("res://tests/fixtures/bad_schema").content_errors()
	check(errs.any(func(e): return e.contains("sell_price")), "type error found: %s" % [errs])
	errs = GameCore.from_content_dir("res://tests/fixtures/bad_refs").content_errors()
	check(errs.any(func(e): return e.contains("unknown product")), "bad reference found: %s" % [errs])


func test_bot_wins_every_level_with_several_seeds() -> void:
	for id in core().all_level_ids():
		for seed in [1, 2, 3]:
			var r := Bot.play(core(), core().get_level(id), seed)
			check(r.won, "%s seed %d not won" % [id, seed])


func test_trophy_limits_consistent_with_bot_time() -> void:
	for id in core().all_level_ids():
		var lvl := core().get_level(id)
		var t := Balancer.bot_ticks(core(), lvl)
		var expect := Balancer.trophy_for(t)
		check_eq(lvl.trophy, expect, id)
