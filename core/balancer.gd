## Trophy limits from bot time: gold = bot × 1.3, silver = bot × 1.8 (PRD, rounded up to whole seconds).
class_name Balancer
extends RefCounted

const SEEDS := [1, 2, 3]
const GOLD_FACTOR_PCT := 130
const SILVER_FACTOR_PCT := 180


## Slowest winning bot time over SEEDS, or -1 if any seed fails.
static func bot_ticks(core: GameCore, level: Dictionary) -> int:
	var worst := 0
	for seed in SEEDS:
		var r := Bot.play(core, level, seed)
		if not r.won:
			return -1
		worst = maxi(worst, r.ticks)
	return worst


static func trophy_for(ticks: int) -> Dictionary:
	return {"gold_ticks": _round_up_second(ticks * GOLD_FACTOR_PCT / 100),
		"silver_ticks": _round_up_second(ticks * SILVER_FACTOR_PCT / 100)}


static func _round_up_second(t: int) -> int:
	var s := LevelSession.TICKS_PER_SECOND
	return (t + s - 1) / s * s
