## A level being played: ticks the session at 10 Hz, renders the farm and HUD,
## sends touch commands, shows tutorials, saves a snapshot when the app pauses.
extends Screen

const TICK := 1.0 / LevelSession.TICKS_PER_SECOND
const STAGE := Vector2(1920, 1080)
const FIELD_POS := Vector2(360, 300)
const AUTOSAVE_TICKS := 50

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
var _goals: VBoxContainer
var _well_btn: Button
var _wh_btn: Button
var _truck_btn: Button
var _ws_btns: Array[Button] = []
var _ws_bars: Array[ProgressBar] = []
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
	_queue_tutorial_trigger.call_deferred("start", {})


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
		_open_panel(_panel_kind, _panel_arg)
	return ok


func _finish() -> void:
	_ended = true
	if _benchmark():
		return
	var result := session.result()
	var out := App.campaign.apply_result(result)
	App.save_campaign()
	App.clear_session()
	await get_tree().create_timer(1.2).timeout
	main.goto("results", {"result": result, "out": out})


# ---------------------------------------------------------------- events

func _handle_events(evts: Array) -> void:
	for e in evts:
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
			"truck_returned":
				_show_toast("+%d" % e.money)
				App.play_sfx("coins")
			"predator_warning":
				_show_toast(tr("predator_warning_" + e.predator))
				App.play_sfx("warning")
			"predator_caged", "predator_chased":
				_farm.pop_text(Vector2(e.x, e.y), "✔", Color("#b9f6ca"))
				App.play_sfx("cage")
			"animal_eaten", "animal_died":
				_farm.pop_text(Vector2(e.x, e.y), "✖", Color("#ff8a80"))
				App.play_sfx("animal_lost")
			"hybrid_born":
				_farm.pop_text(Vector2(e.x, e.y), "♥ " + tr(e.animal), Color("#f8bbd0"))
				App.play_sfx("hybrid")
			"hidden_found":
				_show_toast(App.t("hidden_left", {"n": _st.hidden_items_left}))
				App.play_sfx("sparkle")
			"goal_reached":
				App.play_sfx("goal")
		_queue_tutorial_trigger(e.type, e)


# ---------------------------------------------------------------- tutorials

const TUTORIAL_TRIGGERS := {
	"plant_grass": "animal_hungry", "collect": "product_spawned", "well": "well_empty",
	"warehouse": "product_collected", "click_meter": "click_reward", "mole": "predator_warning:mole",
	"bear": "predator_warning:bear", "truck": "start", "workshop": "start", "buy_animal": "start",
	"hybrid": "start", "city": "start",
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
	bg.color = Color("#9ccc65")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_farm = FarmView.new()
	_farm.position = FIELD_POS
	var f: Dictionary = _cat.farm.field
	_farm.size = Vector2(f.cols, f.rows) * f.cell * FarmView.SCALE
	_farm.command.connect(func(c): _send(c))
	_stage.add_child(_farm)
	var slots: int = session.state().workshops.size()
	for i in slots:
		var b := _stage_button("", Vector2(0, 0), Vector2(250, 130), func(): _open_panel("workshop", i))
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 64)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_constant_override("h_separation", 4)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(210, 18)
		bar.position = Vector2(20, 100)
		bar.size = Vector2(210, 18)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bar)
		_ws_btns.append(b)
		_ws_bars.append(bar)
	_well_btn = _stage_button("", Vector2(40, 300), Vector2(280, 200), func():
		if not _send(Cmd.refill_well()):
			App.play_sfx("error"))
	_wh_btn = _stage_button("", Vector2(40, 560), Vector2(280, 260), func(): _open_panel("warehouse", null))
	_truck_btn = _stage_button("", Vector2(1600, 300), Vector2(280, 200), func(): _open_panel("truck", null))
	for pair in [[_well_btn, "well"], [_wh_btn, "warehouse"], [_truck_btn, "truck"]]:
		_set_building_icon(pair[0], pair[1])
	_stage_button(tr("city"), Vector2(1600, 520), Vector2(280, 140), func(): _open_panel("city", null))
	_stage_button(tr("shop"), Vector2(1600, 680), Vector2(280, 140), func(): _open_panel("animals", null))
	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.position = Vector2(360, 1000)
	_meter.size = Vector2(900, 40)
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
	_hidden = UI.label("", 32)
	_hidden.position = Vector2(1290, 996)
	_stage.add_child(_hidden)
	_boosts = UI.label("", 28)
	_boosts.position = Vector2(40, 840)
	_boosts.size = Vector2(300, 200)
	_stage.add_child(_boosts)
	# HUD pinned to safe area (top bar)
	var hud := safe_root()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UI.hbox([], 32)
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	_money = UI.label("", 44)
	_money.custom_minimum_size.x = 260
	top.add_child(UI.panel(_money))
	_timer = UI.label("", 36)
	top.add_child(UI.panel(_timer))
	_goals = UI.vbox([], 2)
	_goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gp := UI.panel(_goals)
	gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gp)
	top.add_child(UI.button("❚❚", _show_pause, 40))
	_toast = UI.label("", 44, Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(360, 240)
	_toast.size = Vector2(1200, 60)
	_toast.modulate.a = 0
	_stage.add_child(_toast)
	_layout()


func _stage_button(text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := UI.button(text, cb, 30)
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.clip_text = true
	_stage.add_child(b)
	return b


## Shows a building sprite left of the button text, when the sprite exists.
func _set_building_icon(b: Button, id: String) -> void:
	var t := Art.tex(id)
	if t == null:
		return
	b.icon = t
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 120)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_constant_override("h_separation", 6)


## Keeps the 16:9 core stage centered; extra width/height (4:3 … 21:9) is background.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / STAGE.x, vp.y / STAGE.y)
	_stage.scale = Vector2(s, s)
	_stage.position = (vp - STAGE * s) / 2
	var slots := _ws_btns.size()
	var fw: float = _cat.farm.field.cols * _cat.farm.field.cell
	for i in slots:
		var x: float = (i + 1) * fw / (slots + 1) * FarmView.SCALE + FIELD_POS.x - 125
		_ws_btns[i].position = Vector2(x, 150)


func _refresh_hud() -> void:
	_money.text = "◉ %d" % _st.money
	var t: Dictionary = _st.trophy
	var now: int = _st.tick
	var color: String = _st.trophy_now
	_timer.text = "%s  [%s %s | %s %s]" % [App.format_time(now), tr("gold"), App.format_time(t.gold_ticks), tr("silver"), App.format_time(t.silver_ticks)]
	_timer.add_theme_color_override("font_color", TrophyBadge.COLORS[color].darkened(0.3))
	while _goals.get_child_count() < _st.goals.size():
		_goals.add_child(UI.label("", 28))
	for i in _st.goals.size():
		var g: Dictionary = _st.goals[i]
		var l: Label = _goals.get_child(i)
		l.text = "%s %s  %d/%d" % ["✔" if g.done else "•", App.goal_text(g), mini(g.progress, g.target), g.target]
		l.add_theme_color_override("font_color", App.COLOR_ACCENT_DARK if g.done else App.COLOR_INK)
	var w: Dictionary = _st.well
	_well_btn.text = "%s\n%d/%d" % [tr("well"), w.water, w.capacity] if w.refill_left == 0 else "%s\n…%ds" % [tr("well"), ceili(w.refill_left / 10.0)]
	if w.water == 0 and w.refill_left == 0:
		_well_btn.text += "\n" + App.t("refill", {"p": _cat.farm.well.refill_price})
	_wh_btn.text = "%s\n%d/%d" % [tr("warehouse"), _st.warehouse.used, _st.warehouse.capacity]
	var tr_: Dictionary = _st.truck
	_truck_btn.text = "%s\n%s" % [tr("truck"), ("…%ds" % ceili(tr_.left / 10.0)) if tr_.away else "%d/%d" % [tr_.used, tr_.capacity]]
	for i in _ws_btns.size():
		var ws = _st.workshops[i]
		if ws == null:
			_ws_btns[i].text = "+\n" + tr("empty_slot")
			_ws_btns[i].icon = null
			_ws_bars[i].visible = false
		else:
			_ws_btns[i].icon = Art.tex(ws.type)
			_ws_btns[i].text = ("%s\n★%d" if _ws_btns[i].icon != null else "%s ★%d") % [tr(ws.type), ws.level + 1]
			_ws_bars[i].visible = ws.left > 0
			_ws_bars[i].max_value = ws.duration
			_ws_bars[i].value = ws.duration - ws.left
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
	var box := UI.vbox([UI.label(tr("paused"), 56)])
	box.add_child(UI.button(tr("resume"), func():
		_pause_overlay.queue_free()
		_pause_overlay = null
		_paused = false))
	box.add_child(UI.button(tr("restart"), func():
		App.clear_session()
		main.goto("game", {"level_id": session.level_id()})))
	box.add_child(UI.button(tr("quit_level"), func():
		App.clear_session()
		main.goto("map")))
	_pause_overlay = UI.modal(self, box)


# ---------------------------------------------------------------- panels

func _open_panel(kind: String, arg) -> void:
	if _panel != null:
		_panel.queue_free()
	_panel_kind = kind
	_panel_arg = arg
	var box := UI.vbox([], 12)
	box.custom_minimum_size.x = 980
	match kind:
		"warehouse": _warehouse_panel(box)
		"truck": _truck_panel(box)
		"city": _city_panel(box)
		"animals": _animals_panel(box)
		"workshop": _workshop_panel(box, arg)
	box.add_child(UI.button(tr("close"), _close_panel))
	_panel = UI.modal(self, box)
	_panel.get_child(0).get_child(0).get_child(0).scale = Vector2.ONE


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = null
	_panel_kind = ""


func _row(text: String, buttons: Array, icon_id := "") -> HBoxContainer:
	var l := UI.label(text, 32)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lead: Array = [Art.icon(icon_id)] if icon_id != "" and Art.tex(icon_id) != null else []
	return UI.hbox(lead + [l] + buttons)


func _small(text: String, cmd: Dictionary, enabled := true) -> Button:
	var b := UI.button(text, func():
		if not _send(cmd):
			App.play_sfx("error"), 28)
	b.disabled = not enabled
	return b


func _warehouse_panel(box: VBoxContainer) -> void:
	var wh: Dictionary = _st.warehouse
	box.add_child(UI.label("%s — %s" % [tr("warehouse"), App.t("capacity", {"used": wh.used, "cap": wh.capacity})], 40))
	for p in wh.items:
		var n: int = wh.items[p]
		var price: int = _cat.products[p].sell_price
		box.add_child(_row("%s ×%d  (%s)" % [tr(p), n, App.t("price_each", {"p": price})], [
			_small(tr("load"), Cmd.load_truck(p, 1), not _st.truck.away),
			_small(tr("load_all"), Cmd.load_truck(p, mini(n, (_st.truck.capacity - _st.truck.used) / _cat.products[p].size)), not _st.truck.away),
		], p))
	if wh.can_upgrade:
		var next: Dictionary = _cat.farm.warehouse.levels[wh.level + 1]
		box.add_child(_small("%s → %d (◉ %d)" % [tr("upgrade"), next.capacity + wh.bonus, next.price], Cmd.upgrade_warehouse(), _st.money >= next.price))


func _truck_panel(box: VBoxContainer) -> void:
	var t: Dictionary = _st.truck
	box.add_child(UI.label("%s — %s" % [tr("truck"), App.t("capacity", {"used": t.used, "cap": t.capacity})], 40))
	if t.away:
		box.add_child(UI.label(App.t("truck_away", {"s": ceili(t.left / 10.0)}), 32))
		return
	var total := 0
	for p in t.cargo:
		var price: int = _cat.products[p].sell_price
		total += price * t.cargo[p]
		box.add_child(_row("%s ×%d  (%s)" % [tr(p), t.cargo[p], App.t("price_each", {"p": price})], [_small(tr("unload"), Cmd.unload_truck(p, 1))], p))
	box.add_child(_small("%s  (◉ %d)" % [tr("send"), total], Cmd.send_truck(), total > 0 or not t.cargo.is_empty()))
	if t.can_upgrade:
		var next: Dictionary = _cat.farm.truck.levels[t.level + 1]
		box.add_child(_small("%s → %d (◉ %d)" % [tr("upgrade"), next.capacity, next.price], Cmd.upgrade_truck(), _st.money >= next.price))


func _city_panel(box: VBoxContainer) -> void:
	box.add_child(UI.label(tr("city"), 40))
	for p in _cat.products.values():
		if p.buy_price <= 0:
			continue
		box.add_child(_row("%s  (%s)" % [tr(p.id), App.t("price_each", {"p": p.buy_price})], [
			_small(tr("buy") + " 1", Cmd.buy_from_city(p.id, 1), _st.money >= p.buy_price),
			_small(tr("buy") + " 5", Cmd.buy_from_city(p.id, 5), _st.money >= p.buy_price * 5),
		], p.id))


func _animals_panel(box: VBoxContainer) -> void:
	box.add_child(UI.label(tr("shop"), 40))
	var owned := {}
	for a in _st.animals:
		owned[a.type] = owned.get(a.type, []) + [a]
	for id in _st.available_animals:
		var d: Dictionary = _cat.animals[id]
		var mine: Array = owned.get(id, [])
		var sell_btn := _small("%s (◉ %d)" % [tr("sell"), d.sell_price], Cmd.sell_animal(mine[0].uid if not mine.is_empty() else -1), not mine.is_empty())
		box.add_child(_row("%s ×%d" % [tr(id), mine.size()], [_small("%s (◉ %d)" % [tr("buy"), d.price], Cmd.buy_animal(id), _st.money >= d.price), sell_btn], id))
	for id in owned:
		if not _st.available_animals.has(id):
			var d: Dictionary = _cat.animals[id]
			box.add_child(_row("%s ×%d" % [tr(id), owned[id].size()], [_small("%s (◉ %d)" % [tr("sell"), d.sell_price], Cmd.sell_animal(owned[id][0].uid))], id))


func _workshop_panel(box: VBoxContainer, slot: int) -> void:
	var ws = _st.workshops[slot]
	if ws == null:
		box.add_child(UI.label(tr("build"), 40))
		for id in _st.available_workshops:
			var d: Dictionary = _cat.workshops[id]
			box.add_child(_row("%s: %s → %s" % [tr(id), _recipe(d.inputs), tr(d.output)],
				[_small("◉ %d" % d.build_price, Cmd.build_workshop(slot, id), _st.money >= d.build_price)], id))
		return
	box.add_child(UI.label("%s ★%d" % [tr(ws.type), ws.level + 1], 40))
	box.add_child(UI.label("%s → %s  (%ds)" % [_recipe(ws.inputs), tr(ws.output), ceili(ws.duration / 10.0)], 32))
	if ws.left > 0:
		box.add_child(UI.label("…%ds" % ceili(ws.left / 10.0), 32))
	box.add_child(_small(tr("produce"), Cmd.start_workshop(slot), ws.left == 0))
	var d: Dictionary = _cat.workshops[ws.type]
	if ws.can_upgrade:
		var up: Dictionary = d.upgrades[ws.level]
		box.add_child(_small("%s (◉ %d)" % [tr("upgrade"), up.price], Cmd.upgrade_workshop(slot), _st.money >= up.price))
	box.add_child(_small("%s (◉ %d)" % [tr("sell"), d.sell_price], Cmd.sell_workshop(slot), ws.left == 0))


func _recipe(inputs: Dictionary) -> String:
	var parts := []
	for p in inputs:
		parts.append("%d %s" % [inputs[p], tr(p)])
	return " + ".join(parts)
