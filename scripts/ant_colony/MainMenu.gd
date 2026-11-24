extends Control
## Arcade-style Main Menu & Tabbed Popups inspired by top mobile action/strategy games.
const TITLE_FONT = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const UI_FONT = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

const TEX_BG = preload("res://assets/ant_colony/ui/splash.png")
const TEX_NEST = preload("res://assets/ant_colony/homes/stronghold.png")
const TEX_ANT_BLUE = preload("res://assets/ant_colony/units/armored-blue.png")
const TEX_ANT_RED = preload("res://assets/ant_colony/units/armored-red.png")
const TEX_SUGAR = preload("res://assets/ant_colony/ui/power-sugar.png")
const TEX_SHIELD = preload("res://assets/ant_colony/ui/power-shield.png")
const TEX_RALLY = preload("res://assets/ant_colony/ui/power-rally.png")
const TEX_HONEY = preload("res://assets/ant_colony/ui/power-honey.png")

const ICON_COIN = preload("res://assets/ant_colony/ui/icons/icon-coin.png")
const ICON_STAR = preload("res://assets/ant_colony/ui/icons/icon-star.png")
const ICON_SETTINGS = preload("res://assets/ant_colony/ui/icons/icon-settings.png")
const ICON_GUIDE = preload("res://assets/ant_colony/ui/icons/icon-guide.png")
const ICON_STORE = preload("res://assets/ant_colony/ui/icons/icon-store.png")
const ICON_UPGRADES = preload("res://assets/ant_colony/ui/icons/icon-upgrades.png")
const ICON_LEVELS = preload("res://assets/ant_colony/ui/icons/icon-levels.png")

const BIOME_NAMES = [
	"Forest Colony",
	"Mushroom Grove",
	"Autumn Woodland",
	"Rocky Creek",
	"Ancient Root Hollow",
	"Sandy Garden",
]
const UPGRADE_SPECS = [
	["hatchery", "Faster Hatchery", "Blue nests breed faster (-0.15s / lvl)", TEX_SUGAR],
	["barracks", "Starting Army", "+4 starting Blue ants per level", TEX_RALLY],
	["march", "Swift March", "+8% permanent Blue march speed", TEX_HONEY],
	["armor", "Armored Guard", "+1 starting Blue Armored Ant (2x HP)", TEX_SHIELD],
]

var settings_popup: Control
var packs_popup: Control
var daily_popup: Control
var privacy_popup: Control
var support_popup: Control

var coins_lbl: Label
var stars_lbl: Label
var battle_btn: Button
var daily_badge: Control
var upgrade_badge: Control
var challenge_badge: Control

# Settings switches
var settings_tab_main: Control
var settings_tab_guide: Control
var switch_music_knob: PanelContainer
var switch_music_bg: StyleBoxFlat
var switch_sfx_knob: PanelContainer
var switch_sfx_bg: StyleBoxFlat
var switch_send_knob: PanelContainer
var switch_send_bg: StyleBoxFlat
var no_ads_btn: Button
var vip_status_lbl: Label

# Tabbed Packs / Upgrades / Store dialog
var current_pack_tab := "upgrades"
var pack_tab_buttons: Dictionary = {}
var pack_body_root: VBoxContainer
var pack_status_lbl = null

# Daily rewards
var daily_claim_btn: Button
var daily_day_cards: Array = []

# Continuous UI animations
var _anim_t := 0.0
var _title_banner: Label
var _pulsing_badges: Array = []
var _rotating_auras: Array = []
var _bobbing_heroes: Array = []
var _top_left_bar: Control
var _top_right_bar: Control
var _bottom_dock_cards: Array = []

func _ready() -> void:
	MonetizationManager.set_gameplay_active(false)
	MonetizationManager.show_menu_banner()
	build_ui()
	_refresh_all()
	_play_menu_entrance_choreography()

func _process(delta: float) -> void:
	_anim_t += delta
	if is_instance_valid(battle_btn) and _anim_t > 0.55:
		battle_btn.scale = Vector2.ONE * (1.0 + sin(_anim_t * 3.6) * 0.032)
	for i in range(_pulsing_badges.size() - 1, -1, -1):
		var raw_b = _pulsing_badges[i]
		if not is_instance_valid(raw_b):
			_pulsing_badges.remove_at(i)
			continue
		var b: Control = raw_b
		b.pivot_offset = b.size * 0.5
		b.rotation = sin(_anim_t * 6.0 + float(i)) * 0.14
		b.scale = Vector2.ONE * (1.0 + abs(sin(_anim_t * 4.2 + float(i))) * 0.12)
	for i in range(_rotating_auras.size() - 1, -1, -1):
		var raw_aura = _rotating_auras[i]
		if not is_instance_valid(raw_aura):
			_rotating_auras.remove_at(i)
			continue
		var aura: Control = raw_aura
		aura.pivot_offset = aura.size * 0.5
		aura.rotation += delta * 0.85
		aura.scale = Vector2.ONE * (1.0 + sin(_anim_t * 3.0) * 0.06)
	for i in range(_bobbing_heroes.size() - 1, -1, -1):
		var raw_h = _bobbing_heroes[i]
		if not is_instance_valid(raw_h):
			_bobbing_heroes.remove_at(i)
			continue
		var h: Control = raw_h
		h.pivot_offset = h.size * 0.5
		h.position.y = float(h.get_meta("base_y", h.position.y)) + sin(_anim_t * 3.2) * 7.0
		h.scale = Vector2(1.0 + sin(_anim_t * 3.2) * 0.03, 1.0 - sin(_anim_t * 3.2) * 0.025)

func build_ui() -> void:
	# 1. Painted Forest Backdrop
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vignette := ColorRect.new()
	vignette.color = Color(0.02, 0.08, 0.04, 0.22)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# 2. Top-Left Cluster: Settings Gear + Packs + Mega Packs (00:02 video layout)
	var top_left := HBoxContainer.new()
	top_left.position = Vector2(18, 14)
	top_left.add_theme_constant_override("separation", 12)
	add_child(top_left)
	_top_left_bar = top_left

	var gear_btn := _square_top_button("", ICON_SETTINGS, Color("243b4a"), Color("6bc2f5"), Vector2(58, 58))
	gear_btn.pressed.connect(func():
		SoundManager.play_click()
		_refresh_settings_switches()
		_open_popup(settings_popup)
	)
	top_left.add_child(gear_btn)

	var pack_btn := _pack_top_badge("Packs", TEX_ANT_BLUE, Color("266e8a"), Color("7ce0ff"), "pack_commando")
	top_left.add_child(pack_btn)

	var mega_btn := _pack_top_badge("Mega\nPacks", TEX_RALLY, Color("8a2b7d"), Color("ff94f2"), "pack_nuke")
	top_left.add_child(mega_btn)

	# 3. Top-Center Game Title & Biome Ribbon
	_title_banner = Label.new()
	_title_banner.text = "ANT COLONY WARS"
	_title_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_banner.add_theme_font_override("font", TITLE_FONT)
	_title_banner.add_theme_font_size_override("font_size", 46)
	_title_banner.add_theme_color_override("font_color", Color("fff3b8"))
	_title_banner.add_theme_color_override("font_outline_color", Color("122a1b"))
	_title_banner.add_theme_constant_override("outline_size", 11)
	_title_banner.anchor_left = 0.5
	_title_banner.anchor_right = 0.5
	_title_banner.offset_left = -280
	_title_banner.offset_right = 280
	_title_banner.offset_top = 18
	_title_banner.offset_bottom = 78
	_title_banner.pivot_offset = Vector2(280, 30)
	_title_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_banner)

	# 4. Top-Right Currency Bars with [+] Buttons (00:02 video layout)
	var top_right := HBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -360
	top_right.offset_right = -18
	top_right.offset_top = 16
	top_right.offset_bottom = 60
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.add_theme_constant_override("separation", 14)
	add_child(top_right)
	_top_right_bar = top_right

	var coin_bar := _currency_plus_bar(str(GameProgress.coins), ICON_COIN, Color("f0932b"), func():
		SoundManager.play_click()
		_open_packs_tab("store")
	)
	coins_lbl = coin_bar.get_node("Row/Amount")
	top_right.add_child(coin_bar)

	var star_bar := _currency_plus_bar(str(GameProgress.total_stars()), ICON_STAR, Color("eb4d4b"), func():
		SoundManager.play_click()
		_open_packs_tab("upgrades")
	)
	stars_lbl = star_bar.get_node("Row/Amount")
	top_right.add_child(star_bar)

	# 5. Bottom-Left 4-Card Dock (Daily Reward, Upgrades, VIP/Daily Challenge, Chests)
	var bottom_dock := HBoxContainer.new()
	bottom_dock.anchor_top = 1.0
	bottom_dock.anchor_bottom = 1.0
	bottom_dock.offset_left = 20
	bottom_dock.offset_right = 620
	bottom_dock.offset_top = -126
	bottom_dock.offset_bottom = -16
	bottom_dock.add_theme_constant_override("separation", 14)
	add_child(bottom_dock)

	var card_daily := _dock_card("Daily Reward", ICON_COIN, Color("2e6b4e"), func():
		SoundManager.play_click()
		_refresh_daily_panel()
		_open_popup(daily_popup)
	)
	daily_badge = card_daily.get_node("Badge")
	bottom_dock.add_child(card_daily)

	var card_upg := _dock_card("Upgrades", TEX_SHIELD, Color("5c3b7a"), func():
		SoundManager.play_click()
		_open_packs_tab("upgrades")
	)
	upgrade_badge = card_upg.get_node("Badge")
	bottom_dock.add_child(card_upg)

	var card_vip := _dock_card("Daily Boss", ICON_STAR, Color("7a3322"), func():
		SoundManager.play_click()
		if not MonetizationManager.is_daily_challenge_done_today():
			_launch_daily_challenge()
		else:
			_open_packs_tab("pack_nuke")
	)
	challenge_badge = card_vip.get_node("Badge")
	bottom_dock.add_child(card_vip)

	var card_chest := _dock_card("Free Chest", ICON_STORE, Color("6e4f16"), func():
		SoundManager.play_click()
		_open_packs_tab("store")
	)
	bottom_dock.add_child(card_chest)
	_bottom_dock_cards = [card_daily, card_upg, card_vip, card_chest]

	# 6. Bottom-Right Big Glossy "PLAY" Button
	var next_lvl := GameProgress.unlocked_level
	var is_boss := (next_lvl % 5 == 0)
	battle_btn = Button.new()
	battle_btn.text = "▶  PLAY"
	battle_btn.custom_minimum_size = Vector2(294, 96)
	battle_btn.pivot_offset = Vector2(147, 48)
	battle_btn.anchor_left = 1.0
	battle_btn.anchor_right = 1.0
	battle_btn.anchor_top = 1.0
	battle_btn.anchor_bottom = 1.0
	battle_btn.offset_left = -316
	battle_btn.offset_right = -22
	battle_btn.offset_top = -116
	battle_btn.offset_bottom = -20
	battle_btn.add_theme_font_override("font", TITLE_FONT)
	battle_btn.add_theme_font_size_override("font_size", 46)
	battle_btn.add_theme_color_override("font_color", Color("ffffff"))
	battle_btn.add_theme_color_override("font_outline_color", Color("0b2533"))
	battle_btn.add_theme_constant_override("outline_size", 10)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color("22c55e")
	b_style.border_color = Color("0c202b")
	b_style.set_border_width_all(4)
	b_style.border_width_bottom = 8
	b_style.set_corner_radius_all(22)
	b_style.content_margin_left = 18
	b_style.content_margin_right = 18
	var b_hover := b_style.duplicate()
	b_hover.bg_color = b_style.bg_color.lightened(0.12)
	battle_btn.add_theme_stylebox_override("normal", b_style)
	battle_btn.add_theme_stylebox_override("hover", b_hover)
	battle_btn.add_theme_stylebox_override("pressed", b_hover)
	battle_btn.pressed.connect(func():
		SoundManager.play_click()
		_launch_level(GameProgress.unlocked_level)
	)
	add_child(battle_btn)
	_wire_button_juice(battle_btn)

	# Level / Boss badge attached to the top-right corner of the PLAY button
	var lvl_badge := PanelContainer.new()
	lvl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_badge.position = Vector2(184, -14)
	lvl_badge.custom_minimum_size = Vector2(102, 28)
	var lbs := StyleBoxFlat.new()
	lbs.bg_color = Color("e056fd") if is_boss else Color("18a4e0")
	lbs.border_color = Color("0c202b")
	lbs.set_border_width_all(2)
	lbs.set_corner_radius_all(10)
	lbs.content_margin_left = 10
	lbs.content_margin_right = 10
	lbs.content_margin_top = 2
	lbs.content_margin_bottom = 2
	lvl_badge.add_theme_stylebox_override("panel", lbs)
	var lbl_lvl := Label.new()
	lbl_lvl.text = ("BOSS " + str(next_lvl)) if is_boss else ("LEVEL " + str(next_lvl))
	lbl_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lvl.add_theme_font_override("font", TITLE_FONT)
	lbl_lvl.add_theme_font_size_override("font_size", 15)
	lbl_lvl.add_theme_color_override("font_color", Color("ffffff"))
	lbl_lvl.add_theme_color_override("font_outline_color", Color("0c202b"))
	lbl_lvl.add_theme_constant_override("outline_size", 4)
	lvl_badge.add_child(lbl_lvl)
	battle_btn.add_child(lvl_badge)

	# Build all framed popups
	_build_settings_popup()
	_build_packs_popup()
	_build_daily_rewards_popup()
	_build_privacy_popup()
	_build_support_popup()
	if MonetizationManager.should_show_support_popup():
		MonetizationManager.mark_support_popup_shown()
		_open_popup(support_popup)

func _play_menu_entrance_choreography() -> void:
	if is_instance_valid(_top_left_bar):
		_top_left_bar.position.y = -85.0
		var tw1 := _top_left_bar.create_tween()
		tw1.tween_property(_top_left_bar, "position:y", 14.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_top_right_bar):
		_top_right_bar.offset_top = -75.0
		_top_right_bar.offset_bottom = -31.0
		var tw2 := _top_right_bar.create_tween().set_parallel(true)
		tw2.tween_property(_top_right_bar, "offset_top", 16.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_top_right_bar, "offset_bottom", 60.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(_bottom_dock_cards.size()):
		var c: Control = _bottom_dock_cards[i]
		if not is_instance_valid(c):
			continue
		c.pivot_offset = Vector2(65, 53)
		c.scale = Vector2.ZERO
		var ctw := c.create_tween()
		ctw.tween_interval(0.08 + i * 0.065)
		ctw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(battle_btn):
		battle_btn.pivot_offset = Vector2(147, 46)
		battle_btn.scale = Vector2.ZERO
		var btw := battle_btn.create_tween()
		btw.tween_interval(0.16)
		btw.tween_property(battle_btn, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ============================================================================
# SETTINGS POPUP (00:01 Video Style: Left Side Tabs + Toggle Switches + Cyan Buttons + Bottom No-Ads/VIP Bar)
# ============================================================================
func _build_settings_popup() -> void:
	var wrap := _create_framed_dialog(Vector2(760, 450), "Settings")
	settings_popup = wrap.overlay
	var card: Control = wrap.card
	var body: VBoxContainer = wrap.body

	# Left Side Tabs sticking out of the dialog frame (⚙ Settings / 🎮 Controls)
	var side_tabs := VBoxContainer.new()
	side_tabs.position = Vector2(-68, 54)
	side_tabs.add_theme_constant_override("separation", 10)
	card.add_child(side_tabs)

	var tab_gear := _side_tab_button(ICON_SETTINGS, true, func():
		SoundManager.play_click()
		settings_tab_main.visible = true
		settings_tab_guide.visible = false
	)
	side_tabs.add_child(tab_gear)

	var tab_pad := _side_tab_button(ICON_GUIDE, false, func():
		SoundManager.play_click()
		settings_tab_main.visible = false
		settings_tab_guide.visible = true
	)
	side_tabs.add_child(tab_pad)

	# Main Settings Content (2 Columns + Bottom Bar)
	settings_tab_main = VBoxContainer.new()
	settings_tab_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_tab_main.add_theme_constant_override("separation", 16)
	body.add_child(settings_tab_main)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 28)
	settings_tab_main.add_child(cols)

	# Left Column: Pill Toggle Switches
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 18)
	cols.add_child(left_col)

	var m_row := _toggle_switch_row("Music", func():
		SoundManager.toggle_music()
		_refresh_settings_switches()
	)
	switch_music_knob = m_row.knob
	switch_music_bg = m_row.bg
	left_col.add_child(m_row.row)

	var s_row := _toggle_switch_row("Sound FX", func():
		SoundManager.toggle_mute()
		_refresh_settings_switches()
	)
	switch_sfx_knob = s_row.knob
	switch_sfx_bg = s_row.bg
	left_col.add_child(s_row.row)

	var a_row := _toggle_switch_row("Send 100% Army", func():
		SoundManager.play_click()
		GameProgress.default_send_all = not GameProgress.default_send_all
		GameProgress.save_progress()
		_refresh_settings_switches()
	)
	switch_send_knob = a_row.knob
	switch_send_bg = a_row.bg
	left_col.add_child(a_row.row)

	# Right Column: Glossy Cyan Action Pills
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 14)
	cols.add_child(right_col)

	var btn_guide := _glossy_action_button("How to Play", ICON_GUIDE, Color("19b5cc"), Vector2(260, 52))
	btn_guide.pressed.connect(func():
		SoundManager.play_click()
		settings_tab_main.visible = false
		settings_tab_guide.visible = true
	)
	right_col.add_child(btn_guide)

	var btn_priv := _glossy_action_button("Privacy Policy", ICON_LEVELS, Color("19b5cc"), Vector2(260, 52))
	btn_priv.pressed.connect(func():
		SoundManager.play_click()
		settings_popup.visible = false
		_open_popup(privacy_popup)
	)
	right_col.add_child(btn_priv)

	var btn_about := _glossy_action_button("Rate & Share ★", ICON_STAR, Color("19b5cc"), Vector2(260, 52))
	btn_about.pressed.connect(func():
		SoundManager.play_click()
		settings_popup.visible = false
		_open_popup(support_popup)
	)
	right_col.add_child(btn_about)

	# Bottom Row: [ No Ads ] + [ VIP Status ]
	var bot_row := HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 20)
	settings_tab_main.add_child(bot_row)

	no_ads_btn = _glossy_action_button("No Ads  •  $4.99", ICON_STORE, Color("e8edf2"), Vector2(215, 50), Color("162936"))
	no_ads_btn.pressed.connect(func():
		SoundManager.play_click()
		settings_popup.visible = false
		_open_packs_tab("store")
	)
	bot_row.add_child(no_ads_btn)

	var vip_pill := PanelContainer.new()
	vip_pill.custom_minimum_size = Vector2(235, 50)
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color("d8e3ec")
	vs.border_color = Color("162936")
	vs.set_border_width_all(3)
	vs.set_corner_radius_all(12)
	vs.content_margin_left = 14
	vs.content_margin_right = 14
	vip_pill.add_theme_stylebox_override("panel", vs)
	vip_status_lbl = Label.new()
	vip_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vip_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vip_status_lbl.add_theme_font_override("font", UI_FONT)
	vip_status_lbl.add_theme_font_size_override("font_size", 16)
	vip_status_lbl.add_theme_color_override("font_color", Color("162936"))
	vip_pill.add_child(vip_status_lbl)
	bot_row.add_child(vip_pill)

	# Controls / Guide Tab inside Settings
	settings_tab_guide = VBoxContainer.new()
	settings_tab_guide.visible = false
	settings_tab_guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_tab_guide.add_theme_constant_override("separation", 12)
	body.add_child(settings_tab_guide)

	for tip in [
		"• DRAG from any Blue nest to a connected nest to march your ants.",
		"• Toggle SEND 50% / 100% in battle for tactical splits or all-out rushes.",
		"• Opposing Blue & Red armies CLASH mid-road — overwhelm them to break through!",
		"• Strong Blue nests & Royal Rally train ARMORED ANTS with 2x health.",
		"• Every 5th level is a BOSS BATTLE (Queen's Stronghold)!",
	]:
		var tl := Label.new()
		tl.text = tip
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.add_theme_font_override("font", UI_FONT)
		tl.add_theme_font_size_override("font_size", 19)
		tl.add_theme_color_override("font_color", Color("e9f7ff"))
		tl.add_theme_color_override("font_outline_color", Color("0a1824"))
		tl.add_theme_constant_override("outline_size", 5)
		settings_tab_guide.add_child(tl)

	_refresh_settings_switches()

func _toggle_switch_row(label_text: String, on_toggle: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", TITLE_FONT)
	lbl.add_theme_font_size_override("font_size", 24)
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

func _refresh_settings_switches() -> void:
	_set_switch_visual(switch_music_knob, switch_music_bg, not SoundManager.music_muted)
	_set_switch_visual(switch_sfx_knob, switch_sfx_bg, not SoundManager.muted)
	_set_switch_visual(switch_send_knob, switch_send_bg, GameProgress.default_send_all)
	if is_instance_valid(no_ads_btn):
		no_ads_btn.text = "Ad-Free Active ✓" if GameProgress.ads_removed else "No Ads  •  $4.99"
	if is_instance_valid(vip_status_lbl):
		vip_status_lbl.text = "VIP Status:\n" + ("Ad-Free Active" if GameProgress.ads_removed else "Standard Colony")

func _set_switch_visual(knob: PanelContainer, bg: StyleBoxFlat, is_on: bool) -> void:
	if not is_instance_valid(knob) or bg == null:
		return
	bg.bg_color = Color("38c159") if is_on else Color("4a5d6b")
	var tw := knob.create_tween()
	tw.tween_property(knob, "position:x", 41.0 if is_on else 5.0, 0.12).set_trans(Tween.TRANS_QUAD)

# ============================================================================
# TABBED PACKS / UPGRADES / STORE POPUP (00:03 & 00:06 Video Style)
# ============================================================================
func _build_packs_popup() -> void:
	var wrap := _create_framed_dialog(Vector2(860, 480), "")
	packs_popup = wrap.overlay
	var card: Control = wrap.card
	pack_body_root = wrap.body

	# Top Folder Tabs sticking above the dialog frame
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(26, -48)
	tab_row.add_theme_constant_override("separation", 8)
	card.add_child(tab_row)

	for spec in [
		["upgrades", "Upgrades"],
		["store", "Coin Store"],
		["pack_commando", "Armored Pack"],
		["pack_nuke", "Queen Mega Pack"],
	]:
		var key: String = spec[0]
		var label_txt: String = spec[1]
		var tb := Button.new()
		tb.text = label_txt
		tb.custom_minimum_size = Vector2(168, 50)
		tb.add_theme_font_override("font", TITLE_FONT)
		tb.add_theme_font_size_override("font_size", 20)
		tb.add_theme_color_override("font_color", Color("ffffff"))
		tb.add_theme_color_override("font_outline_color", Color("0c1c26"))
		tb.add_theme_constant_override("outline_size", 6)
		tb.pressed.connect(func():
			SoundManager.play_click()
			_open_packs_tab(key)
		)
		tab_row.add_child(tb)
		pack_tab_buttons[key] = tb

	_render_pack_tab_contents()

func _open_packs_tab(tab_key: String) -> void:
	current_pack_tab = tab_key
	for key in pack_tab_buttons:
		var tb: Button = pack_tab_buttons[key]
		var active: bool = (str(key) == tab_key)
		tb.position.y = -6.0 if active else 0.0
		var st := StyleBoxFlat.new()
		st.bg_color = Color("1f4f73") if active else Color("112a3d")
		st.border_color = Color("0a1824")
		st.set_border_width_all(3)
		st.border_width_bottom = 0
		st.corner_radius_top_left = 14
		st.corner_radius_top_right = 14
		tb.add_theme_stylebox_override("normal", st)
		tb.add_theme_stylebox_override("hover", st)
		tb.add_theme_stylebox_override("pressed", st)
	_render_pack_tab_contents()
	if not packs_popup.visible:
		_open_popup(packs_popup)

func _render_pack_tab_contents() -> void:
	pack_status_lbl = null
	_rotating_auras.clear()
	_bobbing_heroes.clear()
	for child in pack_body_root.get_children():
		child.queue_free()

	if current_pack_tab == "pack_commando" or current_pack_tab == "pack_nuke":
		var is_mega := (current_pack_tab == "pack_nuke")
		_build_bundle_showcase(
			"ROYAL QUEEN MEGA PACK" if is_mega else "ARMORED COMMANDO PACK",
			TEX_RALLY if is_mega else TEX_ANT_BLUE,
			3000 if is_mega else 1000,
			"$2.99" if is_mega else "$0.99",
			"-60%" if is_mega else "-50%",
			"coins_3000" if is_mega else "coins_1000",
			[
				[TEX_SHIELD, "Royal Armored Shell" if is_mega else "Commando Carapace", "+2 Starting Armored Ants (2x HP)"],
				[TEX_SUGAR, "Queen's Nectar Boost" if is_mega else "Turbo March Boots", "Faster breeding & march speed"],
				[ICON_COIN, "+3,000 Colony Coins + No Ads" if is_mega else "+1,000 Colony Coins + No Ads", "Instant treasure & ad-free play"],
			]
		)
	elif current_pack_tab == "upgrades":
		_build_upgrades_tab_content()
	else:
		_build_coin_store_tab_content()

func _build_bundle_showcase(title_txt: String, hero_tex: Texture2D, bonus_coins: int, price_txt: String, discount_txt: String, sku: String, items: Array) -> void:
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	pack_body_root.add_child(cols)

	# Left Hero Preview (00:03 & 00:06 Video Layout)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(310, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)

	var hero_stage := Control.new()
	hero_stage.custom_minimum_size = Vector2(250, 225)
	hero_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(hero_stage)

	# Rotating golden glow aura behind hero unit
	var aura := PanelContainer.new()
	aura.size = Vector2(170, 170)
	aura.position = Vector2(40, 28)
	aura.pivot_offset = Vector2(85, 85)
	var as_box := StyleBoxFlat.new()
	as_box.bg_color = Color(1.0, 0.82, 0.25, 0.18)
	as_box.border_color = Color(1.0, 0.88, 0.35, 0.55)
	as_box.set_border_width_all(4)
	as_box.set_corner_radius_all(34)
	aura.add_theme_stylebox_override("panel", as_box)
	hero_stage.add_child(aura)
	_rotating_auras.append(aura)

	var hero := TextureRect.new()
	hero.texture = hero_tex
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.size = Vector2(205, 205)
	hero.position = Vector2(22, 10)
	hero.set_meta("base_y", 10.0)
	hero_stage.add_child(hero)
	_bobbing_heroes.append(hero)

	var perks_row := HBoxContainer.new()
	perks_row.alignment = BoxContainer.ALIGNMENT_CENTER
	perks_row.add_theme_constant_override("separation", 12)
	left.add_child(perks_row)

	perks_row.add_child(_perk_badge("+" + str(bonus_coins), ICON_COIN, Color("ff7ae0")))
	perks_row.add_child(_perk_badge("No Ads", ICON_STORE, Color("7ad7ff")))

	# Right Column ("Includes:" + 3 item boxes + Big Green Buy Button with -50% badge)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)

	var inc := Label.new()
	inc.text = "Includes:"
	inc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inc.add_theme_font_override("font", TITLE_FONT)
	inc.add_theme_font_size_override("font_size", 32)
	inc.add_theme_color_override("font_color", Color("ffffff"))
	inc.add_theme_color_override("font_outline_color", Color("0c1c26"))
	inc.add_theme_constant_override("outline_size", 8)
	right.add_child(inc)

	for idx in range(items.size()):
		var it: Array = items[idx]
		var r := _bundle_item_row(it[0], it[1], it[2])
		r.modulate.a = 0.0
		right.add_child(r)
		var rtw := r.create_tween()
		rtw.tween_interval(0.06 + idx * 0.07)
		rtw.tween_property(r, "modulate:a", 1.0, 0.18)

	pack_status_lbl = Label.new()
	pack_status_lbl.text = title_txt
	pack_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_status_lbl.add_theme_font_override("font", UI_FONT)
	pack_status_lbl.add_theme_font_size_override("font_size", 16)
	pack_status_lbl.add_theme_color_override("font_color", Color("b8e5ff"))
	pack_status_lbl.add_theme_color_override("font_outline_color", Color("0a1824"))
	pack_status_lbl.add_theme_constant_override("outline_size", 4)
	right.add_child(pack_status_lbl)

	var buy_wrap := CenterContainer.new()
	right.add_child(buy_wrap)

	var buy_btn := _lime_buy_button("Buy  " + price_txt, discount_txt, Vector2(290, 68))
	buy_btn.pressed.connect(func():
		SoundManager.play_coin()
		pack_status_lbl.text = "Google Play Billing SKU: " + sku + " (" + price_txt + ")"
	)
	buy_wrap.add_child(buy_btn)

func _build_upgrades_tab_content() -> void:
	var hdr := Label.new()
	hdr.text = "COLONY UPGRADES  (Spend Coins to Upgrade Forever)"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_override("font", TITLE_FONT)
	hdr.add_theme_font_size_override("font_size", 26)
	hdr.add_theme_color_override("font_color", Color("ffe885"))
	hdr.add_theme_color_override("font_outline_color", Color("0c1c26"))
	hdr.add_theme_constant_override("outline_size", 7)
	pack_body_root.add_child(hdr)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	pack_body_root.add_child(grid)

	for spec in UPGRADE_SPECS:
		var key: String = spec[0]
		var name_txt: String = spec[1]
		var desc_txt: String = spec[2]
		var tex: Texture2D = spec[3]
		var lvl := GameProgress.upgrade_level(key)
		var cost := GameProgress.upgrade_cost(key)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.22, 0.34, 0.92)
		cs.border_color = Color("0c1c26")
		cs.set_border_width_all(3)
		cs.set_corner_radius_all(14)
		cs.content_margin_left = 14
		cs.content_margin_right = 14
		cs.content_margin_top = 10
		cs.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", cs)
		grid.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		row.add_child(_icon_slot_box(tex, Vector2(62, 62)))

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(info)

		var t := Label.new()
		t.text = name_txt + "  (Lv " + str(lvl) + "/5)"
		t.add_theme_font_override("font", TITLE_FONT)
		t.add_theme_font_size_override("font_size", 20)
		t.add_theme_color_override("font_color", Color("ffffff"))
		t.add_theme_color_override("font_outline_color", Color("0c1c26"))
		t.add_theme_constant_override("outline_size", 5)
		info.add_child(t)

		var d := Label.new()
		d.text = desc_txt
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_override("font", UI_FONT)
		d.add_theme_font_size_override("font_size", 15)
		d.add_theme_color_override("font_color", Color("bfe6ff"))
		d.add_theme_color_override("font_outline_color", Color("081520"))
		d.add_theme_constant_override("outline_size", 4)
		info.add_child(d)

		var btn_txt := "MAXED" if lvl >= GameProgress.MAX_UPGRADE_LEVEL else (str(cost) + " Coins")
		var b := _lime_buy_button(btn_txt, "", Vector2(126, 48))
		b.disabled = lvl >= GameProgress.MAX_UPGRADE_LEVEL or GameProgress.coins < cost
		var u_key := key
		b.pressed.connect(func():
			if GameProgress.buy_upgrade(u_key):
				SoundManager.play_powerup("rally")
				_refresh_all()
				_render_pack_tab_contents()
		)
		row.add_child(b)

func _build_coin_store_tab_content() -> void:
	pack_status_lbl = Label.new()
	pack_status_lbl.text = "TREASURY & SUPPORT  •  Instant Coins & Ad-Free Perks"
	pack_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_status_lbl.add_theme_font_override("font", TITLE_FONT)
	pack_status_lbl.add_theme_font_size_override("font_size", 24)
	pack_status_lbl.add_theme_color_override("font_color", Color("ffe885"))
	pack_status_lbl.add_theme_color_override("font_outline_color", Color("0c1c26"))
	pack_status_lbl.add_theme_constant_override("outline_size", 6)
	pack_body_root.add_child(pack_status_lbl)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	pack_body_root.add_child(grid)

	var items := [
		["Free +50 Coins", "Watch / Ad-Free Bonus", "CLAIM +50", "", "free_50"],
		["1,000 Coins", "Starter Treasury Pouch", "Buy $0.99", "-20%", "coins_1000"],
		["2,000 Coins", "Warlord Coin Chest", "Buy $1.99", "-35%", "coins_2000"],
		["3,000 Coins", "Royal Queen Vault", "Buy $2.99", "-50%", "coins_3000"],
		["Remove Ads", "100% Ad-Free Forever", "Buy $4.99", "VIP", "remove_ads"],
		["Buy a Coffee", "Support Indie Dev", "Buy $1.99", "♥", "coffee"],
	]

	for it in items:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.22, 0.34, 0.92)
		cs.border_color = Color("0c1c26")
		cs.set_border_width_all(3)
		cs.set_corner_radius_all(14)
		cs.content_margin_left = 12
		cs.content_margin_right = 12
		cs.content_margin_top = 10
		cs.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", cs)
		grid.add_child(card)

		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)

		var t := Label.new()
		t.text = it[0]
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", TITLE_FONT)
		t.add_theme_font_size_override("font_size", 21)
		t.add_theme_color_override("font_color", Color("ffffff"))
		t.add_theme_color_override("font_outline_color", Color("0c1c26"))
		t.add_theme_constant_override("outline_size", 5)
		v.add_child(t)

		var d := Label.new()
		d.text = it[1]
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_override("font", UI_FONT)
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", Color("bfe6ff"))
		d.add_theme_color_override("font_outline_color", Color("081520"))
		d.add_theme_constant_override("outline_size", 4)
		v.add_child(d)

		var btn := _lime_buy_button(it[2], it[3], Vector2(180, 44))
		var action_key: String = it[4]
		btn.pressed.connect(func(): _on_store_item_pressed(action_key))
		var bw := CenterContainer.new()
		bw.add_child(btn)
		v.add_child(bw)

func _on_store_item_pressed(key: String) -> void:
	match key:
		"free_50":
			MonetizationManager.show_rewarded_bonus(func():
				MonetizationManager.grant_store_coins(MonetizationManager.FREE_BONUS_COINS)
				SoundManager.play_coin()
				if is_instance_valid(pack_status_lbl):
					pack_status_lbl.text = "+50 Bonus Coins added to your colony!"
				_refresh_all()
			)
		"coins_1000":
			SoundManager.play_click()
			if is_instance_valid(pack_status_lbl):
				pack_status_lbl.text = "Google Play Billing SKU: coins_1000 ($0.99)"
		"coins_2000":
			SoundManager.play_click()
			if is_instance_valid(pack_status_lbl):
				pack_status_lbl.text = "Google Play Billing SKU: coins_2000 ($1.99)"
		"coins_3000":
			SoundManager.play_click()
			if is_instance_valid(pack_status_lbl):
				pack_status_lbl.text = "Google Play Billing SKU: coins_3000 ($2.99)"
		"remove_ads":
			SoundManager.play_click()
			if is_instance_valid(pack_status_lbl):
				pack_status_lbl.text = "Google Play Billing SKU: remove_ads ($4.99)"
		"coffee":
			SoundManager.play_click()
			if is_instance_valid(pack_status_lbl):
				pack_status_lbl.text = "Google Play Billing SKU: coffee ($1.99) — Thank you!"

# ============================================================================
# 7-DAY ESCALATING DAILY REWARDS POPUP (20 -> 140 Coins)
# ============================================================================
func _build_daily_rewards_popup() -> void:
	var wrap := _create_framed_dialog(Vector2(760, 430), "7-Day Daily Reward")
	daily_popup = wrap.overlay
	var v: VBoxContainer = wrap.body

	var sub := Label.new()
	sub.text = "Claim +20 more coins every day up to Day 7 (+140), then restart at Day 1!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("d4f2ff"))
	sub.add_theme_color_override("font_outline_color", Color("081520"))
	sub.add_theme_constant_override("outline_size", 5)
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	daily_day_cards.clear()
	for d in range(1, 8):
		var reward := d * MonetizationManager.DAILY_STEP_COINS
		var card := _glossy_action_button("DAY " + str(d) + "\n+" + str(reward), ICON_COIN, Color("1a4663"), Vector2(160, 82))
		card.disabled = true
		grid.add_child(card)
		daily_day_cards.append(card)

	daily_claim_btn = _lime_buy_button("CLAIM TODAY'S COINS", "FREE", Vector2(320, 58))
	daily_claim_btn.pressed.connect(func():
		var gained := MonetizationManager.claim_daily_bonus()
		if gained > 0:
			SoundManager.play_coin()
			_refresh_all()
			_refresh_daily_panel()
	)
	var cw := CenterContainer.new()
	cw.add_child(daily_claim_btn)
	v.add_child(cw)
	_refresh_daily_panel()

func _refresh_daily_panel() -> void:
	var can_claim := MonetizationManager.can_claim_daily_bonus()
	var current_idx := GameProgress.daily_streak_day
	for i in range(daily_day_cards.size()):
		var d := i + 1
		var reward := d * MonetizationManager.DAILY_STEP_COINS
		var card: Button = daily_day_cards[i]
		if i < current_idx:
			card.text = "DAY " + str(d) + "\nCLAIMED ✓"
		elif i == current_idx and can_claim:
			card.text = "DAY " + str(d) + " ★\n+" + str(reward)
		else:
			card.text = "DAY " + str(d) + "\n+" + str(reward)
	if is_instance_valid(daily_claim_btn):
		if can_claim:
			var amt := MonetizationManager.next_daily_reward_coins()
			var day_num := MonetizationManager.current_daily_day_number()
			daily_claim_btn.text = "CLAIM DAY " + str(day_num) + " (+" + str(amt) + " COINS)"
			daily_claim_btn.disabled = false
		else:
			daily_claim_btn.text = "COME BACK TOMORROW"
			daily_claim_btn.disabled = true

# ============================================================================
# PRIVACY & RANDOM SINGLE SUPPORT POPUP (Rate / Share / Coffee)
# ============================================================================
func _build_privacy_popup() -> void:
	var wrap := _create_framed_dialog(Vector2(660, 380), "Privacy Policy")
	privacy_popup = wrap.overlay
	var v: VBoxContainer = wrap.body
	var body := Label.new()
	body.text = "Ant Colony Wars is an offline-first strategy game.\n\n• Progress, stars, coins, and upgrades are stored locally on your device.\n• We do not collect or sell personal user data.\n• Optional Google Play services (In-App Updates, Store ratings, or Billing) follow Google Play's privacy standards.\n\nContact: muhammadfaysal.khan7@gmail.com"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", UI_FONT)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color("e4f5ff"))
	body.add_theme_color_override("font_outline_color", Color("081520"))
	body.add_theme_constant_override("outline_size", 5)
	v.add_child(body)

func _build_support_popup() -> void:
	var kind := MonetizationManager.pick_random_support_popup()
	var title_txt := "Rate Ant Colony Wars!"
	var body_txt := "Love commanding your ant army? A quick 5-star review on Google Play helps us add new biomes & bosses!"
	var cta_txt := "Rate 5 Stars ★"
	if kind == "share":
		title_txt = "Share With Friends!"
		body_txt = "Challenge your friends to conquer the forest colonies and beat your highest level!"
		cta_txt = "Share Game"
	elif kind == "coffee":
		title_txt = "Buy Me a Coffee"
		body_txt = "Support the indie developer building new ant units, bosses, and updates!"
		cta_txt = "Buy Coffee  •  $1.99"

	var wrap := _create_framed_dialog(Vector2(540, 320), title_txt)
	support_popup = wrap.overlay
	var v: VBoxContainer = wrap.body
	v.alignment = BoxContainer.ALIGNMENT_CENTER

	var msg := Label.new()
	msg.text = body_txt
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_override("font", UI_FONT)
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color("e9f7ff"))
	msg.add_theme_color_override("font_outline_color", Color("081520"))
	msg.add_theme_constant_override("outline_size", 5)
	v.add_child(msg)

	var cta := _lime_buy_button(cta_txt, "♥", Vector2(280, 58))
	cta.pressed.connect(func():
		SoundManager.play_click()
		support_popup.visible = false
		if kind == "rate":
			MonetizationManager.open_play_store_rate()
		elif kind == "share":
			MonetizationManager.open_share_link()
		else:
			_open_packs_tab("store")
	)
	var cw := CenterContainer.new()
	cw.add_child(cta)
	v.add_child(cw)

# ============================================================================
# SHARED ARCADE UI BUILDERS (Framed Dialogs, Red X Close, Lime Buy Button, Badges)
# ============================================================================
func _create_framed_dialog(card_size: Vector2, header_title: String) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := Control.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	center.add_child(card)

	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("184566")
	style.border_color = Color("0b1d2c")
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	bg_panel.add_theme_stylebox_override("panel", style)
	card.add_child(bg_panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	bg_panel.add_child(body)

	if header_title != "":
		var title := Label.new()
		title.text = header_title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", TITLE_FONT)
		title.add_theme_font_size_override("font_size", 38)
		title.add_theme_color_override("font_color", Color("ffffff"))
		title.add_theme_color_override("font_outline_color", Color("0a1824"))
		title.add_theme_constant_override("outline_size", 9)
		body.add_child(title)

	# Red Square [X] Close Button overlapping top-right corner (00:01 & 00:03 Video Style)
	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.size = Vector2(46, 46)
	close_btn.position = Vector2(card_size.x - 28, -18)
	close_btn.add_theme_font_override("font", TITLE_FONT)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.add_theme_color_override("font_color", Color("ffffff"))
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("e83b3b")
	cs.border_color = Color("1a0808")
	cs.set_border_width_all(3)
	cs.border_width_bottom = 5
	cs.set_corner_radius_all(10)
	var ch := cs.duplicate()
	ch.bg_color = Color("ff5252")
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_stylebox_override("hover", ch)
	close_btn.add_theme_stylebox_override("pressed", ch)
	close_btn.pressed.connect(func():
		SoundManager.play_click()
		_close_popup(overlay)
	)
	card.add_child(close_btn)
	_wire_button_juice(close_btn)

	return {"overlay": overlay, "card": card, "body": body}

func _open_popup(overlay: Control) -> void:
	overlay.visible = true
	var dim: ColorRect = overlay.get_child(0)
	dim.modulate.a = 0.0
	var dtw := dim.create_tween()
	dtw.tween_property(dim, "modulate:a", 1.0, 0.18)
	var center := overlay.get_child(1)
	if center.get_child_count() > 0:
		var card: Control = center.get_child(0)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.42, 0.42)
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(0.98, 1.02), 0.09)
		tw.tween_property(card, "scale", Vector2.ONE, 0.08)

func _close_popup(overlay: Control) -> void:
	if not is_instance_valid(overlay) or not overlay.visible:
		return
	var dim: ColorRect = overlay.get_child(0)
	var center := overlay.get_child(1)
	if center.get_child_count() > 0:
		var card: Control = center.get_child(0)
		card.pivot_offset = card.size * 0.5
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.06)
		tw.tween_property(card, "scale", Vector2(0.35, 0.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "modulate:a", 0.0, 0.14)
		tw.parallel().tween_property(dim, "modulate:a", 0.0, 0.14)
		tw.tween_callback(func():
			overlay.visible = false
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
		)
	else:
		overlay.visible = false

func _wire_button_juice(btn: Button) -> void:
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

func _lime_buy_button(text: String, badge_txt: String, btn_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = btn_size
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color("ffffff"))
	btn.add_theme_color_override("font_outline_color", Color("19470b"))
	btn.add_theme_constant_override("outline_size", 6)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("7ed321")
	st.border_color = Color("153309")
	st.set_border_width_all(3)
	st.border_width_bottom = 6
	st.set_corner_radius_all(16)
	var hv := st.duplicate()
	hv.bg_color = Color("94e835")
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	btn.add_theme_stylebox_override("disabled", st)

	if badge_txt != "":
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(btn_size.x - 54, -12)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("ff6b1a")
		bs.border_color = Color("3b1204")
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(10)
		bs.content_margin_left = 7
		bs.content_margin_right = 7
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bs)
		var bl := Label.new()
		bl.text = badge_txt
		bl.add_theme_font_override("font", TITLE_FONT)
		bl.add_theme_font_size_override("font_size", 14)
		bl.add_theme_color_override("font_color", Color("ffffff"))
		badge.add_child(bl)
		btn.add_child(badge)
		_pulsing_badges.append(badge)
	_wire_button_juice(btn)
	return btn

func _bundle_item_row(icon_tex: Texture2D, title_txt: String, sub_txt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_icon_slot_box(icon_tex, Vector2(58, 58)))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var t := Label.new()
	t.text = title_txt
	t.add_theme_font_override("font", TITLE_FONT)
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color("ffffff"))
	t.add_theme_color_override("font_outline_color", Color("0c1c26"))
	t.add_theme_constant_override("outline_size", 6)
	v.add_child(t)
	var s := Label.new()
	s.text = sub_txt
	s.add_theme_font_override("font", UI_FONT)
	s.add_theme_font_size_override("font_size", 15)
	s.add_theme_color_override("font_color", Color("bfe6ff"))
	s.add_theme_color_override("font_outline_color", Color("081520"))
	s.add_theme_constant_override("outline_size", 4)
	v.add_child(s)
	return row

func _icon_slot_box(icon_tex: Texture2D, box_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = box_size
	var st := StyleBoxFlat.new()
	st.bg_color = Color("7b93a8")
	st.border_color = Color("0c1c26")
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.add_child(ic)
	return p

func _perk_badge(text: String, icon_tex: Texture2D, tint: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("112c42")
	st.border_color = tint
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(22, 22)
	row.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color("ffffff"))
	row.add_child(l)
	return p

func _dock_card(title_txt: String, icon_tex: Texture2D, bg_col: Color, on_press: Callable) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(130, 106)

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = Color("12202b")
	st.set_border_width_all(3)
	st.border_width_bottom = 6
	st.set_corner_radius_all(16)
	var hv := st.duplicate()
	hv.bg_color = bg_col.lightened(0.12)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	btn.pressed.connect(on_press)
	root.add_child(btn)

	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(31, 10)
	ic.size = Vector2(68, 56)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ic)

	var footer := PanelContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.position = Vector2(4, 68)
	footer.size = Vector2(122, 32)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("f2f6fa")
	fs.corner_radius_bottom_left = 12
	fs.corner_radius_bottom_right = 12
	footer.add_theme_stylebox_override("panel", fs)
	root.add_child(footer)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", TITLE_FONT)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("142430"))
	footer.add_child(lbl)

	# Red [!] Notification Badge
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(106, -6)
	badge.size = Vector2(26, 26)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("e83b3b")
	bs.border_color = Color("ffffff")
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(8)
	badge.add_theme_stylebox_override("panel", bs)
	var bl := Label.new()
	bl.text = "!"
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_override("font", TITLE_FONT)
	bl.add_theme_font_size_override("font_size", 16)
	bl.add_theme_color_override("font_color", Color("ffffff"))
	badge.add_child(bl)
	root.add_child(badge)
	_pulsing_badges.append(badge)
	_wire_button_juice(btn)

	return root

func _pack_top_badge(title_txt: String, icon_tex: Texture2D, bg_col: Color, border_col: Color, tab_key: String) -> Button:
	var btn := Button.new()
	btn.text = title_txt
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 36)
	btn.custom_minimum_size = Vector2(76, 74)
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color("ffffff"))
	btn.add_theme_color_override("font_outline_color", Color("0c1c26"))
	btn.add_theme_constant_override("outline_size", 5)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(3)
	st.border_width_bottom = 5
	st.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.pressed.connect(func():
		SoundManager.play_click()
		_open_packs_tab(tab_key)
	)
	_wire_button_juice(btn)
	return btn

func _currency_plus_bar(amount_txt: String, icon_tex: Texture2D, plus_col: Color, on_press: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(158, 42)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.12, 0.18, 0.92)
	st.border_color = Color("0c1c26")
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 6
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(28, 28)
	plus_btn.add_theme_font_override("font", TITLE_FONT)
	plus_btn.add_theme_font_size_override("font_size", 18)
	plus_btn.add_theme_color_override("font_color", Color("ffffff"))
	var ps := StyleBoxFlat.new()
	ps.bg_color = plus_col
	ps.set_corner_radius_all(7)
	plus_btn.add_theme_stylebox_override("normal", ps)
	plus_btn.add_theme_stylebox_override("hover", ps)
	plus_btn.add_theme_stylebox_override("pressed", ps)
	plus_btn.pressed.connect(on_press)
	row.add_child(plus_btn)

	var amt := Label.new()
	amt.name = "Amount"
	amt.text = amount_txt
	amt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amt.add_theme_font_override("font", TITLE_FONT)
	amt.add_theme_font_size_override("font_size", 20)
	amt.add_theme_color_override("font_color", Color("ffffff"))
	row.add_child(amt)

	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(26, 26)
	row.add_child(ic)
	return p

func _square_top_button(text: String, icon_tex: Texture2D, bg_col: Color, border_col: Color, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", 32)
	btn.custom_minimum_size = sz
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(3)
	st.border_width_bottom = 5
	st.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	_wire_button_juice(btn)
	return btn

func _side_tab_button(icon_tex: Texture2D, active: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", 34)
	btn.custom_minimum_size = Vector2(68, 62)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("184566") if active else Color("0f2c42")
	st.border_color = Color("0b1d2c")
	st.set_border_width_all(4)
	st.border_width_right = 0
	st.corner_radius_top_left = 14
	st.corner_radius_bottom_left = 14
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.pressed.connect(on_press)
	_wire_button_juice(btn)
	return btn

func _glossy_action_button(text: String, icon_tex: Texture2D, bg_col: Color, sz: Vector2, text_col: Color = Color("ffffff")) -> Button:
	var btn := Button.new()
	btn.text = "  " + text
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 26)
	btn.custom_minimum_size = sz
	btn.add_theme_font_override("font", TITLE_FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", text_col)
	if text_col == Color("ffffff"):
		btn.add_theme_color_override("font_outline_color", Color("0b2533"))
		btn.add_theme_constant_override("outline_size", 5)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = Color("0c1c26")
	st.set_border_width_all(3)
	st.border_width_bottom = 6
	st.set_corner_radius_all(14)
	st.content_margin_left = 14
	st.content_margin_right = 14
	var hv := st.duplicate()
	hv.bg_color = bg_col.lightened(0.10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	_wire_button_juice(btn)
	return btn

func _refresh_all() -> void:
	if is_instance_valid(coins_lbl):
		coins_lbl.text = str(GameProgress.coins)
	if is_instance_valid(stars_lbl):
		stars_lbl.text = str(GameProgress.total_stars())
	if is_instance_valid(daily_badge):
		daily_badge.visible = MonetizationManager.can_claim_daily_bonus()
	if is_instance_valid(upgrade_badge):
		upgrade_badge.visible = GameProgress.coins >= 40
	if is_instance_valid(challenge_badge):
		challenge_badge.visible = not MonetizationManager.is_daily_challenge_done_today()
	_refresh_settings_switches()

func _launch_level(lvl: int) -> void:
	MonetizationManager.hide_banner()
	GameProgress.playing_daily_challenge = false
	GameProgress.current_level = lvl
	GameProgress.save_progress()
	get_tree().change_scene_to_file("res://scenes/ant_colony/Level1.tscn")

func _launch_daily_challenge() -> void:
	MonetizationManager.hide_banner()
	GameProgress.playing_daily_challenge = true
	get_tree().change_scene_to_file("res://scenes/ant_colony/Level1.tscn")
