class_name Enemy
extends Node2D
## An orc that walks the path toward the gate. Uses a Kenney Tiny Dungeon sprite
## (tinted greener for regular orcs) with a code-driven walk bob/squash so it feels
## animated without needing a spritesheet. HP bar appears only after the first hit.

var path: PackedVector2Array
var speed := 60.0
var max_hp := 40.0
var hp := 40.0
var coin_reward := 4
var xp_reward := 3
var gate_damage := 1
var is_boss := false

var _target_index := 1
var _hurt := false
var _walk_t := 0.0
var _flash := 0.0            # white hit-flash timer
var _spr: Sprite2D
var _base_scale := 1.0


func _ready() -> void:
	if path.size() > 0:
		position = path[0]
	_spr = Sprite2D.new()
	_spr.texture = Assets.tex("orc_boss" if is_boss else "orc")
	# 16px source -> scale up; bosses larger
	_base_scale = (3.4 if is_boss else 2.0)
	_spr.scale = Vector2(_base_scale, _base_scale)
	if not is_boss:
		_spr.modulate = Color(0.7, 1.15, 0.6)   # push toward orc-green
	add_child(_spr)
	# face the initial travel direction
	if path.size() > 1:
		_spr.flip_h = path[1].x < path[0].x


func _process(delta: float) -> void:
	if _target_index >= path.size():
		reached_gate.emit(gate_damage)
		queue_free()
		return
	var target := path[_target_index]
	var to_target := target - position
	var dist := to_target.length()
	var step := speed * delta
	if dist <= step:
		position = target
		_target_index += 1
	else:
		var dir := to_target / dist
		position += dir * step
		if abs(dir.x) > 0.05:
			_spr.flip_h = dir.x < 0.0

	# walk animation: vertical bob + subtle squash
	_walk_t += delta * (speed * 0.10)
	var bob := sin(_walk_t * 2.0)
	_spr.position.y = -bob * 2.0
	_spr.scale = Vector2(_base_scale, _base_scale * (1.0 + 0.06 * bob))

	# hit flash decay
	if _flash > 0.0:
		_flash -= delta
		var base := Color(1, 1, 1) if is_boss else Color(0.7, 1.15, 0.6)
		_spr.modulate = base.lerp(Color(1, 1, 1), clamp(_flash / 0.12, 0, 1)) if _flash > 0 else base

	if _hurt:
		queue_redraw()

signal died(coins: int, xp: int)
signal reached_gate(damage: int)


func take_damage(amount: float) -> void:
	hp -= amount
	_hurt = true
	_flash = 0.12
	if hp <= 0.0:
		died.emit(coin_reward, xp_reward)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	if not _hurt:
		return
	var w := (66.0 if is_boss else 34.0)
	var pct: float = clamp(hp / max_hp, 0.0, 1.0)
	var y := (-34.0 if is_boss else -22.0)
	draw_rect(Rect2(-w * 0.5, y, w, 5.0), Color(0, 0, 0, 0.65))
	var fill := Color(0.9, 0.2, 0.2) if pct > 0.35 else Color(0.95, 0.5, 0.1)
	draw_rect(Rect2(-w * 0.5, y, w * pct, 5.0), fill)
