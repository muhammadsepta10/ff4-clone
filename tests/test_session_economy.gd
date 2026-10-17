extends TestCase


func _session_with_egg(overrides := {}) -> LevelSession:
	var lvl := level({"start_animals": [{"type": "chicken", "count": 1}]})
	for k in overrides:
		lvl[k] = overrides[k]
	var s := core().start_session(lvl, 5)
	s.advance(160)
	s.poll_events()
	return s


func test_collect_moves_product_to_warehouse_and_counts_goal() -> void:
	var s := _session_with_egg({"goals": [{"type": "collect", "product": "egg", "count": 5}]})
	var uid: int = s.state().ground[0].uid
	check(s.apply(Cmd.collect(uid)))
	var st := s.state()
	check_eq(st.warehouse.items.get("egg", 0), 1)
	check_eq(st.ground.size(), 0)
	check_eq(st.goals[0].progress, 1)


func test_full_warehouse_rejects_product() -> void:
	var s := core().start_session(level({"start_money": 10000}), 1)
	check(s.apply(Cmd.buy_from_city("egg", 15)))
	s.advance(120)
	for g in s.state().ground:
		s.apply(Cmd.collect(g.uid))
	check_eq(s.state().warehouse.used, 15)
	check(s.apply(Cmd.buy_from_city("egg", 1)))
	s.advance(120)
	s.poll_events()
	check(not s.apply(Cmd.collect(s.state().ground[0].uid)), "rejected")
	check_eq(events_of(s.poll_events(), "warehouse_full").size(), 1)
	check(s.apply(Cmd.upgrade_warehouse()))
	check_eq(s.state().warehouse.capacity, 30)
	check(s.apply(Cmd.collect(s.state().ground[0].uid)), "fits after upgrade")


func test_workshop_consumes_inputs_and_outputs_crafted_product() -> void:
	var s := core().start_session(level({"start_money": 10000}), 1)
	s.apply(Cmd.buy_from_city("egg", 2))
	s.advance(120)
	for g in s.state().ground:
		s.apply(Cmd.collect(g.uid))
	check(s.apply(Cmd.build_workshop(0, "bakery")))
	check_eq(s.state().money, 10000 - 50 - 300)
	check(s.apply(Cmd.start_workshop(0)))
	check_eq(s.state().warehouse.items.get("egg", 0), 0, "eggs consumed")
	check(not s.apply(Cmd.start_workshop(0)), "busy")
	s.advance(100)
	var evts := s.poll_events()
	check_eq(events_of(evts, "workshop_done").size(), 1)
	var g: Array = s.state().ground
	check_eq(g.size(), 1)
	check_eq(g[0].product, "pastry")


func test_workshop_upgrade_speeds_up_and_sell_frees_slot() -> void:
	var s := core().start_session(level({"start_money": 10000}), 1)
	s.apply(Cmd.build_workshop(0, "bakery"))
	check(s.apply(Cmd.upgrade_workshop(0)))
	check_eq(s.state().workshops[0].duration, 75)
	check(s.apply(Cmd.sell_workshop(0)))
	check(s.state().workshops[0] == null, "slot empty")
	check_eq(s.state().money, 10000 - 300 - 200 + 150)
	check(not s.apply(Cmd.build_workshop(5, "bakery")), "no such slot")
	check(not s.apply(Cmd.build_workshop(0, "tailor")), "not available")


func test_truck_sells_cargo_and_returns_with_money() -> void:
	var s := core().start_session(level({"start_money": 1000}), 1)
	s.apply(Cmd.buy_from_city("egg", 4))
	s.advance(120)
	for g in s.state().ground:
		s.apply(Cmd.collect(g.uid))
	check(s.apply(Cmd.load_truck("egg", 4)))
	check_eq(s.state().warehouse.used, 0)
	check(s.apply(Cmd.unload_truck("egg", 1)))
	check(s.apply(Cmd.send_truck()))
	var money_before: int = s.state().money
	check(not s.apply(Cmd.load_truck("egg", 1)), "truck away")
	s.advance(199)
	check_eq(s.state().money, money_before)
	s.advance(1)
	check_eq(s.state().money, money_before + 3 * 12)
	check_eq(events_of(s.poll_events(), "truck_returned").size(), 1)


func test_truck_upgrade_increases_capacity() -> void:
	var s := core().start_session(level({"start_money": 1000}), 1)
	check_eq(s.state().truck.capacity, 10)
	check(s.apply(Cmd.upgrade_truck()))
	check_eq(s.state().truck.capacity, 20)
	check_eq(s.state().money, 600)


func test_click_meter_pays_when_full_and_hidden_items_speed_it_up() -> void:
	var lvl := level({"hidden_items": [{"id": "h1", "x": 10, "y": 10}, {"id": "h2", "x": 20, "y": 20}]})
	var s := core().start_session(lvl, 1)
	for i in 24:
		s.apply(Cmd.tap())
	check_eq(s.state().click_meter.fill, 96)
	s.apply(Cmd.tap())
	check_eq(s.state().money, 1030)
	check_eq(s.state().click_meter.fill, 0)
	check_eq(events_of(s.poll_events(), "click_reward").size(), 1)
	check(s.apply(Cmd.find_hidden_item("h1")))
	check(not s.apply(Cmd.find_hidden_item("h1")), "only once")
	check_eq(s.state().hidden_items_left, 1)
	s.apply(Cmd.tap())
	check_eq(s.state().click_meter.fill, 6)
