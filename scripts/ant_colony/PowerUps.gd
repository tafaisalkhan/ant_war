extends Node
## One free charge of each power per run. Level owns the gameplay clock.
const SPECS = {
	"sugar": ["SUGAR RUSH", "+50% speed / 8s", Color("62bdff")],
	"shield": ["LEAF SHIELD", "Block 5 losses / 8s", Color("91dc68")],
	"rally": ["ROYAL RALLY", "+6 & 2 Armor", Color("d1a0ff")],
	"honey": ["STICKY HONEY", "Slow enemies / 6s", Color("ffc45b")]
}
const ICONS = {
	"sugar": preload("res://assets/ant_colony/ui/power-sugar.png"),
	"shield": preload("res://assets/ant_colony/ui/power-shield.png"),
	"rally": preload("res://assets/ant_colony/ui/power-rally.png"),
	"honey": preload("res://assets/ant_colony/ui/power-honey.png")
}
const COSTS = {"sugar":15,"shield":20,"rally":25,"honey":15}
var level
var charges := {"sugar":1,"shield":1,"rally":1,"honey":1}
var pending := ""
var sugar_until := 0.0
var shields: Array = []
var honey_patches: Array = []
var buttons: Dictionary = {}
var row: HBoxContainer
var trail_clock := 0.0

func setup(owner_level) -> void:
	level = owner_level
	row = HBoxContainer.new()
	row.name = "PowerUps"
	row.add_theme_constant_override("separation",10)
	level.get_node("HUD").add_child(row)
	row.anchor_left = 0.04
	row.anchor_right = 0.96
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 0
	row.offset_right = 0
	row.offset_top = -88
	row.offset_bottom = -14
	for key in SPECS:
		var button := Button.new()
		button.name = key.capitalize()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(140,68)
		button.icon = ICONS[key]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",52)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font",preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
		button.add_theme_font_size_override("font_size",18)
		button.add_theme_color_override("font_color",SPECS[key][2])
		button.add_theme_color_override("font_disabled_color",Color("879580"))
		button.add_theme_color_override("font_outline_color",Color("091710"))
		button.add_theme_constant_override("outline_size",6)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035,0.10,0.065,0.95)
		style.border_color = SPECS[key][2].darkened(0.25)
		style.set_border_width_all(3)
		style.border_width_bottom = 6
		style.set_corner_radius_all(14)
		button.add_theme_stylebox_override("normal",style)
		var hover := style.duplicate()
		hover.bg_color = Color("254b37")
		hover.border_color = SPECS[key][2]
		button.add_theme_stylebox_override("hover",hover)
		button.add_theme_stylebox_override("pressed",hover)
		button.add_theme_stylebox_override("disabled",style)
		button.pressed.connect(activate.bind(key))
		button.button_down.connect(func():
			button.pivot_offset = button.size * 0.5
			var tw := button.create_tween()
			tw.tween_property(button, "scale", Vector2(0.91, 0.91), 0.06)
		)
		button.button_up.connect(func():
			button.pivot_offset = button.size * 0.5
			var tw := button.create_tween()
			tw.tween_property(button, "scale", Vector2(1.06, 1.06), 0.09)
			tw.tween_property(button, "scale", Vector2.ONE, 0.08)
		)
		row.add_child(button)
		buttons[key] = button
		var idx := buttons.size() - 1
		button.pivot_offset = Vector2(95, 34)
		button.scale = Vector2.ZERO
		var etw := button.create_tween()
		etw.tween_interval(0.14 + idx * 0.065)
		etw.tween_property(button, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	refresh_buttons()

func is_over_controls(screen: Vector2) -> bool:
	return row.visible and row.get_global_rect().has_point(screen)

func activate(key: String) -> bool:
	if not level.active or not charges.has(key) or charges[key] == 0:
		return false
	if GameProgress.coins < COSTS[key]:
		level.hint.text = "Need "+str(COSTS[key])+" coins for "+SPECS[key][0]
		return false
	level.cancel_drag()
	if key == "sugar":
		if not GameProgress.spend_coins(COSTS[key]):
			return false
		charges[key] = 0
		SoundManager.play_powerup(key)
		level.coin_label.text = str(GameProgress.coins)
		sugar_until = level.elapsed+8.0
		pending = ""
		level.hint.text = "Sugar Rush! Blue armies move 50% faster for 8 seconds"
		_play_power_banner("SUGAR RUSH!  +50% SPEED", Color("62bdff"))
		_flash_screen(Color(0.28, 0.72, 1.0, 0.24))
		level.shake(0.18, 0.14)
		for nest in level.nests:
			if nest.team == 1:
				_spawn_shockwave(nest.global_position + Vector3.UP * 0.12, Color("62bdff"), 4.2)
				level.burst(nest.global_position+Vector3.UP*0.3,Color("93d9ff"),16)
	else:
		pending = "" if pending == key else key
		level.hint.text = ("Tap a dirt path to place Sticky Honey" if key == "honey" else "Tap a blue nest for "+SPECS[key][0]) if pending != "" else "Drag from a blue nest to send half your ants"
	refresh_buttons()
	return true

func target(screen: Vector2) -> bool:
	if pending == "" or not level.active:
		return false
	var key := pending
	if key == "honey":
		var ground: Vector3 = level.ground_point(screen)
		var closest := Vector3.ZERO
		var route: Array = []
		var distance := 1.5
		for edge in level.EDGES:
			var a: Vector3 = level.POSITIONS[edge[0]]
			var b: Vector3 = level.POSITIONS[edge[1]]
			var candidate := Geometry3D.get_closest_point_to_segment(ground,a,b)
			if candidate.distance_to(ground) < distance:
				closest = candidate
				distance = candidate.distance_to(ground)
				route = edge
		if route.is_empty():
			level.hint.text = "Tap directly on a dirt path for Sticky Honey"
			return false
		if not GameProgress.spend_coins(COSTS[key]):
			return false
		create_honey(closest,route)
		_play_power_banner("STICKY HONEY!  ENEMIES SLOWED", Color("ffc45b"))
		_flash_screen(Color(1.0, 0.72, 0.18, 0.20))
		_spawn_shockwave(closest + Vector3.UP * 0.12, Color("ffc45b"), 3.6)
		level.shake(0.16, 0.12)
	else:
		var nest = level.pick_nest(screen)
		if nest == null or nest.team != 1:
			level.hint.text = "Choose a blue nest for "+SPECS[key][0]
			return false
		if key == "rally":
			if nest.population >= 100 and nest.armored_population >= 10:
				level.hint.text = "That nest is full - choose another blue nest"
				return false
			if not GameProgress.spend_coins(COSTS[key]):
				return false
			var added: int = mini(6,100-nest.population)
			var armored_added: int = mini(2,10-nest.armored_population)
			nest.population += added
			nest.armored_population += armored_added
			nest.refresh()
			nest.emerge(added+armored_added)
			level.burst(nest.global_position+Vector3.UP*0.4,Color("d6a8ff"),20)
			_spawn_shockwave(nest.global_position + Vector3.UP * 0.12, Color("d1a0ff"), 4.4)
			_spawn_light_pillar(nest.global_position, Color("d1a0ff"))
			_play_power_banner("ROYAL RALLY!  +" + str(added) + " & " + str(armored_added) + " ARMOR", Color("d8a7ff"))
			_flash_screen(Color(0.76, 0.48, 1.0, 0.22))
			level.shake(0.20, 0.16)
			var rally_text := world_label("+"+str(added)+" & "+str(armored_added)+" ARMOR",Color("d8a7ff"))
			level.effects.add_child(rally_text)
			rally_text.global_position = nest.global_position+Vector3.UP*1.35
			var rally_tween := rally_text.create_tween().set_parallel(true)
			rally_tween.tween_property(rally_text,"global_position",rally_text.global_position+Vector3.UP*1.4,1.2)
			rally_tween.tween_property(rally_text,"modulate:a",0.0,1.2)
			rally_tween.chain().tween_callback(rally_text.queue_free)
		elif key == "shield":
			if not GameProgress.spend_coins(COSTS[key]):
				return false
			create_shield(nest)
			_spawn_shockwave(nest.global_position + Vector3.UP * 0.12, Color("91dc68"), 4.2)
			_play_power_banner("LEAF SHIELD!  BLOCKS 5 LOSSES", Color("91dc68"))
			_flash_screen(Color(0.45, 0.92, 0.40, 0.20))
			level.shake(0.16, 0.12)
	SoundManager.play_powerup(key)
	level.coin_label.text = str(GameProgress.coins)
	charges[key] = 0
	pending = ""
	level.hint.text = SPECS[key][0]+" activated!"
	refresh_buttons()
	return true

func create_shield(nest) -> void:
	nest.shield_hits = 5
	nest.shield_until = level.elapsed+8.0
	var dome := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 2.0
	mesh.height = 4.0
	mesh.radial_segments = 32
	mesh.rings = 16
	dome.mesh = mesh
	dome.position.y = 0.15
	dome.scale = Vector3(1,0.8,1)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/ant_colony/shield.gdshader")
	material.render_priority = 2
	dome.material_override = material
	nest.add_child(dome)
	var shield_ring := MeshInstance3D.new()
	var shield_torus := TorusMesh.new()
	shield_torus.inner_radius = 1.68
	shield_torus.outer_radius = 1.82
	shield_ring.mesh = shield_torus
	shield_ring.position.y = -0.1
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("8cff68")
	ring_material.emission_enabled = true
	ring_material.emission = Color("57e84d")
	ring_material.emission_energy_multiplier = 2.2
	shield_ring.material_override = ring_material
	dome.add_child(shield_ring)
	var counter := world_label("LEAF SHIELD  5",Color("aaf07f"))
	counter.position = Vector3(0,2.25,0)
	nest.add_child(counter)
	shields.append({"nest":nest,"visual":dome,"label":counter})
	level.burst(nest.global_position+Vector3.UP*0.6,Color("91dc68"),12)

func create_honey(pos: Vector3, edge: Array) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0,0.57,0.08,0.88)
	material.emission_enabled = true
	material.emission = Color("ff9f24")
	material.emission_energy_multiplier = 1.5
	var root := Node3D.new()
	root.name = "StickyHoneyEffect"
	root.position = pos
	level.effects.add_child(root)
	var patch = level.sphere(root,Vector3.UP*0.06,Vector3(1.6,0.04,0.95),Color.WHITE)
	patch.name = "StickyHoney"
	patch.material_override = material
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for radius in [1.15,1.55]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius
		torus.outer_radius = radius+0.07
		ring.mesh = torus
		ring.position.y = 0.1
		ring.material_override = material
		root.add_child(ring)
	var counter := world_label("HONEY  6s",Color("ffd05b"))
	counter.position = Vector3(0,1.15,0)
	root.add_child(counter)
	honey_patches.append({"position":pos,"edge":edge,"until":level.elapsed+6.0,"visual":root,"label":counter})
	level.burst(pos+Vector3.UP*0.2,Color("ffd36c"),8)

func speed_multiplier(army) -> float:
	if army.team == 1:
		return 1.5 if level.elapsed < sugar_until else 1.0
	var position: Vector3 = army.start.lerp(army.finish,army.progress)
	for patch in honey_patches:
		var a = level.nests[patch.edge[0]]
		var b = level.nests[patch.edge[1]]
		var same_route: bool = (army.source == a and army.target == b) or (army.source == b and army.target == a)
		if level.elapsed < patch.until and same_route and position.distance_to(patch.position) < 1.8:
			return 0.45
	return 1.0

func update(delta: float) -> void:
	for i in range(shields.size()-1,-1,-1):
		var entry: Dictionary = shields[i]
		var nest = entry.nest
		if nest.team != 1 or nest.shield_hits <= 0 or level.elapsed >= nest.shield_until:
			nest.shield_hits = 0
			if is_instance_valid(entry.visual):
				entry.visual.queue_free()
			if is_instance_valid(entry.label):
				entry.label.queue_free()
			shields.remove_at(i)
		else:
			var pulse: float = 1.0+sin(level.elapsed*3.0)*0.025
			entry.visual.scale = Vector3(pulse,0.8*pulse,pulse)
			entry.label.text = "LEAF SHIELD  "+str(nest.shield_hits)
	for i in range(honey_patches.size()-1,-1,-1):
		var patch: Dictionary = honey_patches[i]
		if level.elapsed >= patch.until:
			patch.visual.queue_free()
			honey_patches.remove_at(i)
		else:
			var remaining := int(ceil(patch.until-level.elapsed))
			patch.label.text = "HONEY  "+str(remaining)+"s"
			var pulse := 1.0+sin(level.elapsed*5.0)*0.06
			patch.visual.scale = Vector3(pulse,1.0,pulse)
	trail_clock += delta
	if level.elapsed < sugar_until and trail_clock > 0.16:
		trail_clock = 0.0
		for army in level.armies.get_children():
			if army.team == 1 and not army.arrived and not army.resolved:
				level.burst(army.start.lerp(army.finish,army.progress)+Vector3.UP*0.12,Color("95dfff"),4)
	refresh_buttons()

func refresh_buttons() -> void:
	for key in buttons:
		var button: Button = buttons[key]
		var detail: String = SPECS[key][1]
		if charges[key] > 0:
			detail = str(COSTS[key])+" COINS  •  "+detail
		if charges[key] == 0:
			detail = "Used"
			if key == "sugar" and level.elapsed < sugar_until:
				detail = str(int(ceil(sugar_until-level.elapsed)))+"s remaining"
			elif key == "shield" and not shields.is_empty():
				detail = str(shields[0].nest.shield_hits)+" blocks left"
			elif key == "honey" and not honey_patches.is_empty():
				detail = str(int(ceil(honey_patches[0].until-level.elapsed)))+"s remaining"
		elif pending == key:
			detail = "TAP PATH" if key == "honey" else "TAP BLUE NEST"
		button.text = "   "+SPECS[key][0]+"\n   "+detail
		button.disabled = charges[key] == 0 or (GameProgress.coins < COSTS[key] and pending != key)

func finish() -> void:
	pending = ""
	row.visible = false

func world_label(message: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = message
	label.font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
	label.font_size = 64
	label.pixel_size = 0.0075
	label.modulate = color
	label.outline_modulate = Color("18251d")
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	return label

func _spawn_shockwave(pos: Vector3, color: Color, target_scale: float = 4.0) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.96
	ring.mesh = torus
	ring.position = pos
	ring.scale = Vector3.ONE * 0.4
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.92)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	ring.material_override = mat
	level.effects.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(target_scale, 0.5, target_scale), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_light_pillar(pos: Vector3, color: Color) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 1.55
	cyl.height = 6.5
	beam.mesh = cyl
	beam.position = pos + Vector3.UP * 3.2
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	beam.material_override = mat
	level.effects.add_child(beam)
	var tw := beam.create_tween().set_parallel(true)
	tw.tween_property(beam, "scale", Vector3(0.15, 1.35, 0.15), 0.65).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.65)
	tw.chain().tween_callback(beam.queue_free)

func _flash_screen(color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.get_node("HUD").add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.38)
	tw.tween_callback(flash.queue_free)

func _play_power_banner(message: String, color: Color) -> void:
	var banner := Label.new()
	banner.text = message
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
	banner.add_theme_font_size_override("font_size", 38)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color("122218"))
	banner.add_theme_constant_override("outline_size", 10)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 135
	banner.offset_bottom = 195
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	level.get_node("HUD").add_child(banner)
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(banner, "offset_top", 118.0, 0.22).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.95)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35)
	tw.tween_callback(banner.queue_free)
