extends Control
## Settings: audio toggles (persisted; audio hooked up later), reset progress, back.

var _confirm_reset := false
var _reset_btn: Button


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.11)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	vb.add_child(_toggle_row("Music", "music", Game.music_on))
	vb.add_child(_toggle_row("Sound FX", "sfx", Game.sfx_on))

	_reset_btn = Button.new()
	_reset_btn.text = "Reset Progress"
	_reset_btn.custom_minimum_size = Vector2(0, 70)
	_reset_btn.pressed.connect(_on_reset)
	vb.add_child(_reset_btn)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 70)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	vb.add_child(back)


func _toggle_row(label_text: String, key: String, value: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 32)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var cb := CheckButton.new()
	cb.button_pressed = value
	cb.toggled.connect(_on_toggle.bind(key))
	row.add_child(cb)
	return row


func _on_toggle(value: bool, key: String) -> void:
	if key == "music":
		Game.music_on = value
	else:
		Game.sfx_on = value
	Game.save_game()


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = "Tap again to CONFIRM reset"
		return
	Game.reset_progress()
	_reset_btn.text = "Progress reset!"
	_confirm_reset = false
