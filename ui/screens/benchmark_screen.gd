## Device benchmark (US 79): loads the busiest level, lets the bot play it with full
## rendering for a fixed time, then reports load time, average FPS and 1% low FPS.
extends Screen

const DURATION := 20.0

var _game: Node
var _frames: PackedFloat32Array = []
var _elapsed := 0.0
var _load_ms := 0
var _label: Label
var _done := false
var _since_bot := 0.0


func _ready() -> void:
	var level_id := _busiest_level()
	var t0 := Time.get_ticks_msec()
	_game = load("res://ui/screens/game_screen.gd").new()
	_game.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game.set("main", self)
	_game.set("args", {"level_id": level_id, "benchmark": true})
	add_child(_game)
	_load_ms = Time.get_ticks_msec() - t0
	_label = UI.label(tr("benchmark_running"), 40, Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 10)
	_label.position = Vector2(40, 160)
	add_child(_label)


## Level with the most predators and starting animals.
func _busiest_level() -> String:
	var best := ""
	var score := -1
	for id in App.core.all_level_ids():
		var l := App.core.get_level(id)
		var s: int = l.predators.size() * 5 + l.goals.size() * 3 + l.workshop_slots
		if s > score:
			score = s
			best = id
	return best


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed > 1.0:
		_frames.append(delta)
		_since_bot += delta
		if _since_bot >= 0.5:
			_since_bot = 0.0
			Bot.act(App.core, _game.session)
		_label.text = "%s %.0fs  FPS %d" % [tr("benchmark_running"), DURATION - _elapsed, Engine.get_frames_per_second()]
	if _elapsed >= DURATION:
		_finish()


func _finish() -> void:
	_done = true
	var sorted := Array(_frames)
	sorted.sort()
	var total := 0.0
	for f in sorted:
		total += f
	var avg := sorted.size() / total
	var worst: Array = sorted.slice(int(sorted.size() * 0.99))
	var low_sum := 0.0
	for f in worst:
		low_sum += f
	var low := worst.size() / low_sum if low_sum > 0 else avg
	_game.set_process(false)
	var text := App.t("benchmark_result", {"load": _load_ms, "avg": "%.1f" % avg, "low": "%.1f" % low})
	print(text.replace("\n", " | "))
	var box := UI.vbox([UI.label(tr("benchmark"), 56), UI.label(text, 40),
		UI.button(tr("back"), func(): get_parent().goto("profiles"))])
	UI.modal(self, box)
	if OS.get_cmdline_user_args().has("--benchmark"):
		get_tree().quit()

