extends Node3D
const AntScene = preload("res://scenes/ant_colony/Ant.tscn")
const NestTexture = preload("res://assets/ant_colony/nest-transparent.png")
const StrongholdTexture = preload("res://assets/ant_colony/homes/stronghold.png")
const CountFont = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
var level
var team := 0
var population := 0
var armored_population := 0
var armored_damage := 0
var stronghold := false
var nest_id := "A"
var links: Array = []
var production_clock := 0.0
var armor_ticks := 0
var selected := false
var fighting := false
var ring: MeshInstance3D
var flag: MeshInstance3D
var mound: Sprite3D
var label: Marker3D
var screen_label: Label
var residents: Node3D
var last_population := -1
var last_team := -1
var damage_clock := 0.0
var patrol_angle := 0.0
var alerted := false
var shield_hits := 0
var shield_until := 0.0

func _ready() -> void:
	mound = Sprite3D.new()
	mound.name = "NestArtwork"
	mound.texture = StrongholdTexture if stronghold else NestTexture
	mound.pixel_size = (4.9 if stronghold else 3.6)/float(mound.texture.get_width())
	mound.position = Vector3(0,1.75 if stronghold else 1.35,0)
	mound.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mound.shaded = false
	mound.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mound.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mound)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0 if stronghold else 1.5
	torus.outer_radius = 2.14 if stronghold else 1.63
	ring.mesh = torus
	ring.position.y = 0.065
	add_child(ring)
	level.segment(self,Vector3(1.28,0.1,0),Vector3(1.28,2.0,0),0.035,Color("59432a"))
	flag = MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.52,0.32,0.035)
	flag.mesh = cloth
	flag.position = Vector3(1.52,1.8,0)
	add_child(flag)
	label = Marker3D.new()
	label.name = "CountAnchor"
	label.position = Vector3(0,5.0 if stronghold else 3.55,0)
	add_child(label)
	screen_label = Label.new()
	screen_label.name = "Population"+nest_id
	screen_label.z_index = 5
	var bold_font := FontVariation.new()
	bold_font.base_font = CountFont
	bold_font.variation_opentype = {0x77676874: 700.0}
	bold_font.variation_embolden = 0.15
	screen_label.add_theme_font_override("font",bold_font)
	screen_label.add_theme_font_size_override("font_size",40)
	screen_label.add_theme_color_override("font_outline_color",Color("122218"))
	screen_label.add_theme_constant_override("outline_size",7)
	screen_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	screen_label.add_theme_constant_override("shadow_offset_y",2)
	screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen_label.size = Vector2(180,72)
	screen_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.get_node("HUD").add_child(screen_label)
	residents = Node3D.new()
	residents.name = "VisibleGarrison"
	add_child(residents)
	refresh()
	update_count_position()

func _process(delta: float) -> void:
	if not level.active or level.paused:
		return
	if team != 0:
		production_clock += delta
		var blue_interval: float = maxf(1.15, 2.0 - GameProgress.upgrade_level("hatchery") * 0.15)
		var interval: float = blue_interval if team == 1 else 3.0
		while production_clock >= interval:
			production_clock -= interval
			if team == 1 and level.level_number >= 2 and population >= 28 and armored_population < 6:
				armor_ticks += 1
				if armor_ticks >= 4:
					armor_ticks = 0
					armored_population += 1
					level.float_text(global_position + Vector3.UP * 1.8, "+1 ARMOR", Color("7cc6ff"))
					continue
			population = mini(100,population+1)
	damage_clock = maxf(0,damage_clock-delta)
	mound.position.x = sin(damage_clock*75)*damage_clock*0.12
	mound.scale.y = 0.96 if fighting and population < 6 else 1.0
	mound.modulate = Color("d5a17d") if fighting and population < 6 else Color.WHITE
	if last_population != population or last_team != team:
		refresh()
	ring.scale = Vector3.ONE*(1.12 if selected else 1.0)
	update_garrison(delta)
	update_count_position()

func update_count_position() -> void:
	screen_label.position = level.camera.unproject_position(label.global_position)-screen_label.size*0.5

func update_garrison(delta: float) -> void:
	patrol_angle += delta*0.55
	var threat = null
	var nearest := 5.0
	for army in level.armies.get_children():
		if army.resolved or army.target != self or army.team == team:
			continue
		var distance: float = army.start.lerp(army.finish,army.progress).distance_to(global_position)
		if distance < nearest:
			nearest = distance
			threat = army
	alerted = threat != null
	var approach := Vector3.ZERO
	if alerted:
		approach = (threat.start-global_position).normalized()
	var side := Vector3(-approach.z,0,approach.x)
	for i in range(residents.get_child_count()):
		var ant = residents.get_child(i)
		var destination: Vector3
		if alerted:
			destination = approach*(1.85-float(i/3)*0.45)+side*(float(i%3)-1.0)*0.58
		else:
			var angle: float = patrol_angle+i*TAU/6.0
			destination = Vector3(cos(angle)*1.7,0,sin(angle)*1.58)
		destination.y = 0.08
		var velocity: Vector3 = destination-ant.position
		ant.position = ant.position.move_toward(destination,delta*(2.2 if alerted else 1.1))
		ant.face(approach if alerted else velocity)
		ant.attacking = fighting and alerted

func refresh() -> void:
	last_population = population
	last_team = team
	var color: Color = level.team_color(team)
	ring.material_override = level.mat(color)
	flag.material_override = level.mat(color)
	screen_label.text = nest_id+"  "+str(population)
	if armored_population > 0:
		screen_label.text += "  ARMOR "+str(armored_population)
		screen_label.size.x = 300
		screen_label.add_theme_font_size_override("font_size",32)
	else:
		screen_label.size.x = 180
		screen_label.add_theme_font_size_override("font_size",40)
	screen_label.add_theme_color_override("font_color",Color("2995ff") if team == 1 else (Color("f04432") if team == 2 else Color("d5bc82")))
	for child in residents.get_children():
		if child.team != team:
			child.free()
	var wanted := mini(population+armored_population,6)
	var armor_visuals := mini(armored_population,wanted)
	var armor_mismatch := false
	for i in range(residents.get_child_count()):
		if residents.get_child(i).armored != (i < armor_visuals):
			armor_mismatch = true
			break
	if armor_mismatch:
		for child in residents.get_children():
			child.free()
	while residents.get_child_count() > wanted:
		residents.get_child(residents.get_child_count()-1).free()
	while residents.get_child_count() < wanted:
		var i := residents.get_child_count()
		var ant = AntScene.instantiate()
		ant.team = team
		ant.armored = i < armor_visuals
		ant.level = level
		residents.add_child(ant)
		var angle: float = patrol_angle+i*TAU/6.0
		ant.position = Vector3(cos(angle)*1.7,0.08,sin(angle)*1.58)
		ant.rotation.y = -angle
		ant.scale = Vector3.ONE*0.7

func capture(new_team: int, survivors: int, armored_survivors: int = 0) -> void:
	shield_hits = 0
	armored_population = mini(10, armored_survivors)
	armored_damage = 0
	armor_ticks = 0
	if team != new_team:
		level.smoke(global_position+Vector3.UP*0.3,team,true)
		SoundManager.play_capture(new_team == 1)
		level.shake(0.24, 0.22)
		level.float_text(
			global_position + Vector3.UP * 2.0,
			"CAPTURED!" if new_team == 1 else "NEST LOST!",
			Color("7fd4ff") if new_team == 1 else Color("ff7b6b")
		)
	team = new_team
	population = mini(100,survivors)
	production_clock = 0.0
	level.last_captured_nest = self
	refresh()
	level.burst(global_position+Vector3.UP*0.6,level.team_color(team),14)

func hit() -> void:
	damage_clock = 0.35
	level.burst(global_position+Vector3(0,0.3,0),Color("c5ad78"),3)

func emerge(amount: int) -> void:
	for i in range(mini(amount,8)):
		var ant = AntScene.instantiate()
		ant.team = team
		ant.level = level
		level.effects.add_child(ant)
		ant.global_position = global_position+Vector3(0,0.48,0)
		var angle: float = i*TAU/8.0
		var destination: Vector3 = global_position+Vector3(cos(angle)*1.1,0.04,sin(angle)*1.1)
		ant.face(destination-ant.global_position)
		var tween := ant.create_tween()
		tween.tween_property(ant,"global_position",destination,0.8)
		tween.tween_callback(ant.queue_free)
