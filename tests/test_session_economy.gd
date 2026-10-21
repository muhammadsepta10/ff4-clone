extends TestCase


func _session_with_egg(overrides := {}) -> LevelSession:
	var lvl := level({"start_animals": [{"type": "chicken", "count": 1}]})
	for k in overrides:
		lvl[k] = overrides[k]
	var s := core().start_session(lvl, 5)
	s.advance(95)
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


func test_warehouse_counts_space_by_item_size() -> void:
	var s := core().start_session(level({"start_money": 100000}), 1)
	fly_in(s, "sugar", 4)
	check_eq(s.state().warehouse.used, 20, "sugar takes 5 each")
	for i in 3:
		fly_in(s, "sugar", 4)
	fly_in(s, "chalk", 20)
	check_eq(s.state().warehouse.used, 100)
	s.apply(Cmd.order_plane("chalk", 1))
	s.apply(Cmd.send_plane())
	s.advance(s.state().plane.trip_ticks)
	s.poll_events()
	check(not s.apply(Cmd.collect(s.state().ground[0].uid)), "rejected")
	check_eq(events_of(s.poll_events(), "warehouse_full").size(), 1)
	check(s.apply(Cmd.upgrade_warehouse()))
	check_eq(s.state().warehouse.capacity, 250)
	check(s.apply(Cmd.collect(s.state().ground[0].uid)), "fits after upgrade")


func test_bought_goods_need_the_plane_and_money() -> void:
	var s := core().start_session(level({"start_money": 60}), 1)
	check(not s.apply(Cmd.order_plane("egg", 1)), "eggs are not sold in town")
	check(s.apply(Cmd.order_plane("sugar", 3)))
	check_eq(s.state().plane.cost, 75)
	check(not s.apply(Cmd.send_plane()), "too expensive")
	check(s.apply(Cmd.order_plane("sugar", -1)))
	check(s.apply(Cmd.send_plane()))
	check_eq(s.state().money, 10)
	check(not s.apply(Cmd.order_plane("sugar", 1)), "plane away")
	s.advance(s.state().plane.trip_ticks)
	check_eq(s.state().ground.filter(func(g): return g.product == "sugar").size(), 2)
	var no_plane := core().start_session(level({"plane": false}), 1)
	check(not no_plane.apply(Cmd.order_plane("sugar", 1)), "level without plane")


func test_workshop_consumes_inputs_and_outputs_crafted_product() -> void:
	var s := _session_with_egg()
	s.apply(Cmd.collect(s.state().ground[0].uid))
	check(not s.apply(Cmd.build_workshop(0, "bakery")), "bakery cannot stand in slot 0")
	check(s.apply(Cmd.build_workshop(0, "mixer")))
	check_eq(s.state().money, 1000 - 150)
	check(s.apply(Cmd.start_workshop(0)))
	check_eq(s.state().warehouse.items.get("egg", 0), 0, "egg consumed")
	s.advance(200)
	var evts := s.poll_events()
	check_eq(events_of(evts, "workshop_done").size(), 1)
	check(s.state().ground.any(func(g): return g.product == "egg_mix"))


func test_workshop_queue_grows_with_level() -> void:
	var s := core().start_session(level({"start_money": 100000, "start_animals": [{"type": "chicken", "count": 3}]}), 2)
	s.advance(95)
	for g in s.state().ground:
		s.apply(Cmd.collect(g.uid))
	check_eq(s.state().warehouse.items.get("egg", 0), 3)
	s.apply(Cmd.build_workshop(0, "mixer"))
	check(s.apply(Cmd.start_workshop(0)))
	check(not s.apply(Cmd.start_workshop(0)), "level 1 makes one batch at a time")
	check(s.apply(Cmd.upgrade_workshop(0)))
	check_eq(s.state().workshops[0].duration, 150)
	check(s.apply(Cmd.start_workshop(0)), "level 2 queues one more")
	check_eq(s.state().workshops[0].queued, 1)
	s.advance(200 + 150)
	check_eq(events_of(s.poll_events(), "workshop_done").size(), 2)


func test_slot_offers_a_choice_and_selling_frees_it() -> void:
	var s := core().start_session(level({"start_money": 10000}), 1)
	check(s.apply(Cmd.build_workshop(1, "bakery")))
	check(not s.apply(Cmd.build_workshop(1, "butchery")), "slot taken")
	check(s.apply(Cmd.sell_workshop(1)))
	check(s.state().workshops[1] == null, "slot empty")
	check_eq(s.state().money, 10000 - 400 + 200)
	check(s.apply(Cmd.build_workshop(1, "butchery")))
	check(not s.apply(Cmd.build_workshop(5, "mixer")), "slot has no options")


func test_prebuilt_building_from_level() -> void:
	var s := core().start_session(level({"slots": [[{"type": "mixer", "level": 3}], [], [], [], [], []]}), 1)
	var w: Dictionary = s.state().workshops[0]
	check_eq(w.type, "mixer")
	check_eq(w.level, 3)
	check_eq(w.queue_max, 3)


func test_truck_sells_cargo_and_returns_with_money() -> void:
	var s := core().start_session(level({"start_money": 1000}), 1)
	fly_in(s, "sugar", 4)
	var money_before: int = s.state().money
	check(s.apply(Cmd.load_truck("sugar", 4)))
	check_eq(s.state().warehouse.used, 0)
	check(s.apply(Cmd.unload_truck("sugar", 1)))
	check(s.apply(Cmd.send_truck()))
	check(not s.apply(Cmd.load_truck("sugar", 1)), "truck away")
	s.advance(199)
	check_eq(s.state().money, money_before)
	s.advance(1)
	check_eq(s.state().money, money_before + 3 * 25)
	check_eq(events_of(s.poll_events(), "truck_returned").size(), 1)


func test_truck_capacity_counts_item_size_and_upgrades() -> void:
	var s := core().start_session(level({"start_money": 100000}), 1)
	check_eq(s.state().truck.capacity, 40)
	fly_in(s, "sugar", 4)
	fly_in(s, "sugar", 4)
	fly_in(s, "sugar", 1)
	check(s.apply(Cmd.load_truck("sugar", 8)))
	check(not s.apply(Cmd.load_truck("sugar", 1)), "40 space units full")
	s.apply(Cmd.unload_truck("sugar", 8))
	check(s.apply(Cmd.upgrade_truck()))
	check_eq(s.state().truck.capacity, 80)
	var no_truck := core().start_session(level({"truck": false}), 1)
	check(not no_truck.state().truck.available)


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
