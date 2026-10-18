extends TestCase


func _buy_and_collect(s: LevelSession, product: String, n: int) -> void:
	s.apply(Cmd.buy_from_city(product, n))
	s.advance(120)
	for g in s.state().ground:
		s.apply(Cmd.collect(g.uid))


func test_level_won_when_all_goals_met_with_gold_trophy() -> void:
	var lvl := level({"start_animals": [{"type": "chicken", "count": 1}],
		"goals": [{"type": "collect", "product": "egg", "count": 1}, {"type": "animal", "animal": "chicken", "count": 2}]})
	var s := core().start_session(lvl, 5)
	s.advance(150)
	s.apply(Cmd.collect(s.state().ground[0].uid))
	var evts := s.poll_events()
	check_eq(events_of(evts, "goal_reached").size(), 1)
	check(not s.is_won())
	check_eq(s.state().trophy_now, "gold")
	s.apply(Cmd.buy_animal("chicken"))
	evts = s.poll_events()
	check_eq(events_of(evts, "level_won").size(), 1)
	check(s.is_won())
	var r := s.result()
	check_eq(r.trophy, "gold")
	check_eq(r.ticks, 150)
	check_eq(r.level_id, "test_level")


func test_products_bought_in_town_do_not_count_for_collect_goals() -> void:
	var s := core().start_session(level({"goals": [{"type": "collect", "product": "egg", "count": 2}]}), 1)
	_buy_and_collect(s, "egg", 2)
	check_eq(s.state().warehouse.items.get("egg", 0), 2, "stored")
	check_eq(s.state().goals[0].progress, 0, "not counted")


func test_slow_win_still_wins_with_lower_trophy() -> void:
	var lvl := level({"goals": [{"type": "money", "amount": 1000}], "start_money": 990, "trophy": {"gold_ticks": 10, "silver_ticks": 20}})
	var s := core().start_session(lvl, 1)
	s.advance(15)
	check_eq(s.state().trophy_now, "silver")
	for i in 25:
		s.apply(Cmd.tap())
	check(s.is_won())
	check_eq(s.result().trophy, "silver")
	var s2 := core().start_session(lvl, 1)
	s2.advance(50)
	for i in 25:
		s2.apply(Cmd.tap())
	check_eq(s2.result().trophy, "bronze")


func test_won_session_ignores_further_commands_and_time() -> void:
	var s := core().start_session(level({"goals": [{"type": "money", "amount": 1}]}), 1)
	s.advance(1)
	check(s.is_won())
	check(not s.apply(Cmd.buy_animal("chicken")))
	s.advance(100)
	check_eq(s.state().tick, 0)


func test_state_exposes_goal_progress_and_trophy_limits() -> void:
	var s := core().start_session(level({"goals": [{"type": "collect", "product": "egg", "count": 3}]}), 1)
	var st := s.state()
	check_eq(st.goals[0].target, 3)
	check_eq(st.goals[0].progress, 0)
	check_eq(st.trophy.gold_ticks, 1000)


func test_boost_start_money_and_fast_production_expires() -> void:
	var lvl := level({"start_animals": [{"type": "chicken", "count": 1}]})
	var s := core().start_session(lvl, 5, ["start_money", "fast_animals"])
	check_eq(s.state().money, 1300)
	check_eq(s.state().boosts.size(), 1, "only timed boosts listed")
	check_eq(s.state().boosts[0].left, 1200)
	s.advance(101)
	check_eq(events_of(s.poll_events(), "product_spawned").size(), 1, "egg at 1.5x speed")
	s.advance(1100)
	check_eq(events_of(s.poll_events(), "boost_expired").size(), 1)
	check_eq(s.state().boosts.size(), 0)


func test_big_warehouse_boost() -> void:
	var s := core().start_session(level(), 1, ["big_warehouse"])
	check_eq(s.state().warehouse.capacity, 30)
