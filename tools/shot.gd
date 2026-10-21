## Dev helper: opens a screen with a throwaway profile and saves a screenshot.
## Usage: godot --path . -s tools/shot.gd -- <screen> <out.png> [level_id] [seconds]
extends SceneTree


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var screen: String = a[0]
	var out: String = a[1]
	var level := a[2] if a.size() > 2 else "l1"
	var secs := float(a[3]) if a.size() > 3 else 2.0
	await process_frame
	var app: Node = root.get_node("App")
	app.campaign = app.core.new_campaign()
	app.campaign.create_profile(0, "Tester", {})
	app.campaign.select_profile(0)
	for id in app.core.catalog().tutorials:
		app.campaign.mark_tutorial_done(id)
	app.campaign.apply_result({"level_id": "l1", "won": true, "ticks": 100, "trophy": "gold", "money": 0, "stats": {}})
	var main: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.goto(screen, {"level_id": level})
	if screen == "game":
		var g = main.get("_current")
		var t := 0.0
		while t < secs:
			Bot.act(app.core, g.session)
			await create_timer(0.5).timeout
			t += 0.5
	else:
		await create_timer(secs).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	app.clear_session()
	quit()
