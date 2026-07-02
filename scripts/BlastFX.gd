class_name BlastFX
extends Node2D
## Short-lived explosion visual: an expanding, fading ring/disc. Purely cosmetic.

var radius := 80.0
var _t := 0.0
const LIFE := 0.35


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var k: float = clamp(_t / LIFE, 0.0, 1.0)
	var r: float = lerp(radius * 0.3, radius, k)
	var a: float = 1.0 - k
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.6, 0.2, 0.35 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.8 * a), 3.0)
