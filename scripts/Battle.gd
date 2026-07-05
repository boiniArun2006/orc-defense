extends Node2D
## Battle screen. Runs one game level: finite waves (boss every 5th level), a gate
## with HP, deploy-from-inventory placement (select -> preview -> confirm -> aim),
## pinch-to-zoom camera (visual only), and Victory/Defeat overlays.

# ---- Gate / level tuning ----
const GATE_HP_MAX := 100          # each leaked orc removes 5, so ~20 leaks = loss
const ORC_GATE_DAMAGE := 5

# ---- Horde tuning ----
const BASE_WAVE_SIZE := 65        # orcs in the first wave of level 1
const WAVE_GROWTH := 1.8          # each wave ~1.8x the previous (feels like doubling)
const LEVEL_SIZE_BONUS := 0.15    # +15% base horde per game level
const MAX_ALIVE := 200            # concurrency cap: pause spawns above this (perf)

# Placement flow states
const MODE_IDLE := 0
const MODE_PREVIEW := 1
const MODE_AIM := 2
const MODE_STRIKE := 3           # artillery targeting: next tap calls the barrage

# ---- Artillery ability ----
const STRIKE_COOLDOWN := 45.0
const STRIKE_SHELLS := 6
const STRIKE_SPREAD := 130.0
const STRIKE_DAMAGE := 55.0
const STRIKE_RADIUS := 85.0

# Build-phase timing: generous window before wave 1 and between waves so the
# player can actually place/aim turrets under no pressure.
const PREP_TIME := 10.0

# Playable area for turret placement (inside the map's border frame)
const PLAY_RECT := Rect2(40, 40, 1200, 640)

var level := 1
var gate_hp := GATE_HP_MAX

var waves_total := 2
var wave := 0
var wave_active := false
var spawned := 0
var to_spawn := 0
var spawn_timer := 0.0
var spawn_interval := 0.9
var between_timer := PREP_TIME
var boss_wave := false
var finished := false            # victory or defeat reached

var path_points: PackedVector2Array
var gate_pos: Vector2
var enemies: Array = []

# How many of each turret the player can still deploy THIS battle. A local copy of
# Game.inventory so deploying doesn't permanently consume the owned roster.
var deploy_left := {}

# Placement
var mode: int = MODE_IDLE
var pending_type := ""
var ghost_pos := Vector2.ZERO
var aim_dir := 0.0
var aim_half := deg_to_rad(60)
var pending_auto_fire := true

# Camera / zoom
var cam: Camera2D
var _zoom := 1.0
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0
var _active_touches := {}

# World layer that the camera looks at (map + units live here)
var world: Node2D
var gore: GoreLayer              # corpses / blood / damage numbers (under units)
var strike_cd := 0.0             # artillery cooldown remaining
var _shake := 0.0                # camera shake amplitude
var sel_turret: Turret = null    # turret selected for in-battle upgrade

# UI refs
var ui: CanvasLayer
var lbl_top: Label
var lbl_msg: Label
var deploy_bar: HBoxContainer
var confirm_box: HBoxContainer
var aim_panel: VBoxContainer
var lbl_arc: Label
var arc_slider: HSlider
var auto_check: CheckButton
var overlay: Control
var btn_strike: Button
var upgrade_panel: VBoxContainer
var lbl_upg: Label
var b_upg: Button


func _ready() -> void:
	level = Game.highest_level
	_configure_level()
	for k in Game.inventory.keys():
		deploy_left[k] = int(Game.inventory[k])
	var map: Dictionary = MapData.get_for_level(level)
	path_points = map["path"]
	gate_pos = path_points[path_points.size() - 1]
	# static textured map (drawn once, sits behind everything)
	var ground := GroundLayer.new()
	ground.battle = self
	ground.biome = map["biome"]
	ground.decos = map["decos"]
	add_child(ground)
	# gore layer: corpses/blood/damage numbers, above ground, below units
	gore = GoreLayer.new()
	add_child(gore)
	# per-frame overlay layer that also parents the units
	world = BattleWorld.new()
	world.battle = self
	add_child(world)
	_setup_camera()
	_build_ui()
	set_process_unhandled_input(true)


func _configure_level() -> void:
	# early levels: 2 waves; grows as you clear boss levels
	var bosses_beaten := int(floor((level - 1) / 5.0))
	waves_total = 2 + bosses_beaten
	boss_wave = (level % 5 == 0)


func _setup_camera() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	cam.enabled = true
	world.add_child(cam)
	cam.make_current()


# ================= Waves =================
func _process(delta: float) -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e))
	if not finished:
		if wave_active:
			if spawned < to_spawn:
				# concurrency cap: hold spawns while the field is full (protects FPS)
				if enemies.size() < MAX_ALIVE:
					spawn_timer -= delta
					if spawn_timer <= 0.0:
						_spawn_one()
						spawned += 1
						spawn_timer = spawn_interval
			elif enemies.is_empty():
				_end_wave()
		else:
			between_timer -= delta
			if between_timer <= 0.0:
				_start_wave()
	# artillery cooldown + camera shake decay
	if strike_cd > 0.0:
		strike_cd = max(0.0, strike_cd - delta)
	if _shake > 0.01:
		_shake = move_toward(_shake, 0.0, 24.0 * delta)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
	_update_top()
	# only the gate + placement ghost need per-frame redraw; keep it to placement mode
	if mode != MODE_IDLE:
		world.queue_redraw()


func _start_wave() -> void:
	wave += 1
	wave_active = true
	spawned = 0
	# Geometric growth so each wave feels ~2x the last, plus a per-level base bump.
	# e.g. L1: 50, 90, 162...  Higher levels start larger.
	var level_base: float = BASE_WAVE_SIZE * (1.0 + LEVEL_SIZE_BONUS * (level - 1))
	to_spawn = int(round(level_base * pow(WAVE_GROWTH, wave - 1)))
	# fast trickle so many are on screen at once (clamped, subject to MAX_ALIVE gate)
	spawn_interval = max(0.05, 0.16 - level * 0.008)
	spawn_timer = 0.0
	_flash("HORDE INCOMING!")


func _end_wave() -> void:
	wave_active = false
	between_timer = PREP_TIME
	Game.add_xp(6 + level)
	Game.add_coins(5 + level)              # trimmed wave bonus
	Game.save_game()                       # don't lose battle earnings if OS kills the app
	if wave >= waves_total:
		_victory()


func _spawn_one() -> void:
	var e := Enemy.new()
	e.path = path_points
	var is_last_wave_boss: bool = boss_wave and wave == waves_total and spawned == to_spawn - 1
	if is_last_wave_boss:
		e.is_boss = true
		e.speed = 40.0 + level
		e.max_hp = 900.0 + level * 160.0
		e.coin_reward = 30 + level * 2
		e.xp_reward = 40 + level * 3
		e.gate_damage = 25             # a boss breaching hurts a lot
	else:
		# lots of weaker orcs — die to sustained fire, not one shot.
		# Meaty enough from level 1 that unguarded stretches WILL leak.
		e.speed = 62.0 + level * 2.4
		e.max_hp = 30.0 + level * 7.0 + wave * 4.0
		e.coin_reward = 1              # earn turrets, don't drown in gold
		e.xp_reward = 1
		e.gate_damage = ORC_GATE_DAMAGE
	e.hp = e.max_hp
	e.battle = self
	e.died.connect(_on_enemy_died.bind(e))
	e.reached_gate.connect(_on_enemy_reached_gate)
	world.add_child(e)
	enemies.append(e)


func _on_enemy_died(coins: int, xp: int, e: Enemy) -> void:
	Game.add_coins(coins)
	Game.add_xp(xp)
	if is_instance_valid(e):
		gore.add_corpse(e.position, e.is_boss)
		if e.is_boss:
			shake(8.0)


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func _on_enemy_reached_gate(dmg: int) -> void:
	gate_hp -= dmg
	world.queue_redraw()       # refresh the gate HP bar
	if gate_hp <= 0:
		gate_hp = 0
		_defeat()


# ================= Placement flow =================
func _select_type(type_id: String) -> void:
	if finished or mode == MODE_AIM:
		return
	if _deploy_count(type_id) <= 0:
		_flash("None left to deploy — buy more in the Workshop")
		return
	pending_type = type_id
	mode = MODE_PREVIEW
	ghost_pos = Vector2(640, 360)
	_sync_placement_ui()
	_flash("Drag to position, then Confirm")


func _confirm_pressed() -> void:
	if mode == MODE_PREVIEW:
		if not PLAY_RECT.has_point(ghost_pos):
			_flash("Outside the battlefield — place inside the border")
			return
		if _dist_to_path(ghost_pos) < 40.0:
			_flash("Too close to the path")
			return
		var def := TurretData.get_def(pending_type)
		if def["kind"] == "bomb":
			_place_turret()             # bombers skip aiming
		else:
			mode = MODE_AIM
			aim_dir = 0.0
			arc_slider.value = 120
			aim_half = deg_to_rad(60)
			auto_check.button_pressed = true
			pending_auto_fire = true
			_sync_placement_ui()
			_flash("Drag to aim, slider sets arc width, then Confirm")
	elif mode == MODE_AIM:
		_place_turret()


func _cancel_pressed() -> void:
	mode = MODE_IDLE
	pending_type = ""
	_sync_placement_ui()


func _place_turret() -> void:
	var t := Turret.new()
	t.battle = self
	t.position = ghost_pos
	t.setup(pending_type)
	if TurretData.get_def(pending_type)["kind"] == "gun":
		t.aim_angle = aim_dir
		t.arc_half = aim_half
		if pending_type == "sniper":
			t.auto_fire = pending_auto_fire
	world.add_child(t)
	deploy_left[pending_type] = _deploy_count(pending_type) - 1
	mode = MODE_IDLE
	pending_type = ""
	_sync_placement_ui()
	_refresh_deploy_bar()


func _deploy_count(type_id: String) -> int:
	return int(deploy_left.get(type_id, 0))


# ================= Input =================
func _unhandled_input(event: InputEvent) -> void:
	# --- multi-touch pinch zoom (view only) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = event.position
		else:
			_active_touches.erase(event.index)
		if _active_touches.size() == 2:
			var pts := _active_touches.values()
			_pinch_start_dist = pts[0].distance_to(pts[1])
			_pinch_start_zoom = _zoom
	elif event is InputEventScreenDrag:
		_active_touches[event.index] = event.position
		if _active_touches.size() == 2:
			var pts := _active_touches.values()
			var d: float = pts[0].distance_to(pts[1])
			if _pinch_start_dist > 0.0:
				_zoom = clamp(_pinch_start_zoom * (d / _pinch_start_dist), 0.6, 2.2)
				cam.zoom = Vector2(_zoom, _zoom)
			return

	# --- single-pointer placement (touch or mouse) ---
	var pos := Vector2.ZERO
	var down := false
	var drag := false
	if event is InputEventScreenTouch and event.pressed and _active_touches.size() < 2:
		pos = event.position; down = true
	elif event is InputEventScreenDrag and _active_touches.size() < 2:
		pos = event.position; drag = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position; down = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		pos = event.position; drag = true
	if not (down or drag):
		return

	var world_pos := _screen_to_world(pos)
	if mode == MODE_PREVIEW:
		ghost_pos = world_pos
	elif mode == MODE_AIM:
		aim_dir = (world_pos - ghost_pos).angle()
	elif mode == MODE_STRIKE and down:
		if PLAY_RECT.has_point(world_pos):
			_call_strike(world_pos)
		else:
			mode = MODE_IDLE
			_flash("Artillery cancelled")
	elif mode == MODE_IDLE and down:
		# tap a turret: tap-fire turrets shoot, and any turret opens the upgrade panel
		for c in world.get_children():
			if c is Turret and c.position.distance_to(world_pos) < 44.0:
				if c.def.get("can_tap", false) and not c.auto_fire:
					c.tap_fire()
				_select_turret(c)
				return
		_close_upgrade()   # tapped empty ground


# ================= Artillery strike =================
func _strike_pressed() -> void:
	if finished or strike_cd > 0.0 or mode != MODE_IDLE:
		return
	mode = MODE_STRIKE
	_flash("TAP THE BATTLEFIELD to call artillery!")


func _call_strike(at: Vector2) -> void:
	mode = MODE_IDLE
	strike_cd = STRIKE_COOLDOWN
	_flash("ARTILLERY INBOUND!")
	for i in range(STRIKE_SHELLS):
		var impact := at + Vector2(
			randf_range(-STRIKE_SPREAD, STRIKE_SPREAD),
			randf_range(-STRIKE_SPREAD * 0.6, STRIKE_SPREAD * 0.6))
		get_tree().create_timer(0.16 * i).timeout.connect(_fire_shell.bind(impact))


func _fire_shell(impact: Vector2) -> void:
	if finished or not is_instance_valid(world):
		return
	var m := Missile.new()
	m.battle = self
	m.position = impact + Vector2(randf_range(-40, 40), -760)
	m.target_pos = impact
	m.speed = 1050.0
	m.damage = STRIKE_DAMAGE
	m.blast_radius = STRIKE_RADIUS
	world.add_child(m)


# ================= In-battle turret upgrades =================
func _select_turret(t: Turret) -> void:
	sel_turret = t
	_refresh_upgrade_panel()


func _close_upgrade() -> void:
	sel_turret = null
	if upgrade_panel:
		upgrade_panel.visible = false


func _refresh_upgrade_panel() -> void:
	if sel_turret == null or not is_instance_valid(sel_turret):
		_close_upgrade()
		return
	upgrade_panel.visible = true
	var t := sel_turret
	if t.lvl >= Turret.MAX_LVL:
		lbl_upg.text = "%s  Lv%d (MAX)" % [t.def["name"], t.lvl]
		b_upg.disabled = true
		b_upg.text = "Maxed out"
	else:
		lbl_upg.text = "%s  Lv%d → Lv%d\n+35%% dmg  +12%% range  faster" % [t.def["name"], t.lvl, t.lvl + 1]
		b_upg.text = "Upgrade  (%d coins)" % t.upgrade_cost()
		b_upg.disabled = Game.coins < t.upgrade_cost()


func _do_upgrade() -> void:
	if sel_turret == null or not is_instance_valid(sel_turret):
		_close_upgrade()
		return
	var cost := sel_turret.upgrade_cost()
	if Game.coins < cost or sel_turret.lvl >= Turret.MAX_LVL:
		_flash("Not enough coins")
		return
	Game.add_coins(-cost)
	sel_turret.upgrade()
	Game.save_game()
	_refresh_upgrade_panel()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Canvas transform already includes the active Camera2D zoom/offset AND the
	# window stretch, so this stays correct on any aspect ratio and zoom level.
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


# ================= UI =================
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	lbl_top = Label.new()
	lbl_top.position = Vector2(24, 16)
	lbl_top.add_theme_font_size_override("font_size", 30)
	lbl_top.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_top.add_theme_constant_override("outline_size", 6)
	ui.add_child(lbl_top)

	lbl_msg = Label.new()
	lbl_msg.position = Vector2(24, 92)
	lbl_msg.add_theme_font_size_override("font_size", 26)
	lbl_msg.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	lbl_msg.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_msg.add_theme_constant_override("outline_size", 6)
	ui.add_child(lbl_msg)

	# deploy bar (bottom-left), one button per owned turret type
	deploy_bar = HBoxContainer.new()
	deploy_bar.add_theme_constant_override("separation", 12)
	deploy_bar.anchor_top = 1.0
	deploy_bar.anchor_bottom = 1.0
	deploy_bar.offset_top = -96
	deploy_bar.offset_left = 24
	deploy_bar.offset_bottom = -16
	ui.add_child(deploy_bar)
	_refresh_deploy_bar()

	# confirm / cancel (bottom-right), shown only during placement
	confirm_box = HBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 16)
	confirm_box.anchor_left = 1.0
	confirm_box.anchor_right = 1.0
	confirm_box.anchor_top = 1.0
	confirm_box.anchor_bottom = 1.0
	confirm_box.offset_left = -360
	confirm_box.offset_right = -24
	confirm_box.offset_top = -96
	confirm_box.offset_bottom = -16
	ui.add_child(confirm_box)
	var b_confirm := Button.new()
	b_confirm.text = "Confirm"
	b_confirm.custom_minimum_size = Vector2(160, 72)
	b_confirm.pressed.connect(_confirm_pressed)
	confirm_box.add_child(b_confirm)
	var b_cancel := Button.new()
	b_cancel.text = "Cancel"
	b_cancel.custom_minimum_size = Vector2(150, 72)
	b_cancel.pressed.connect(_cancel_pressed)
	confirm_box.add_child(b_cancel)

	# aim panel (bottom-center): arc-width slider + sniper auto/tap toggle, AIM only
	aim_panel = VBoxContainer.new()
	aim_panel.add_theme_constant_override("separation", 6)
	aim_panel.anchor_left = 0.5
	aim_panel.anchor_right = 0.5
	aim_panel.anchor_top = 1.0
	aim_panel.anchor_bottom = 1.0
	aim_panel.offset_left = -180
	aim_panel.offset_right = 180
	aim_panel.offset_top = -150
	aim_panel.offset_bottom = -16
	ui.add_child(aim_panel)
	lbl_arc = Label.new()
	lbl_arc.add_theme_font_size_override("font_size", 24)
	lbl_arc.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_arc.add_theme_constant_override("outline_size", 6)
	aim_panel.add_child(lbl_arc)
	arc_slider = HSlider.new()
	arc_slider.min_value = 20
	arc_slider.max_value = 120
	arc_slider.value = 120
	arc_slider.step = 5
	arc_slider.custom_minimum_size = Vector2(360, 40)
	arc_slider.value_changed.connect(_on_arc_changed)
	aim_panel.add_child(arc_slider)
	auto_check = CheckButton.new()
	auto_check.text = "Auto-fire (off = tap turret)"
	auto_check.button_pressed = true
	auto_check.toggled.connect(func(v): pending_auto_fire = v)
	aim_panel.add_child(auto_check)

	# artillery button (right edge, above the confirm row)
	btn_strike = Button.new()
	btn_strike.text = "ARTILLERY"
	btn_strike.custom_minimum_size = Vector2(200, 68)
	btn_strike.anchor_left = 1.0
	btn_strike.anchor_right = 1.0
	btn_strike.anchor_top = 1.0
	btn_strike.anchor_bottom = 1.0
	btn_strike.offset_left = -224
	btn_strike.offset_right = -24
	btn_strike.offset_top = -180
	btn_strike.offset_bottom = -112
	btn_strike.pressed.connect(_strike_pressed)
	ui.add_child(btn_strike)

	# turret upgrade panel (right edge, mid-screen; shown when a turret is tapped)
	upgrade_panel = VBoxContainer.new()
	upgrade_panel.add_theme_constant_override("separation", 10)
	upgrade_panel.anchor_left = 1.0
	upgrade_panel.anchor_right = 1.0
	upgrade_panel.anchor_top = 0.5
	upgrade_panel.anchor_bottom = 0.5
	upgrade_panel.offset_left = -340
	upgrade_panel.offset_right = -24
	upgrade_panel.offset_top = -110
	upgrade_panel.visible = false
	ui.add_child(upgrade_panel)
	lbl_upg = Label.new()
	lbl_upg.add_theme_font_size_override("font_size", 24)
	lbl_upg.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_upg.add_theme_constant_override("outline_size", 6)
	upgrade_panel.add_child(lbl_upg)
	b_upg = Button.new()
	b_upg.custom_minimum_size = Vector2(300, 64)
	b_upg.pressed.connect(_do_upgrade)
	upgrade_panel.add_child(b_upg)
	var b_close := Button.new()
	b_close.text = "Close"
	b_close.custom_minimum_size = Vector2(300, 52)
	b_close.pressed.connect(_close_upgrade)
	upgrade_panel.add_child(b_close)

	_sync_placement_ui()


func _on_arc_changed(v: float) -> void:
	aim_half = deg_to_rad(v * 0.5)
	if lbl_arc:
		lbl_arc.text = "Firing arc: %d°" % int(v)


func _sync_placement_ui() -> void:
	confirm_box.visible = mode == MODE_PREVIEW or mode == MODE_AIM
	aim_panel.visible = mode == MODE_AIM
	auto_check.visible = mode == MODE_AIM and pending_type == "sniper"
	if world:
		world.queue_redraw()   # refresh/clear the gate+ghost overlay on any transition


func _refresh_deploy_bar() -> void:
	for c in deploy_bar.get_children():
		c.queue_free()
	for type_id in TurretData.ORDER:
		var n: int = _deploy_count(type_id)
		if n <= 0:
			continue
		var b := Button.new()
		b.text = "%s\nx%d" % [TurretData.get_def(type_id)["name"], n]
		b.custom_minimum_size = Vector2(120, 84)
		b.icon = Assets.turret_tex(type_id)
		b.expand_icon = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_select_type.bind(type_id))
		deploy_bar.add_child(b)


var _msg_timer := 0.0
func _flash(msg: String) -> void:
	lbl_msg.text = msg
	_msg_timer = 2.5


func _update_top() -> void:
	if _msg_timer > 0.0:
		_msg_timer -= get_process_delta_time()
		if _msg_timer <= 0.0:
			lbl_msg.text = ""
	if finished:
		return
	var status := "Wave %d/%d" % [wave, waves_total]
	if not wave_active:
		status = "PLACE TURRETS!  Wave %d in %.0fs" % [wave + 1, ceil(between_timer)]
	else:
		# orcs still to come this wave + those currently alive
		var remaining: int = (to_spawn - spawned) + enemies.size()
		status = "Wave %d/%d   Orcs left: %d" % [wave, waves_total, remaining]
	var boss_tag := "  BOSS LEVEL" if boss_wave else ""
	lbl_top.text = "Level %d%s   Gate %d/%d   Coins %d   %s" % [
		level, boss_tag, gate_hp, GATE_HP_MAX, Game.coins, status]
	if btn_strike:
		if strike_cd > 0.0:
			btn_strike.text = "ARTILLERY %ds" % int(ceil(strike_cd))
			btn_strike.disabled = true
		else:
			btn_strike.text = "ARTILLERY"
			btn_strike.disabled = false
	# keep upgrade affordability live while coins change mid-battle
	if upgrade_panel and upgrade_panel.visible:
		_refresh_upgrade_panel()


# ================= End states =================
func _victory() -> void:
	finished = true
	Game.add_xp(20 + level * 4)
	Game.add_coins(30 + level * 5)
	Game.highest_level = max(Game.highest_level, level + 1)
	Game.save_game()
	_show_overlay("VICTORY!", "Level %d cleared" % level, "Continue", "res://scenes/MainMenu.tscn")


func _defeat() -> void:
	finished = true
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	# lose-but-earn: salvage rewards so a failed run still makes progress
	var salvage_coins := 10 + level * 2 + wave * 5
	var salvage_xp := 8 + level + wave * 4
	Game.add_coins(salvage_coins)
	Game.add_xp(salvage_xp)
	Game.save_game()
	_show_overlay("DEFEAT",
		"The gate has fallen\nSalvage recovered: +%d coins, +%d XP" % [salvage_coins, salvage_xp],
		"Retry", "res://scenes/Battle.tscn")


func _show_overlay(title: String, sub: String, btn: String, primary_scene: String) -> void:
	overlay = Control.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	ui.add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	overlay.add_child(bg)
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.4
	vb.anchor_bottom = 0.4
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	overlay.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 72)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 34)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	var b := Button.new()
	b.text = btn
	b.custom_minimum_size = Vector2(220, 80)
	b.pressed.connect(func(): get_tree().change_scene_to_file(primary_scene))
	row.add_child(b)
	var w := Button.new()
	w.text = "Workshop"
	w.custom_minimum_size = Vector2(220, 80)
	w.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Workshop.tscn"))
	row.add_child(w)


# ================= Geometry / drawing =================
func _placement_ok(p: Vector2) -> bool:
	# valid spot = inside the arena frame AND not on the orc road
	return PLAY_RECT.has_point(p) and _dist_to_path(p) >= 40.0


func _dist_to_path(p: Vector2) -> float:
	var best := INF
	for i in range(path_points.size() - 1):
		best = min(best, _dist_point_segment(p, path_points[i], path_points[i + 1]))
	return best


func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
