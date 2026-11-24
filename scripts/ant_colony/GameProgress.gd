extends Node
const STARTING_COINS := 50
var current_level := 1
var unlocked_level := 1
var coins := STARTING_COINS
var best_stars: Dictionary = {}
var sound_muted := false
var music_muted := false
var default_send_all := false
var ads_removed := false
var has_rated := false
var last_daily_claim := ""
var daily_streak_day := 0
var last_daily_challenge_date := ""
var last_support_popup := ""
var playing_daily_challenge := false
var upgrades: Dictionary = {"hatchery": 0, "barracks": 0, "march": 0, "armor": 0}
const MAX_UPGRADE_LEVEL := 5
const SAVE_PATH = "user://ant_colony_progress.cfg"

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	current_level = maxi(1,int(config.get_value("progress","current_level",1)))
	unlocked_level = maxi(current_level,int(config.get_value("progress","unlocked_level",current_level)))
	coins = maxi(0,int(config.get_value("progress","coins",STARTING_COINS)))
	if unlocked_level == 1 and coins == 0:
		coins = STARTING_COINS
	best_stars = config.get_value("progress","best_stars",{})
	sound_muted = bool(config.get_value("settings","sound_muted",false))
	music_muted = bool(config.get_value("settings","music_muted",false))
	default_send_all = bool(config.get_value("settings","default_send_all",false))
	ads_removed = bool(config.get_value("settings","ads_removed",false))
	has_rated = bool(config.get_value("settings","has_rated",false))
	last_daily_claim = str(config.get_value("progress","last_daily_claim",""))
	daily_streak_day = clampi(int(config.get_value("progress","daily_streak_day",0)), 0, 6)
	last_daily_challenge_date = str(config.get_value("progress","last_daily_challenge_date",""))
	last_support_popup = str(config.get_value("settings","last_support_popup",""))
	for key in upgrades.keys():
		upgrades[key] = clampi(int(config.get_value("upgrades", key, 0)), 0, MAX_UPGRADE_LEVEL)

func upgrade_level(key: String) -> int:
	return int(upgrades.get(key, 0))

func upgrade_cost(key: String) -> int:
	return 40 * (upgrade_level(key) + 1)

func buy_upgrade(key: String) -> bool:
	var lvl := upgrade_level(key)
	if lvl >= MAX_UPGRADE_LEVEL:
		return false
	var cost := upgrade_cost(key)
	if not spend_coins(cost):
		return false
	upgrades[key] = lvl + 1
	save_progress()
	return true

func total_stars() -> int:
	var sum := 0
	for v in best_stars.values():
		sum += int(v)
	return sum

func complete(level_number: int, stars: int, reward: int) -> int:
	var key := str(level_number)
	var old_stars: int = int(best_stars.get(key,0))
	coins += reward
	if stars > old_stars:
		best_stars[key] = stars
	unlocked_level = maxi(unlocked_level,level_number+1)
	save_progress()
	return reward

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	save_progress()
	return true

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress","current_level",current_level)
	config.set_value("progress","unlocked_level",unlocked_level)
	config.set_value("progress","coins",coins)
	config.set_value("progress","best_stars",best_stars)
	config.set_value("progress","last_daily_claim",last_daily_claim)
	config.set_value("progress","daily_streak_day",daily_streak_day)
	config.set_value("progress","last_daily_challenge_date",last_daily_challenge_date)
	config.set_value("settings","sound_muted",sound_muted)
	config.set_value("settings","music_muted",music_muted)
	config.set_value("settings","default_send_all",default_send_all)
	config.set_value("settings","ads_removed",ads_removed)
	config.set_value("settings","has_rated",has_rated)
	config.set_value("settings","last_support_popup",last_support_popup)
	for key in upgrades.keys():
		config.set_value("upgrades", key, int(upgrades[key]))
	config.save(SAVE_PATH)

func reset_progress() -> void:
	current_level = 1
	unlocked_level = 1
	coins = STARTING_COINS
	best_stars = {}
	last_daily_claim = ""
	daily_streak_day = 0
	last_daily_challenge_date = ""
	playing_daily_challenge = false
	for key in upgrades.keys():
		upgrades[key] = 0
	save_progress()
