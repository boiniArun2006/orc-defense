class_name Enemy
extends Node2D
## An orc that walks the path toward the gate. Its HP bar stays hidden until it
## takes its first hit. Bosses are larger, tougher, and worth more.

var path: PackedVector2Array
var speed := 60.0
var max_hp := 40.0
var hp := 40.0
var coin_reward := 4
var xp_reward := 3
var gate_damage := 1
var is_boss := false

var _radius := 12.0
var _target_index := 1
var _hurt := false            # becomes true after the first hit (reveals HP bar)

signal died(coins: int, xp: int)
signal reached_gate(damage: int)


func _ready() -> void:
	_radius = 30.0 if is_boss else 12.0
	if path.size() > 0:
		position = path[0]


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
		position += to_target / dist * step


func take_damage(amount: float) -> void:
	hp -= amount
	_hurt = true
	if hp <= 0.0:
		died.emit(coin_reward, xp_reward)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var body := Color(0.7, 0.2, 0.7) if is_boss else Color(0.32, 0.68, 0.26)
	draw_circle(Vector2.ZERO, _radius, body)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 20, Color(0.1, 0.28, 0.1), 2.0)
	if _hurt:
		# HP bar appears only after the orc has been hit at least once
		var w := _radius * 2.2
		var pct: float = clamp(hp / max_hp, 0.0, 1.0)
		var y := -_radius - 10.0
		draw_rect(Rect2(-w * 0.5, y, w, 5.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, y, w * pct, 5.0), Color(0.9, 0.2, 0.2))
