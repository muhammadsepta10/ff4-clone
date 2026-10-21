## Checks that the bot can win every level. Trophy times come from the original
## game's level data and are never rewritten here.
## Usage: godot --headless --path . -s tools/balance.gd [-- l1 l2 ...]
extends SceneTree

const SEED := 1


func _init() -> void:
	var core := GameCore.from_content_dir("res://content")
	if not core.content_errors().is_empty():
		for e in core.content_errors():
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var ids: Array = core.all_level_ids() if args.is_empty() else Array(args)
	var bad := 0
	for id in ids:
		var lvl := core.get_level(id)
		var r := Bot.play(core, lvl, SEED)
		if not r.won:
			printerr("%s: bot cannot win" % id)
			bad += 1
			continue
		print("%s: bot %ds, gold %ds, silver %ds, trophy %s" % [id, r.ticks / 10, lvl.trophy.gold_ticks / 10, lvl.trophy.silver_ticks / 10, r.trophy])
	print("%d of %d levels won" % [ids.size() - bad, ids.size()])
	quit(1 if bad > 0 else 0)
