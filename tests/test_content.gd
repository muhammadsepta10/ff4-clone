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


func test_campaign_has_90_levels_in_four_worlds() -> void:
	check_eq(core().all_level_ids().size(), 90)
	for w in ["w1", "w2", "w3", "w4"]:
		check(core().level_ids_in_world(w).size() > 0, w)


func test_bot_wins_first_levels() -> void:
	# Every level is checked by tools/balance.gd in CI; this keeps the
	# test run short.
	for id in ["l1", "l2", "l3", "l4", "l5"]:
		var r := Bot.play(core(), core().get_level(id), 1)
		check(r.won, "%s not won" % id)
