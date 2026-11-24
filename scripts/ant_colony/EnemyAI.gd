extends Node
var level
var clock := 0.0

func _process(delta: float) -> void:
	if not level.active or level.paused:
		return
	clock += delta
	var interval: float = 3.8 if bool(level.level_data.get("boss", false)) else 5.0
	if clock >= interval:
		clock -= interval
		evaluate()

func evaluate() -> void:
	for source in level.nests:
		if source.team != 2 or source.population < 16 or source.fighting:
			continue
		var count: int = mini(source.population-8,int(source.population*0.5))
		if level.incoming(source,1) > source.population-count:
			continue
		var best = null
		var best_score := -1000.0
		for destination in source.links:
			if level.incoming(destination,2) > 0:
				continue
			var score := -1000.0
			var defense: int = destination.population+destination.armored_population*2
			if destination.team != 2 and count > defense+2:
				score = (35.0 if destination.team == 0 else 25.0)-defense
			# Level 1 begins deliberately asymmetric (12 red versus 35 blue).
			# A strictly winning-only rule would therefore wait forever while both
			# colonies produce. Once red reaches 20, send a measured half-army raid;
			# the eight-ant reserve and five-second evaluation prevent attack spam.
			elif destination.team == 1 and source.population >= 20 and count >= 8:
				score = 8.0-float(defense)*0.1
			elif destination.team == 2:
				var threat: int = level.incoming(destination,1)
				if threat > destination.population or (destination.population < 8 and source.population > 25):
					score = 40.0+threat-destination.population
			if score > best_score:
				best_score = score
				best = destination
		if best != null and best_score > -1000.0:
			level.deploy(source,best,2)
