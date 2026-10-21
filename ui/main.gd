## Root scene: background + screen router.
extends Control

const SCREENS := {
	"profiles": preload("res://ui/screens/profiles_screen.gd"),
	"map": preload("res://ui/screens/map_screen.gd"),
	"game": preload("res://ui/screens/game_screen.gd"),
	"achievements": preload("res://ui/screens/achievements_screen.gd"),
	"settings": preload("res://ui/screens/settings_screen.gd"),
	"credits": preload("res://ui/screens/credits_screen.gd"),
	"benchmark": preload("res://ui/screens/benchmark_screen.gd"),
}

var _current: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	App.language_changed.connect(func(): goto("settings"))
	var bench := OS.get_cmdline_user_args().has("--benchmark")
	goto("benchmark" if bench else "profiles")


func goto(screen: String, args := {}) -> void:
	if _current:
		_current.queue_free()
	var s: Control = SCREENS[screen].new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.set("main", self)
	s.set("args", args)
	add_child(s)
	_current = s
	App.play_music("menu" if screen != "game" else App.core.get_level(args.get("level_id", "w1_l1")).world)
