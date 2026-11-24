extends SceneTree
## Integration checks run against the actual Level1 scene and input handlers.
var level
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

func load_level() -> void:
	root.get_node("GameProgress").current_level = 1
	change_scene_to_file("res://scenes/ant_colony/Level1.tscn")
	await process_frame
	await process_frame
	level = current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED

func tick(seconds: float) -> void:
	for i in range(int(ceil(seconds/0.05))):
		if not level.active:
			return
		for nest in level.nests:
			nest._process(0.05)
		level.ai._process(0.05)
		for army in level.armies.get_children():
			army._process(0.05)
		level._process(0.05)

func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	level._input(event)

func run() -> void:
	await load_level()
	verify(level.nests.size() == 2,"Level 1 has exactly two nests")
	var a = level.nests[0]
	var b = level.nests[1]
	verify(a.team == 1 and a.population == 35 and b.team == 2 and b.population == 12,"Beginner starting ownership and populations")
	verify(a.links == [b] and b.links == [a],"One bidirectional route connects both nests")
	verify(level.forest_backdrop.material_override.albedo_texture != null,"Forest background is loaded")
	verify(a.mound is Sprite3D and a.mound.texture != null,"Nest uses the reusable PNG artwork")
	verify(level.get_node("Paths").get_child(0).material_override.albedo_texture != null,"Route uses the separate dirt-path texture")
	var nest_image: Image = a.mound.texture.get_image()
	verify(nest_image.get_pixel(0,0).a == 0.0,"Nest cutout has genuine transparent pixels")
	var blue_ant = a.residents.get_child(0)
	var red_ant = b.residents.get_child(0)
	verify(blue_ant.body is Sprite3D and red_ant.body is Sprite3D,"Ants use flat sprites rather than primitive models")
	verify(blue_ant.body.texture.resource_path.ends_with("ant-blue.png") and red_ant.body.texture.resource_path.ends_with("ant-red.png"),"Player uses blue sprite and enemy uses red sprite")
	var resting_position: Vector3 = blue_ant.body.position
	blue_ant.last_world_position = blue_ant.global_position
	blue_ant._process(0.5)
	verify(blue_ant.body.position == resting_position,"Idle ant rests without sliding its feet")
	var resting_phase: float = blue_ant.phase
	blue_ant.position.x += 0.1
	blue_ant._process(0.1)
	verify(blue_ant.phase > resting_phase and blue_ant.gait_strength > 0.5,"Moving ant animates a distance-driven walking gait")
	verify(a.screen_label is Label and a.screen_label.text == "A  35","Population uses a complete screen-space label")
	verify(level.powerups.buttons.size() == 4,"Four power-up controls are available")
	verify(level.powerups.buttons["sugar"].icon != null and level.powerups.buttons["honey"].icon != null,"Power-up controls use image icons")
	level.powerups.activate("sugar")
	verify(level.powerups.charges["sugar"] == 0 and level.powerups.sugar_until == 8.0,"Sugar Rush activates for eight seconds")
	level.powerups.activate("rally")
	var before_rally: int = a.population
	level.powerups.target(level.camera.unproject_position(a.global_position))
	verify(a.population == before_rally+8,"Royal Rally adds eight ants")
	level.powerups.activate("shield")
	level.powerups.target(level.camera.unproject_position(a.global_position))
	verify(a.shield_hits == 5,"Leaf Shield prepares five blocks")
	level.powerups.activate("honey")
	level.powerups.target(level.camera.unproject_position((a.global_position+b.global_position)*0.5))
	verify(level.powerups.honey_patches.size() == 1,"Sticky Honey targets the connected path")
	a.population = 35
	a.shield_hits = 0
	a.refresh()
	var start_patrol: Vector3 = blue_ant.position
	a.update_garrison(0.5)
	verify(blue_ant.position.distance_to(start_patrol) > 0.05,"Resident ants patrol around their nest")
	if "--capture" in OS.get_cmdline_user_args():
		level.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ant_colony/level1-two-nests.png")
		level.deploy(a,b)
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ant_colony/level1-assets-marching.png")
		await create_timer(3.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ant_colony/level1-assets-combat.png")
		level.smoke(Vector3(-2.5,0.4,3),1,true)
		level.smoke(Vector3(2.5,0.4,3),2,true)
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ant_colony/team-smoke.png")
		a.population = 100
		b.population = 88
		a.refresh()
		b.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ant_colony/count-legibility.png")
		quit()
		return
	var screen_a: Vector2 = level.camera.unproject_position(a.global_position)
	var screen_b: Vector2 = level.camera.unproject_position(b.global_position)
	mouse(level.camera.unproject_position(a.label.global_position),true)
	verify(level.dragging and a.selected,"Population label remains a selectable touch target")
	level.cancel_drag()
	mouse(screen_a,true)
	verify(level.dragging and a.selected,"Mouse selects player nest")
	mouse(screen_b,false)
	verify(a.population == 18 and level.armies.get_child_count() == 1,"Mouse drag deploys half")
	var army = level.armies.get_child(0)
	army.progress = 0.6
	b.update_garrison(0.5)
	verify(b.alerted,"Defenders prepare when a hostile army approaches")
	var blue_effects_before: int = level.effects.get_child_count()
	level.smoke(a.global_position,1)
	level.smoke(b.global_position,2)
	verify(level.effects.get_child_count() == blue_effects_before+10,"Both blue and red smoke spawn")
	army.progress = 0.0
	army._process(1.0)
	verify(army.progress > 0 and army.progress < 1,"Army physically marches along the route")
	verify(level.deploy(b,a) == null,"Player cannot deploy enemy ants")
	for i in range(100):
		tick(0.1)
		await process_frame
	verify(not level.active and level.result == "VICTORY" and b.team == 1,"Capturing the second nest wins Level 1")
	level.outcome.get_node("Center/Panel/Contents").get_child(1).pressed.emit()
	await process_frame
	await process_frame
	level = current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED
	a = level.nests[0]
	b = level.nests[1]
	verify(level.active and level.nests.size() == 2 and a.population == 35 and b.population == 12,"Restart resets the two-nest level")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = screen_a
	touch.pressed = true
	level._input(touch)
	verify(level.dragging,"Touch selects the player nest")
	touch.position = screen_b
	touch.pressed = false
	level._input(touch)
	verify(a.population == 18,"Touch release deploys half")
	await load_level()
	a = level.nests[0]
	b = level.nests[1]
	for i in range(5):
		tick(5.0)
	verify(level.armies.get_child_count() > 0 and level.armies.get_child(0).team == 2,"Starting enemy launches a controlled raid")
	await load_level()
	a = level.nests[0]
	b = level.nests[1]
	b.population = 100
	level.ai._process(5.01)
	verify(level.armies.get_child_count() == 1 and b.population == 50,"Enemy AI attacks while keeping a reserve")
	level.elapsed = 59.9
	level._process(0.2)
	verify(level.wave_done and b.population == 58,"Single reinforcement wave remains functional")
	level._process(0.2)
	verify(b.population == 58,"Reinforcement is not repeated")
	a.capture(2,5)
	level.check_outcome()
	verify(not level.active and level.result == "DEFEAT","Losing both nests triggers defeat")
	print("LEVEL1 CHECKS: ",checks,"; FAILURES: ",failures.size())
	quit(0 if failures.is_empty() else 1)
