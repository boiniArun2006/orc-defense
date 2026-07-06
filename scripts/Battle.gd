extends Node2D
## Battle screen. Runs one game level: finite waves (boss every 5th level), a gate
## with HP, deploy-from-inventory placement (select -> preview -> confirm -> aim),
## enemy variants (runners/brutes) that force real tactics, a drag-to-target AIR
## STRIKE with fly-by planes, pinch-to-zoom camera, and Victory/Defeat overlays.

# ---- Gate / level tuning ----
const GATE_HP_MAX := 100          # each leaked orc removes 5, so ~20 leaks = loss
const ORC_GATE_DAMAGE := 5

# ---- Horde tuning ----
# More waves per level with steady growth: mid-game levels are meant to be HARD.
# The player is supposed to lose sometimes and come back with a better plan.
const BASE_WAVE_SIZE := 120       # orcs in the first wave of level 1 (a real horde now)
const WAVE_GROWTH := 1.5          # each wave ~1.5x the previous
const LEVEL_SIZE_BONUS := 0.20    # +20% base horde per game level
const MAX_ALIVE := 1500           # data-oriented swarm handles thousands; cap for phone safety
const MAX_WAVES := 9

# Placement flow states
const MODE_IDLE := 0
const MODE_PREVIEW := 1
const MODE_STRIKE := 3           # air strike: drag a corridor, planes bomb it

# ---- Air strike ability ----
const STRIKE_COOLDOWN := 50.0
const STRIKE_PLANES := 2
const STRIKE_BOMBS := 5          # bombs per plane
const STRIKE_DAMAGE := 50.0
const STRIKE_RADIUS := 80.0
const STRIKE_MIN_DRAG := 24.0    # tiny drag needed just to define a direction
const STRIKE_LEN := 380.0        # FIXED corridor length — drag only sets direction

# Build-phase timing: generous window before wave 1 and between waves so the
# player can actually place/aim turrets under no pressure.
const PREP_TIME := 10.0

# Playable area for turret placement (inside the map's border frame)
const PLAY_RECT := Rect2(40, 40, 1200, 640)

var level := 1
var gate_hp := GATE_HP_MAX

var waves_total := 3
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
var path_width := 110.0
var gate_pos: Vector2
var swarm: OrcSwarm

# How many of each turret the player can still deploy THIS battle. A local copy of
# Game.inventory so deploying doesn't permanently consume the owned roster.
var deploy_left := {}

# Placement
var mode: int = MODE_IDLE
var pending_type := ""
var ghost_pos := Vector2.ZERO

# Air strike drag state (read by BattleWorld for the preview overlay)
var strike_from := Vector2.ZERO
var strike_to := Vector2.ZERO
var strike_dragging := false

# Camera / zoom
var cam: Camera2D
var _zoom := 1.0
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0
var _active_touches := {}

# World layer that the camera looks at (map + units live here)
var world: Node2D
var gore: GoreLayer              # corpses / blood / damage numbers (under units)
var strike_cd := 0.0             # air strike cooldown remaining
var _shake := 0.0                # camera shake amplitude
var sel_turret: Turret = null    # turret selected for in-battle upgrade

# UI refs
var ui: CanvasLayer
var lbl_level: Label
var lbl_coins: Label
var lbl_wave: Label
var gate_bar: ProgressBar
var msg_panel: PanelContainer
var lbl_msg: Label
var deploy_bar: HBoxContainer
var confirm_box: HBoxContainer
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
	path_width = map.get("path_width", 110.0)
	gate_pos = path_points[path_points.size() - 1]
	# static textured map (drawn once, sits behind everything)
	var ground := GroundLayer.new()
	ground.battle = self
	ground.biome = map["biome"]
	ground.decos = map["decos"]
	ground.ponds = map.get("ponds", [])
	ground.tufts = map.get("tufts", [])
	add_child(ground)
	# gore layer: corpses/blood/damage numbers, above ground, below units
	gore = GoreLayer.new()
	add_child(gore)
	# the horde: data-oriented swarm (thousands of orcs, one draw call per type)
	swarm = OrcSwarm.new()
	swarm.battle = self
	add_child(swarm)
	swarm.setup(path_points)
	# per-frame overlay layer that also parents the units (turrets draw above orcs)
	world = BattleWorld.new()
	world.battle = self
	add_child(world)
	_setup_camera()
	_build_ui()
	set_process_unhandled_input(true)


func _configure_level() -> void:
	# waves scale with level: L1-2 -> 3 waves ... capped at MAX_WAVES
	waves_total = min(MAX_WAVES, 3 + int(floor(level / 2.0)))
	boss_wave = (level % 5 == 0)


func _setup_camera() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	cam.enabled = true
	world.add_child(cam)
	cam.make_current()


# ================= Waves =================
func _process(delta: float) -> void:
	if not finished:
		if wave_active:
			if spawned < to_spawn:
				# concurrency cap: hold spawns while the field is full (protects FPS)
				if swarm.alive_count() < MAX_ALIVE:
					spawn_timer -= delta
					if spawn_timer <= 0.0:
						_spawn_one()
						spawned += 1
						spawn_timer = spawn_interval
			elif swarm.alive_count() == 0:
				_end_wave()
		else:
			between_timer -= delta
			if between_timer <= 0.0:
				_start_wave()
	# air strike cooldown + camera shake decay
	if strike_cd > 0.0:
		strike_cd = max(0.0, strike_cd - delta)
	if _shake > 0.01:
		_shake = move_toward(_shake, 0.0, 24.0 * delta)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
	_update_top()
	# only the gate + placement/strike overlays need per-frame redraw
	if mode != MODE_IDLE:
		world.queue_redraw()


func _start_wave() -> void:
	wave += 1
	wave_active = true
	spawned = 0
	# Geometric growth so each wave feels bigger, plus a per-level base bump.
	var level_base: float = BASE_WAVE_SIZE * (1.0 + LEVEL_SIZE_BONUS * (level - 1))
	to_spawn = int(round(level_base * pow(WAVE_GROWTH, wave - 1)))
	# fast trickle so many are on screen at once (clamped, subject to MAX_ALIVE gate)
	spawn_interval = max(0.015, 0.05 - level * 0.003)   # fast trickle: flood the path
	spawn_timer = 0.0
	_flash("HORDE INCOMING!")


func _end_wave() -> void:
	wave_active = false
	between_timer = PREP_TIME
	# lean wave bonus: kills alone must not fund a turret spree
	Game.add_xp(4 + level)
	Game.add_coins(3 + int(level / 3.0))
	Game.save_game()                       # don't lose battle earnings if OS kills the app
	if wave >= waves_total:
		_victory()


func _spawn_one() -> void:
	var is_last_wave_boss: bool = boss_wave and wave == waves_total and spawned == to_spawn - 1
	if is_last_wave_boss:
		swarm.spawn("boss", level, wave, path_width)
		return
	# the standard flood: mostly weak orcs, spiced with variants that punish a
	# one-note turret layout. Chances grow with level.
	var roll := randf()
	var runner_chance: float = 0.0 if level < 3 else minf(0.28, 0.08 + 0.02 * level)
	var brute_chance: float = 0.0 if level < 6 else minf(0.18, 0.03 + 0.012 * level)
	var skel_chance: float = 0.0 if level < 4 else minf(0.22, 0.05 + 0.015 * level)
	var t := "orc"
	if roll < brute_chance:
		t = "brute"
	elif roll < brute_chance + runner_chance:
		t = "runner"
	elif roll < brute_chance + runner_chance + skel_chance:
		t = "skeleton"
	elif randf() < 0.30:
		t = "slime"
	swarm.spawn(t, level, wave, path_width)


# Called by OrcSwarm when an orc dies (corpse/blood already spawned by the swarm).
func _on_orc_died(coins: int, xp: int, is_boss: bool) -> void:
	Game.add_coins(coins)
	Game.add_xp(xp)
	if is_boss:
		shake(8.0)


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


# Called by OrcSwarm when an orc reaches the gate.
func _on_gate_hit(dmg: int) -> void:
	gate_hp -= dmg
	if gate_hp <= 0:
		gate_hp = 0
		_defeat()


# ================= Placement flow =================
func _select_type(type_id: String) -> void:
	if finished:
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
		_place_turret()


func _cancel_pressed() -> void:
	mode = MODE_IDLE
	pending_type = ""
	_sync_placement_ui()


func _place_turret() -> void:
	var t := Turret.new()
	t.battle = self
	t.position = ghost_pos
	t.aim_angle = (_nearest_path_point(ghost_pos) - ghost_pos).angle()
	t.setup(pending_type)
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

	# --- single-pointer events (touch or mouse): down / drag / release ---
	var pos := Vector2.ZERO
	var down := false
	var drag := false
	var up := false
	if event is InputEventScreenTouch and _active_touches.size() < 2:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag and _active_touches.size() < 2:
		pos = event.position; drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		pos = event.position; drag = true
	if not (down or drag or up):
		return

	var world_pos := _screen_to_world(pos)
	if mode == MODE_PREVIEW:
		if down or drag:
			ghost_pos = world_pos
	elif mode == MODE_STRIKE:
		# fixed-length corridor: touch = anchor, drag = point the run, release = go
		if down:
			strike_from = world_pos
			strike_to = world_pos
			strike_dragging = true
		elif drag and strike_dragging:
			var v := world_pos - strike_from
			if v.length() >= STRIKE_MIN_DRAG:
				strike_to = strike_from + v.normalized() * STRIKE_LEN
			else:
				strike_to = strike_from
		elif up and strike_dragging:
			strike_dragging = false
			if strike_from.distance_to(strike_to) >= STRIKE_LEN * 0.5:
				_call_air_strike(strike_from, strike_to)
			else:
				_flash("Touch the target, then DRAG to point the bombing run")
	elif mode == MODE_IDLE and down:
		# tap a turret: tap-fire turrets shoot, and any turret opens the upgrade panel
		for c in world.get_children():
			if c is Turret and c.position.distance_to(world_pos) < 44.0:
				_select_turret(c)
				return
		_close_upgrade()   # tapped empty ground


# ================= Air strike =================
func _strike_pressed() -> void:
	if finished or strike_cd > 0.0 or mode != MODE_IDLE:
		return
	mode = MODE_STRIKE
	strike_dragging = false
	_flash("Touch the target, then DRAG to aim the bombing run")


func _call_air_strike(from_p: Vector2, to_p: Vector2) -> void:
	mode = MODE_IDLE
	strike_cd = STRIKE_COOLDOWN
	_flash("AIR STRIKE INBOUND!")
	shake(3.0)
	for i in range(STRIKE_PLANES):
		var p := StrikePlane.new()
		p.battle = self
		p.from_pos = from_p
		p.to_pos = to_p
		p.bombs = STRIKE_BOMBS
		p.damage = STRIKE_DAMAGE
		p.blast_radius = STRIKE_RADIUS
		p.lateral = (float(i) - (STRIKE_PLANES - 1) * 0.5) * 56.0
		p.z_index = 50            # planes fly ABOVE everything
		# stagger the wingman slightly behind the leader
		if i == 0:
			world.add_child(p)
		else:
			get_tree().create_timer(0.30 * i).timeout.connect(func():
				if not finished and is_instance_valid(world):
					world.add_child(p))
	world.queue_redraw()


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
		lbl_upg.text = "%s  Lv%d → Lv%d\n+30%% dmg  +10%% range  faster" % [t.def["name"], t.lvl, t.lvl + 1]
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

	# ---- top HUD strip: level badge | gate bar | coins | wave status ----
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = Color(0.10, 0.09, 0.08, 0.88)
	top_sb.border_color = Color(0.42, 0.35, 0.26)
	top_sb.set_border_width_all(2)
	top_sb.set_corner_radius_all(12)
	top_sb.content_margin_left = 18
	top_sb.content_margin_right = 18
	top_sb.content_margin_top = 6
	top_sb.content_margin_bottom = 6
	top.add_theme_stylebox_override("panel", top_sb)
	ui.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)

	lbl_level = Label.new()
	lbl_level.add_theme_font_size_override("font_size", 28)
	lbl_level.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	row.add_child(lbl_level)

	var gate_icon := TextureRect.new()
	gate_icon.texture = Assets.tex("gate")
	gate_icon.custom_minimum_size = Vector2(36, 36)
	gate_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gate_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(gate_icon)

	gate_bar = ProgressBar.new()
	gate_bar.min_value = 0
	gate_bar.max_value = GATE_HP_MAX
	gate_bar.value = GATE_HP_MAX
	gate_bar.show_percentage = false
	gate_bar.custom_minimum_size = Vector2(220, 26)
	gate_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gb_bg := StyleBoxFlat.new()
	gb_bg.bg_color = Color(0.05, 0.05, 0.05)
	gb_bg.set_corner_radius_all(8)
	var gb_fill := StyleBoxFlat.new()
	gb_fill.bg_color = Color(0.35, 0.78, 0.35)
	gb_fill.set_corner_radius_all(8)
	gate_bar.add_theme_stylebox_override("background", gb_bg)
	gate_bar.add_theme_stylebox_override("fill", gb_fill)
	row.add_child(gate_bar)

	var coin_icon := TextureRect.new()
	coin_icon.texture = Assets.tex("coin")
	coin_icon.custom_minimum_size = Vector2(32, 32)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(coin_icon)

	lbl_coins = Label.new()
	lbl_coins.add_theme_font_size_override("font_size", 28)
	lbl_coins.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	row.add_child(lbl_coins)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	lbl_wave = Label.new()
	lbl_wave.add_theme_font_size_override("font_size", 26)
	row.add_child(lbl_wave)

	# ---- flash message banner (center-top, hidden when empty) ----
	msg_panel = PanelContainer.new()
	msg_panel.anchor_left = 0.5
	msg_panel.anchor_right = 0.5
	msg_panel.offset_top = 74
	msg_panel.offset_left = -320
	msg_panel.offset_right = 320
	var msg_sb := StyleBoxFlat.new()
	msg_sb.bg_color = Color(0.12, 0.08, 0.03, 0.85)
	msg_sb.border_color = Color(0.85, 0.68, 0.28)
	msg_sb.set_border_width_all(2)
	msg_sb.set_corner_radius_all(10)
	msg_sb.content_margin_left = 16
	msg_sb.content_margin_right = 16
	msg_sb.content_margin_top = 6
	msg_sb.content_margin_bottom = 6
	msg_panel.add_theme_stylebox_override("panel", msg_sb)
	msg_panel.visible = false
	ui.add_child(msg_panel)
	lbl_msg = Label.new()
	lbl_msg.add_theme_font_size_override("font_size", 26)
	lbl_msg.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_panel.add_child(lbl_msg)

	# deploy bar (bottom-left), one button per owned turret type
	deploy_bar = HBoxContainer.new()
	deploy_bar.add_theme_constant_override("separation", 12)
	deploy_bar.anchor_top = 1.0
	deploy_bar.anchor_bottom = 1.0
	deploy_bar.offset_top = -100
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

	# air strike button (right edge, above the confirm row) with a plane icon
	btn_strike = Button.new()
	btn_strike.text = "AIR STRIKE"
	btn_strike.icon = Assets.tex("plane")
	btn_strike.expand_icon = true
	btn_strike.custom_minimum_size = Vector2(230, 68)
	btn_strike.anchor_left = 1.0
	btn_strike.anchor_right = 1.0
	btn_strike.anchor_top = 1.0
	btn_strike.anchor_bottom = 1.0
	btn_strike.offset_left = -254
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



func _sync_placement_ui() -> void:
	confirm_box.visible = mode == MODE_PREVIEW
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
		b.custom_minimum_size = Vector2(126, 88)
		b.icon = Assets.turret_tex(type_id)
		b.expand_icon = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_select_type.bind(type_id))
		deploy_bar.add_child(b)


var _msg_timer := 0.0
func _flash(msg: String) -> void:
	lbl_msg.text = msg
	msg_panel.visible = true
	_msg_timer = 2.5


func _update_top() -> void:
	if _msg_timer > 0.0:
		_msg_timer -= get_process_delta_time()
		if _msg_timer <= 0.0:
			lbl_msg.text = ""
			msg_panel.visible = false
	if finished:
		return
	var status: String
	if not wave_active:
		status = "Wave %d in %.0fs — PLACE TURRETS" % [wave + 1, ceil(between_timer)]
	else:
		var remaining: int = (to_spawn - spawned) + swarm.alive_count()
		status = "Wave %d/%d    Orcs: %s" % [wave, waves_total, _fmt_k(remaining)]
	lbl_level.text = ("LV %d  BOSS" % level) if boss_wave else ("LV %d" % level)
	lbl_coins.text = str(Game.coins)
	lbl_wave.text = status
	gate_bar.value = gate_hp
	var fill: StyleBoxFlat = gate_bar.get_theme_stylebox("fill")
	if fill:
		var pct := float(gate_hp) / GATE_HP_MAX
		fill.bg_color = Color(0.35, 0.78, 0.35) if pct > 0.5 else \
			(Color(0.9, 0.75, 0.2) if pct > 0.25 else Color(0.9, 0.25, 0.2))
	if btn_strike:
		if strike_cd > 0.0:
			btn_strike.text = "STRIKE %ds" % int(ceil(strike_cd))
			btn_strike.disabled = true
		else:
			btn_strike.text = "AIR STRIKE"
			btn_strike.disabled = false
	# keep upgrade affordability live while coins change mid-battle
	if upgrade_panel and upgrade_panel.visible:
		_refresh_upgrade_panel()


# ================= End states =================
func _victory() -> void:
	finished = true
	Game.add_xp(15 + level * 3)
	Game.add_coins(18 + level * 3)
	Game.highest_level = max(Game.highest_level, level + 1)
	Game.save_game()
	_show_overlay("VICTORY!", "Level %d cleared" % level, "Next Level", "res://scenes/Battle.tscn")


func _fmt_k(n: int) -> String:
	return "%.1fK" % (n / 1000.0) if n >= 1000 else str(n)


func _defeat() -> void:
	finished = true
	if swarm:
		swarm.queue_free()
	# lose-but-earn: modest salvage so a failed run still makes SOME progress,
	# but losing must sting enough that the player rethinks the layout
	var salvage_coins := 4 + level + wave * 2
	var salvage_xp := 6 + level + wave * 2
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
	bg.color = Color(0, 0, 0, 0.65)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	overlay.add_child(bg)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color",
		Color(0.55, 0.95, 0.5) if title.begins_with("V") else Color(0.95, 0.35, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 32)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	var b := Button.new()
	b.text = btn
	b.custom_minimum_size = Vector2(230, 80)
	b.pressed.connect(func(): Game.goto(primary_scene))
	row.add_child(b)
	var w := Button.new()
	w.text = "Workshop"
	w.custom_minimum_size = Vector2(220, 80)
	w.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Workshop.tscn"))
	row.add_child(w)
	var m := Button.new()
	m.text = "Menu"
	m.custom_minimum_size = Vector2(160, 80)
	m.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	row.add_child(m)


# ================= Geometry / drawing =================
func _placement_ok(p: Vector2) -> bool:
	# valid spot = inside the arena frame AND not on the orc road
	return PLAY_RECT.has_point(p) and _dist_to_path(p) >= 40.0


func _nearest_path_point(p: Vector2) -> Vector2:
	var best := p + Vector2.RIGHT
	var best_d := INF
	for i in range(path_points.size() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, path_points[i], path_points[i + 1])
		var d := p.distance_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


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
