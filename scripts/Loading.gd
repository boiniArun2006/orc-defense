extends Control
## Proper game loading screen. Shown on boot and before every battle.
## Displays the level being entered (name + biome), a rotating tactics tip and
## an animated progress bar, then hops to Game.next_scene ("" -> MainMenu).
## The pause is deliberate and short — it sells the transition and gives the
## player a beat to read the tip.

const TIPS := [
	"Turrets only fire inside their aim arc — cover the road, not the scenery.",
	"Runners (yellow) are fast but frail. Short-range SMG fire shreds them.",
	"Brutes (blue) shrug off small bullets. Snipers and bombs punch through armor.",
	"Air Strike: press the button, then DRAG a line — planes bomb along it.",
	"Corners are gold: turrets there watch two stretches of road at once.",
	"Upgrading a well-placed turret often beats placing a new one.",
	"Losing still earns salvage. Regroup, rebuild, try a new layout.",
	"Wide arcs react to everything; narrow arcs are only strong on one lane.",
	"Bosses hit the gate for massive damage. Do NOT let them walk.",
	"Buy turrets in the Workshop between battles — kills alone won't fund you.",
]

var _t := 0.0
var _dur := 1.4
var _bar: ColorRect
var _bar_bg: Panel
var _done := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.07)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.5
	vb.anchor_bottom = 0.5
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	add_child(vb)

	var going_to_battle := Game.next_scene.contains("Battle")
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if going_to_battle:
		var map: Dictionary = MapData.get_for_level(Game.highest_level)
		title.text = "LEVEL %d — %s" % [Game.highest_level, MapData.biome_name(map["biome"])]
	else:
		title.text = "ORC DEFENSE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.09, 0.05))
	vb.add_child(title)

	if going_to_battle and Game.highest_level % 5 == 0:
		var warn := Label.new()
		warn.text = "!!  BOSS LEVEL  !!"
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 34)
		warn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		vb.add_child(warn)

	var tip := Label.new()
	tip.text = "TIP:  " + TIPS[randi() % TIPS.size()]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(820, 0)
	tip.add_theme_font_size_override("font_size", 26)
	tip.add_theme_color_override("font_color", Color(0.85, 0.83, 0.72))
	vb.add_child(tip)

	# progress bar: dark trough + growing gold fill
	_bar_bg = Panel.new()
	_bar_bg.custom_minimum_size = Vector2(680, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.05)
	sb.border_color = Color(0.4, 0.34, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(13)
	_bar_bg.add_theme_stylebox_override("panel", sb)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(680, 40)
	center.add_child(_bar_bg)
	vb.add_child(center)
	_bar = ColorRect.new()
	_bar.color = Color(0.98, 0.8, 0.3)
	_bar.position = Vector2(4, 4)
	_bar.size = Vector2(0, 18)
	_bar_bg.add_child(_bar)

	_dur = 1.4 if going_to_battle else 1.0


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var pct: float = clamp(_t / _dur, 0.0, 1.0)
	# ease-out so the bar sprints early and glides in — feels like real loading
	var eased := 1.0 - pow(1.0 - pct, 2.2)
	_bar.size.x = (_bar_bg.size.x - 8.0) * eased
	if pct >= 1.0:
		_done = true
		var target := Game.next_scene
		Game.next_scene = ""
		if target == "":
			target = "res://scenes/MainMenu.tscn"
		get_tree().change_scene_to_file(target)
