extends Control
## Title screen: a logo banner (orc vs turret) + stats + Play / Workshop / Settings.

var lbl_stats: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.12)
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

	vb.add_child(_make_logo())

	lbl_stats = Label.new()
	lbl_stats.add_theme_font_size_override("font_size", 28)
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl_stats)

	vb.add_child(_menu_button("PLAY  (Level %d)" % Game.highest_level,
		"res://scenes/Battle.tscn", Vector2(400, 88)))
	vb.add_child(_menu_button("WORKSHOP", "res://scenes/Workshop.tscn", Vector2(400, 76)))
	vb.add_child(_menu_button("SETTINGS", "res://scenes/Settings.tscn", Vector2(400, 76)))

	_refresh()
	Game.changed.connect(_refresh)


func _make_logo() -> Control:
	# a banner panel with the title flanked by an orc and a turret sprite
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	row.add_child(_sprite_icon("orc", 84, Color(0.7, 1.15, 0.6)))

	var title := Label.new()
	title.text = "ORC DEFENSE"
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.09, 0.05))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(title)

	row.add_child(_sprite_icon("rifle", 84, Color(1, 1, 1)))
	return panel


func _sprite_icon(key: String, size: int, tint: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Assets.tex(key)
	tr.custom_minimum_size = Vector2(size, size)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	return tr


func _menu_button(text: String, scene: String, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	return b


func _refresh() -> void:
	lbl_stats.text = "Character Lv %d    XP %d/%d    Coins %d" % [
		Game.char_level, Game.xp_into_level(), Game.xp_for_next_level(), Game.coins]
