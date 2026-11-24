extends SceneTree
var failures: Array[String] = []
var checks := 0

func verify(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var generator = preload("res://scripts/ant_colony/LevelGenerator.gd")
	var expected := {1:2,2:3,5:4,8:5,12:6,50:8}
	for level_number in expected:
		var data: Dictionary = generator.generate(level_number)
		verify(data.positions.size() == expected[level_number],"Level "+str(level_number)+" has "+str(expected[level_number])+" nests")
		verify(data.edges.size() >= data.positions.size()-1,"Level "+str(level_number)+" has a connected route backbone")
		for edge in data.edges:
			verify(edge[0] >= 0 and edge[1] < data.positions.size() and edge[0] != edge[1],"Level "+str(level_number)+" route endpoints are valid")
	var level5: Dictionary = generator.generate(5)
	verify(level5.strongholds.any(func(value): return value),"Level 5 introduces a stronghold")
	var level8: Dictionary = generator.generate(8)
	verify(level8.armored.reduce(func(total,value): return total+value,0) > 0,"Level 8 introduces armored defenders")
	verify(generator.generate(8) == level8,"Generation is deterministic for a level number")
	var progress = root.get_node("GameProgress")
	progress.current_level = 8
	change_scene_to_file("res://scenes/ant_colony/Level1.tscn")
	await process_frame
	await process_frame
	var game = current_scene
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var armored_nest = null
	for nest in game.nests:
		if nest.armored_population > 0:
			armored_nest = nest
			break
	verify(armored_nest != null and armored_nest.stronghold,"Generated Level 8 visibly combines armor and a stronghold")
	if "--capture" in OS.get_cmdline_user_args():
		game.process_mode = Node.PROCESS_MODE_INHERIT
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ant_colony/level8-stronghold.png")
		game.process_mode = Node.PROCESS_MODE_DISABLED
	var initial_armor: int = armored_nest.armored_population
	var attacker = preload("res://scenes/ant_colony/Army.tscn").instantiate()
	attacker.level = game
	attacker.source = game.nests[0]
	attacker.target = armored_nest
	attacker.team = 1
	attacker.strength = 4
	game.armies.add_child(attacker)
	attacker.arrived = true
	attacker.progress = 1.0
	attacker._process(0.14)
	verify(armored_nest.armored_population == initial_armor and armored_nest.armored_damage == 1,"First normal attacker damages but does not defeat armored defender")
	attacker._process(0.14)
	verify(armored_nest.armored_population == initial_armor-1 and armored_nest.armored_damage == 0,"Second normal attacker defeats armored defender")
	progress.current_level = 1
	print("PROGRESSION CHECKS: ",checks,"; FAILURES: ",failures.size())
	quit(0 if failures.is_empty() else 1)
