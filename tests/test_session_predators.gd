extends TestCase


func test_warning_before_predator_arrives() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 100, "count": 2}]}), 1)
	s.advance(50)
	check_eq(events_of(s.poll_events(), "predator_warning").size(), 1)
	s.advance(50)
	check_eq(events_of(s.poll_events(), "predator_arrived").size(), 2)
	check_eq(s.state().predators.size(), 2)


func test_bear_caged_after_enough_taps_and_can_be_sold() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 0, "count": 1}]}), 1)
	s.advance(1)
	var uid: int = s.state().predators[0].uid
	for i in 5:
		check(s.apply(Cmd.tap_predator(uid)))
	check_eq(s.state().predators.size(), 1, "not caged yet")
	s.apply(Cmd.tap_predator(uid))
	check_eq(s.state().predators.size(), 0, "caged")
	check_eq(events_of(s.poll_events(), "predator_caged").size(), 1)
	var g: Dictionary = s.state().ground[0]
	check_eq(g.product, "caged_bear")
	check(s.apply(Cmd.collect(g.uid)))
	check_eq(s.state().warehouse.used, 10, "a caged bear takes 10 space")
	check(s.apply(Cmd.load_truck("caged_bear", 1)))
	s.apply(Cmd.send_truck())
	s.advance(200)
	check_eq(s.state().money, 1080)


func test_bear_hits_decay_over_time() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 0, "count": 1}]}), 1)
	s.advance(1)
	var uid: int = s.state().predators[0].uid
	for i in 4:
		s.apply(Cmd.tap_predator(uid))
	s.advance(16)
	check_eq(s.state().predators[0].hits, 2)


func test_bear_scares_animals_but_does_not_eat_them() -> void:
	var lvl := level({"start_animals": [{"type": "chicken", "count": 6}], "predators": [{"type": "bear", "tick": 0, "count": 1}]})
	var s := core().start_session(lvl, 2)
	var scared := 0
	for i in 60:
		s.advance(10)
		scared += s.state().animals.filter(func(a): return a.scared).size()
	check(scared > 0, "some animals ran away")
	check_eq(s.state().animals.size(), 6, "none eaten")
	check_eq(s.state().predators.size(), 1, "bear stays until caged")


func test_uncollected_caged_bear_breaks_free() -> void:
	var s := core().start_session(level({"predators": [{"type": "bear", "tick": 0, "count": 1}]}), 1)
	s.advance(1)
	var uid: int = s.state().predators[0].uid
	for i in 6:
		s.apply(Cmd.tap_predator(uid))
	s.advance(400)
	check_eq(events_of(s.poll_events(), "bear_escaped").size(), 1)
	check_eq(s.state().predators.size(), 1)


func test_dog_cages_bears() -> void:
	var lvl := level({"start_animals": [{"type": "dog", "count": 1}], "predators": [{"type": "bear", "tick": 0, "count": 1}]})
	var s := core().start_session(lvl, 3)
	s.advance(400)
	check_eq(events_of(s.poll_events(), "predator_caged").size(), 1)
	check(s.state().ground.any(func(g): return g.product == "caged_bear"))


func test_mole_eats_grass_until_chased_away() -> void:
	var s := core().start_session(level({"predators": [{"type": "mole", "tick": 0, "count": 1, "tier": "mature"}]}), 1)
	s.advance(1)
	var m: Dictionary = s.state().predators[0]
	check_eq(m.needed, 3, "mature mole takes 3 taps")
	s.apply(Cmd.plant_grass(m.x / 100, m.y / 100))
	var before: int = s.state().grass_total
	s.advance(40)
	check(s.state().grass_total < before, "grass eaten")
	for i in 3:
		s.apply(Cmd.tap_predator(m.uid))
	check_eq(s.state().predators.size(), 0)
	check_eq(events_of(s.poll_events(), "predator_chased").size(), 1)


func test_mole_leaves_after_lifetime() -> void:
	var s := core().start_session(level({"predators": [{"type": "mole", "tick": 0, "count": 1, "tier": "beginner"}]}), 1)
	s.advance(301)
	check_eq(s.state().predators.size(), 0)
	check_eq(events_of(s.poll_events(), "predator_left").size(), 1)
