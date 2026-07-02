class_name Tower
extends Node2D
## A turret that auto-fires at the nearest orc in range.

var main: Node                # reference to Main (spawns bullets, lists enemies)
var range_px := 150.0
var fire_rate := 0.45
var damage := 22.0
var bullet_speed := 460.0

var _cooldown := 0.0


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _nearest_enemy()
	if target != null:
		main._spawn_bullet(position, target, damage, bullet_speed)
		_cooldown = fire_rate
		queue_redraw()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := range_px
	for e in main.enemies:
		if not is_instance_valid(e):
			continue
		var d: float = position.distance_to(e.position)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	# faint range ring
	draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 48, Color(1, 1, 1, 0.08), 1.5)
	# body
	draw_rect(Rect2(Vector2(-13, -13), Vector2(26, 26)), Color(0.55, 0.55, 0.6))
	draw_rect(Rect2(Vector2(-13, -13), Vector2(26, 26)), Color(0.85, 0.85, 0.9), false, 2.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.25, 0.25, 0.3))
