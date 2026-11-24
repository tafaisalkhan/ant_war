extends Control
const FONT = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
var elapsed := 0.0
var launched := false

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://assets/ant_colony/ui/splash.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.08,0.035,0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := Label.new()
	title.text = "ANT COLONY\nWARS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",FONT)
	title.add_theme_font_size_override("font_size",68)
	title.add_theme_color_override("font_color",Color("fff2b8"))
	title.add_theme_color_override("font_outline_color",Color("173b27"))
	title.add_theme_constant_override("outline_size",12)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -320
	title.offset_right = 320
	title.offset_top = 42
	title.offset_bottom = 205
	add_child(title)
	var loading := Label.new()
	loading.name = "Loading"
	loading.text = "Preparing the colonies..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_font_override("font",preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	loading.add_theme_font_size_override("font_size",22)
	loading.add_theme_color_override("font_color",Color("fff4d0"))
	loading.add_theme_color_override("font_outline_color",Color("163522"))
	loading.add_theme_constant_override("outline_size",6)
	loading.anchor_left = 0.5
	loading.anchor_right = 0.5
	loading.anchor_top = 1.0
	loading.anchor_bottom = 1.0
	loading.offset_left = -260
	loading.offset_right = 260
	loading.offset_top = -70
	loading.offset_bottom = -24
	add_child(loading)

func _process(delta: float) -> void:
	elapsed += delta
	$Loading.modulate.a = 0.55+sin(elapsed*4.0)*0.35
	if elapsed >= 1.8 and not launched:
		launched = true
		get_tree().change_scene_to_file("res://scenes/ant_colony/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or (event is InputEventKey and event.pressed):
		if elapsed > 0.35 and not launched:
			launched = true
			get_tree().change_scene_to_file("res://scenes/ant_colony/MainMenu.tscn")
