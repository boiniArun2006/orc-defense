class_name Enemy
extends Node2D
## An orc that walks the path toward the base.

var path: PackedVector2Array
var speed := 62.0
var max_hp := 40.0
var hp := 40.0
var reward := 8
var target_index := 1

signal died(reward: int)
signal reached_base


func _ready() -> void:
	if path.size() > 0:
		position = path[0]


func _process(delta: float) -> void:
	if target_index >= path.size():
		reached_base.emit()
		queue_free()
		return
	var target := path[target_index]
	var to_target := target - position
	var dist := to_target.length()
	var step := speed * delta
	if dist <= step:
		position = target
		target_index += 1
	else:
		position += to_target / dist * step


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit(reward)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var r := 12.0
	draw_circle(Vector2.ZERO, r, Color(0.32, 0.68, 0.26))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 18, Color(0.12, 0.3, 0.1), 2.0)
	# tiny hp bar above the orc
	var w := 26.0
	var pct: float = clamp(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w * 0.5, -r - 10.0, w, 4.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w * 0.5, -r - 10.0, w * pct, 4.0), Color(0.9, 0.2, 0.2))
