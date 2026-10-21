extends TestCase


func test_buy_animal_costs_money_and_adds_animal() -> void:
	var s := core().start_session(level({"start_money": 250}), 1)
	check(s.apply(Cmd.buy_animal("chicken")), "buy ok")
	var st := s.state()
	check_eq(st.money, 150)
	check_eq(st.animals.size(), 1)
	check(not s.apply(Cmd.buy_animal("pig")), "cannot afford pig")


func test_animal_not_available_in_level_cannot_be_bought() -> void:
	var s := core().start_session(level({"available_animals": ["chicken"]}), 1)
	check(not s.apply(Cmd.buy_animal("sheep")))


func test_fed_animal_produces_then_gets_hungry() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 5)
	s.advance(95)
	check_eq(events_of(s.poll_events(), "product_spawned").size(), 1, "egg after 9.5 s")
	check_eq(s.state().ground[0].product, "egg")
	s.advance(5)
	check_eq(events_of(s.poll_events(), "animal_hungry").size(), 1, "hungry after 10 s")
	check(s.state().animals[0].hungry, "hungry flag")


func test_hungry_animal_does_not_produce_and_falls_asleep_instead_of_dying() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 3)
	s.advance(100)
	s.poll_events()
	s.advance(1000)
	var evts := s.poll_events()
	check_eq(events_of(evts, "product_spawned").size(), 0, "no eggs while hungry")
	check_eq(events_of(evts, "animal_asleep").size(), 1, "dozed off")
	check_eq(s.state().animals.size(), 1, "still alive")
	check(s.state().animals[0].asleep)


func test_grass_wakes_and_feeds_hungry_animal() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 7)
	s.advance(200)
	var a: Dictionary = s.state().animals[0]
	check(a.asleep, "asleep first")
	check(s.apply(Cmd.plant_grass(a.x / 100, a.y / 100)), "plant ok")
	check_eq(s.state().well.water, 4, "water used")
	var before: int = s.state().grass_total
	s.advance(40)
	var st := s.state()
	check(not st.animals[0].hungry, "fed")
	check(not st.animals[0].asleep, "awake")
	check_eq(before - st.grass_total, 1, "one bite of grass eaten")


func test_cow_needs_four_bites_of_grass() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "cow", "count": 1}]}), 7)
	s.advance(200)
	var a: Dictionary = s.state().animals[0]
	s.apply(Cmd.plant_grass(a.x / 100, a.y / 100))
	var before: int = s.state().grass_total
	s.advance(80)
	check(not s.state().animals[0].hungry, "fed")
	check_eq(before - s.state().grass_total, 4, "four bites")


func test_well_runs_dry_and_refills_for_money() -> void:
	var s := core().start_session(level({"start_money": 100}), 1)
	for i in 5:
		check(s.apply(Cmd.plant_grass(i * 2, 0)))
	check(not s.apply(Cmd.plant_grass(12, 0)), "well dry")
	check(s.apply(Cmd.refill_well()))
	check_eq(s.state().money, 85)
	check(not s.apply(Cmd.plant_grass(12, 0)), "still refilling")
	s.advance(50)
	check_eq(s.state().well.water, 5)
	check(s.apply(Cmd.plant_grass(12, 0)))


func test_well_upgrade_holds_more_water() -> void:
	var s := core().start_session(level(), 1)
	check(s.apply(Cmd.upgrade_well()))
	check_eq(s.state().well.level, 2)
	check_eq(s.state().well.capacity, 7)
	check_eq(s.state().well.water, 7)
	check_eq(s.state().money, 850)
	var capped := core().start_session(level({"max_level": {}}), 1)
	check(not capped.apply(Cmd.upgrade_well()), "level caps upgrades")


func test_uncollected_product_expires() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 5)
	s.advance(95)
	s.poll_events()
	s.advance(200)
	check_eq(events_of(s.poll_events(), "product_expired").size(), 1)


func test_sell_animal_refunds_sell_price() -> void:
	var s := core().start_session(level({"start_money": 100}), 1)
	s.apply(Cmd.buy_animal("chicken"))
	var uid: int = s.state().animals[0].uid
	check(s.apply(Cmd.sell_animal(uid)))
	check_eq(s.state().money, 50)
	check_eq(s.state().animals.size(), 0)


func test_cat_carries_goods_to_the_warehouse() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 2}, {"type": "cat", "count": 1}]}), 4)
	s.advance(300)
	check(s.state().warehouse.items.get("egg", 0) >= 1, "cat stored eggs")
	check(s.state().goals[0].progress >= 1, "counts for the goal")
