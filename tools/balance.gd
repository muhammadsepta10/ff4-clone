## Validates every level with the bot and writes trophy limits back to the level JSON.
## Usage: godot --headless --path . -s tools/balance.gd [-- --check]
## --check: only verify (CI); exits 1 if a level is unwinnable or limits are stale.
extends SceneTree


func _init() -> void:
	var check_only := OS.get_cmdline_user_args().has("--check")
	var core := GameCore.from_content_dir("res://content")
	if not core.content_errors().is_empty():
		for e in core.content_errors():
			printerr(e)
		quit(1)
		return
	var bad := 0
	for w in core.worlds():
		if w.levels_file == "":
			continue
		var path: String = "res://content/" + w.levels_file
		var text := FileAccess.get_file_as_string(path)
		for id in core.level_ids_in_world(w.id):
			var lvl := core.get_level(id)
			var t := Balancer.bot_ticks(core, lvl)
			if t < 0:
				printerr("%s: bot cannot win" % id)
				bad += 1
				continue
			var tr := Balancer.trophy_for(t)
			var stale: bool = tr.gold_ticks != lvl.trophy.gold_ticks or tr.silver_ticks != lvl.trophy.silver_ticks
			print("%s: bot %.1fs gold %ds silver %ds%s" % [id, t / 10.0, tr.gold_ticks / 10, tr.silver_ticks / 10, " (stale)" if stale else ""])
			if stale:
				if check_only:
					bad += 1
				else:
					text = _replace_trophy(text, id, tr)
		if not check_only:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(text)
	quit(1 if bad > 0 else 0)


## Rewrites the "trophy" line of one level in place, keeping the file's formatting.
func _replace_trophy(text: String, id: String, tr: Dictionary) -> String:
	var start := text.find("\"id\": \"%s\"" % id)
	var at := text.find("\"trophy\":", start)
	var end := text.find("}", at) + 1
	return text.substr(0, at) + "\"trophy\": {\"gold_ticks\": %d, \"silver_ticks\": %d}" % [tr.gold_ticks, tr.silver_ticks] + text.substr(end)
