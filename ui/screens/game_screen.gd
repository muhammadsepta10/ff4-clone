## A level being played: ticks the session at 10 Hz, renders the farm and HUD,
## sends touch commands, shows tutorials, saves a snapshot when the app pauses.
extends Screen

const TICK := 1.0 / LevelSession.TICKS_PER_SECOND
const STAGE := Vector2(1920, 1080)
const FIELD_POS := Vector2(360, 300)
const AUTOSAVE_TICKS := 50
const HUD_FG := Color("#fff3d6")
# Where buildings stand on the yard (feet, stage px). Workshop slots fill in order.
const SLOT_FEET := [Vector2(560, 300), Vector2(1360, 300), Vector2(1705, 590), Vector2(215, 590),
	Vector2(1705, 830), Vector2(215, 830)]
const WELL_FOOT := Vector2(960, 300)
const WAREHOUSE_FOOT := Vector2(255, 950)
const TRUCK_FOOT := Vector2(490, 1000)
const PLANE_FOOT := Vector2(1720, 330)

var session: LevelSession
var _cat: Content
var _st: Dictionary
var _acc := 0.0
var _paused := false
var _ended := false
var _since_save := 0

var _stage: Control
var _farm: FarmView
var _money: Label
var _timer: Label
var _goals: HBoxContainer
var _goal_labels: Array[Label] = []
var _trophy_dot: TrophyBadge
var _buy_btns := {}  # animal id -> Button
var _well_b: Building
var _wh_b: Building
var _truck_b: Building
var _truck_home := Vector2.ZERO
var _plane_b: Building
var _plane_home := Vector2.ZERO
var _road: TransportBar
var _ws_b: Array = []  # Building per slot, null where the level has no building spot
var _meter: ProgressBar
var _hidden: Label
var _boosts: Label
var _toast: Label
var _panel: Control
var _panel_kind := ""
var _panel_arg = null
var _pause_overlay: Control
var _tutorial_overlay: Control
var _tutorial_queue: Array = []


func _ready() -> void:
	_cat = App.core.catalog()
	if args.has("snapshot"):
		session = App.core.restore_session(args.snapshot)
	else:
		session = App.core.start_level(args.level_id, Time.get_ticks_usec() & 0x7fffffff, args.get("boosts", []))
	App.app_paused.connect(_on_app_paused)
	_build()
	_st = session.state()
	_farm.push_state(_st)
	_refresh_hud()
	_handle_events.call_deferred(session.poll_events())
	if args.has("snapshot") or args.get("intro_done", false) or _benchmark():
		_queue_tutorial_trigger.call_deferred("start", {})
	else:
		_start_intro.call_deferred()


func _start_intro() -> void:
	await _intro()
	_queue_tutorial_trigger("start", {})


func _benchmark() -> bool:
	return args.get("benchmark", false)


func _on_app_paused() -> void:
	if _ended or session == null or _benchmark():
		return
	App.save_session(session)
	if not _paused:
		_show_pause.call_deferred()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if _ended:
		return
	_layout()
	if _paused or _tutorial_overlay != null:
		return
	_acc += minf(delta, 0.25)
	while _acc >= TICK and not session.is_won():
		_acc -= TICK
		session.advance(1)
		_st = session.state()
		_farm.push_state(_st)
		_handle_events(session.poll_events())
		_since_save += 1
		if _since_save >= AUTOSAVE_TICKS and not _benchmark():
			_since_save = 0
			App.save_session(session)
	_farm.set_alpha(_acc / TICK)
	_refresh_hud()
	if session.is_won():
		_finish()


func _input(event: InputEvent) -> void:
	# Every tap on the screen feeds the click meter (US 55).
	if event is InputEventMouseButton and event.pressed and not _paused and not _ended and _tutorial_overlay == null:
		_send(Cmd.tap())


func _send(cmd: Dictionary) -> bool:
	var ok := session.apply(cmd)
	_st = session.state()
	_farm.push_state(_st)
	_farm.set_alpha(1.0)
	_handle_events(session.poll_events())
	if _panel != null and cmd.type != "tap":
		_fill_panel()
	return ok


# ---------------------------------------------------------------- events

func _handle_events(evts: Array) -> void:
	for e in evts:
		_farm.on_event(e)
		match e.type:
			"product_collected":
				_farm.pop_text(Vector2(e.x, e.y), "+1 " + tr(e.product), Color("#fff59d"))
				App.play_sfx("collect")
			"warehouse_full":
				_show_toast(tr("warehouse_full"))
				App.play_sfx("error")
			"click_reward":
				_farm.pop_text(Vector2(800, 850), "+%d" % e.money, Color("#ffd54f"))
				App.play_sfx("coins")
			"truck_sent":
				_drive_truck(false)
			"truck_returned":
				_drive_truck(true)
				_farm.pop_text((_truck_home - FIELD_POS + Vector2(80, -60)) / FarmView.SCALE, "+%d" % e.money, Color("#ffd54f"))
				App.play_sfx("coins")
			"plane_sent":
				_fly_plane(false)
			"plane_returned":
				_fly_plane(true)
				App.play_sfx("collect")
			"bear_escaped":
				_show_toast(tr("bear_escaped"))
				App.play_sfx("warning")
			"animal_asleep":
				_farm.pop_text(Vector2(e.x, e.y), "z z", Color("#e1f5fe"))
			"workshop_upgraded", "warehouse_upgraded", "well_upgraded", "truck_upgraded", "plane_upgraded":
				App.play_sfx("goal")
			"predator_warning":
				_show_toast(tr("predator_warning_" + e.predator))
				App.play_sfx("warning")
			"predator_caged", "predator_chased":
				_farm.pop_text(Vector2(e.x, e.y), "✔", Color("#b9f6ca"))
				App.play_sfx("cage")
			"hidden_found":
				_show_toast(App.t("hidden_left", {"n": _st.hidden_items_left}))
				App.play_sfx("sparkle")
			"goal_reached":
				App.play_sfx("goal")
		_queue_tutorial_trigger(e.type, e)


## The truck drives off the left edge towards town, and back in when it returns.
func _drive_truck(back: bool) -> void:
	var off := _truck_home - Vector2(700, 0)
	_truck_b.pivot_offset = _truck_b.size / 2
	var tw := create_tween()
	if back:
		_truck_b.visible = true
		_truck_b.position = off
		_truck_b.scale = Vector2(-1, 1)  # art faces left; drive in facing right
		tw.tween_property(_truck_b, "position", _truck_home, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): _truck_b.scale = Vector2.ONE)
	else:
		_truck_b.scale = Vector2.ONE
		tw.tween_property(_truck_b, "position", _truck_home + Vector2(20, 0), 0.15)
		tw.tween_property(_truck_b, "position", off, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _truck_b.visible = false)


## The plane takes off to the top right to shop in town and lands back with the goods.
func _fly_plane(back: bool) -> void:
	var off := _plane_home + Vector2(500, -420)
	var tw := create_tween()
	if back:
		_plane_b.visible = true
		_plane_b.position = off
		tw.tween_property(_plane_b, "position", _plane_home, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(_plane_b, "position", off, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _plane_b.visible = false)


# ---------------------------------------------------------------- tutorials

const TUTORIAL_TRIGGERS := {
	"plant_grass": "animal_hungry", "collect": "product_spawned", "well": "well_empty",
	"warehouse": "product_collected", "click_meter": "click_reward", "mole": "predator_warning:mole",
	"bear": "predator_warning:bear", "truck": "start", "workshop": "start", "buy_animal": "start",
	"city": "start", "plane": "start", "cat": "start", "dog": "predator_warning:bear", "upgrade": "start",
}


func _queue_tutorial_trigger(evt: String, e: Dictionary) -> void:
	if _benchmark():
		return
	var key := evt
	if evt == "predator_warning":
		key += ":" + e.predator
	for id in App.core.get_level(session.level_id()).get("tutorials", []):
		if TUTORIAL_TRIGGERS.get(id, "") == key and not App.campaign.is_tutorial_done(id) and not _tutorial_queue.has(id):
			_tutorial_queue.append(id)
	_show_next_tutorial()


func _show_next_tutorial() -> void:
	if _tutorial_overlay != null or _tutorial_queue.is_empty():
		return
	var id: String = _tutorial_queue.pop_front()
	var box := UI.vbox()
	box.custom_minimum_size.x = 900
	box.add_child(UI.para(tr(_cat.tutorials[id].text_key), 880, 40))
	box.add_child(UI.button(tr("ok"), func():
		App.campaign.mark_tutorial_done(id)
		App.save_campaign()
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
		_show_next_tutorial()))
	_tutorial_overlay = UI.modal(self, box)
	_tutorial_overlay.color = Color(0, 0, 0, 0.25)


# ---------------------------------------------------------------- layout

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#8cc63f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.add_child(FarmScene.new())
	_farm = FarmView.new()
	_farm.position = FIELD_POS
	var f: Dictionary = _cat.farm.field
	_farm.size = Vector2(f.cols, f.rows) * f.cell * FarmView.SCALE
	_farm.command.connect(func(c): _send(c))
	_farm.warehouse_pos = WAREHOUSE_FOOT - FIELD_POS - Vector2(0, 90)
	_stage.add_child(_farm)
	var st := session.state()
	for i in st.slots.size():
		# A spot only exists where the level offers buildings (or one stands already).
		if st.slots[i].is_empty() and st.workshops[i] == null:
			_ws_b.append(null)
			continue
		var b := _building("plot", SLOT_FEET[i], 170, func(): _open_panel("workshop", i))
		_ws_b.append(b)
	_well_b = _building("well", WELL_FOOT, 180, _on_well_tapped)
	_wh_b = _building("warehouse", WAREHOUSE_FOOT, 210, func(): _open_panel("market", null))
	_truck_b = _building("truck", TRUCK_FOOT, 120, _on_truck_tapped)
	_truck_home = _truck_b.position
	_truck_b.visible = st.truck.available
	_plane_b = _building("plane", PLANE_FOOT, 120, _on_plane_tapped)
	_plane_home = _plane_b.position
	_plane_b.visible = st.plane.available
	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.position = Vector2(1862, 330)
	_meter.size = Vector2(38, 520)
	_meter.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_meter.max_value = _cat.farm.click_meter.max
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ffca28")
	fill.set_corner_radius_all(16)
	_meter.add_theme_stylebox_override("fill", fill)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.25)
	bgs.set_corner_radius_all(16)
	_meter.add_theme_stylebox_override("background", bgs)
	_stage.add_child(_meter)
	_hidden = UI.label("", 26, Color.WHITE)
	_hidden.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hidden.add_theme_constant_override("outline_size", 6)
	_hidden.position = Vector2(1500, 860)
	_hidden.size = Vector2(400, 40)
	_hidden.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(_hidden)
	_boosts = UI.label("", 26, Color.WHITE)
	_boosts.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_boosts.add_theme_constant_override("outline_size", 6)
	_boosts.position = Vector2(800, 80)
	_boosts.size = Vector2(320, 120)
	_boosts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_boosts)
	_build_hud()
	_toast = UI.label("", 44, Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(360, 240)
	_toast.size = Vector2(1200, 60)
	_toast.modulate.a = 0
	_stage.add_child(_toast)
	_layout()


## HUD laid out like the reference: coins top centre, animal shop down the left edge,
## pause + timer bottom-left, goals with product icons bottom-right.
func _build_hud() -> void:
	_money = UI.label("", 40, HUD_FG)
	var coin := UI.label("●", 40, Color("#ffd54f"))
	coin.add_theme_color_override("font_outline_color", Color("#b8860b"))
	coin.add_theme_constant_override("outline_size", 6)
	var mp := _wood(UI.hbox([coin, _money], 12))
	mp.position = Vector2(810, 6)
	mp.custom_minimum_size = Vector2(300, 0)
	_stage.add_child(mp)
	# Road to town under the coins: the truck icon drives it while away.
	_road = TransportBar.new()
	_road.position = Vector2(STAGE.x / 2 - _road.size.x / 2, 58)
	_road.visible = session.state().truck.available
	_stage.add_child(_road)
	# Animal shop column
	var col := UI.vbox([], 10)
	col.position = Vector2(10, 110)
	_stage.add_child(col)
	for id in _st_avail_animals():
		var d: Dictionary = _cat.animals[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 104)
		b.icon = Art.tex(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 72)
		b.text = "%d" % d.price
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func():
			if not _send(Cmd.buy_animal(id)):
				App.play_sfx("error")
			else:
				App.play_sfx("coins"))
		_hud_style(b)
		col.add_child(b)
		_buy_btns[id] = b
	var shop := UI.button("⇄", func(): _open_panel("animals", null), 34)
	shop.custom_minimum_size = Vector2(120, 80)
	_hud_style(shop)
	col.add_child(shop)
	# Pause + timer, bottom-left
	var pause := UI.button("❚❚", _show_pause, 34)
	pause.custom_minimum_size = Vector2(84, 72)
	pause.position = Vector2(12, 996)
	_hud_style(pause)
	_stage.add_child(pause)
	_timer = UI.label("", 34, HUD_FG)
	_trophy_dot = TrophyBadge.make("gold")
	var tp := _wood(UI.hbox([_trophy_dot, _timer], 10))
	tp.position = Vector2(106, 1000)
	_stage.add_child(tp)
	# Goals, bottom-right
	_goals = UI.hbox([], 18)
	for g in session.state().goals:
		var icon_id: String = g.get("product", g.get("animal", ""))
		var cell := UI.hbox([], 6)
		if icon_id != "" and Art.tex(icon_id) != null:
			cell.add_child(Art.icon(icon_id, 58))
		else:
			cell.add_child(UI.label("●" if g.type == "money" else "•", 40, Color("#ffd54f")))
		var l := UI.label("", 30, HUD_FG)
		cell.add_child(l)
		_goal_labels.append(l)
		_goals.add_child(cell)
	var gp := _wood(_goals)
	_stage.add_child(gp)
	gp.reset_size()
	gp.position = Vector2(STAGE.x - 12 - gp.size.x, STAGE.y - 8 - gp.size.y)
	gp.resized.connect(func(): gp.position = Vector2(STAGE.x - 12 - gp.size.x, STAGE.y - 8 - gp.size.y))


## Wooden HUD button, matching the coin and timer plaques.
func _hud_style(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("#7a4a22"), "hover": Color("#8d5a2b"), "pressed": Color("#5d3a1a"), "disabled": Color("#6b5a4a")}[state]
		sb.border_color = Color("#3e2410")
		sb.set_border_width_all(4)
		sb.border_width_bottom = 4 if state == "pressed" else 9
		sb.set_corner_radius_all(22)
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", HUD_FG)
	b.add_theme_color_override("font_hover_color", HUD_FG)
	b.add_theme_color_override("font_outline_color", Color("#3e2410"))
	b.add_theme_constant_override("outline_size", 6)


func _st_avail_animals() -> Array:
	return session.state().available_animals


func _wood(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#7a4a22")
	sb.border_color = Color("#4a2c12")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(child)
	return p


func _building(id: String, foot: Vector2, height: float, cb: Callable) -> Building:
	var b := Building.new().setup(id, foot, height)
	b.tapped.connect(cb)
	_stage.add_child(b)
	return b


## Keeps the 16:9 core stage centered; extra width/height (4:3 … 21:9) is background.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / STAGE.x, vp.y / STAGE.y)
	_stage.scale = Vector2(s, s)
	_stage.position = (vp - STAGE * s) / 2


func _refresh_hud() -> void:
	_money.text = "%d" % _st.money
	var t: Dictionary = _st.trophy
	var now: int = _st.tick
	var color: String = _st.trophy_now
	var limit: int = t.gold_ticks if color == "gold" else t.silver_ticks
	_timer.text = App.format_time(now) + ("  / " + App.format_time(limit) if color in ["gold", "silver"] else "")
	_trophy_dot.set_trophy(color)
	for i in _st.goals.size():
		var g: Dictionary = _st.goals[i]
		_goal_labels[i].text = ("✔ " if g.done else "") + "%d/%d" % [mini(g.progress, g.target), g.target]
		_goal_labels[i].add_theme_color_override("font_color", Color("#b9f6ca") if g.done else HUD_FG)
	for id in _buy_btns:
		_buy_btns[id].modulate.a = 1.0 if _st.money >= _cat.animals[id].price else 0.5
	var w: Dictionary = _st.well
	if w.refill_left > 0:
		_well_b.set_badge("…%ds" % ceili(w.refill_left / 10.0))
	elif w.water == 0:
		_well_b.set_badge(App.t("refill", {"p": w.refill_price}))
	else:
		_well_b.set_badge("%d/%d" % [w.water, w.capacity])
	_well_b.set_meter(w.water, w.capacity, Color("#4fc3f7"))
	_well_b.set_tag("⬆ %d" % w.upgrade_price if w.can_upgrade else "")
	var wh: Dictionary = _st.warehouse
	_wh_b.set_badge("%d/%d" % [wh.used, wh.capacity])
	_wh_b.set_tag("⬆ %d" % wh.upgrade_price if wh.can_upgrade else "")
	var tr_: Dictionary = _st.truck
	_truck_b.set_badge(("…%ds" % ceili(tr_.left / 10.0)) if tr_.away else "%d/%d" % [tr_.used, tr_.capacity])
	_road.set_trip(tr_.left, tr_.trip_ticks)
	_truck_b.set_tag("⬆ %d" % tr_.upgrade_price if tr_.can_upgrade else "")
	var pl: Dictionary = _st.plane
	_plane_b.set_badge(("…%ds" % ceili(pl.left / 10.0)) if pl.away else tr("city"))
	_plane_b.set_tag("⬆ %d" % pl.upgrade_price if pl.can_upgrade else "")
	for i in _ws_b.size():
		var ws = _st.workshops[i]
		var b = _ws_b[i]
		if b == null:
			continue
		if ws == null:
			if b.sprite_id != "plot":
				b.sprite_id = "plot"
				b.set_sprite("plot")
			b.set_badge("+ " + tr("empty_slot"))
			b.set_tag("")
			b.set_meter(-1, 1, Color.WHITE)
		else:
			if b.sprite_id != ws.type:
				b.sprite_id = ws.type
				b.set_sprite(ws.type)
				b.bounce()
			b.set_badge("%s ★%d" % [tr(ws.type), ws.level] + ("  +%d" % ws.queued if ws.queued > 0 else ""))
			b.set_tag("⬆ %d" % ws.upgrade_price if ws.can_upgrade else "")
			b.set_meter(ws.duration - ws.left if ws.left > 0 else -1, ws.duration, Color("#ffca28"))
	_meter.value = _st.click_meter.fill
	_hidden.text = App.t("hidden_left", {"n": _st.hidden_items_left})
	var bl := []
	for b in _st.boosts:
		bl.append("%s %ds" % [tr("boost_" + b.id), ceili(b.left / 10.0)])
	_boosts.text = "\n".join(bl)


func _show_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ---------------------------------------------------------------- pause

func _show_pause() -> void:
	if _pause_overlay != null or _ended:
		return
	_paused = true
	var p := GamePopup.open(self, tr("paused"), false)
	_pause_overlay = p
	p.body.custom_minimum_size.x = 560
	p.body.add_child(GamePopup.big_button(tr("resume"), func():
		p.close()
		_pause_overlay = null
		_paused = false))
	p.body.add_child(GamePopup.big_button(tr("restart"), func():
		App.clear_session()
		main.goto("game", {"level_id": session.level_id(), "intro_done": true}), Color("#e69138")))
	p.body.add_child(GamePopup.big_button(tr("quit_level"), func():
		App.clear_session()
		main.goto("map"), Color("#a0522d")))


# ---------------------------------------------------------------- level start / end

## Story (first time only), then the giver's goal popup over the farm. The level
## stays paused until the player presses Start.
func _intro() -> void:
	var lid := session.level_id()
	var lvl := App.core.get_level(lid)
	_paused = true
	var story_id := "story_" + lid
	if not App.campaign.is_tutorial_done(story_id):
		var keys := []
		if App.core.level_ids_in_world(lvl.world).find(lid) == 0:
			for w in _cat.worlds:
				if w.id == lvl.world:
					keys.append(w.story_key)
		keys.append(lvl.get("story_key", ""))
		var d := StoryDialog.show_keys(self, keys)
		if d != null:
			await d.finished
		App.campaign.mark_tutorial_done(story_id)
		App.save_campaign()
	_goals_popup(lvl)


func _goals_popup(lvl: Dictionary) -> void:
	var lid := session.level_id()
	var n := App.core.all_level_ids().find(lid) + 1
	var p := GamePopup.open(self, App.t("level_n", {"n": n}), false)
	p.body.custom_minimum_size.x = 980
	p.body.add_child(_giver_row(tr(lvl.get("story_key", ""))))
	p.body.add_child(UI.label(tr("briefing"), 36, GamePopup.WOOD_DARK))
	var goals := UI.hbox([], 18)
	goals.alignment = BoxContainer.ALIGNMENT_CENTER
	for g in session.state().goals:
		var id: String = g.get("product", g.get("animal", ""))
		goals.add_child(GamePopup.tile(id if id != "" else "coin", "%d" % g.target, "", func(): pass, true, 120))
	p.body.add_child(goals)
	p.body.add_child(UI.hbox([TrophyBadge.make("gold"), UI.label(App.format_time(lvl.trophy.gold_ticks), 32),
		TrophyBadge.make("silver"), UI.label(App.format_time(lvl.trophy.silver_ticks), 32)], 14))
	# Boosts bought with items found on earlier levels.
	var boosts := UI.hbox([], 12)
	var items := App.campaign.items()
	for b in _cat.boosts.values():
		var affordable := true
		for i in b.cost:
			affordable = affordable and items.get(i, 0) >= b.cost[i]
		var prepared := App.campaign.prepared_boosts().has(b.id)
		if not affordable and not prepared:
			continue
		var bb := GamePopup.big_button(("✔ " if prepared else "+ ") + tr("boost_" + b.id), func(): pass, Color("#8e7cc3"), 26)
		bb.disabled = prepared
		bb.pressed.connect(func():
			if App.campaign.prepare_boost(b.id):
				App.save_campaign()
				bb.text = "✔ " + tr("boost_" + b.id)
				bb.disabled = true)
		boosts.add_child(bb)
	if boosts.get_child_count() > 0:
		p.body.add_child(UI.label(tr("boosts"), 30, GamePopup.WOOD_DARK))
		p.body.add_child(boosts)
	var go := GamePopup.big_button(tr("start") + "!", func():
		var chosen := App.campaign.take_prepared_boosts()
		App.save_campaign()
		if not chosen.is_empty():
			# Boosts change the level's start state, so start it again with them.
			main.goto("game", {"level_id": lid, "boosts": chosen, "intro_done": true})
			return
		p.close()
		_paused = false, GamePopup.RIBBON, 48)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size = Vector2(380, 110)
	p.body.add_child(go)


## Portrait of whoever speaks the line, next to the line in a bubble.
func _giver_row(line: String) -> HBoxContainer:
	var l := StoryDialog.parse(line)
	var pic := TextureRect.new()
	pic.texture = Art.tex(l.sprite)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(190, 230)
	var bubble := PanelContainer.new()
	var sb := GamePopup.frame_style(Color("#fffaf0"), Color("#c9a66b"), 24, 4)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.shadow_size = 0
	bubble.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox([], 4)
	if l.speaker != "":
		v.add_child(UI.label(l.speaker, 30, Color("#b45f06")))
	v.add_child(UI.para(l.text, 640, 32))
	bubble.add_child(v)
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UI.hbox([pic, bubble], 16)


func _finish() -> void:
	_ended = true
	if _benchmark():
		return
	_close_panel()
	var result := session.result()
	var out := App.campaign.apply_result(result)
	App.save_campaign()
	App.clear_session()
	App.play_sfx("goal")
	await get_tree().create_timer(1.0).timeout
	_results_popup(result, out)


## Level complete, over the farm: giver's closing line, trophy, time, rewards.
func _results_popup(r: Dictionary, out: Dictionary) -> void:
	var lvl := App.core.get_level(r.level_id)
	var p := GamePopup.open(self, tr("level_complete"), false, 0.45)
	p.body.custom_minimum_size.x = 980
	var end_key: String = lvl.get("story_key", "") + "_end"
	if tr(end_key) != end_key:
		p.body.add_child(_giver_row(tr(end_key)))
	var badge := TrophyBadge.make(r.trophy, 150)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.pivot_offset = Vector2(75, 75)
	badge.scale = Vector2.ZERO
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.6).set_delay(0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var stats := UI.vbox([UI.label(App.t("result_trophy", {"t": tr(r.trophy)}), 36),
		UI.label(App.t("result_time", {"t": App.format_time(r.ticks)}), 34),
		UI.label(App.t("result_money", {"m": r.money}), 34)], 6)
	var items := []
	for i in out.items_gained:
		items.append("%d %s" % [out.items_gained[i], tr("item_" + i)])
	if not items.is_empty():
		stats.add_child(UI.label(App.t("result_items", {"i": ", ".join(items)}), 30))
	for a in out.new_achievements:
		stats.add_child(UI.label("★ " + App.t("achievement_unlocked", {"name": tr(a)}), 30, Color("#b45f06")))
		App.play_sfx("achievement")
	var row := UI.hbox([badge, stats], 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.body.add_child(row)
	var ids := App.core.all_level_ids()
	var next_i := ids.find(r.level_id) + 1
	var buttons := UI.hbox([
		GamePopup.big_button(tr("map"), func(): main.goto("map"), Color("#a0522d")),
		GamePopup.big_button(tr("restart"), func(): main.goto("game", {"level_id": r.level_id, "intro_done": true}), Color("#e69138")),
	], 20)
	if next_i < ids.size() and App.campaign.is_level_unlocked(ids[next_i]):
		buttons.add_child(GamePopup.big_button(tr("next") + " ▶", func(): main.goto("game", {"level_id": ids[next_i]})))
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	p.body.add_child(buttons)
	App.play_sfx("win")


# ---------------------------------------------------------------- panels

const PANEL_TITLES := {"market": "truck", "city": "plane", "animals": "shop", "well": "well"}


func _open_panel(kind: String, arg) -> void:
	_close_panel()
	_panel_kind = kind
	_panel_arg = arg
	var title: String
	if kind == "workshop":
		var ws = _st.workshops[arg]
		title = tr("build") if ws == null else "%s ★%d" % [tr(ws.type), ws.level]
	else:
		title = tr(PANEL_TITLES[kind])
	var p := GamePopup.open(self, title)
	p.closed.connect(func():
		if _panel == p:
			_panel = null
			_panel_kind = "")
	_panel = p
	_fill_panel()


## Rebuilds the open window's content from the current state (after a command).
func _fill_panel() -> void:
	var p := _panel as GamePopup
	if p == null:
		return
	p.clear()
	match _panel_kind:
		"market": _market_panel(p.body)
		"city": _city_panel(p.body)
		"animals": _animals_panel(p.body)
		"workshop": _workshop_panel(p.body, _panel_arg)
		"well": _well_panel(p.body)


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = null
	_panel_kind = ""


## Truck tapped: load goods and send in one window, as in the original. While the
## truck is on the road the tap only reports when it comes back.
func _on_truck_tapped() -> void:
	if _st.truck.away:
		_truck_b.bounce()
		_show_toast(App.t("truck_away", {"s": ceili(_st.truck.left / 10.0)}))
		return
	_open_panel("market", null)


## Tap the well to refill it; when it is full the tap opens its upgrade window.
func _on_well_tapped() -> void:
	var w: Dictionary = _st.well
	if w.water < w.capacity and w.refill_left == 0:
		if not _send(Cmd.refill_well()):
			App.play_sfx("error")
		return
	if w.can_upgrade:
		_open_panel("well", null)
	else:
		_well_b.bounce()


func _on_plane_tapped() -> void:
	if _st.plane.away:
		_plane_b.bounce()
		_show_toast(App.t("plane_away", {"s": ceili(_st.plane.left / 10.0)}))
		return
	_open_panel("city", null)


func _well_panel(box: VBoxContainer) -> void:
	var w: Dictionary = _st.well
	box.add_child(UI.label("★%d  ·  %d %s" % [w.level, w.capacity, tr("water")], 34, GamePopup.WOOD_DARK))
	if w.can_upgrade:
		box.add_child(_cmd_button("⬆ ◉ %d" % w.upgrade_price, Cmd.upgrade_well(), _st.money >= w.upgrade_price, Color("#e69138"), 32))


func _cmd_button(text: String, cmd: Dictionary, enabled := true, color := GamePopup.RIBBON, size := 30) -> Button:
	var b := GamePopup.big_button(text, func():
		if not _send(cmd):
			App.play_sfx("error"), color, size)
	b.disabled = not enabled
	return b


func _try(cmd: Dictionary) -> void:
	if not _send(cmd):
		App.play_sfx("error")


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	return g


func _market_panel(box: VBoxContainer) -> void:
	var wh: Dictionary = _st.warehouse
	var t: Dictionary = _st.truck
	var cols := UI.hbox([], 36)
	box.add_child(cols)
	# Left: the warehouse; tap a good to put one on the truck.
	var left := UI.vbox([], 10)
	left.custom_minimum_size.x = 600
	cols.add_child(left)
	left.add_child(UI.label("%s  %d/%d" % [tr("warehouse"), wh.used, wh.capacity], 32, GamePopup.WOOD_DARK))
	var grid := _grid(4)
	left.add_child(grid)
	for prod in wh.items:
		var sz: int = _cat.products[prod].size
		grid.add_child(GamePopup.tile(prod, "×%d" % wh.items[prod], "◉ %d" % _cat.products[prod].sell_price,
			func(): _try(Cmd.load_truck(prod, 1)), t.available and t.used + sz <= t.capacity))
	if wh.items.is_empty():
		left.add_child(UI.para(tr("warehouse_empty"), 580, 30, Color(App.COLOR_INK, 0.7)))
	var lower := UI.hbox([], 12)
	if not wh.items.is_empty() and t.available:
		lower.add_child(GamePopup.big_button(tr("load_all"), _load_all, Color("#3d85c6"), 28))
	if wh.can_upgrade:
		lower.add_child(_cmd_button("⬆ %s ◉ %d" % [tr("warehouse"), wh.upgrade_price], Cmd.upgrade_warehouse(), _st.money >= wh.upgrade_price, Color("#e69138"), 26))
	left.add_child(lower)
	# Right: the truck's load, total and Send.
	var right := UI.vbox([], 10)
	right.custom_minimum_size.x = 440
	cols.add_child(right)
	right.add_child(UI.label("%s  %d/%d" % [tr("truck"), t.used, t.capacity], 32, GamePopup.WOOD_DARK))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = t.capacity
	bar.value = t.used
	bar.custom_minimum_size = Vector2(420, 26)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#6aa84f")
	fill.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#e9dfc8")
	bg.border_color = Color("#c9a66b")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("background", bg)
	right.add_child(bar)
	var cargo := _grid(3)
	right.add_child(cargo)
	var total := 0
	for prod in t.cargo:
		total += _cat.products[prod].sell_price * t.cargo[prod]
		cargo.add_child(GamePopup.tile(prod, "×%d" % t.cargo[prod], "", func(): _try(Cmd.unload_truck(prod, 1)), true, 112))
	if t.cargo.is_empty():
		right.add_child(UI.para(tr("truck_empty"), 420, 28, Color(App.COLOR_INK, 0.7)))
	right.add_child(UI.label("◉ %d" % total, 40, Color("#b8860b")))
	var send := GamePopup.big_button("🚚 " + tr("send"), func():
		if _send(Cmd.send_truck()):
			_close_panel()
		else:
			App.play_sfx("error"), GamePopup.RIBBON, 40)
	send.disabled = t.cargo.is_empty() or not t.available
	right.add_child(send)
	if not t.available:
		right.add_child(UI.para(tr("no_truck"), 420, 26, Color(App.COLOR_INK, 0.7)))
	if t.can_upgrade:
		right.add_child(_cmd_button("⬆ %s ◉ %d" % [tr("truck"), t.upgrade_price], Cmd.upgrade_truck(), _st.money >= t.upgrade_price, Color("#e69138"), 26))


## Loads as much of every good as still fits.
func _load_all() -> void:
	var loaded := false
	for prod in _st.warehouse.items.keys():
		var sz: int = _cat.products[prod].size
		var room: int = (_st.truck.capacity - _st.truck.used) / sz
		var n := mini(room, _st.warehouse.items.get(prod, 0))
		if n > 0 and session.apply(Cmd.load_truck(prod, n)):
			loaded = true
			_st = session.state()
	if not loaded:
		App.play_sfx("error")
	_st = session.state()
	_farm.push_state(_st)
	_handle_events(session.poll_events())
	_fill_panel()


## The plane's shopping list: tap a good to add one, tap it in the list to take
## it off; paying happens when the plane leaves.
func _city_panel(box: VBoxContainer) -> void:
	var t: Dictionary = _st.plane
	var cols := UI.hbox([], 36)
	box.add_child(cols)
	var left := UI.vbox([], 10)
	left.custom_minimum_size.x = 600
	cols.add_child(left)
	left.add_child(UI.label(tr("city"), 32, GamePopup.WOOD_DARK))
	var grid := _grid(4)
	left.add_child(grid)
	for prod in _cat.products.values():
		if prod.buy_price <= 0:
			continue
		grid.add_child(GamePopup.tile(prod.id, "", "◉ %d" % prod.buy_price, func(): _try(Cmd.order_plane(prod.id, 1)),
			t.used + prod.size <= t.capacity))
	var right := UI.vbox([], 10)
	right.custom_minimum_size.x = 440
	cols.add_child(right)
	right.add_child(UI.label("%s  %d/%d" % [tr("plane"), t.used, t.capacity], 32, GamePopup.WOOD_DARK))
	var cargo := _grid(3)
	right.add_child(cargo)
	for prod in t.cargo:
		cargo.add_child(GamePopup.tile(prod, "×%d" % t.cargo[prod], "", func(): _try(Cmd.order_plane(prod, -1)), true, 112))
	if t.cargo.is_empty():
		right.add_child(UI.para(tr("plane_empty"), 420, 28, Color(App.COLOR_INK, 0.7)))
	right.add_child(UI.label("◉ %d" % t.cost, 40, Color("#b8860b") if _st.money >= t.cost else Color("#c0504d")))
	var send := GamePopup.big_button("✈ " + tr("send"), func():
		if _send(Cmd.send_plane()):
			_close_panel()
		else:
			App.play_sfx("error"), GamePopup.RIBBON, 40)
	send.disabled = t.cargo.is_empty() or _st.money < t.cost
	right.add_child(send)
	if t.can_upgrade:
		right.add_child(_cmd_button("⬆ %s ◉ %d" % [tr("plane"), t.upgrade_price], Cmd.upgrade_plane(), _st.money >= t.upgrade_price, Color("#e69138"), 26))


func _animals_panel(box: VBoxContainer) -> void:
	var owned := {}
	for a in _st.animals:
		owned[a.type] = owned.get(a.type, []) + [a]
	var ids: Array = _st.available_animals.duplicate()
	for id in owned:
		if not ids.has(id):
			ids.append(id)
	var grid := _grid(2)
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	for id in ids:
		var d: Dictionary = _cat.animals[id]
		var mine: Array = owned.get(id, [])
		var can_buy: bool = _st.available_animals.has(id) and _st.money >= d.price
		var buttons := UI.vbox([], 8)
		if _st.available_animals.has(id):
			buttons.add_child(_cmd_button("%s ◉ %d" % [tr("buy"), d.price], Cmd.buy_animal(id), can_buy, GamePopup.RIBBON, 26))
		buttons.add_child(_cmd_button("%s ◉ %d" % [tr("sell"), d.sell_price], Cmd.sell_animal(mine[0].uid if not mine.is_empty() else -1),
			not mine.is_empty(), Color("#e69138"), 26))
		grid.add_child(UI.hbox([GamePopup.tile(id, "×%d" % mine.size(), "", func(): pass, true, 120), buttons], 12))


func _workshop_panel(box: VBoxContainer, slot: int) -> void:
	var ws = _st.workshops[slot]
	if ws == null:
		# The spot offers one or more buildings; pick which one to build.
		var grid := _grid(3)
		box.add_child(grid)
		for id in _st.slots[slot]:
			var d: Dictionary = _cat.workshops[id]
			var price: int = d.levels[0].price
			var v := UI.vbox([GamePopup.tile(id, "", "◉ %d" % price, func(): _try(Cmd.build_workshop(slot, id)),
				_st.money >= price, 150), _recipe_row(d.inputs, d.output, 44)], 6)
			grid.add_child(v)
		return
	box.add_child(_recipe_row(ws.inputs, ws.output, 72))
	var status := "%d dtk" % ceili(ws.duration / 10.0)
	if ws.left > 0:
		status = "… %d dtk" % ceili(ws.left / 10.0)
	var busy: int = (1 if ws.left > 0 else 0) + ws.queued
	box.add_child(UI.label("%s   ·   %s %d/%d" % [status, tr("queue"), busy, ws.queue_max], 32, GamePopup.WOOD_DARK))
	var row := UI.hbox([_cmd_button("▶ " + tr("produce"), Cmd.start_workshop(slot), busy < ws.queue_max, GamePopup.RIBBON, 34)], 12)
	if ws.can_upgrade:
		row.add_child(_cmd_button("⬆ ★%d ◉ %d" % [ws.level + 1, ws.upgrade_price], Cmd.upgrade_workshop(slot), _st.money >= ws.upgrade_price, Color("#e69138"), 28))
	row.add_child(_cmd_button("%s ◉ %d" % [tr("sell"), ws.sell_price], Cmd.sell_workshop(slot), ws.left == 0, Color("#a0522d"), 26))
	box.add_child(row)
	# Other buildings this spot could hold instead.
	var others: Array = _st.slots[slot].filter(func(o): return o != ws.type)
	if not others.is_empty():
		box.add_child(UI.label(tr("slot_alternatives") + ": " + ", ".join(others.map(func(o): return tr(o))), 26, Color(App.COLOR_INK, 0.7)))


## Inputs → output drawn with icons, e.g. [egg] 2 → [pastry].
func _recipe_row(inputs: Dictionary, output: String, px: int) -> HBoxContainer:
	var h := UI.hbox([], 8)
	for p in inputs:
		h.add_child(Art.icon(p, px))
		h.add_child(UI.label("×%d" % inputs[p], int(px * 0.5), GamePopup.WOOD_DARK))
	h.add_child(UI.label("→", int(px * 0.6), GamePopup.WOOD_DARK))
	h.add_child(Art.icon(output, px))
	return h
