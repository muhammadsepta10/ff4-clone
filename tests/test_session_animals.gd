extends TestCase


func test_buy_animal_costs_money_and_adds_animal() -> void:
	var s := core().start_session(level({"start_money": 250}), 1)
	check(s.apply(Cmd.buy_animal("chicken")), "buy ok")
	var st := s.state()
	check_eq(st.money, 150)
	check_eq(st.animals.size(), 1)
	check(not s.apply(Cmd.buy_animal("cow")), "cannot afford cow")
	check(not s.apply(Cmd.buy_animal("fluffhen")), "hybrid not buyable")


func test_animal_not_available_in_level_cannot_be_bought() -> void:
	var s := core().start_session(level({"available_animals": ["chicken"]}), 1)
	check(not s.apply(Cmd.buy_animal("sheep")))


func test_hungry_animal_without_grass_emits_hungry_then_dies() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 3)
	s.advance(200)
	check_eq(events_of(s.poll_events(), "animal_hungry").size(), 1, "hungry event")
	check(s.state().animals[0].hungry, "hungry flag")
	s.advance(400)
	check_eq(events_of(s.poll_events(), "animal_died").size(), 1, "died")
	check_eq(s.state().animals.size(), 0)


func test_fed_animal_produces_product_on_ground() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 5)
	s.advance(160)
	var evts := s.poll_events()
	check_eq(events_of(evts, "product_spawned").size(), 1, "egg laid")
	check_eq(s.state().ground[0].product, "egg")


func test_grass_feeds_hungry_animal() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 7)
	s.advance(160)
	var a: Dictionary = s.state().animals[0]
	check(s.apply(Cmd.plant_grass(a.x / 100, a.y / 100)), "plant ok")
	check_eq(s.state().well.water, 5, "water used")
	s.advance(60)
	var st := s.state()
	check(not st.animals[0].hungry, "fed")
	check(st.grass_total < 15, "grass eaten")


func test_well_runs_dry_and_refills_for_money() -> void:
	var s := core().start_session(level({"start_money": 100}), 1)
	for i in 6:
		check(s.apply(Cmd.plant_grass(i, 0)))
	check(not s.apply(Cmd.plant_grass(7, 0)), "well dry")
	check(s.apply(Cmd.refill_well()))
	check_eq(s.state().money, 80)
	check(not s.apply(Cmd.plant_grass(7, 0)), "still refilling")
	s.advance(40)
	check_eq(s.state().well.water, 6)
	check(s.apply(Cmd.plant_grass(7, 0)))


func test_uncollected_product_expires() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 1}]}), 5)
	s.advance(160)
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


func test_hybrid_born_when_parents_meet() -> void:
	var lvl := level({"allow_hybrids": true, "start_animals": [{"type": "chicken", "count": 3}, {"type": "sheep", "count": 3}]})
	var s := core().start_session(lvl, 11)
	var born := 0
	for i in 60:
		var st := s.state()
		for a in st.animals:
			if a.hungry:
				s.apply(Cmd.plant_grass(a.x / 100, a.y / 100))
		if st.well.water == 0:
			s.apply(Cmd.refill_well())
		s.advance(50)
		born += events_of(s.poll_events(), "hybrid_born").size()
	check(born >= 1, "at least one hybrid born")
	check(s.state().animals.any(func(a): return a.type == "fluffhen"), "fluffhen exists")


func test_no_hybrid_when_level_disallows() -> void:
	var s := core().start_session(level({"start_animals": [{"type": "chicken", "count": 3}, {"type": "sheep", "count": 3}]}), 11)
	s.advance(600)
	check_eq(events_of(s.poll_events(), "hybrid_born").size(), 0)
