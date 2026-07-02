extends Node2D
## Orc Defense — Phase 1 prototype.
## One map, orcs walk a path toward your base, tap empty ground to place a
## tower, towers auto-shoot the nearest orc, orcs drop gold, base has lives.
## Everything is drawn with simple shapes for now (art comes later).

# ---- Balance knobs (easy to tweak) ----
const START_GOLD := 120
const START_LIVES := 20
const TOWER_COST := 50
const KILL_REWARD := 8
const WAVE_BONUS := 20

const TOWER_RANGE := 150.0
const TOWER_FIRE_RATE := 0.45      # seconds between shots
const TOWER_DAMAGE := 22.0
const BULLET_SPEED := 460.0

const ENEMY_SPEED := 62.0
const ENEMY_HP_BASE := 40.0
const PLACE_CLEARANCE := 42.0      # min distance from the path to place a tower
const TOWER_SPACING := 34.0        # min distance between two towers

# ---- Runtime state ----
var gold := START_GOLD
var lives := START_LIVES
var wave := 0
var spawned_in_wave := 0
var enemies_this_wave := 6
var spawn_timer := 0.0
var spawn_interval := 1.0
var wave_active := false
var between_timer := 3.0
var game_over := false

var path_points: PackedVector2Array
var base_pos: Vector2
var enemies: Array = []

var lbl_lives: Label
var lbl_gold: Label
var lbl_wave: Label
var lbl_info: Label


func _ready() -> void:
	_build_path()
	_build_hud()
	set_process_unhandled_input(true)


func _build_path() -> void:
	var vp := get_viewport_rect().size
	# A snaking lane from the top edge down to the base near the bottom.
	path_points = PackedVector2Array([
		Vector2(vp.x * 0.15, -40),
		Vector2(vp.x * 0.15, vp.y * 0.18),
		Vector2(vp.x * 0.80, vp.y * 0.18),
		Vector2(vp.x * 0.80, vp.y * 0.42),
		Vector2(vp.x * 0.20, vp.y * 0.42),
		Vector2(vp.x * 0.20, vp.y * 0.66),
		Vector2(vp.x * 0.80, vp.y * 0.66),
		Vector2(vp.x * 0.80, vp.y * 0.86),
		Vector2(vp.x * 0.45, vp.y * 0.86),
	])
	base_pos = path_points[path_points.size() - 1]


func _process(delta: float) -> void:
	enemies = enemies.filter(func(e): return is_instance_valid(e))

	if not game_over:
		if wave_active:
			if spawned_in_wave < enemies_this_wave:
				spawn_timer -= delta
				if spawn_timer <= 0.0:
					_spawn_enemy()
					spawned_in_wave += 1
					spawn_timer = spawn_interval
			elif enemies.is_empty():
				_end_wave()
		else:
			between_timer -= delta
			if between_timer <= 0.0:
				_start_wave()

	_update_hud()
	queue_redraw()


# ---- Waves ----
func _start_wave() -> void:
	wave += 1
	wave_active = true
	spawned_in_wave = 0
	enemies_this_wave = 5 + wave * 2
	spawn_interval = max(0.35, 1.0 - wave * 0.03)
	spawn_timer = 0.0


func _end_wave() -> void:
	wave_active = false
	between_timer = 4.0
	gold += WAVE_BONUS


func _spawn_enemy() -> void:
	var e := Enemy.new()
	e.path = path_points
	e.speed = ENEMY_SPEED + wave * 3.0
	e.max_hp = ENEMY_HP_BASE + wave * 14.0
	e.hp = e.max_hp
	e.reward = KILL_REWARD
	e.died.connect(_on_enemy_died)
	e.reached_base.connect(_on_enemy_reached_base)
	add_child(e)
	enemies.append(e)


func _on_enemy_died(reward: int) -> void:
	gold += reward


func _on_enemy_reached_base() -> void:
	lives -= 1
	if lives <= 0:
		lives = 0
		_trigger_game_over()


func _trigger_game_over() -> void:
	game_over = true
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()


# ---- Towers / bullets ----
func _spawn_bullet(from: Vector2, target: Node2D, dmg: float, spd: float) -> void:
	var b := Bullet.new()
	b.position = from
	b.target = target
	b.damage = dmg
	b.speed = spd
	add_child(b)


func _try_place_tower(pos: Vector2) -> void:
	if game_over:
		return
	if gold < TOWER_COST:
		_flash_info("Not enough gold (need %d)" % TOWER_COST)
		return
	if _dist_to_path(pos) < PLACE_CLEARANCE:
		_flash_info("Too close to the path")
		return
	for c in get_children():
		if c is Tower and c.position.distance_to(pos) < TOWER_SPACING:
			_flash_info("Too close to another tower")
			return

	var t := Tower.new()
	t.position = pos
	t.main = self
	t.range_px = TOWER_RANGE
	t.fire_rate = TOWER_FIRE_RATE
	t.damage = TOWER_DAMAGE
	t.bullet_speed = BULLET_SPEED
	add_child(t)
	gold -= TOWER_COST


# ---- Input ----
func _unhandled_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		tapped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		tapped = true
	if not tapped:
		return

	if game_over:
		get_tree().reload_current_scene()
		return
	_try_place_tower(pos)


# ---- HUD ----
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	lbl_lives = _mk_label(layer, Vector2(18, 16))
	lbl_gold = _mk_label(layer, Vector2(18, 48))
	lbl_wave = _mk_label(layer, Vector2(18, 80))
	lbl_info = _mk_label(layer, Vector2(18, 120))
	lbl_info.add_theme_color_override("font_color", Color(1, 0.88, 0.4))


func _mk_label(parent: Node, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


var _info_timer := 0.0
func _flash_info(msg: String) -> void:
	lbl_info.text = msg
	_info_timer = 2.0


func _update_hud() -> void:
	lbl_lives.text = "Lives: %d" % lives
	lbl_gold.text = "Gold: %d   (tower = %d, tap ground)" % [gold, TOWER_COST]
	if game_over:
		lbl_wave.text = "GAME OVER — reached wave %d" % wave
		lbl_info.text = "Tap anywhere to restart"
		return
	if wave_active:
		lbl_wave.text = "Wave %d — orcs left: %d" % [wave, enemies.size() + (enemies_this_wave - spawned_in_wave)]
	else:
		lbl_wave.text = "Wave %d starting in %.0f..." % [wave + 1, ceil(between_timer)]
	if _info_timer > 0.0:
		_info_timer -= get_process_delta_time()
		if _info_timer <= 0.0:
			lbl_info.text = ""


# ---- Geometry + drawing ----
func _dist_to_path(p: Vector2) -> float:
	var best := INF
	for i in range(path_points.size() - 1):
		var d := _dist_point_segment(p, path_points[i], path_points[i + 1])
		best = min(best, d)
	return best


func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.16, 0.34, 0.16))  # grass
	if path_points.size() >= 2:
		draw_polyline(path_points, Color(0.42, 0.29, 0.17), 36.0)
		for p in path_points:
			draw_circle(p, 18.0, Color(0.42, 0.29, 0.17))
	# base
	draw_circle(base_pos, 28.0, Color(0.2, 0.3, 0.72))
	draw_arc(base_pos, 28.0, 0.0, TAU, 28, Color(0.85, 0.92, 1.0), 3.0)
