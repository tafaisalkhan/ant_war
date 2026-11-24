extends Node3D
const AntScene = preload("res://scenes/ant_colony/Ant.tscn")
var level
var source
var target
var team := 1
var strength := 0
var armored_strength := 0
var armored_damage := 0
var start: Vector3
var finish: Vector3
var progress := 0.0
var speed := 2.2
var arrived := false
var resolved := false
var combat_clock := 0.0
var visuals: Array = []
var direction: Vector3

func total_units() -> int:
	return strength + armored_strength

func _ready() -> void:
	start = source.global_position
	finish = target.global_position
	direction = (finish - start).normalized()
	var vis_total := mini(total_units(), 24)
	var armor_vis := mini(armored_strength, vis_total)
	for i in range(vis_total):
		var ant = AntScene.instantiate()
		ant.team = team
		ant.armored = i < armor_vis
		ant.level = level
		add_child(ant)
		ant.phase = i * 1.7
		ant.scale = Vector3.ONE * 0.8
		ant.face(direction)
		visuals.append(ant)
	place_visuals()

func _find_opposing_road_army():
	for other in level.armies.get_children():
		if other == self or other.resolved or other.arrived or other.team == team:
			continue
		if other.source == target and other.target == source and (progress + other.progress) >= 0.96:
			return other
	return null

func take_hit() -> bool:
	if armored_strength > 0:
		armored_damage += 1
		if armored_damage >= 2:
			armored_damage = 0
			armored_strength -= 1
			return true
		return false
	if strength > 0:
		strength -= 1
		return true
	return false

func _process(delta: float) -> void:
	if resolved or not level.active or level.paused:
		return
	if not arrived:
		var opposing = _find_opposing_road_army()
		if opposing != null:
			for ant in visuals:
				if is_instance_valid(ant):
					ant.attacking = true
			# Only one of the two armies ticks the shared mid-road clash.
			if get_instance_id() < opposing.get_instance_id():
				combat_clock += delta
				while combat_clock >= 0.09 and not resolved and not opposing.resolved:
					combat_clock -= 0.09
					var clash_pos := start.lerp(finish, progress)
					if take_hit():
						casualty(false)
					if opposing.take_hit():
						opposing.casualty(false)
					level.burst(clash_pos + Vector3.UP * 0.25, Color("ffda8c"), 2)
					SoundManager.play_hit()
					if total_units() <= 0:
						resolve()
					if opposing.total_units() <= 0:
						opposing.resolve()
			return
		for ant in visuals:
			if is_instance_valid(ant):
				ant.attacking = false
		var multiplier: float = level.powerups.speed_multiplier(self)
		if team == 1:
			multiplier *= 1.0 + GameProgress.upgrade_level("march") * 0.08
		progress = minf(1.0, progress + delta * speed * multiplier / maxf(0.1, start.distance_to(finish)))
		place_visuals()
		if progress >= 1.0:
			arrived = true
		return
	if target.team == team:
		target.population = mini(100, target.population + strength)
		target.armored_population = mini(10, target.armored_population + armored_strength)
		target.refresh()
		resolve()
		return
	# Serialize hostile arrivals; waiting formations remain visible.
	if level.combat_owner(target) != self:
		return
	target.fighting = true
	for ant in visuals:
		if is_instance_valid(ant):
			ant.attacking = true
	combat_clock += delta
	while combat_clock >= 0.13 and not resolved:
		combat_clock -= 0.13
		if (target.population > 0 or target.armored_population > 0) and total_units() > 0:
			var attacker_died := take_hit()
			var protected: bool = target.shield_hits > 0 and level.elapsed < target.shield_until
			if protected:
				target.shield_hits -= 1
				level.burst(target.global_position - direction * 1.3 + Vector3.UP * 0.4, Color("adf583"), 3)
			elif target.armored_population > 0:
				target.armored_damage += 1
				if target.armored_damage >= 2:
					target.armored_damage = 0
					target.armored_population -= 1
			else:
				target.population -= 1
			target.hit()
			SoundManager.play_hit()
			if attacker_died:
				casualty(not protected)
			elif not protected:
				spawn_defender_casualty()
			target.refresh()
			if total_units() <= 0:
				resolve()
			elif target.population <= 0 and target.armored_population <= 0:
				target.capture(team, strength, armored_strength)
				resolve()
		elif total_units() > 0:
			target.capture(team, strength, armored_strength)
			resolve()
		else:
			resolve()

func place_visuals() -> void:
	var side := Vector3(-direction.z, 0, direction.x)
	var center := start.lerp(finish, progress)
	if progress > 0.85:
		center -= direction * 0.85 * ((progress - 0.85) / 0.15)
	for i in range(visuals.size()):
		var ant = visuals[i]
		if is_instance_valid(ant):
			var traveled := maxf(0.0, (center - start).dot(direction) - float(i / 3) * 0.9)
			ant.global_position = start + direction * traveled + side * (float(i % 3) - 1.0) * 0.52
			ant.global_position.y = 0.035

func casualty(defender_killed: bool = true) -> void:
	if not visuals.is_empty():
		var ant = visuals.pop_front()
		if is_instance_valid(ant):
			ant.reparent(level.effects)
			ant.die()
	if visuals.size() < mini(total_units(), 24):
		var replacement = AntScene.instantiate()
		replacement.team = team
		replacement.armored = armored_strength > 0
		replacement.level = level
		add_child(replacement)
		replacement.face(direction)
		replacement.attacking = true
		replacement.scale = Vector3.ONE * 0.8
		visuals.push_back(replacement)
	place_visuals()
	if defender_killed:
		spawn_defender_casualty()

func spawn_defender_casualty() -> void:
	var defender = AntScene.instantiate()
	defender.team = target.team
	defender.level = level
	level.effects.add_child(defender)
	defender.global_position = target.global_position - direction * 0.6 + Vector3(0, 0.1, 0)
	defender.face(-direction)
	defender.die()
	level.burst(defender.global_position, Color("ffda8c"), 2)

func resolve() -> void:
	resolved = true
	if is_instance_valid(target):
		target.fighting = false
	queue_free()
