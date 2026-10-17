## Headless test runner.
## Usage: godot --headless --path . -s tests/run_tests.gd [-- test_file_filter]
extends SceneTree


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd" and (filter == "" or f.contains(filter)):
			files.append(f)
	files.sort()
	var total := 0
	var failed: Array[String] = []
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: failed to compile" % f)
			continue
		var inst: TestCase = script.new()
		for m in inst.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			inst.current_test = "%s::%s" % [f, name]
			var before := inst.failures.size()
			inst.call(name)
			if inst.failures.size() > before:
				print("  FAIL ", inst.current_test)
		failed.append_array(inst.failures)
		print("%s: %d failure(s)" % [f, inst.failures.size()])
	for msg in failed:
		print("    ", msg)
	print("\n%d tests, %d failures" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
