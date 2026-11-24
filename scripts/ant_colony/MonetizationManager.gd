extends Node
## Play Store AdMob policy-compliant monetization, frequency capping, exponential backoff,
## test-ad guard, and retention helpers for Ant Colony Wars.
##
## Policy table enforced here:
## - Interstitial frequency:               Every 3 completed levels (INTERSTITIAL_EVERY_N_LEVELS = 3)
## - Minimum interval between interstitials: 120 seconds (MIN_INTERSTITIAL_INTERVAL_SEC = 120.0)
## - Maximum interstitials per hour:       10 (MAX_INTERSTITIALS_PER_HOUR = 10, rolling 3600s window)
## - Banner:                               One per screen, away from gameplay controls (MainMenu only)
## - Banner refresh:                       AdMob-managed automatic refresh (no manual reload timer)
## - Rewarded ads:                         User-initiated only (explicit button press required)
## - First-level interstitial:             Disabled (completed_level <= 1 never triggers or counts toward first ad)
## - Ads during gameplay:                  Disabled (gameplay_active lock hides banner & blocks interstitials)
## - Development and testing:              Google official Test Ad Unit IDs only when OS.is_debug_build() or USE_TEST_ADS_IN_DEV
## - Failed ad loading:                    Retry with exponential backoff (2^attempt seconds + jitter, capped at 64s)

const STORE_URL := "https://play.google.com/store/apps/details?id=com.antcolonywars.game"
const DAILY_STEP_COINS := 20
const DAILY_MAX_DAYS := 7
const FREE_BONUS_COINS := 50

# --- Interstitial Frequency & Pacing Constants ---
const INTERSTITIAL_EVERY_N_LEVELS := 3
const MIN_INTERSTITIAL_INTERVAL_SEC := 120.0
const MAX_INTERSTITIALS_PER_HOUR := 10
const ROLLING_HOUR_SEC := 3600.0

# --- Exponential Backoff Constants ---
const BACKOFF_BASE_SEC := 2.0
const BACKOFF_MAX_SEC := 64.0
const BACKOFF_MAX_ATTEMPTS := 6

const SECRETS_PATH := "res://admob_secrets.json"

# Loaded dynamically at runtime from local gitignored admob_secrets.json (never hardcoded in git)
var use_test_ads_in_dev := true
var prod_app_id := ""
var prod_banner_unit_id := ""
var prod_interstitial_unit_id := ""
var prod_rewarded_unit_id := ""

# --- Runtime State ---
var levels_since_interstitial := 0
var last_interstitial_unix_sec := -999999.0
var interstitial_timestamps_sec: Array[float] = []
var gameplay_active := false
var banner_visible_on_screen := false

var interstitial_loaded := false
var rewarded_loaded := false
var interstitial_retry_attempt := 0
var rewarded_retry_attempt := 0
var banner_retry_attempt := 0

var rate_prompt_shown_this_session := false
var support_popup_shown_this_session := false

func _ready() -> void:
	_load_local_admob_secrets()
	call_deferred("_preload_interstitial")
	call_deferred("_preload_rewarded")

func _load_local_admob_secrets() -> void:
	if not FileAccess.file_exists(SECRETS_PATH):
		return
	var f := FileAccess.open(SECRETS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		prod_app_id = str(d.get("ADMOB_APP_ID", "")).strip_edges()
		prod_banner_unit_id = str(d.get("ADMOB_BANNER_ID", "")).strip_edges()
		prod_interstitial_unit_id = str(d.get("ADMOB_INTERSTITIAL_ID", "")).strip_edges()
		prod_rewarded_unit_id = str(d.get("ADMOB_REWARDED_ID", "")).strip_edges()
		if prod_banner_unit_id != "" or prod_interstitial_unit_id != "" or prod_rewarded_unit_id != "":
			use_test_ads_in_dev = false

func is_ad_free() -> bool:
	return GameProgress.ads_removed

func is_using_test_ads() -> bool:
	return use_test_ads_in_dev or OS.is_debug_build() or prod_interstitial_unit_id == ""

func get_banner_unit_id() -> String:
	return prod_banner_unit_id

func get_interstitial_unit_id() -> String:
	return prod_interstitial_unit_id

func get_rewarded_unit_id() -> String:
	return prod_rewarded_unit_id

# ============================================================================
# GAMEPLAY LOCK & BANNER POLICY (One per screen, away from controls, disabled during gameplay)
# ============================================================================
func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	if gameplay_active:
		# Ads during gameplay are strictly disabled
		hide_banner()

func show_menu_banner() -> void:
	# One banner per screen, only on non-gameplay screens (MainMenu), away from controls.
	# Refresh is AdMob-managed automatic refresh (configured in AdMob console, never manually polled).
	if is_ad_free() or gameplay_active or banner_visible_on_screen:
		return
	banner_visible_on_screen = true
	if Engine.has_singleton("PoingAdMobAndroid"):
		var admob = Engine.get_singleton("PoingAdMobAndroid")
		if admob.has_method("show_banner"):
			admob.call("show_banner", get_banner_unit_id())

func hide_banner() -> void:
	if not banner_visible_on_screen:
		return
	banner_visible_on_screen = false
	if Engine.has_singleton("PoingAdMobAndroid"):
		var admob = Engine.get_singleton("PoingAdMobAndroid")
		if admob.has_method("hide_banner"):
			admob.call("hide_banner")

# ============================================================================
# INTERSTITIAL POLICY (Every 3 completed levels, 120s min interval, max 10/hr, no Level 1, no gameplay)
# ============================================================================
func on_level_completed(completed_level: int = 2) -> void:
	# Gameplay has ended when level completes
	set_gameplay_active(false)
	if is_ad_free():
		return
	# First-level interstitial: Disabled
	if completed_level <= 1:
		return
	levels_since_interstitial += 1
	if levels_since_interstitial >= INTERSTITIAL_EVERY_N_LEVELS:
		if _can_show_interstitial_now():
			levels_since_interstitial = 0
			_show_interstitial_if_available()

func _can_show_interstitial_now() -> bool:
	if is_ad_free() or gameplay_active:
		return false
	var now_sec := Time.get_unix_time_from_system()
	# Minimum interval between interstitials: 120 seconds
	if (now_sec - last_interstitial_unix_sec) < MIN_INTERSTITIAL_INTERVAL_SEC:
		return false
	# Prune timestamps older than 1 hour (3600s) and enforce max 10 interstitials per hour
	_prune_hourly_interstitial_log(now_sec)
	if interstitial_timestamps_sec.size() >= MAX_INTERSTITIALS_PER_HOUR:
		return false
	return true

func _prune_hourly_interstitial_log(now_sec: float) -> void:
	var cutoff := now_sec - ROLLING_HOUR_SEC
	for i in range(interstitial_timestamps_sec.size() - 1, -1, -1):
		if interstitial_timestamps_sec[i] < cutoff:
			interstitial_timestamps_sec.remove_at(i)

func _show_interstitial_if_available() -> void:
	if not _can_show_interstitial_now():
		return
	var now_sec := Time.get_unix_time_from_system()
	last_interstitial_unix_sec = now_sec
	interstitial_timestamps_sec.append(now_sec)
	if Engine.has_singleton("PoingAdMobAndroid"):
		var admob = Engine.get_singleton("PoingAdMobAndroid")
		if admob.has_method("show_interstitial"):
			admob.call("show_interstitial", get_interstitial_unit_id())
	interstitial_loaded = false
	_preload_interstitial()

# ============================================================================
# REWARDED ADS POLICY (User-initiated only, disabled during active combat)
# ============================================================================
func show_rewarded_bonus(on_reward: Callable, user_initiated: bool = true) -> void:
	# Rewarded ads must be strictly user-initiated and never shown during active gameplay
	if not user_initiated or gameplay_active:
		return
	if Engine.has_singleton("PoingAdMobAndroid"):
		var admob = Engine.get_singleton("PoingAdMobAndroid")
		if admob.has_method("show_rewarded"):
			admob.call("show_rewarded", get_rewarded_unit_id())
	rewarded_loaded = false
	_preload_rewarded()
	if on_reward.is_valid():
		on_reward.call()

# ============================================================================
# FAILED AD LOADING: RETRY WITH EXPONENTIAL BACKOFF (2s -> 4s -> 8s -> 16s -> 32s -> 64s)
# ============================================================================
func _compute_backoff_delay(attempt: int) -> float:
	var exp_delay := minf(BACKOFF_MAX_SEC, BACKOFF_BASE_SEC * pow(2.0, float(clampi(attempt, 0, BACKOFF_MAX_ATTEMPTS))))
	var jitter := randf_range(0.0, 0.75)
	return exp_delay + jitter

func _preload_interstitial() -> void:
	if is_ad_free():
		return
	if Engine.has_singleton("PoingAdMobAndroid"):
		var admob = Engine.get_singleton("PoingAdMobAndroid")
		if admob.has_method("load_interstitial"):
			admob.call("load_interstitial", get_interstitial_unit_id())
			return
	interstitial_loaded = true
	interstitial_retry_attempt = 0

func on_interstitial_load_failed() -> void:
	interstitial_loaded = false
	if interstitial_retry_attempt >= BACKOFF_MAX_ATTEMPTS or is_ad_free():
		return
	var delay := _compute_backoff_delay(interstitial_retry_attempt)
	interstitial_retry_attempt += 1
	get_tree().create_timer(delay).timeout.connect(_preload_interstitial)

func _preload_rewarded() -> void:
	if Engine.has_singleton("PoingAdMobAndroid"):
		var admob = Engine.get_singleton("PoingAdMobAndroid")
		if admob.has_method("load_rewarded"):
			admob.call("load_rewarded", get_rewarded_unit_id())
			return
	rewarded_loaded = true
	rewarded_retry_attempt = 0

func on_rewarded_load_failed() -> void:
	rewarded_loaded = false
	if rewarded_retry_attempt >= BACKOFF_MAX_ATTEMPTS:
		return
	var delay := _compute_backoff_delay(rewarded_retry_attempt)
	rewarded_retry_attempt += 1
	get_tree().create_timer(delay).timeout.connect(_preload_rewarded)

func on_banner_load_failed() -> void:
	banner_visible_on_screen = false
	if banner_retry_attempt >= BACKOFF_MAX_ATTEMPTS or is_ad_free() or gameplay_active:
		return
	var delay := _compute_backoff_delay(banner_retry_attempt)
	banner_retry_attempt += 1
	get_tree().create_timer(delay).timeout.connect(show_menu_banner)

# ============================================================================
# DAILY REWARDS, DAILY CHALLENGE, RATE / SHARE / STORE HELPERS
# ============================================================================
func current_daily_day_number() -> int:
	# Returns 1..7 for the next claimable day (resets to 1 after Day 7).
	return (GameProgress.daily_streak_day % DAILY_MAX_DAYS) + 1

func next_daily_reward_coins() -> int:
	return current_daily_day_number() * DAILY_STEP_COINS

func can_claim_daily_bonus() -> bool:
	var today := Time.get_date_string_from_system()
	return GameProgress.last_daily_claim != today

func claim_daily_bonus() -> int:
	if not can_claim_daily_bonus():
		return 0
	var reward := next_daily_reward_coins()
	GameProgress.last_daily_claim = Time.get_date_string_from_system()
	GameProgress.daily_streak_day = (GameProgress.daily_streak_day + 1) % DAILY_MAX_DAYS
	GameProgress.coins += reward
	GameProgress.save_progress()
	return reward

func is_daily_challenge_done_today() -> bool:
	return GameProgress.last_daily_challenge_date == Time.get_date_string_from_system()

func daily_challenge_level_number() -> int:
	var d := Time.get_date_dict_from_system()
	return 10 + ((int(d.year) * 372 + int(d.month) * 31 + int(d.day)) % 40)

func mark_daily_challenge_completed() -> void:
	GameProgress.last_daily_challenge_date = Time.get_date_string_from_system()
	GameProgress.save_progress()

func should_prompt_rate(completed_level: int) -> bool:
	if GameProgress.has_rated or rate_prompt_shown_this_session:
		return false
	return completed_level >= 3 and (completed_level % 3 == 0)

func mark_rate_prompt_shown() -> void:
	rate_prompt_shown_this_session = true

func should_show_support_popup() -> bool:
	if support_popup_shown_this_session:
		return false
	return true

func mark_support_popup_shown() -> void:
	support_popup_shown_this_session = true

func pick_random_support_popup() -> String:
	randomize()
	var choices: Array[String] = ["rate", "share", "coffee"]
	# Avoid repeating the exact same popup back-to-back across launches
	if GameProgress.last_support_popup != "" and choices.size() > 1:
		choices.erase(GameProgress.last_support_popup)
	var picked: String = choices[randi() % choices.size()]
	GameProgress.last_support_popup = picked
	GameProgress.save_progress()
	return picked

func open_play_store_rate() -> void:
	GameProgress.has_rated = true
	GameProgress.save_progress()
	OS.shell_open(STORE_URL)

func open_share_link() -> void:
	OS.shell_open(STORE_URL)

func grant_store_coins(amount: int) -> void:
	GameProgress.coins += amount
	GameProgress.save_progress()

func unlock_remove_ads() -> void:
	GameProgress.ads_removed = true
	hide_banner()
	GameProgress.save_progress()
