extends Control
## Title screen. Shows character level / XP / coins and lets the player jump into
## battle or open the Workshop. Built code-driven for a clean full-screen layout.

var lbl_stats: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.12)
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
	vb.add_theme_constant_override("separation", 22)
	add_child(vb)

	var title := Label.new()
	title.text = "ORC DEFENSE"
	title.add_theme_font_size_override("font_size", 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	lbl_stats = Label.new()
	lbl_stats.add_theme_font_size_override("font_size", 30)
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl_stats)

	var play := Button.new()
	play.text = "PLAY  (Level %d)" % Game.highest_level
	play.custom_minimum_size = Vector2(360, 88)
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Battle.tscn"))
	vb.add_child(play)

	var shop := Button.new()
	shop.text = "WORKSHOP"
	shop.custom_minimum_size = Vector2(360, 80)
	shop.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Workshop.tscn"))
	vb.add_child(shop)

	_refresh()
	Game.changed.connect(_refresh)


func _refresh() -> void:
	lbl_stats.text = "Character Lv %d   XP %d/%d   Coins %d" % [
		Game.char_level, Game.xp_into_level(), Game.xp_for_next_level(), Game.coins]
