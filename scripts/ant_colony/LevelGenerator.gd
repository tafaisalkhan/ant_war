extends RefCounted
# 8 non-overlapping tactical slots (every pair >= 4.5 units apart, safely inside HUD bounds).
const SLOTS = [
	Vector3(-8.2, 0,  1.4), Vector3( 8.2, 0, -1.0),
	Vector3(-3.0, 0, -3.4), Vector3( 3.0, 0, -3.4),
	Vector3(-3.0, 0,  3.8), Vector3( 3.0, 0,  3.8),
	Vector3(-7.8, 0, -3.2), Vector3( 7.8, 0,  3.6)
]

static func generate(level_number: int) -> Dictionary:
	var count: int
	if level_number == 1: count = 2
	elif level_number <= 4: count = 3
	elif level_number <= 7: count = 4
	elif level_number <= 10: count = 5
	else: count = mini(8,5+int((level_number-8)/4))
	var order := [0,1,2,3,4,5,6,7]
	var rng := RandomNumberGenerator.new()
	rng.seed = level_number*104729+31
	if level_number > 1:
		for i in range(order.size()-1,1,-1):
			var j := rng.randi_range(2,i)
			var swap: int = order[i]
			order[i] = order[j]
			order[j] = swap
	var positions: Array[Vector3] = []
	for i in range(count): positions.append(SLOTS[order[i]])
	var edges: Array = []
	# A connected backbone guarantees every generated battlefield is playable.
	for i in range(1,count):
		var parent := maxi(0,int((i-1)/2))
		edges.append([parent,i])
	if count >= 4: edges.append([1,3])
	if count >= 6: edges.append([2,5])
	if count >= 7: edges.append([3,6])
	var is_boss := (level_number % 5 == 0)
	var teams: Array[int] = []
	var populations: Array[int] = []
	var armored: Array[int] = []
	var strongholds: Array[bool] = []
	for i in range(count):
		var team := 0
		if i == 0: team = 1
		elif i == 1 or (level_number >= 6 and i == count-1): team = 2
		teams.append(team)
		var population := 8+rng.randi_range(0,5)+level_number/4
		if team == 1: population = 35+mini(15,level_number/2)
		elif team == 2:
			population = 12+mini(30,level_number*2)
			if is_boss and i == 1:
				population += 12
		if level_number == 1 and team == 2: population = 12
		populations.append(clampi(population,1,100))
		var armored_count := 0
		if level_number >= 8 and team == 2:
			armored_count = mini(8,1+int((level_number-8)/3)+rng.randi_range(0,1))
		if is_boss and team == 2 and i == 1:
			armored_count = mini(10, maxi(3, armored_count + 2))
		armored.append(armored_count)
		strongholds.append((level_number >= 5 or is_boss) and team == 2 and (i == 1 or i == count-1))
	return {"positions":positions,"edges":edges,"teams":teams,"populations":populations,"armored":armored,"strongholds":strongholds,"biome":(level_number-1)%6,"boss":is_boss}
