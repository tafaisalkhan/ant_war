extends Node3D
const NestScene = preload("res://scenes/ant_colony/Nest.tscn")
const ArmyScene = preload("res://scenes/ant_colony/Army.tscn")
const AntScene = preload("res://scenes/ant_colony/Ant.tscn")
const AntVisual = preload("res://scripts/ant_colony/Ant.gd")
const ForestTexture = preload("res://assets/ant_colony/forest_background.png")
const Biomes = [
	preload("res://assets/ant_colony/forest_background.png"),
	preload("res://assets/ant_colony/backgrounds/mushroom-grove.png"),
	preload("res://assets/ant_colony/backgrounds/autumn-woodland.png"),
	preload("res://assets/ant_colony/backgrounds/rocky-creek.png"),
	preload("res://assets/ant_colony/backgrounds/ancient-root-hollow.png"),
	preload("res://assets/ant_colony/backgrounds/sandy-garden.png")
]
const PathTexture = preload("res://assets/ant_colony/path-transparent.png")
const SmokeShader = preload("res://assets/ant_colony/smoke.gdshader")
const PowerUpScript = preload("res://scripts/ant_colony/PowerUps.gd")
const TitleFont = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const UiFont = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const ICON_COIN = preload("res://assets/ant_colony/ui/icons/icon-coin.png")
const ICON_STAR = preload("res://assets/ant_colony/ui/icons/icon-star.png")
const ICON_CLOCK = preload("res://assets/ant_colony/ui/icons/icon-clock.png")
const ICON_SETTINGS = preload("res://assets/ant_colony/ui/icons/icon-settings.png")
const ICON_PAUSE = preload("res://assets/ant_colony/ui/icons/icon-pause.png")
var POSITIONS: Array[Vector3] = []
var EDGES: Array = []
var level_number := 1
var level_data: Dictionary
var background_texture: Texture2D
var nests: Array = []
var active := true
var paused := false
var send_ratio := 0.5
var elapsed := 0.0
var wave_done := false
var selected = null
var dragging := false
var touch_id := -1
var pointer := Vector2.ZERO
var targeting = null
var result := ""
var material_cache: Dictionary = {}
var forest_backdrop: MeshInstance3D
var powerups
var ambient_items: Array = []
var ambient_clock := 0.0
var rng := RandomNumberGenerator.new()
var last_captured_nest = null
var last_victory_reward := 0
var double_coins_claimed := false
var camera_base_pos := Vector3(0, 22, 18)
var shake_time := 0.0
var shake_strength := 0.0
@onready var camera: Camera3D = $Camera3D
@onready var armies: Node3D = $AntArmies
@onready var effects: Node3D = $CombatEffects
@onready var ai = $EnemyAI
var notice: Label
var hint: Label
var outcome: Control
var outcome_panel: PanelContainer
var pause_overlay: Control
var pause_card: Control
var settings_overlay: Control
var settings_card: Control
var switch_music_knob: PanelContainer
var switch_music_bg: StyleBoxFlat
var switch_sfx_knob: PanelContainer
var switch_sfx_bg: StyleBoxFlat
var switch_send_knob: PanelContainer
var switch_send_bg: StyleBoxFlat
var top_controls: HBoxContainer
var top_hud_bar: HBoxContainer
var timer_label: Label
var hud_star_icons: Array = []
var send_btn: Button
var coin_label: Label

func _ready() -> void:
	MonetizationManager.set_gameplay_active(true)
	rng.seed = 1739
	send_ratio = 1.0 if GameProgress.default_send_all else 0.5
	level_number = MonetizationManager.daily_challenge_level_number() if GameProgress.playing_daily_challenge else GameProgress.current_level
	level_data = preload("res://scripts/ant_colony/LevelGenerator.gd").generate(level_number)
	POSITIONS = level_data.positions
	EDGES = level_data.edges
	background_texture = Biomes[level_data.biome]
	setup_camera()
	build_terrain()
	build_nests()
	build_hud()
	powerups = PowerUpScript.new()
	powerups.name = "PowerUps"
	add_child(powerups)
	powerups.setup(self)
	build_ambience()
	ai.level = self
	get_viewport().size_changed.connect(setup_camera)
	_play_battle_intro_choreography()

func _play_battle_intro_choreography() -> void:
	if is_instance_valid(top_hud_bar):
		top_hud_bar.offset_top = -68.0
		top_hud_bar.offset_bottom = -20.0
		var htw := top_hud_bar.create_tween().set_parallel(true)
		htw.tween_property(top_hud_bar, "offset_top", 10.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		htw.tween_property(top_hud_bar, "offset_bottom", 58.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(nests.size()):
		var n: Node3D = nests[i]
		n.scale = Vector3.ONE * 0.22
		var ntw := n.create_tween()
		ntw.tween_interval(0.05 + i * 0.065)
		ntw.tween_property(n, "scale", Vector3.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func setup_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0,22,18)
	camera.look_at(Vector3(0,0,0.3))
	# Fit both axes, including on narrower landscape tablets.
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x/maxf(1,viewport_size.y)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = maxf(15.8,25.0/aspect)
	if is_instance_valid(forest_backdrop):
		resize_backdrop(aspect)

func build_nests() -> void:
	var teams: Array = level_data.teams
	var populations: Array = level_data.populations
	for i in range(POSITIONS.size()):
		var nest = NestScene.instantiate()
		nest.name = "Nest"+String.chr(65+i)
		nest.nest_id = String.chr(65+i)
		nest.level = self
		nest.team = teams[i]
		nest.population = populations[i]
		nest.armored_population = level_data.armored[i]
		if nest.team == 1:
			nest.population = mini(100, nest.population + GameProgress.upgrade_level("barracks") * 4)
			nest.armored_population = mini(10, nest.armored_population + GameProgress.upgrade_level("armor"))
		nest.stronghold = level_data.strongholds[i]
		nest.position = POSITIONS[i]
		$Nests.add_child(nest)
		nests.append(nest)
	for edge in EDGES:
		nests[edge[0]].links.append(nests[edge[1]])
		nests[edge[1]].links.append(nests[edge[0]])

func build_terrain() -> void:
	# The painted environment sits behind the XZ gameplay plane. Unlike a flat
	# ground texture, a camera-aligned backdrop preserves its authored perspective.
	forest_backdrop = MeshInstance3D.new()
	forest_backdrop.name = "ForestBackground"
	forest_backdrop.mesh = QuadMesh.new()
	forest_backdrop.position = Vector3(0,0,-60)
	forest_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var background_material := StandardMaterial3D.new()
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_material.albedo_texture = background_texture
	forest_backdrop.material_override = background_material
	camera.add_child(forest_backdrop)
	var viewport_size := get_viewport().get_visible_rect().size
	resize_backdrop(viewport_size.x/maxf(1,viewport_size.y))
	for edge in EDGES:
		var a: Vector3 = POSITIONS[edge[0]]
		var b: Vector3 = POSITIONS[edge[1]]
		var route := MeshInstance3D.new()
		route.name = "DirtRoute"+str(edge[0])+str(edge[1])
		var surface := PlaneMesh.new()
		surface.size = Vector2(a.distance_to(b),3.4)
		route.mesh = surface
		route.position = (a+b)*0.5+Vector3.UP*0.015
		route.rotation.y = -atan2(b.z-a.z,b.x-a.x)
		route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var path_material := StandardMaterial3D.new()
		path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		path_material.albedo_texture = PathTexture
		path_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		route.material_override = path_material
		$Paths.add_child(route)

func resize_backdrop(aspect: float) -> void:
	# Cover the viewport without distorting the image on tablets or wide phones.
	var image_aspect: float = float(background_texture.get_width())/background_texture.get_height()
	var height := maxf(camera.size,camera.size*aspect/image_aspect)
	forest_backdrop.mesh.size = Vector2(height*image_aspect,height)

func build_placeholder_terrain() -> void:
	# Preserved original colored scenery; the painted battlefield is now active.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70,60)
	ground.mesh = plane
	ground.material_override = mat(Color("3e6338"))
	$Terrain.add_child(ground)
	# Overlapping low flattened stones create a soft irregular forest clearing.
	for i in range(80):
		var p := Vector3(rng.randf_range(-15,15),0.012,rng.randf_range(-10,10))
		sphere($Terrain,p,Vector3(rng.randf_range(0.3,1.1),0.012,rng.randf_range(0.25,0.8)),Color("4a703b") if i%2 == 0 else Color("385c31"))
	for edge in EDGES:
		var a: Vector3 = POSITIONS[edge[0]]
		var b: Vector3 = POSITIONS[edge[1]]
		var steps := int(a.distance_to(b)/0.3)
		for i in range(steps+1):
			var p := a.lerp(b,float(i)/steps)
			p.y = 0.025
			sphere($Paths,p,Vector3(0.42,0.022,0.36),Color("8b704c") if i%3 else Color("947952"))
	# Decoration deliberately avoids every nest and required route.
	for i in range(125):
		var p := Vector3(rng.randf_range(-13.5,13.5),0,rng.randf_range(-8.5,8.5))
		if not clear_for_prop(p):
			continue
		match i%7:
			0: # Mushrooms, with cream stalks and bright caps.
				segment($EnvironmentProps,p,p+Vector3.UP*0.48,0.08,Color("f2dfb2"))
				sphere($EnvironmentProps,p+Vector3.UP*0.5,Vector3(0.36,0.17,0.32),Color("e16e51"))
				sphere($EnvironmentProps,p+Vector3(0.08,0.65,0.04),Vector3(0.06,0.025,0.06),Color("fff0cf"))
			1: # Weathered rocks.
				sphere($EnvironmentProps,p+Vector3.UP*0.16,Vector3(0.46,0.3,0.36),Color("87928b"))
			2: # Logs and exposed roots.
				segment($EnvironmentProps,p+Vector3.UP*0.2,p+Vector3(0.95,0.2,0.5),0.19,Color("765034"))
				segment($EnvironmentProps,p,p+Vector3(-0.6,0.06,0.5),0.055,Color("80603e"))
			3: # Bush clusters.
				for j in range(3):
					sphere($EnvironmentProps,p+Vector3(j*0.22,0.2,0),Vector3(0.36,0.37,0.36),Color("3f7541"))
			4: # Flowers.
				segment($EnvironmentProps,p,p+Vector3.UP*0.3,0.025,Color("387548"))
				for j in range(5):
					var angle: float = j*TAU/5.0
					sphere($EnvironmentProps,p+Vector3(cos(angle)*0.1,0.32,sin(angle)*0.1),Vector3(0.085,0.035,0.085),Color("f7d875"))
			5: # Fallen leaves.
				sphere($EnvironmentProps,p+Vector3.UP*0.04,Vector3(0.34,0.028,0.13),Color("c7a54d"))
			6:
				for j in range(3):
					segment($EnvironmentProps,p,p+Vector3((j-1)*0.12,0.35,0.08),0.02,Color("8eb861"))
	# A low forest border frames the map without occluding its nests.
	for i in range(22):
		var x: float = -15.0+i*1.4
		var p := Vector3(x,0,-9.5)
		segment($EnvironmentProps,p,p+Vector3.UP*1.7,0.17,Color("695139"))
		sphere($EnvironmentProps,p+Vector3.UP*2.0,Vector3(0.95,1.0,0.8),Color("366c40"))

func clear_for_prop(p: Vector3) -> bool:
	for nest_position in POSITIONS:
		if p.distance_to(nest_position) < 1.9:
			return false
	for edge in EDGES:
		var closest := Geometry3D.get_closest_point_to_segment(p,POSITIONS[edge[0]],POSITIONS[edge[1]])
		if p.distance_to(closest) < 1.0:
			return false
	return true

func _process(delta: float) -> void:
	if not active or paused:
		return
	elapsed += delta
	_update_timer_hud()
	powerups.update(delta)
	update_ambience(delta)
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		if shake_time > 0.0:
			camera.position = camera_base_pos + Vector3(
				rng.randf_range(-shake_strength, shake_strength),
				0.0,
				rng.randf_range(-shake_strength, shake_strength)
			)
		else:
			camera.position = camera_base_pos
	if elapsed >= 60.0 and not wave_done:
		reinforcement_wave()
	if dragging:
		update_targeting()
	check_outcome()

func shake(duration: float, strength: float = 0.2) -> void:
	shake_time = maxf(shake_time, duration)
	shake_strength = maxf(shake_strength, strength)

func float_text(pos: Vector3, message: String, color: Color) -> void:
	var lbl: Label3D = powerups.world_label(message, color)
	effects.add_child(lbl)
	lbl.global_position = pos
	var tw: Tween = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position", pos + Vector3.UP * 1.4, 1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(lbl.queue_free)

func deploy(source, target, issuing_team: int = 1):
	if not active or paused or source == null or target == null:
		return null
	if source.team != issuing_team or target not in source.links:
		return null
	var ratio := send_ratio if issuing_team == 1 else 0.5
	var count: int = int(floor(float(source.population) * ratio))
	var armored_count: int = int(ceil(float(source.armored_population) * ratio)) if source.armored_population > 0 else 0
	if count <= 0 and armored_count <= 0:
		return null
	source.population -= count
	source.armored_population -= armored_count
	source.refresh()
	var army = ArmyScene.instantiate()
	army.level = self
	army.source = source
	army.target = target
	army.team = issuing_team
	army.strength = count
	army.armored_strength = armored_count
	armies.add_child(army)
	if issuing_team == 1:
		SoundManager.play_deploy()
	return army

func combat_owner(target):
	for army in armies.get_children():
		if not army.resolved and army.arrived and army.target == target and army.team != target.team:
			return army
	return null

func incoming(target, team: int) -> int:
	var total := 0
	for army in armies.get_children():
		if not army.resolved and army.target == target and army.team == team:
			total += army.strength
	return total

func reinforcement_wave() -> void:
	wave_done = true
	var weakest = null
	for nest in nests:
		if nest.team == 2 and (weakest == null or nest.population < weakest.population):
			weakest = nest
	if weakest != null:
		weakest.population = mini(100,weakest.population+8)
		weakest.refresh()
		weakest.emerge(8)
		notice.text = "Enemy Reinforcements"
		notice.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(3.0)
		tween.tween_property(notice,"modulate:a",0.0,0.5)

func check_outcome() -> void:
	var player_nests := 0
	for nest in nests:
		if nest.team == 1:
			player_nests += 1
	if player_nests == nests.size():
		finish_game("VICTORY")
	elif player_nests == 0:
		for army in armies.get_children():
			if not army.resolved and army.team == 1 and army.total_units() > 0:
				return
		finish_game("DEFEAT")

func finish_game(message: String) -> void:
	active = false
	paused = false
	MonetizationManager.set_gameplay_active(false)
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = false
	if is_instance_valid(settings_overlay):
		settings_overlay.visible = false
	if is_instance_valid(top_controls):
		top_controls.visible = false
	result = message
	powerups.finish()
	cancel_drag()
	hint.visible = false
	outcome.visible = true
	var result_label: Label = outcome.get_node("Center/Panel/Contents/Result")
	if message == "VICTORY":
		SoundManager.play_victory()
		var stars := 3 if elapsed <= 45.0 else (2 if elapsed <= 90.0 else 1)
		var is_daily := GameProgress.playing_daily_challenge
		var is_boss := bool(level_data.get("boss", false))
		var reward := 20
		last_victory_reward = reward
		double_coins_claimed = false
		if is_daily:
			MonetizationManager.mark_daily_challenge_completed()
			GameProgress.coins += reward
			GameProgress.save_progress()
		else:
			GameProgress.complete(level_number,stars,reward)
		MonetizationManager.on_level_completed(level_number)
		var header := "DAILY CHALLENGE COMPLETE!" if is_daily else ("BOSS LEVEL "+str(level_number)+" CLEARED!" if is_boss else "LEVEL "+str(level_number)+" COMPLETE")
		result_label.text = header
		outcome.get_node("Center/Panel/Contents/StarsRow").visible = true
		var reward_row: HBoxContainer = outcome.get_node("Center/Panel/Contents/RewardRow")
		reward_row.visible = true
		reward_row.get_node("Amount").text = "+" + str(reward) + " COINS"
		outcome.get_node("Center/Panel/Contents/NextLevel").visible = not is_daily
		var dbl_btn: Button = outcome.get_node("Center/Panel/Contents/DoubleCoins")
		dbl_btn.visible = true
		dbl_btn.disabled = false
		dbl_btn.text = "2X BONUS (+"+str(reward)+" COINS)"
		var rate_btn: Button = outcome.get_node("Center/Panel/Contents/RateGame")
		rate_btn.visible = MonetizationManager.should_prompt_rate(level_number)
		if rate_btn.visible:
			MonetizationManager.mark_rate_prompt_shown()
		play_victory_celebration(stars,reward)
	else:
		SoundManager.play_defeat()
		result_label.text = message
		outcome.get_node("Center/Panel/Contents/StarsRow").visible = false
		outcome.get_node("Center/Panel/Contents/RewardRow").visible = false
		outcome.modulate.a = 1.0
		if is_instance_valid(outcome_panel):
			outcome_panel.pivot_offset = outcome_panel.size * 0.5
			outcome_panel.scale = Vector2(0.42, 0.42)
			var otw := outcome_panel.create_tween()
			otw.tween_property(outcome_panel, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			otw.tween_property(outcome_panel, "scale", Vector2(0.98, 1.02), 0.09)
			otw.tween_property(outcome_panel, "scale", Vector2.ONE, 0.08)
	coin_label.text = str(GameProgress.coins)
	# Freeze unit motion, combat effects and production at the outcome.
	for node in [armies,ai]:
		node.process_mode = Node.PROCESS_MODE_DISABLED

func play_victory_celebration(stars: int, reward: int) -> void:
	outcome.modulate.a = 0.0
	var target = last_captured_nest if is_instance_valid(last_captured_nest) else nests[-1]
	for nest in nests:
		if nest.team == 1:
			var flag_tween := create_tween().set_loops(6)
			flag_tween.tween_property(nest.flag,"rotation:z",0.15,0.12)
			flag_tween.tween_property(nest.flag,"rotation:z",-0.15,0.12)
	for i in range(14):
		var ant = AntScene.instantiate()
		ant.team = 1
		ant.level = self
		effects.add_child(ant)
		var angle: float = i*TAU/14.0
		ant.global_position = target.global_position+Vector3(cos(angle)*3.8,0.06,sin(angle)*3.2)
		var destination: Vector3 = target.global_position+Vector3(cos(angle)*2.0,0.06,sin(angle)*1.8)
		ant.face(destination-ant.global_position)
		var tween := ant.create_tween()
		tween.tween_property(ant,"global_position",destination,0.75).set_delay(i*0.025)
		tween.tween_callback(func(): ant.attacking = true)
		var dance := ant.create_tween().set_loops(4)
		dance.tween_property(ant,"scale",Vector3.ONE*1.12,0.14)
		dance.tween_property(ant,"scale",Vector3.ONE*0.9,0.14)
	for i in range(stars*4):
		burst(target.global_position+Vector3.UP*(0.5+i*0.05),Color("ffe06c"),2)
	var coin_origin := camera.unproject_position(target.global_position+Vector3.UP*1.5)
	_spawn_flying_coins(coin_origin, mini(12, reward))
	var stars_row: HBoxContainer = outcome.get_node("Center/Panel/Contents/StarsRow")
	for i in range(3):
		var star_icon: TextureRect = stars_row.get_child(i)
		star_icon.pivot_offset = Vector2(28, 28)
		star_icon.scale = Vector2.ONE * 0.1
		star_icon.modulate = Color(0.35, 0.42, 0.38, 0.55) if i >= stars else Color.WHITE
	var reveal := create_tween()
	reveal.tween_interval(1.25)
	reveal.tween_property(outcome,"modulate:a",1.0,0.22)
	reveal.tween_callback(func():
		if is_instance_valid(outcome_panel):
			outcome_panel.pivot_offset = outcome_panel.size * 0.5
			outcome_panel.scale = Vector2(0.45, 0.45)
			var ptw := outcome_panel.create_tween()
			ptw.tween_property(outcome_panel, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			ptw.tween_property(outcome_panel, "scale", Vector2(0.98, 1.02), 0.09)
			ptw.tween_property(outcome_panel, "scale", Vector2.ONE, 0.08)
	)
	for i in range(3):
		var star_icon: TextureRect = stars_row.get_child(i)
		var earned := i < stars
		reveal.tween_callback(func():
			if earned:
				SoundManager.play_star()
			var stw := star_icon.create_tween()
			stw.tween_property(star_icon, "scale", Vector2.ONE * (1.28 if earned else 0.9), 0.18).set_trans(Tween.TRANS_BACK)
			stw.tween_property(star_icon, "scale", Vector2.ONE, 0.12)
		)
		reveal.tween_interval(0.18)

func _spawn_flying_coins(origin: Vector2, count: int) -> void:
	var dest: Vector2 = coin_label.global_position - Vector2(22, 6)
	for i in range(count):
		var coin := TextureRect.new()
		coin.texture = ICON_COIN
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(34, 34)
		coin.size = Vector2(34, 34)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var scatter := Vector2(rng.randf_range(-42, 42), rng.randf_range(-34, 24))
		coin.position = origin + scatter
		$HUD.add_child(coin)
		var tween := coin.create_tween()
		tween.tween_interval(i * 0.055)
		tween.tween_property(coin, "position", dest, 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if i % 3 == 0:
			tween.tween_callback(func(): SoundManager.play_coin())
		tween.tween_callback(coin.queue_free)

func restart() -> void:
	SoundManager.play_click()
	get_tree().reload_current_scene()

func next_level() -> void:
	SoundManager.play_click()
	GameProgress.current_level = level_number+1
	GameProgress.save_progress()
	get_tree().reload_current_scene()

func go_to_menu() -> void:
	SoundManager.play_click()
	GameProgress.playing_daily_challenge = false
	get_tree().change_scene_to_file("res://scenes/ant_colony/MainMenu.tscn")

func set_paused(value: bool) -> void:
	if not active:
		return
	cancel_drag()
	if is_instance_valid(settings_overlay):
		settings_overlay.visible = false
	SoundManager.play_click()
	if value:
		paused = true
		if is_instance_valid(pause_overlay):
			pause_overlay.visible = true
			if is_instance_valid(pause_card):
				pause_card.pivot_offset = pause_card.size * 0.5
				pause_card.scale = Vector2(0.42, 0.42)
				pause_card.modulate.a = 0.0
				var tw := pause_card.create_tween()
				tw.tween_property(pause_card, "modulate:a", 1.0, 0.12)
				tw.parallel().tween_property(pause_card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(pause_card, "scale", Vector2(0.98, 1.02), 0.09)
				tw.tween_property(pause_card, "scale", Vector2.ONE, 0.08)
	else:
		if is_instance_valid(pause_overlay) and is_instance_valid(pause_card) and pause_overlay.visible:
			pause_card.pivot_offset = pause_card.size * 0.5
			var tw := pause_card.create_tween()
			tw.tween_property(pause_card, "scale", Vector2(1.05, 1.05), 0.05)
			tw.tween_property(pause_card, "scale", Vector2(0.35, 0.35), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(pause_card, "modulate:a", 0.0, 0.13)
			tw.tween_callback(func():
				pause_overlay.visible = false
				pause_card.scale = Vector2.ONE
				pause_card.modulate.a = 1.0
				paused = false
			)
		else:
			if is_instance_valid(pause_overlay):
				pause_overlay.visible = false
			paused = false

func open_in_game_settings() -> void:
	if not active:
		return
	paused = true
	cancel_drag()
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = false
	_refresh_in_game_settings()
	if is_instance_valid(settings_overlay):
		settings_overlay.visible = true
		if is_instance_valid(settings_card):
			settings_card.pivot_offset = settings_card.size * 0.5
			settings_card.scale = Vector2(0.42, 0.42)
			settings_card.modulate.a = 0.0
			var tw := settings_card.create_tween()
			tw.tween_property(settings_card, "modulate:a", 1.0, 0.12)
			tw.parallel().tween_property(settings_card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(settings_card, "scale", Vector2(0.98, 1.02), 0.09)
			tw.tween_property(settings_card, "scale", Vector2.ONE, 0.08)
	SoundManager.play_click()

func close_in_game_settings() -> void:
	SoundManager.play_click()
	if is_instance_valid(settings_overlay) and is_instance_valid(settings_card):
		settings_card.pivot_offset = settings_card.size * 0.5
		var tw := settings_card.create_tween()
		tw.tween_property(settings_card, "scale", Vector2(1.05, 1.05), 0.05)
		tw.tween_property(settings_card, "scale", Vector2(0.35, 0.35), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(settings_card, "modulate:a", 0.0, 0.13)
		tw.tween_callback(func():
			settings_overlay.visible = false
			settings_card.scale = Vector2.ONE
			settings_card.modulate.a = 1.0
			paused = false
		)
	else:
		if is_instance_valid(settings_overlay):
			settings_overlay.visible = false
		paused = false

func _refresh_in_game_settings() -> void:
	_set_in_game_switch(switch_music_knob, switch_music_bg, not SoundManager.music_muted)
	_set_in_game_switch(switch_sfx_knob, switch_sfx_bg, not SoundManager.muted)
	_set_in_game_switch(switch_send_knob, switch_send_bg, send_ratio > 0.9)

func _set_in_game_switch(knob: PanelContainer, bg: StyleBoxFlat, is_on: bool) -> void:
	if not is_instance_valid(knob) or bg == null:
		return
	bg.bg_color = Color("38c159") if is_on else Color("4a5d6b")
	var tw := knob.create_tween()
	tw.tween_property(knob, "position:x", 41.0 if is_on else 5.0, 0.12).set_trans(Tween.TRANS_QUAD)

func toggle_send_ratio() -> void:
	send_ratio = 1.0 if send_ratio < 0.9 else 0.5
	SoundManager.play_click()
	if is_instance_valid(send_btn):
		send_btn.text = "SEND: 100%" if send_ratio > 0.9 else "SEND: 50%"
	hint.text = "Drag from a blue nest to send ALL ants!" if send_ratio > 0.9 else "Drag from a blue nest to send half your ants"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and active:
		set_paused(not paused)

func _is_over_top_controls(screen: Vector2) -> bool:
	return is_instance_valid(top_controls) and top_controls.visible and top_controls.get_global_rect().has_point(screen)

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if dragging or powerups.pending != "":
			cancel_drag()
			powerups.pending = ""
			powerups.refresh_buttons()
		else:
			set_paused(not paused)
		return
	if paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			if powerups.is_over_controls(event.position) or _is_over_top_controls(event.position):
				return
			touch_id = event.index
			begin_drag(event.position)
		elif not event.pressed and event.index == touch_id:
			end_drag(event.position)
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id:
		pointer = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION or touch_id != -1:
			return
		if event.pressed:
			if powerups.is_over_controls(event.position) or _is_over_top_controls(event.position):
				return
			begin_drag(event.position)
		else:
			end_drag(event.position)
	elif event is InputEventMouseMotion and touch_id == -1:
		pointer = event.position

func pick_nest(screen: Vector2):
	var best = null
	var best_distance := 1.5
	var point := ground_point(screen)
	for nest in nests:
		var distance: float = nest.global_position.distance_to(point)
		# Include the visible mound and population label in the touch target.
		if nest.screen_label.get_global_rect().has_point(screen):
			return nest
		if distance < best_distance:
			best_distance = distance
			best = nest
	return best

func ground_point(screen: Vector2) -> Vector3:
	var hit = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	return hit if hit != null else Vector3.ZERO

func begin_drag(screen: Vector2) -> void:
	if powerups.pending != "":
		powerups.target(screen)
		return
	cancel_drag()
	pointer = screen
	var nest = pick_nest(screen)
	if nest != null and nest.team == 1:
		selected = nest
		selected.selected = true
		dragging = true
		hint.text = "Drag to a connected nest • Send half your ants"
		update_targeting()

func end_drag(screen: Vector2) -> void:
	if dragging and selected != null:
		var destination = pick_nest(screen)
		if destination != null and destination != selected:
			var sent = deploy(selected,destination)
			if sent == null:
				hint.text = "Use a connected route and at least 2 ants"
			else:
				hint.text = "Army marching • Capture and reinforce connected nests"
	cancel_drag()

func cancel_drag() -> void:
	dragging = false
	if selected != null:
		selected.selected = false
	selected = null
	if is_instance_valid(targeting):
		targeting.queue_free()
	targeting = null

func update_targeting() -> void:
	if is_instance_valid(targeting):
		targeting.free()
	targeting = null
	var destination = pick_nest(pointer)
	var valid: bool = destination != null and destination in selected.links and selected.team == 1
	var end: Vector3 = destination.global_position if destination != null else ground_point(pointer)
	targeting = segment($Paths,selected.global_position+Vector3.UP*0.2,end+Vector3.UP*0.2,0.055,Color("b7f58a") if valid else Color("edcf80"))

func _update_timer_hud() -> void:
	if not is_instance_valid(timer_label):
		return
	var secs := int(elapsed)
	var mins := secs / 60
	var rem := secs % 60
	timer_label.text = "%02d:%02d" % [mins, rem]
	var pace_stars := 3 if elapsed <= 45.0 else (2 if elapsed <= 90.0 else 1)
	for i in range(hud_star_icons.size()):
		var raw_ic = hud_star_icons[i]
		if is_instance_valid(raw_ic):
			var ic: TextureRect = raw_ic
			ic.modulate = Color.WHITE if i < pace_stars else Color(0.35, 0.42, 0.38, 0.45)

func _hud_pill(text: String, fg: Color, border: Color, font_size: int = 18, use_title_font: bool = false, icon_tex: Texture2D = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.12, 0.08, 0.88)
	s.border_color = border.darkened(0.22)
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.content_margin_left = 12
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon_tex != null:
		var ic := TextureRect.new()
		ic.texture = icon_tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(22, 22)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var l := Label.new()
	l.name = "Text"
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", TitleFont)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", fg)
	l.add_theme_color_override("font_outline_color", Color("09161e"))
	l.add_theme_constant_override("outline_size", 5)
	row.add_child(l)
	return p

func build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(root)
	var biome_name: String = ["Forest Colony","Mushroom Grove","Autumn Woodland","Rocky Creek","Ancient Root Hollow","Sandy Garden"][level_data.biome]
	var is_boss := bool(level_data.get("boss", false))

	# --- Kitty Hunt Style Translucent Upper HUD Bar ---
	top_hud_bar = HBoxContainer.new()
	top_hud_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_hud_bar.offset_left = 16
	top_hud_bar.offset_right = -16
	top_hud_bar.offset_top = 10
	top_hud_bar.offset_bottom = 58
	top_hud_bar.add_theme_constant_override("separation", 10)
	top_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_hud_bar)

	var coins_pill := _hud_pill(str(GameProgress.coins), Color("ffd85c"), Color("ffd85c"), 20, false, ICON_COIN)
	coin_label = coins_pill.get_node("Row/Text")
	top_hud_bar.add_child(coins_pill)

	var timer_pill := _hud_pill("00:00", Color("d8f7dd"), Color("6bd988"), 17, false, ICON_CLOCK)
	timer_label = timer_pill.get_node("Row/Text")
	var timer_row: HBoxContainer = timer_pill.get_node("Row")
	hud_star_icons.clear()
	for i in range(3):
		var st := TextureRect.new()
		st.texture = ICON_STAR
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.custom_minimum_size = Vector2(20, 20)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timer_row.add_child(st)
		hud_star_icons.append(st)
	top_hud_bar.add_child(timer_pill)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hud_bar.add_child(left_spacer)

	var is_daily := GameProgress.playing_daily_challenge
	var title_text := ("DAILY CHALLENGE  •  " + biome_name.to_upper()) if is_daily else (("BOSS " if is_boss else "LVL ") + str(level_number) + "  •  " + biome_name.to_upper())
	var title_pill := _hud_pill(
		title_text,
		Color("ffd85c") if is_daily else (Color("ff9e5e") if is_boss else Color("fff3cd")),
		Color("ffd85c") if is_daily else (Color("ff7a45") if is_boss else Color("8ce39e")),
		20,
		true
	)
	top_hud_bar.add_child(title_pill)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hud_bar.add_child(right_spacer)

	top_controls = HBoxContainer.new()
	top_controls.add_theme_constant_override("separation", 8)
	top_hud_bar.add_child(top_controls)

	send_btn = _hud_button("SEND: 100%" if send_ratio > 0.9 else "SEND: 50%", Color("1f4c36"), Color("9bf5b8"), 118)
	send_btn.pressed.connect(toggle_send_ratio)
	top_controls.add_child(send_btn)
	var settings_btn := _hud_button("", Color("233f52"), Color("d4eeff"), 46, ICON_SETTINGS)
	settings_btn.tooltip_text = "Settings"
	settings_btn.pressed.connect(open_in_game_settings)
	top_controls.add_child(settings_btn)
	var pause_btn := _hud_button("", Color("3d3522"), Color("ffd85c"), 46, ICON_PAUSE)
	pause_btn.tooltip_text = "Pause"
	pause_btn.pressed.connect(func(): set_paused(true))
	top_controls.add_child(pause_btn)

	hint = Label.new()
	hint.text = "Drag from a blue nest to send ALL ants!" if send_ratio > 0.9 else "Drag from a blue nest to a connected nest • Send half your ants"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", UiFont)
	hint.add_theme_font_size_override("font_size",17)
	hint.add_theme_color_override("font_color",Color("fff3cd"))
	hint.add_theme_color_override("font_outline_color",Color("263a2b"))
	hint.add_theme_constant_override("outline_size",6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.position.y = 64
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	hint.offset_left = 0
	hint.offset_right = 0
	notice = Label.new()
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_override("font", TitleFont)
	notice.add_theme_font_size_override("font_size",25)
	notice.add_theme_color_override("font_color",Color("ffcf8d"))
	notice.add_theme_color_override("font_outline_color",Color("412c24"))
	notice.add_theme_constant_override("outline_size",8)
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice.position.y = 94
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice)
	notice.offset_left = 0
	notice.offset_right = 0
	if is_boss:
		notice.text = "QUEEN'S STRONGHOLD  •  2X COIN REWARD!"
		notice.modulate.a = 1.0
		var boss_tw := create_tween()
		boss_tw.tween_interval(3.4)
		boss_tw.tween_property(notice, "modulate:a", 0.0, 0.6)
	outcome = Control.new()
	outcome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(outcome)
	var shade := ColorRect.new()
	shade.color = Color(0.03,0.09,0.05,0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	outcome_panel = panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color("184566")
	style.border_color = Color("0b1d2c")
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 54
	style.content_margin_right = 54
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var contents := VBoxContainer.new()
	contents.name = "Contents"
	contents.add_theme_constant_override("separation",24)
	panel.add_child(contents)
	var result_label := Label.new()
	result_label.name = "Result"
	result_label.add_theme_font_override("font", TitleFont)
	result_label.add_theme_font_size_override("font_size",42)
	result_label.add_theme_color_override("font_color", Color("fff2b8"))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(result_label)
	var stars_row := HBoxContainer.new()
	stars_row.name = "StarsRow"
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 14)
	for i in range(3):
		var s_ic := TextureRect.new()
		s_ic.texture = ICON_STAR
		s_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s_ic.custom_minimum_size = Vector2(56, 56)
		stars_row.add_child(s_ic)
	contents.add_child(stars_row)
	var reward_row := HBoxContainer.new()
	reward_row.name = "RewardRow"
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 10)
	var c_ic := TextureRect.new()
	c_ic.texture = ICON_COIN
	c_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_ic.custom_minimum_size = Vector2(34, 34)
	reward_row.add_child(c_ic)
	var amt_lbl := Label.new()
	amt_lbl.name = "Amount"
	amt_lbl.text = "+20 COINS"
	amt_lbl.add_theme_font_override("font", UiFont)
	amt_lbl.add_theme_font_size_override("font_size", 28)
	amt_lbl.add_theme_color_override("font_color", Color("ffd85c"))
	reward_row.add_child(amt_lbl)
	contents.add_child(reward_row)
	var button := _hud_button("RESTART", Color("2b5241"), Color("fff2b8"), 260)
	button.custom_minimum_size = Vector2(260,54)
	button.add_theme_font_size_override("font_size",22)
	button.pressed.connect(restart)
	contents.add_child(button)
	var next_button := _hud_button("NEXT LEVEL", Color("2b8a4e"), Color("ffffff"), 260)
	next_button.name = "NextLevel"
	next_button.custom_minimum_size = Vector2(260,56)
	next_button.add_theme_font_size_override("font_size",24)
	next_button.pressed.connect(next_level)
	next_button.visible = false
	contents.add_child(next_button)
	var double_button := _hud_button("2X BONUS COINS", Color("6e4f16"), Color("ffe58a"), 260)
	double_button.name = "DoubleCoins"
	double_button.custom_minimum_size = Vector2(260, 50)
	double_button.visible = false
	double_button.pressed.connect(func():
		if double_coins_claimed or last_victory_reward <= 0:
			return
		MonetizationManager.show_rewarded_bonus(func():
			double_coins_claimed = true
			GameProgress.coins += last_victory_reward
			GameProgress.save_progress()
			SoundManager.play_coin()
			_spawn_flying_coins(double_button.global_position + double_button.size * 0.5, 8)
			coin_label.text = str(GameProgress.coins)
			double_button.text = "2X BONUS CLAIMED!"
			double_button.disabled = true
		)
	)
	contents.add_child(double_button)
	var rate_button := _hud_button("ENJOYING IT? RATE US ★", Color("2a4c6e"), Color("d2eeff"), 260)
	rate_button.name = "RateGame"
	rate_button.custom_minimum_size = Vector2(260, 46)
	rate_button.visible = false
	rate_button.pressed.connect(func():
		SoundManager.play_click()
		MonetizationManager.open_play_store_rate()
		rate_button.visible = false
	)
	contents.add_child(rate_button)
	var menu_button := _hud_button("MAIN MENU", Color("233f34"), Color("d7f5dc"), 260)
	menu_button.custom_minimum_size = Vector2(260,50)
	menu_button.add_theme_font_size_override("font_size",20)
	menu_button.pressed.connect(go_to_menu)
	contents.add_child(menu_button)
	outcome.visible = false
	_build_pause_overlay(root)

func _hud_button(text: String, bg: Color, fg: Color, width: float, icon_tex: Texture2D = null) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, 44)
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 26)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_override("font", TitleFont)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_outline_color", Color("081822"))
	btn.add_theme_constant_override("outline_size", 6)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("0c1c26")
	style.set_border_width_all(3)
	style.border_width_bottom = 6
	style.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.14)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.91, 0.91), 0.06)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.09)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	return btn

func _build_pause_overlay(root: Control) -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	root.add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.05, 0.08, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(center)

	var card_size := Vector2(420, 340)
	pause_card = Control.new()
	pause_card.custom_minimum_size = card_size
	pause_card.size = card_size
	pause_card.pivot_offset = card_size * 0.5
	center.add_child(pause_card)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("184566")
	style.border_color = Color("0b1d2c")
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 42
	style.content_margin_right = 42
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	pause_card.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var lbl := Label.new()
	lbl.text = "Paused"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", TitleFont)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color("ffffff"))
	lbl.add_theme_color_override("font_outline_color", Color("0a1824"))
	lbl.add_theme_constant_override("outline_size", 9)
	box.add_child(lbl)
	var resume_btn := _hud_button("RESUME", Color("7ed321"), Color("ffffff"), 240)
	resume_btn.custom_minimum_size = Vector2(240, 52)
	resume_btn.pressed.connect(func(): set_paused(false))
	box.add_child(resume_btn)
	var restart_btn := _hud_button("RESTART LEVEL", Color("19b5cc"), Color("ffffff"), 240)
	restart_btn.custom_minimum_size = Vector2(240, 48)
	restart_btn.pressed.connect(restart)
	box.add_child(restart_btn)
	var levels_btn := _hud_button("MAIN MENU", Color("19b5cc"), Color("ffffff"), 240)
	levels_btn.custom_minimum_size = Vector2(240, 48)
	levels_btn.pressed.connect(go_to_menu)
	box.add_child(levels_btn)
	var close_x := Button.new()
	close_x.text = "✖"
	close_x.size = Vector2(44, 44)
	close_x.position = Vector2(card_size.x - 26, -16)
	close_x.add_theme_font_override("font", TitleFont)
	close_x.add_theme_font_size_override("font_size", 22)
	close_x.add_theme_color_override("font_color", Color("ffffff"))
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("e83b3b")
	cs.border_color = Color("1a0808")
	cs.set_border_width_all(3)
	cs.border_width_bottom = 5
	cs.set_corner_radius_all(10)
	close_x.add_theme_stylebox_override("normal", cs)
	close_x.add_theme_stylebox_override("hover", cs)
	close_x.add_theme_stylebox_override("pressed", cs)
	close_x.pressed.connect(func(): set_paused(false))
	pause_card.add_child(close_x)
	_build_in_game_settings_overlay(root)

func _build_in_game_settings_overlay(root: Control) -> void:
	settings_overlay = Control.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	root.add_child(settings_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.05, 0.08, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)

	var card_size := Vector2(680, 410)
	settings_card = Control.new()
	settings_card.custom_minimum_size = card_size
	settings_card.size = card_size
	settings_card.pivot_offset = card_size * 0.5
	center.add_child(settings_card)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("184566")
	style.border_color = Color("0b1d2c")
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	settings_card.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var lbl := Label.new()
	lbl.text = "Settings"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", TitleFont)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color("ffffff"))
	lbl.add_theme_color_override("font_outline_color", Color("0a1824"))
	lbl.add_theme_constant_override("outline_size", 9)
	box.add_child(lbl)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 28)
	box.add_child(cols)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 16)
	cols.add_child(left_col)

	var m_sw := _in_game_switch_row("Music", func():
		SoundManager.toggle_music()
		_refresh_in_game_settings()
	)
	switch_music_knob = m_sw.knob
	switch_music_bg = m_sw.bg
	left_col.add_child(m_sw.row)

	var s_sw := _in_game_switch_row("Sound FX", func():
		SoundManager.toggle_mute()
		_refresh_in_game_settings()
	)
	switch_sfx_knob = s_sw.knob
	switch_sfx_bg = s_sw.bg
	left_col.add_child(s_sw.row)

	var a_sw := _in_game_switch_row("Send 100%", func():
		toggle_send_ratio()
		GameProgress.default_send_all = send_ratio > 0.9
		GameProgress.save_progress()
		_refresh_in_game_settings()
	)
	switch_send_knob = a_sw.knob
	switch_send_bg = a_sw.bg
	left_col.add_child(a_sw.row)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 14)
	cols.add_child(right_col)

	var resume_b := _hud_button("RESUME BATTLE", Color("7ed321"), Color("ffffff"), 240)
	resume_b.custom_minimum_size = Vector2(240, 52)
	resume_b.pressed.connect(close_in_game_settings)
	right_col.add_child(resume_b)

	var restart_b := _hud_button("RESTART LEVEL", Color("19b5cc"), Color("ffffff"), 240)
	restart_b.custom_minimum_size = Vector2(240, 48)
	restart_b.pressed.connect(restart)
	right_col.add_child(restart_b)

	var menu_b := _hud_button("MAIN MENU", Color("19b5cc"), Color("ffffff"), 240)
	menu_b.custom_minimum_size = Vector2(240, 48)
	menu_b.pressed.connect(go_to_menu)
	right_col.add_child(menu_b)

	var close_x := Button.new()
	close_x.text = "✖"
	close_x.size = Vector2(46, 46)
	close_x.position = Vector2(card_size.x - 28, -18)
	close_x.add_theme_font_override("font", TitleFont)
	close_x.add_theme_font_size_override("font_size", 24)
	close_x.add_theme_color_override("font_color", Color("ffffff"))
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("e83b3b")
	cs.border_color = Color("1a0808")
	cs.set_border_width_all(3)
	cs.border_width_bottom = 5
	cs.set_corner_radius_all(10)
	close_x.add_theme_stylebox_override("normal", cs)
	close_x.add_theme_stylebox_override("hover", cs)
	close_x.add_theme_stylebox_override("pressed", cs)
	close_x.pressed.connect(close_in_game_settings)
	settings_card.add_child(close_x)

func _in_game_switch_row(label_text: String, on_toggle: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", TitleFont)
	lbl.add_theme_font_size_override("font_size", 23)
	lbl.add_theme_color_override("font_color", Color("ffffff"))
	lbl.add_theme_color_override("font_outline_color", Color("0c1c26"))
	lbl.add_theme_constant_override("outline_size", 6)
	row.add_child(lbl)
	var track := Button.new()
	track.custom_minimum_size = Vector2(74, 36)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("38c159")
	bg.border_color = Color("0c1c26")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(18)
	track.add_theme_stylebox_override("normal", bg)
	track.add_theme_stylebox_override("hover", bg)
	track.add_theme_stylebox_override("pressed", bg)
	track.pressed.connect(on_toggle)
	row.add_child(track)
	var knob := PanelContainer.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.size = Vector2(28, 28)
	knob.position = Vector2(40, 4)
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color("ffffff")
	ks.border_color = Color("0c1c26")
	ks.set_border_width_all(2)
	ks.set_corner_radius_all(14)
	knob.add_theme_stylebox_override("panel", ks)
	track.add_child(knob)
	return {"row": row, "knob": knob, "bg": bg}

func team_color(team: int) -> Color:
	return [Color("d5bc82"),Color("439af0"),Color("e55c4b")][team]

func mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not material_cache.has(key):
		material_cache[key] = AntVisual.material(color)
	return material_cache[key]

func sphere(parent: Node, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.position = pos
	node.scale = dimensions
	node.material_override = mat(color)
	parent.add_child(node)
	return node

func segment(parent: Node, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(0.001,a.distance_to(b))
	mesh.radial_segments = 8
	node.mesh = mesh
	node.position = (a+b)*0.5
	var direction := b-a
	if direction.length_squared() > 0.0001:
		node.quaternion = Quaternion(Vector3.UP,direction.normalized())
	node.material_override = mat(color)
	parent.add_child(node)
	return node

func burst(pos: Vector3, color: Color, count: int) -> void:
	for i in range(count):
		var particle := sphere(effects,pos,Vector3.ONE*0.07,color)
		var offset := Vector3(rng.randf_range(-0.6,0.6),rng.randf_range(0.2,0.8),rng.randf_range(-0.6,0.6))
		var tween := particle.create_tween().set_parallel(true)
		tween.tween_property(particle,"position",pos+offset,0.4)
		tween.tween_property(particle,"scale",Vector3.ONE*0.001,0.45)
		tween.chain().tween_callback(particle.queue_free)

func smoke(pos: Vector3, team: int, large: bool = false) -> void:
	# Soft procedural smoke; each victim keeps its own colony's death color.
	var count := 10 if large else 5
	var spread := 1.1 if large else 0.45
	for i in range(count):
		var puff := MeshInstance3D.new()
		puff.name = "BlueSmoke" if team == 1 else ("RedSmoke" if team == 2 else "NeutralSmoke")
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE*(1.3 if large else 0.75)
		puff.mesh = quad
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.quaternion = camera.global_basis.get_rotation_quaternion()
		puff.position = pos+Vector3(rng.randf_range(-spread,spread)*0.3,0.15,rng.randf_range(-spread,spread)*0.3)
		puff.scale = Vector3.ONE*0.45
		var material := ShaderMaterial.new()
		material.shader = SmokeShader
		material.render_priority = 3
		material.set_shader_parameter("smoke_color",team_color(team))
		material.set_shader_parameter("opacity",0.8)
		puff.material_override = material
		effects.add_child(puff)
		var destination := puff.position+Vector3(rng.randf_range(-spread,spread),rng.randf_range(0.45,1.05),rng.randf_range(-spread,spread)*0.5)
		var tween := puff.create_tween().set_parallel(true)
		tween.tween_property(puff,"position",destination,0.75)
		tween.tween_property(puff,"scale",Vector3.ONE*1.5,0.75)
		tween.tween_property(material,"shader_parameter/opacity",0.0,0.75)
		tween.chain().tween_callback(puff.queue_free)

func build_ambience() -> void:
	var ambience := Node3D.new()
	ambience.name = "AmbientLife"
	$EnvironmentProps.add_child(ambience)
	for i in range(20):
		var item := Node3D.new()
		item.name = ("Firefly" if i < 12 else "DriftingLeaf")+str(i)
		ambience.add_child(item)
		var base := Vector3(rng.randf_range(-11,11),rng.randf_range(0.6,2.6),rng.randf_range(-6.2,5.5))
		item.position = base
		if i < 12:
			var glow := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE*0.24
			glow.mesh = quad
			glow.quaternion = camera.global_basis.get_rotation_quaternion()
			var material := ShaderMaterial.new()
			material.shader = SmokeShader
			material.set_shader_parameter("smoke_color",Color("ffe8a0"))
			material.set_shader_parameter("opacity",0.9)
			glow.material_override = material
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.add_child(glow)
			sphere(item,Vector3.ZERO,Vector3.ONE*0.022,Color("fff4c2"))
		else:
			# A small leaf silhouette, with a central vein, rather than a rectangle.
			var mesh := ImmediateMesh.new()
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			var perimeter := [Vector3(0,0,-0.25),Vector3(0.10,0,-0.12),Vector3(0.12,0,0.05),Vector3(0,0,0.25),Vector3(-0.10,0,0.12),Vector3(-0.12,0,-0.05)]
			for j in range(perimeter.size()):
				mesh.surface_add_vertex(Vector3.ZERO)
				mesh.surface_add_vertex(perimeter[j])
				mesh.surface_add_vertex(perimeter[(j+1)%perimeter.size()])
			mesh.surface_end()
			var leaf := MeshInstance3D.new()
			leaf.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("b2c35a") if i%2 == 0 else Color("d4a853")
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			leaf.material_override = material
			item.add_child(leaf)
			segment(item,Vector3(0,0.005,-0.21),Vector3(0,0.005,0.24),0.007,Color("778644"))
		ambient_items.append({"node":item,"base":base,"phase":float(i)*1.7,"firefly":i<12})

func update_ambience(delta: float) -> void:
	ambient_clock += delta
	for entry in ambient_items:
		var node: Node3D = entry.node
		var t: float = ambient_clock+entry.phase
		if entry.firefly:
			node.position = entry.base+Vector3(sin(t*0.55)*0.8,sin(t*1.3)*0.22,cos(t*0.43)*0.55)
			node.scale = Vector3.ONE*(0.65+0.35*pow(sin(t*1.8)*0.5+0.5,2))
		else:
			node.position = entry.base+Vector3(sin(t*0.19)*1.5,sin(t*0.7)*0.35,cos(t*0.16)*0.6)
			node.rotation = Vector3(sin(t*0.9)*0.35,t*0.25,sin(t*0.8)*0.4)
