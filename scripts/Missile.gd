class_name Missile
extends Node2D
## Bomber projectile: launches upward, arcs over, descends onto the target point,
## then deals AoE damage to every orc within blast_radius and spawns a blast VFX.
## Uses a parabolic height offset for a "lobbed" look while traveling to target_pos.

var battle: Node
var target_pos := Vector2.ZERO
var damage := 55.0
var blast_radius := 80.0
var speed := 260.0          # horizontal travel speed toward target

var _start := Vector2.ZERO
var _total := 0.0
var _travelled := 0.0
var _arc_height := 90.0


func _ready() -> void:
	_start = position
	_total = max(1.0, _start.distance_to(target_pos))
	_arc_height = clamp(_total * 0.35, 60.0, 160.0)


func _process(delta: float) -> void:
	_travelled += speed * delta
	var t: float = clamp(_travelled / _total, 0.0, 1.0)
	var ground := _start.lerp(target_pos, t)
	# parabola: peaks at t=0.5, zero at ends — subtract from Y to lift the sprite
	var lift := _arc_height * (4.0 * t * (1.0 - t))
	position = ground - Vector2(0, lift)
	if t >= 1.0:
		_explode(ground)


func _explode(at: Vector2) -> void:
	for e in battle.enemies:
		if is_instance_valid(e) and e.position.distance_to(at) <= blast_radius:
			e.take_damage(damage)
	var fx := BlastFX.new()
	fx.position = at
	fx.radius = blast_radius
	battle.world.add_child(fx)
	queue_free()


func _draw() -> void:
	# shadow on the ground + the bomb itself
	draw_circle(Vector2(0, 6), 5.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, 6.0, Color(0.25, 0.25, 0.3))
	draw_circle(Vector2(0, -3), 3.0, Color(0.95, 0.6, 0.2))
