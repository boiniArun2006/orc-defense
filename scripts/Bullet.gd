class_name Bullet
extends Node2D
## A homing projectile fired by a Tower.

var target: Node2D
var speed := 460.0
var damage := 22.0
var _dir := Vector2.RIGHT


func _process(delta: float) -> void:
	if is_instance_valid(target):
		var to_target: Vector2 = target.position - position
		var dist := to_target.length()
		if dist < 9.0:
			target.take_damage(damage)
			queue_free()
			return
		_dir = to_target / dist
	# keep flying (toward target, or straight on if the target is gone)
	position += _dir * speed * delta
	var vp := get_viewport_rect().size
	if position.x < -60 or position.y < -60 or position.x > vp.x + 60 or position.y > vp.y + 60:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.2))
