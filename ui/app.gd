## Autoload "App": owns GameCore + Campaign, settings, local saves, audio buses and
## the theme. The only place that touches the file system.
extends Node

signal app_paused
signal language_changed

const CAMPAIGN_PATH := "user://campaign.save"
const SESSION_PATH := "user://session.save"
const SETTINGS_PATH := "user://settings.cfg"

var core: GameCore
var campaign: Campaign
var settings := {"language": "id", "music": 0.8, "sfx": 0.8}
var theme: Theme


func _ready() -> void:
	core = GameCore.from_content_dir("res://content")
	assert(core.content_errors().is_empty(), str(core.content_errors()))
	_load_translations()
	_load_settings()
	campaign = core.new_campaign()
	if FileAccess.file_exists(CAMPAIGN_PATH):
		var data = str_to_var(FileAccess.get_file_as_string(CAMPAIGN_PATH))
		if data is Dictionary:
			campaign = core.load_campaign(data)
	_setup_audio()
	theme = _build_theme()
	get_tree().root.theme = theme


func _notification(what: int) -> void:
	var leaving := what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]
	# On phones losing focus (call, notification shade) also stops the timer (US 22).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"):
		leaving = true
	if leaving:
		app_paused.emit()
		save_campaign()


# ---------------------------------------------------------------- saves

func save_campaign() -> void:
	if campaign == null:
		return
	_write(CAMPAIGN_PATH, var_to_str(campaign.to_dict()))


func save_session(session: LevelSession) -> void:
	_write(SESSION_PATH, var_to_str({"slot": campaign.active_slot(), "snapshot": session.snapshot()}))


func clear_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)


## Snapshot of an interrupted level for the active profile, or {}.
func pending_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var data = str_to_var(FileAccess.get_file_as_string(SESSION_PATH))
	if data is Dictionary and data.get("slot", -1) == campaign.active_slot():
		return data.snapshot
	return {}


func _write(path: String, text: String) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
	DirAccess.rename_absolute(tmp, path)


# ---------------------------------------------------------------- settings

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
	TranslationServer.set_locale(settings.language)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func set_language(lang: String) -> void:
	settings.language = lang
	TranslationServer.set_locale(lang)
	save_settings()
	language_changed.emit()


func set_volume(bus: String, value: float) -> void:
	settings[bus] = value
	_apply_volume(bus)
	save_settings()


# ---------------------------------------------------------------- i18n

func _load_translations() -> void:
	for lang in ["id", "en"]:
		var t := Translation.new()
		t.locale = lang
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/%s.json" % lang))
		for k in data:
			t.add_message(k, data[k])
		TranslationServer.add_translation(t)


## tr() with {placeholder} substitution.
func t(key: String, args := {}) -> String:
	return tr(key).format(args)


func goal_text(g: Dictionary) -> String:
	match g.type:
		"collect": return t("goal_collect", {"n": g.target, "product": tr(g.product)})
		"animal": return t("goal_animal", {"n": g.target, "animal": tr(g.animal)})
		_: return t("goal_money", {"n": g.target})


static func format_time(ticks: int) -> String:
	var s := ticks / LevelSession.TICKS_PER_SECOND
	return "%d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- audio

const MUSIC_FADE := 0.6
## Effect ids the game plays (docs/style-bible.md). Files live in audio/sfx/<id>.ogg.
const SFX_IDS := ["click", "collect", "coins", "error", "warning", "cage", "sparkle", "goal",
	"achievement", "win", "animal_lost", "hybrid"]

var _music := AudioStreamPlayer.new()
var _music_id := ""
var _music_tween: Tween
var _music_next: AudioStream
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_streams := {}
var _sfx_next := 0


func _setup_audio() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_apply_volume("music")
	_apply_volume("sfx")
	_music.bus = "Music"
	add_child(_music)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	# Load every effect once so the first tap on a phone does not stall on disk.
	for id in SFX_IDS:
		var path := "res://audio/sfx/%s.ogg" % id
		if ResourceLoader.exists(path):
			_sfx_streams[id] = load(path)


func _apply_volume(key: String) -> void:
	var idx := AudioServer.get_bus_index("Music" if key == "music" else "SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(settings[key], 0.0001)))


## Music per world and menu (US 75). Tracks loop and crossfade when the id changes.
func play_music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	var path := "res://audio/music/%s.ogg" % id
	_music_next = load(path) if ResourceLoader.exists(path) else null
	if _music_next is AudioStreamOggVorbis:
		_music_next.loop = true
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0, MUSIC_FADE)
	_music_tween.tween_callback(_swap_music)
	if _music_next != null:
		_music_tween.tween_property(_music, "volume_db", 0.0, MUSIC_FADE)


func _swap_music() -> void:
	_music.stop()
	_music.stream = _music_next
	_music_next = null
	if _music.stream != null:
		_music.volume_db = -40.0
		_music.play()


func play_sfx(id: String) -> void:
	var s: AudioStream = _sfx_streams.get(id)
	if s == null:
		return
	# Prefer an idle player; when all are busy, take them over in turn.
	var p: AudioStreamPlayer = null
	for q in _sfx:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _sfx[_sfx_next]
		_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = s
	p.play()


# ---------------------------------------------------------------- theme

const COLOR_BG := Color("#f6eedc")
const COLOR_PANEL := Color("#fffaf0")
const COLOR_INK := Color("#3b2a1a")
const COLOR_ACCENT := Color("#6aa84f")
const COLOR_ACCENT_DARK := Color("#38761d")
const COLOR_WARN := Color("#cc4125")


func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 36
	# Chunky game buttons: rounded, a thick darker bottom edge that flattens when
	# pressed, and outlined white text.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var c: Color = {"normal": COLOR_ACCENT, "hover": COLOR_ACCENT.lightened(0.12),
			"pressed": COLOR_ACCENT.darkened(0.12), "disabled": Color("#a9a49a")}[state]
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.border_color = c.darkened(0.42)
		sb.set_border_width_all(5)
		sb.border_width_bottom = 5 if state == "pressed" else 11
		sb.set_corner_radius_all(30)
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 12
		sb.content_margin_bottom = 16
		th.set_stylebox(state, "Button", sb)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("#f2efe8"))
	th.set_color("font_outline_color", "Button", COLOR_ACCENT_DARK.darkened(0.45))
	th.set_constant("outline_size", "Button", 8)
	th.set_color("font_color", "Label", COLOR_INK)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#fdf1d4")
	panel.set_corner_radius_all(34)
	panel.set_content_margin_all(32)
	panel.border_color = Color("#8d5a2b")
	panel.set_border_width_all(10)
	panel.shadow_color = Color(0, 0, 0, 0.3)
	panel.shadow_size = 12
	th.set_stylebox("panel", "PanelContainer", panel)
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color("#fffaf0")
	edit.set_corner_radius_all(24)
	edit.set_content_margin_all(18)
	edit.border_color = Color("#8d5a2b")
	edit.set_border_width_all(5)
	th.set_stylebox("normal", "LineEdit", edit)
	th.set_color("font_color", "LineEdit", COLOR_INK)
	th.set_constant("separation", "VBoxContainer", 16)
	th.set_constant("separation", "HBoxContainer", 16)
	return th
