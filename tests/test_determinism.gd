extends TestCase


func _script(s: LevelSession) -> void:
	for i in 40:
		var st := s.state()
		for a in st.animals:
			if a.hungry:
				s.apply(Cmd.plant_grass(a.x / 100, a.y / 100))
		for g in st.ground:
			s.apply(Cmd.collect(g.uid))
		for p in st.predators:
			s.apply(Cmd.tap_predator(p.uid))
		if st.well.water == 0:
			s.apply(Cmd.refill_well())
		s.apply(Cmd.tap())
		s.advance(25)


func _lvl() -> Dictionary:
	return level({"start_animals": [{"type": "chicken", "count": 3}, {"type": "sheep", "count": 2}, {"type": "cat", "count": 1}, {"type": "dog", "count": 1}],
		"predators": [{"type": "bear", "tick": 200, "count": 2}, {"type": "mole", "tick": 300, "count": 1, "tier": "veteran"}]})


func test_same_seed_and_commands_give_identical_state() -> void:
	var a := core().start_session(_lvl(), 42)
	var b := core().start_session(_lvl(), 42)
	_script(a)
	_script(b)
	check_eq(var_to_str(a.state()), var_to_str(b.state()))


func test_different_seed_diverges() -> void:
	var a := core().start_session(_lvl(), 1)
	var b := core().start_session(_lvl(), 2)
	_script(a)
	_script(b)
	check(var_to_str(a.state()) != var_to_str(b.state()))


func test_snapshot_restore_continues_identically() -> void:
	var a := core().start_session(_lvl(), 9)
	_script(a)
	var snap_text := var_to_str(a.snapshot())
	var b := core().restore_session(str_to_var(snap_text))
	_script(a)
	_script(b)
	check_eq(var_to_str(a.state()), var_to_str(b.state()))
	check_eq(var_to_str(a.poll_events()), var_to_str(b.poll_events()))
