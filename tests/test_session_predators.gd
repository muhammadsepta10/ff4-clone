extends TestCase


func test_warning_before_predator_arrives() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 100}]}), 1)
	s.advance(50)
	check_eq(events_of(s.poll_events(), "predator_warning").size(), 1)
	s.advance(50)
	check_eq(events_of(s.poll_events(), "predator_arrived").size(), 1)
	check_eq(s.state().predators.size(), 1)


func test_bear_caged_after_enough_taps_and_can_be_sold() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 0}]}), 1)
	s.advance(1)
	var uid: int = s.state().predators[0].uid
	for i in 7:
		check(s.apply(Cmd.tap_predator(uid)))
	check_eq(s.state().predators.size(), 1, "not caged yet")
	s.apply(Cmd.tap_predator(uid))
	check_eq(s.state().predators.size(), 0, "caged")
	check_eq(events_of(s.poll_events(), "predator_caged").size(), 1)
	var g: Dictionary = s.state().ground[0]
	check_eq(g.product, "caged_bear")
	check(s.apply(Cmd.collect(g.uid)))
	check(s.apply(Cmd.load_truck("caged_bear", 1)))
	s.apply(Cmd.send_truck())
	s.advance(200)
	check_eq(s.state().money, 1400)


func test_bear_hits_decay_over_time() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 0}]}), 1)
	s.advance(1)
	var uid: int = s.state().predators[0].uid
	for i in 4:
		s.apply(Cmd.tap_predator(uid))
	s.advance(16)
	check_eq(s.state().predators[0].hits, 2)


func test_bear_eats_animal_if_not_caged() -> void:
	var lvl := level({"start_animals": [{"type": "chicken", "count": 6}], "predators": [{"type": "bear", "tick": 0}]})
	var s := core().start_session(lvl, 2)
	s.advance(600)
	check(events_of(s.poll_events(), "animal_eaten").size() >= 1)


func test_mole_eats_grass_until_chased_away() -> void:
	var s := core().start_session(level({"predators": [{"type": "mole", "tick": 0}]}), 1)
	s.advance(1)
	var m: Dictionary = s.state().predators[0]
	s.apply(Cmd.plant_grass(m.x / 100, m.y / 100))
	var before: int = s.state().grass_total
	s.advance(40)
	check(s.state().grass_total < before, "grass eaten")
	for i in 3:
		s.apply(Cmd.tap_predator(m.uid))
	check_eq(s.state().predators.size(), 0)
	check_eq(events_of(s.poll_events(), "predator_chased").size(), 1)


func test_bear_leaves_after_lifetime() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 0}]}), 1)
	s.advance(601)
	check_eq(s.state().predators.size(), 0)
	check_eq(events_of(s.poll_events(), "predator_left").size(), 1)


func test_mole_stays_until_chased_away() -> void:
	var s := core().start_session(level({"predators": [{"type": "mole", "tick": 0}]}), 1)
	s.advance(3000)
	check_eq(s.state().predators.size(), 1)
