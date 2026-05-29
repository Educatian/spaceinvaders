extends Node2D
## Top-down arena shooter â€” upgraded build (fx/sfx, sprites, shake, powerups,
## combo, dash, waves+boss, hit-stop).
## Move: WASD / arrows. Aim: mouse (ship rotates to face cursor).
## Fire: hold left-click or SPACE (fires along ship facing).
## Dash: SHIFT or right-click (burst + i-frames). Cycle weapons: Q / TAB / button.
## On-screen FIRE button = auto-aim assist fire.
## Gauges: HP (green) + ENERGY (cyan, drains on fire, regenerates).

# --- Player ---------------------------------------------------------------
const PLAYER_SPEED := 235.0
const PLAYER_RADIUS := 16.0
const PLAYER_MAX_HP := 5

# --- Energy gauge ---------------------------------------------------------
const ENERGY_MAX := 100.0
const ENERGY_REGEN := 30.0

# --- Game states ----------------------------------------------------------
const STATE_SELECT := 0
const STATE_PLAY := 1
const STATE_OVER := 2

# --- Weapon upgrades ------------------------------------------------------
const WEAPON_LEVEL_MAX := 5

# --- Player classes -------------------------------------------------------
# Each class's values are copied into runtime stats on select. fire_cost_mult
# and cooldown_mult scale the existing per-weapon cost + cd. dash_cd overrides
# the base dash cooldown. hull_color tints the procedural ship + HUD accents.
const CLASSES := [
	{
		"name": "ASSAULT",
		"desc": "Balanced all-rounder.",
		"max_hp": 5,
		"speed": 235.0,
		"energy_max": 100.0,
		"energy_regen": 30.0,
		"fire_cost_mult": 1.0,
		"cooldown_mult": 1.0,
		"dash_cd": 0.9,
		"dmg_bonus": 0,
		"bullet_scale": 1.0,
		"hull_scale": 1.0,
		"color": Color(0.30, 0.62, 1.0),
		"start_weapon": 0,
	},
	{
		"name": "TANK",
		"desc": "Heavy: more HP + energy, hits harder, slow dash.",
		"max_hp": 8,
		"speed": 175.0,
		"energy_max": 130.0,
		"energy_regen": 24.0,
		"fire_cost_mult": 1.15,
		"cooldown_mult": 1.0,
		"dash_cd": 1.35,
		"dmg_bonus": 1,
		"bullet_scale": 1.35,
		"hull_scale": 1.3,
		"color": Color(0.62, 0.38, 0.92),
		"start_weapon": 0,
	},
	{
		"name": "SCOUT",
		"desc": "Agile glass-cannon: fast, cheap fire, quick dash.",
		"max_hp": 3,
		"speed": 320.0,
		"energy_max": 100.0,
		"energy_regen": 44.0,
		"fire_cost_mult": 0.7,
		"cooldown_mult": 0.7,
		"dash_cd": 0.55,
		"dmg_bonus": 0,
		"bullet_scale": 0.85,
		"hull_scale": 0.8,
		"color": Color(0.40, 1.0, 0.45),
		"start_weapon": 0,
	},
]

# --- Bullets --------------------------------------------------------------
const BULLET_SPEED := 640.0
const BULLET_RADIUS := 5.0
const BULLET_LIFE := 1.3

# --- Weapons (slug, name, cost, cooldown) ---------------------------------
# LASER cost is per-second drain (handled specially in the firing path), not a
# per-shot cost; its cd is the time between damage ticks. HOMING is a normal
# discrete weapon like SINGLE/TRIPLE.
const WEAPONS := [
	{"name": "SINGLE", "cost": 10.0, "cd": 0.16},
	{"name": "TRIPLE", "cost": 22.0, "cd": 0.30},
	{"name": "SPIRAL", "cost": 6.0,  "cd": 0.05},
	{"name": "LASER",  "cost": 55.0, "cd": 0.08},
	{"name": "HOMING", "cost": 26.0, "cd": 0.42},
]

# Weapon index constants for readability.
const W_SINGLE := 0
const W_TRIPLE := 1
const W_SPIRAL := 2
const W_LASER := 3
const W_HOMING := 4

# --- Difficulty -----------------------------------------------------------
# enemy_hp_mult / enemy_speed_mult scale spawned enemy hp + chase speed.
# spawn_mult scales the spawn interval (lower = faster spawns).
# boss_hp_mult scales boss hp. ebullet_speed_mult scales enemy bullet speed.
# score_mult folds into scoring (and XP / bomb gains).
const DIFFS := [
	{
		"name": "EASY",
		"enemy_hp_mult": 0.8, "enemy_speed_mult": 0.85, "spawn_mult": 1.25,
		"boss_hp_mult": 0.8, "ebullet_speed_mult": 0.85, "score_mult": 0.8,
		"color": Color(0.45, 1.0, 0.6),
	},
	{
		"name": "NORMAL",
		"enemy_hp_mult": 1.0, "enemy_speed_mult": 1.0, "spawn_mult": 1.0,
		"boss_hp_mult": 1.0, "ebullet_speed_mult": 1.0, "score_mult": 1.0,
		"color": Color(0.6, 0.8, 1.0),
	},
	{
		"name": "HARD",
		"enemy_hp_mult": 1.4, "enemy_speed_mult": 1.15, "spawn_mult": 0.8,
		"boss_hp_mult": 1.4, "ebullet_speed_mult": 1.15, "score_mult": 1.5,
		"color": Color(1.0, 0.5, 0.45),
	},
]

# --- Laser tuning ---------------------------------------------------------
const LASER_TICK := 0.08          # seconds between damage applications
const LASER_BASE_LEN := 360.0     # beam length at Lv1
const LASER_BASE_HALFW := 8.0     # beam half-width at Lv1
const LASER_BASE_DMG := 1         # damage per tick at Lv1 (before class bonus)
const LASER_COST_PER_SEC := 55.0  # energy drained per second while firing

# --- Homing tuning --------------------------------------------------------
const HOMING_SPEED := 360.0       # missile travel speed (slower than bullets)
const HOMING_LIFE := 2.4
const HOMING_BASE_TURN := 3.2     # radians/sec steer rate at Lv1

# --- Achievements ---------------------------------------------------------
const ACHIEVEMENTS := [
	{"id": "first_blood", "title": "First Blood", "desc": "Destroy your first enemy."},
	{"id": "combo25", "title": "Combo Master", "desc": "Reach an x8 combo."},
	{"id": "boss_slayer", "title": "Boss Slayer", "desc": "Defeat a boss."},
	{"id": "wave10", "title": "Veteran", "desc": "Reach wave 10."},
	{"id": "maxed", "title": "Fully Loaded", "desc": "Bring a weapon to Lv5."},
	{"id": "bomber", "title": "Bombs Away", "desc": "Detonate a bomb."},
	{"id": "elite_hunter", "title": "Elite Hunter", "desc": "Kill 10 elites (lifetime)."},
	{"id": "survivor", "title": "Survivor", "desc": "Survive 5 minutes in one run."},
]

# --- Enemies --------------------------------------------------------------
const SPAWN_START := 1.3
const SPAWN_MIN := 0.32
const SPAWN_RAMP := 0.984

# --- Dash -----------------------------------------------------------------
const DASH_DIST := 140.0
const DASH_TIME := 0.12
const DASH_CD := 0.9

# --- Combo ----------------------------------------------------------------
const COMBO_WINDOW := 2.5
const COMBO_MAX := 8

# --- Shake ----------------------------------------------------------------
const SHAKE_MAG := 14.0
const ONE := Vector2.ONE
const ZERO := Vector2.ZERO

# --- Hit-stop -------------------------------------------------------------
const HITSTOP_SCALE := 0.25
const HITSTOP_TIME := 0.06

# --- Boss -----------------------------------------------------------------
const BOSS_RADIUS := 46.0
const BOSS_HP := 40
const BOSS_SPEED := 42.0
const BOSS_BULLET_SPEED := 200.0

# --- State ----------------------------------------------------------------
var arena = Vector2(480, 720)
var t = 0.0

var state = STATE_SELECT     # SELECT / PLAY / OVER
var class_idx = 0            # currently selected / last-played class

# Runtime player stats (copied from the chosen class on select).
var p_max_hp = PLAYER_MAX_HP
var p_speed = PLAYER_SPEED
var p_energy_max = ENERGY_MAX
var energy_regen_rate = ENERGY_REGEN
var fire_cost_mult = 1.0
var cooldown_mult = 1.0
var dash_cd_base = DASH_CD
var p_dmg_bonus = 0
var bullet_scale = 1.0
var hull_scale = 1.0
var hull_color = Color(0.30, 0.62, 1.0)
var class_label = "ASSAULT"

# Weapon progression: per-weapon level + shared XP toward next level.
var weapon_level = [1, 1, 1, 1, 1]
var weapon_xp = 0.0
var weapon_xp_next = 20.0

# --- difficulty -----------------------------------------------------------
var difficulty = 1   # 0=Easy, 1=Normal, 2=Hard (default Normal)

# --- laser runtime --------------------------------------------------------
var laser_tick_t = 0.0     # countdown to next laser damage tick
var laser_firing = false   # true on frames the beam is actually active
var laser_end = Vector2.ZERO   # cached beam endpoint for drawing

# --- run timer ------------------------------------------------------------
var run_time = 0.0         # seconds survived this run

# --- achievements ---------------------------------------------------------
const ACH_PATH := "user://scores.save"   # same ConfigFile as high scores
var ach_unlocked: Dictionary = {}   # id -> true (persisted, lifetime)
var elite_kills_total = 0            # lifetime elite kills (persisted)
# Per-run achievement counters.
var run_kills = 0
# Toast queue (separate from the WAVE/WEAPON banner).
var toasts: Array = []   # {text, life, max_life}

var player_pos = Vector2.ZERO
var player_rot = 0.0
var player_hp = PLAYER_MAX_HP
var energy = ENERGY_MAX
var invuln = 0.0
var weapon = 0
var spiral_angle = 0.0
var muzzle_flash = 0.0
var thrust = 0.0
var last_move_dir = Vector2.RIGHT

var bullets: Array = []         # {pos, vel, life, dmg, pierce}
var enemy_bullets: Array = []   # {pos, vel, life}
var enemies: Array = []         # {pos, type, hp, spin, maxhp, fire_t?}
var stars: Array = []           # {pos, spd, size}
var pickups: Array = []         # {pos, vel, type, life}

var fire_timer = 0.0
var spawn_timer = 0.0
var spawn_interval = SPAWN_START
var score = 0
var game_over = false
var death_announced = false
var _font: Font

# --- modules --------------------------------------------------------------
var fx
var sfx
var _shoot_snd_t = 0.0

# --- sprites --------------------------------------------------------------
var textures: Dictionary = {}

# --- shake ----------------------------------------------------------------
var trauma = 0.0
var shake_offset = Vector2.ZERO

# --- dash -----------------------------------------------------------------
var dash_t = 0.0          # remaining dash motion time
var dash_cd = 0.0         # cooldown remaining
var dash_vel = Vector2.ZERO

# --- combo ----------------------------------------------------------------
var combo = 0
var combo_t = 0.0         # remaining combo window

# --- waves ----------------------------------------------------------------
var wave = 1
var wave_kills = 0
var wave_quota = 8
var banner_t = 0.0
var banner_text = ""

# --- buffs ----------------------------------------------------------------
var buf_rapid = 0.0
var buf_spread = 0.0
var shield = 0           # remaining absorbing contacts

# --- roguelite in-run upgrades --------------------------------------------
# Run-scoped multipliers/bonuses drafted between waves. All reset to neutral
# each run in _reset(). They layer ON TOP of class + difficulty + weapon-level
# effects (never replace them).
var up_damage_mult = 1.0      # final bullet/laser dmg multiplier
var up_firerate_mult = 1.0    # >1 = faster (cooldown divided by this)
var up_move_mult = 1.0        # player move-speed multiplier
var up_pierce_bonus = 0       # extra pierce added to spawned player bullets
var up_crit_chance = 0.0      # 0..1 chance a hit crits
var up_crit_mult = 2.0        # crit damage multiplier
var up_lifesteal = 0.0        # fraction of dealt damage healed (via accumulator)
var up_multishot = 0          # extra parallel projectiles on discrete weapons
var up_xp_mult = 1.0          # weapon-XP gain multiplier
var up_bomb_gain_mult = 1.0   # bomb-charge gain multiplier
var up_pickup_luck = 0.0      # added flat drop chance
var up_regen_bonus = 0.0      # added energy regen per second
var _lifesteal_acc = 0.0      # fractional-HP accumulator for lifesteal
var taken_upgrades: Dictionary = {}   # id -> stack count (for stacking + UI)

# Upgrade pool. Each entry: id, name, desc, accent color, max_stacks.
# _apply_upgrade(id) mutates the run vars above; caps enforced via max_stacks.
const UPGRADES := [
	{"id": "overcharge", "name": "OVERCHARGE", "desc": "+25% damage",
		"accent": Color(1.0, 0.55, 0.35), "max_stacks": 6},
	{"id": "rapidfire", "name": "RAPID FIRE", "desc": "+20% fire rate",
		"accent": Color(1.0, 0.85, 0.30), "max_stacks": 5},
	{"id": "piercing", "name": "PIERCING ROUNDS", "desc": "+1 pierce",
		"accent": Color(0.55, 0.85, 1.0), "max_stacks": 3},
	{"id": "crit", "name": "CRITICAL STRIKE", "desc": "+12% crit chance",
		"accent": Color(1.0, 0.40, 0.55), "max_stacks": 5},
	{"id": "vampiric", "name": "VAMPIRIC", "desc": "+ lifesteal on damage",
		"accent": Color(0.85, 0.30, 0.45), "max_stacks": 4},
	{"id": "multishot", "name": "MULTISHOT", "desc": "+1 projectile",
		"accent": Color(0.60, 1.0, 0.70), "max_stacks": 3},
	{"id": "adrenaline", "name": "ADRENALINE", "desc": "+15% move speed",
		"accent": Color(0.45, 1.0, 0.55), "max_stacks": 4},
	{"id": "battery", "name": "BATTERY", "desc": "+ energy regen & max",
		"accent": Color(0.30, 0.85, 1.0), "max_stacks": 5},
	{"id": "scholar", "name": "SCHOLAR", "desc": "+30% weapon XP",
		"accent": Color(0.70, 0.60, 1.0), "max_stacks": 4},
	{"id": "munitions", "name": "MUNITIONS", "desc": "+40% bomb charge rate",
		"accent": Color(1.0, 0.45, 0.90), "max_stacks": 4},
	{"id": "lucky", "name": "LUCKY", "desc": "+ drop chance",
		"accent": Color(1.0, 0.78, 0.32), "max_stacks": 4},
	{"id": "vitality", "name": "VITALITY", "desc": "+1 max HP & heal full",
		"accent": Color(0.40, 1.0, 0.50), "max_stacks": 4},
	{"id": "glasscannon", "name": "GLASS CANNON", "desc": "+40% dmg, -1 max HP",
		"accent": Color(1.0, 0.35, 0.30), "max_stacks": 3},
]

# --- hit-stop -------------------------------------------------------------
var hitstop_t = 0.0

# --- high scores ----------------------------------------------------------
const SCORES_PATH := "user://scores.save"
var best_by_class: Dictionary = {}   # class_label -> int
var new_best = false

# --- pause ----------------------------------------------------------------
var paused = false

# --- upgrade draft --------------------------------------------------------
# When a wave is cleared (and after a boss dies) the game freezes and offers
# 3 upgrade cards. Gameplay updates are skipped (like `paused`) until a pick.
var drafting = false
var draft_offers: Array = []        # up to 3 upgrade dicts being offered
var draft_cards: Array = []         # Rect2 hit-targets, one per offer
var draft_pending_wave = false      # true when a wave-start was deferred for a draft
var draft_pending_boss = false      # true when this draft was triggered by a boss kill

# --- meta currency (persistent) -------------------------------------------
const CREDITS_PER_KILL := 1         # base credits per kill (scaled by value/diff)
var run_credits = 0                  # credits earned this run
var total_credits = 0               # lifetime credits (persisted in [meta])

# --- one-shot auto-screenshot ---------------------------------------------
var _shot_done: bool = false
var _shot_t: float = 0.0

# --- bomb / ultimate ------------------------------------------------------
const BOMB_MAX := 100.0
var bomb_charge = 0.0
var bomb_pulse = 0.0   # cosmetic pulse phase for READY indicator

# --- boss attack patterns -------------------------------------------------
const BOSS_PATTERN_TIME := 3.0
const BOSS_TELEGRAPH := 0.4

# UI buttons.
var fire_btn = Vector2.ZERO
var fire_btn_r = 48.0
var weapon_btn = Vector2.ZERO
var weapon_btn_r = 30.0

# Class-select card hit-rects (computed in _layout_ui).
var class_cards: Array = []   # Array of Rect2, one per class
var diff_row_rect = Rect2()   # clickable difficulty selector row on SELECT


func _ready() -> void:
	_font = ThemeDB.fallback_font
	arena = Vector2(get_viewport_rect().size)
	_layout_ui()
	_make_stars()
	_load_textures()
	# Modules.
	fx = preload("res://scripts/Fx.gd").new()
	add_child(fx)
	sfx = preload("res://scripts/Sfx.gd").new()
	add_child(sfx)
	get_viewport().size_changed.connect(func():
		arena = Vector2(get_viewport_rect().size)
		_layout_ui())
	_load_scores()
	# Start on the class-select screen; a run begins once a class is picked.
	_apply_class(0)
	state = STATE_SELECT
	sfx.play_music()
	queue_redraw()


# ============================  HIGH SCORES  ===============================
func _load_scores() -> void:
	best_by_class = {}
	ach_unlocked = {}
	elite_kills_total = 0
	var cfg = ConfigFile.new()
	var err = cfg.load(SCORES_PATH)
	if err != OK:
		return
	if cfg.has_section("scores"):
		for lbl in cfg.get_section_keys("scores"):
			var v = cfg.get_value("scores", lbl, 0)
			best_by_class[lbl] = int(v)
	# Achievements live in a separate [achievements] section. Reading them
	# never disturbs the existing best-score loading above.
	if cfg.has_section("achievements"):
		for aid in cfg.get_section_keys("achievements"):
			if bool(cfg.get_value("achievements", aid, false)):
				ach_unlocked[aid] = true
	# Persisted lifetime stats (its own section).
	if cfg.has_section("stats"):
		elite_kills_total = int(cfg.get_value("stats", "elite_kills", 0))
	# Lifetime meta currency (its own [meta] section; independent of the above).
	total_credits = 0
	if cfg.has_section("meta"):
		total_credits = int(cfg.get_value("meta", "total_credits", 0))
	# Remember the last-chosen difficulty (cosmetic default).
	if cfg.has_section("prefs"):
		difficulty = clampi(int(cfg.get_value("prefs", "difficulty", 1)), 0, DIFFS.size() - 1)


func _save_scores() -> void:
	# Re-load so we never clobber sections we are not actively rewriting.
	var cfg = ConfigFile.new()
	cfg.load(SCORES_PATH)
	for lbl in best_by_class.keys():
		cfg.set_value("scores", lbl, int(best_by_class[lbl]))
	cfg.save(SCORES_PATH)


func _save_ach() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SCORES_PATH)
	for aid in ach_unlocked.keys():
		cfg.set_value("achievements", aid, true)
	cfg.set_value("stats", "elite_kills", int(elite_kills_total))
	cfg.set_value("prefs", "difficulty", int(difficulty))
	cfg.save(SCORES_PATH)


func _save_credits() -> void:
	# Persist lifetime meta currency in its own [meta] section. Re-loads first
	# so existing [scores]/[achievements]/[stats]/[prefs] are never clobbered.
	var cfg = ConfigFile.new()
	cfg.load(SCORES_PATH)
	cfg.set_value("meta", "total_credits", int(total_credits))
	cfg.save(SCORES_PATH)


func _diff() -> Dictionary:
	return DIFFS[clampi(difficulty, 0, DIFFS.size() - 1)]


# ============================  ACHIEVEMENTS  ==============================
func _push_toast(text: String) -> void:
	toasts.append({"text": text, "life": 3.2, "max_life": 3.2})


func _unlock_ach(aid: String) -> void:
	if ach_unlocked.has(aid):
		return
	ach_unlocked[aid] = true
	# Find the title for a nicer toast.
	var title = aid
	for a in ACHIEVEMENTS:
		if String(a.id) == aid:
			title = String(a.title)
			break
	_push_toast("ACHIEVEMENT: " + title)
	sfx.play("powerup")
	_save_ach()


func _best_for(lbl: String) -> int:
	if best_by_class.has(lbl):
		return int(best_by_class[lbl])
	return 0


func _load_textures() -> void:
	textures.clear()
	for key in ["player", "pship0", "pship1", "pship2", "grunt", "fast", "tank", "bullet", "background"]:
		var path = "res://assets/sprites/" + key + ".png"
		if ResourceLoader.exists(path):
			textures[key] = load(path)


func _layout_ui() -> void:
	fire_btn = Vector2(arena.x - 66, arena.y - 74)
	weapon_btn = Vector2(arena.x - 152, arena.y - 60)
	_layout_cards()


func _layout_cards() -> void:
	class_cards.clear()
	var n = CLASSES.size()
	var margin = 24.0
	var gap = 14.0
	var card_w = arena.x - margin * 2.0
	var avail = arena.y * 0.60
	var card_h: float = min((avail - gap * float(n - 1)) / float(n), 150.0)
	var start_y = arena.y * 0.26
	for i in n:
		var top = start_y + float(i) * (card_h + gap)
		class_cards.append(Rect2(Vector2(margin, top), Vector2(card_w, card_h)))
	# Difficulty selector row sits just below the cards.
	var rows_bottom = start_y + float(n) * (card_h + gap)
	diff_row_rect = Rect2(Vector2(margin, rows_bottom), Vector2(card_w, 34.0))


func _make_stars() -> void:
	stars.clear()
	for i in 80:
		stars.append({
			"pos": Vector2(randf() * arena.x, randf() * arena.y),
			"spd": 12.0 + randf() * 45.0,
			"size": 1.0 + randf() * 1.8,
		})


func _apply_class(idx: int) -> void:
	# Copy the chosen class's definition into runtime stats.
	class_idx = clampi(idx, 0, CLASSES.size() - 1)
	var c: Dictionary = CLASSES[class_idx]
	p_max_hp = int(c.max_hp)
	p_speed = float(c.speed)
	p_energy_max = float(c.energy_max)
	energy_regen_rate = float(c.energy_regen)
	fire_cost_mult = float(c.fire_cost_mult)
	cooldown_mult = float(c.cooldown_mult)
	dash_cd_base = float(c.dash_cd)
	p_dmg_bonus = int(c.dmg_bonus)
	bullet_scale = float(c.bullet_scale)
	hull_scale = float(c.hull_scale)
	hull_color = c.color
	class_label = c.name


func _select_class(idx: int) -> void:
	_apply_class(idx)
	var c: Dictionary = CLASSES[class_idx]
	weapon = int(c.start_weapon)
	_reset()


func _change_difficulty(step: int) -> void:
	difficulty = wrapi(difficulty + step, 0, DIFFS.size())
	_save_ach()   # persist the preference (also keeps prefs section in sync)
	queue_redraw()


func _reset() -> void:
	# Begin a run with the currently-applied class stats.
	player_pos = arena * 0.5
	player_rot = -PI / 2.0
	player_hp = p_max_hp
	energy = p_energy_max
	invuln = 0.0
	spiral_angle = 0.0
	bullets.clear()
	enemy_bullets.clear()
	enemies.clear()
	pickups.clear()
	fire_timer = 0.0
	spawn_timer = 0.0
	spawn_interval = SPAWN_START
	score = 0
	game_over = false
	death_announced = false
	trauma = 0.0
	dash_t = 0.0
	dash_cd = 0.0
	combo = 0
	combo_t = 0.0
	wave = 1
	wave_kills = 0
	wave_quota = 8
	banner_t = 1.6
	banner_text = "WAVE 1"
	buf_rapid = 0.0
	buf_spread = 0.0
	shield = 0
	hitstop_t = 0.0
	last_move_dir = Vector2.RIGHT
	# Fresh roguelite upgrade state (all neutral) + meta-currency for this run.
	up_damage_mult = 1.0
	up_firerate_mult = 1.0
	up_move_mult = 1.0
	up_pierce_bonus = 0
	up_crit_chance = 0.0
	up_crit_mult = 2.0
	up_lifesteal = 0.0
	up_multishot = 0
	up_xp_mult = 1.0
	up_bomb_gain_mult = 1.0
	up_pickup_luck = 0.0
	up_regen_bonus = 0.0
	_lifesteal_acc = 0.0
	taken_upgrades = {}
	run_credits = 0
	# Draft never carries across runs.
	drafting = false
	draft_offers = []
	draft_cards = []
	draft_pending_wave = false
	draft_pending_boss = false
	# Fresh weapon progression each run.
	weapon_level = [1, 1, 1, 1, 1]
	weapon_xp = 0.0
	weapon_xp_next = 20.0
	bomb_charge = 0.0
	bomb_pulse = 0.0
	paused = false
	new_best = false
	# Per-run achievement / timing state.
	laser_tick_t = 0.0
	laser_firing = false
	laser_end = Vector2.ZERO
	run_time = 0.0
	run_kills = 0
	toasts.clear()
	Engine.time_scale = 1.0
	state = STATE_PLAY
	sfx.play_music()


func _input(event: InputEvent) -> void:
	# --- Global: mute toggle works in any state ---
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_M:
		sfx.toggle_mute()
		queue_redraw()
		return

	# --- Class-select screen ---
	if state == STATE_SELECT:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_1:
				_select_class(0)
			elif event.keycode == KEY_2:
				_select_class(1)
			elif event.keycode == KEY_3:
				_select_class(2)
			elif event.keycode == KEY_LEFT:
				_change_difficulty(-1)
			elif event.keycode == KEY_RIGHT:
				_change_difficulty(1)
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var mpos = Vector2(event.position)
			# Clicking the difficulty row cycles forward.
			if diff_row_rect.has_point(mpos):
				_change_difficulty(1)
				return
			for i in class_cards.size():
				var r: Rect2 = class_cards[i]
				if r.has_point(mpos):
					_select_class(i)
					break
		return

	# --- Game-over screen ---
	if state == STATE_OVER:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				_reset()                      # replay same class
			elif event.keycode == KEY_C:
				state = STATE_SELECT          # choose a class
				Engine.time_scale = 1.0
				queue_redraw()
		return

	# --- Upgrade draft overlay: consumes 1/2/3 + clicks, blocks other input. ---
	if drafting:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_1:
				_pick_draft(0)
			elif event.keycode == KEY_2:
				_pick_draft(1)
			elif event.keycode == KEY_3:
				_pick_draft(2)
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var dmp: Vector2 = Vector2(event.position)
			for i in draft_cards.size():
				var dr: Rect2 = draft_cards[i]
				if dr.has_point(dmp):
					_pick_draft(i)
					break
			return
		return

	# --- In-play ---
	if event is InputEventKey and event.pressed and not event.echo:
		# Pause toggle is always available.
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()
			return
		if paused:
			# Pause-menu input only.
			if event.keycode == KEY_R:
				paused = false
				_reset()                      # replay same class
			elif event.keycode == KEY_C:
				paused = false
				state = STATE_SELECT          # choose a class
				Engine.time_scale = 1.0
				queue_redraw()
			return
		if event.keycode == KEY_Q or event.keycode == KEY_TAB:
			weapon = (weapon + 1) % WEAPONS.size()
		if event.keycode == KEY_SHIFT:
			_try_dash()
		if event.keycode == KEY_E:
			_try_bomb()
		if event.keycode == KEY_C:
			state = STATE_SELECT              # back to class-select
			Engine.time_scale = 1.0
			queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if paused:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Vector2(event.position).distance_to(weapon_btn) <= weapon_btn_r:
				weapon = (weapon + 1) % WEAPONS.size()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_dash()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_try_bomb()


func _toggle_pause() -> void:
	paused = not paused
	if paused:
		# Ensure no leftover hit-stop time scaling while paused.
		Engine.time_scale = 1.0


func _try_bomb() -> void:
	if state != STATE_PLAY or paused or game_over:
		return
	if bomb_charge < BOMB_MAX:
		return
	bomb_charge = 0.0
	_unlock_ach("bomber")
	# Clear all incoming enemy fire.
	enemy_bullets.clear()
	# Heavy damage to every enemy / boss via the existing kill path.
	var ei: int = enemies.size() - 1
	while ei >= 0:
		var e: Dictionary = enemies[ei]
		e.hp = int(e.hp) - 6
		if int(e.hp) <= 0:
			_on_enemy_killed(String(e.type), e.pos, bool(e.get("elite", false)))
		ei -= 1
	enemies = enemies.filter(func(en): return int(en.hp) > 0)
	# Big visuals.
	fx.shockwave(player_pos, Color(1.0, 0.4, 1.0))
	fx.explosion(player_pos, Color(1.0, 0.5, 0.9), 2.6)
	for k in range(6):
		var a: float = randf() * TAU
		var off: Vector2 = Vector2(cos(a), sin(a)) * randf_range(40.0, 160.0)
		fx.explosion(player_pos + off, Color(1.0, 0.6, 0.3), 1.4)
	_add_trauma(0.8)
	invuln = max(invuln, 1.0)
	banner_text = "BOMB!"
	banner_t = 1.0
	sfx.play("explode")
	sfx.play("wave")


# ============================  HIT-STOP  ==================================
func _trigger_hitstop() -> void:
	# Guard against stacking: only set scale if not already in a hit-stop.
	if hitstop_t <= 0.0:
		Engine.time_scale = HITSTOP_SCALE
	hitstop_t = HITSTOP_TIME


func _add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)


# ============================  PROCESS  ===================================
func _process(delta: float) -> void:
	# One-shot auto-screenshot: capture the menu shortly after launch, once.
	# Runs before any early-return so it always fires regardless of state/pause.
	if not _shot_done:
		_shot_t += delta
		if _shot_t >= 1.2:
			_shot_done = true
			_capture_shot()

	# Hit-stop runs on unscaled time so it always restores.
	if hitstop_t > 0.0:
		hitstop_t -= delta / max(Engine.time_scale, 0.001)
		if hitstop_t <= 0.0:
			Engine.time_scale = 1.0

	t += delta

	# --- Class-select: animate starfield only, no simulation ---
	if state == STATE_SELECT:
		_update_stars(delta)
		_update_toasts(delta)
		trauma = 0.0
		shake_offset = ZERO
		Engine.time_scale = 1.0
		queue_redraw()
		return

	_update_stars(delta)
	_decay_shake(delta)
	fx.position = shake_offset

	if game_over:
		state = STATE_OVER
		_update_toasts(delta)
		if not death_announced:
			death_announced = true
			# High-score check for the active class.
			new_best = false
			var prev = _best_for(class_label)
			if score > prev:
				best_by_class[class_label] = score
				new_best = true
				_save_scores()
			# Bank this run's meta currency into the lifetime total + persist.
			total_credits += run_credits
			_save_credits()
			sfx.play("gameover")
		# R = replay same class, C = choose class (handled in _input).
		queue_redraw()
		return

	# Drafting: freeze gameplay (like pause) while the upgrade cards are up.
	# Force time scale normal and keep the toast queue + cosmetic pulse alive.
	if drafting:
		Engine.time_scale = 1.0
		bomb_pulse += delta * 4.0
		_update_toasts(delta)
		queue_redraw()
		return

	# Paused: skip all gameplay updates, keep time scale normal, still redraw.
	if paused:
		Engine.time_scale = 1.0
		bomb_pulse += delta * 4.0
		_update_toasts(delta)
		queue_redraw()
		return

	bomb_pulse += delta * 4.0
	# Run timer + survivor achievement (5 minutes in one run).
	run_time += delta
	if run_time >= 300.0:
		_unlock_ach("survivor")
	_update_toasts(delta)
	_handle_movement(delta)
	_handle_aim_and_fire(delta)
	_handle_spawning(delta)
	_update_bullets(delta)
	_update_enemy_bullets(delta)
	_update_enemies(delta)
	_update_pickups(delta)
	_resolve_collisions()

	# Timers.
	energy = min(p_energy_max, energy + (energy_regen_rate + up_regen_bonus) * delta)
	if invuln > 0.0:
		invuln -= delta
	if muzzle_flash > 0.0:
		muzzle_flash -= delta
	if dash_cd > 0.0:
		dash_cd -= delta
	if _shoot_snd_t > 0.0:
		_shoot_snd_t -= delta
	if buf_rapid > 0.0:
		buf_rapid -= delta
	if buf_spread > 0.0:
		buf_spread -= delta
	if banner_t > 0.0:
		banner_t -= delta
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
	thrust = move_toward(thrust, 0.0, delta * 4.0)
	queue_redraw()


func _capture_shot() -> void:
	# Wait one rendered frame, then save the current viewport to user://shot.png.
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://shot.png")


func _decay_shake(delta: float) -> void:
	trauma = max(0.0, trauma - delta * 1.4)
	var shake = trauma * trauma
	if shake > 0.0:
		shake_offset = Vector2.RIGHT.rotated(randf() * TAU) * shake * SHAKE_MAG
	else:
		shake_offset = ZERO


func _update_toasts(delta: float) -> void:
	if toasts.is_empty():
		return
	for to in toasts:
		to.life = float(to.life) - delta
	toasts = toasts.filter(func(to): return float(to.life) > 0.0)


func _update_stars(delta: float) -> void:
	for s in stars:
		var p: Vector2 = s.pos
		var spd: float = s.spd
		p.y += spd * delta
		if p.y > arena.y:
			p.y = 0.0
			p.x = randf() * arena.x
		s.pos = p


# ============================  MOVEMENT / DASH  ===========================
func _try_dash() -> void:
	if game_over or dash_cd > 0.0 or dash_t > 0.0:
		return
	var dir = last_move_dir
	if dir.length() < 0.01:
		dir = Vector2.RIGHT.rotated(player_rot)
	dir = dir.normalized()
	dash_vel = dir * (DASH_DIST / DASH_TIME)
	dash_t = DASH_TIME
	dash_cd = dash_cd_base
	invuln = max(invuln, DASH_TIME + 0.04)  # i-frames during dash
	_add_trauma(0.08)
	fx.burst(player_pos, Color(0.5, 0.85, 1.0), 14, 220.0)
	sfx.play("dash")


func _handle_movement(delta: float) -> void:
	if dash_t > 0.0:
		dash_t -= delta
		player_pos += dash_vel * delta
		thrust = 1.0
		fx.burst(player_pos, Color(0.4, 0.8, 1.0, 0.8), 2, 60.0)
	else:
		var dir = Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1.0
		if dir != Vector2.ZERO:
			var nd = dir.normalized()
			last_move_dir = nd
			# Roguelite move-speed upgrade multiplies the class base speed.
			player_pos += nd * p_speed * up_move_mult * delta
			thrust = 1.0
	player_pos.x = clamp(player_pos.x, PLAYER_RADIUS, arena.x - PLAYER_RADIUS)
	player_pos.y = clamp(player_pos.y, PLAYER_RADIUS, arena.y - PLAYER_RADIUS)


func _handle_aim_and_fire(delta: float) -> void:
	fire_timer -= delta
	var mp = get_global_mouse_position()
	var over_fire = mp.distance_to(fire_btn) <= fire_btn_r
	var over_weapon = mp.distance_to(weapon_btn) <= weapon_btn_r
	var lmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	var aim = mp - player_pos
	var want_fire = false
	if lmb and over_fire:
		var tgt = _nearest_enemy()
		if tgt != null:
			aim = (tgt - player_pos)
		else:
			aim = Vector2.RIGHT.rotated(player_rot)
		want_fire = true
	elif (lmb and not over_weapon) or Input.is_key_pressed(KEY_SPACE):
		want_fire = true

	if aim.length() > 1.0:
		player_rot = lerp_angle(player_rot, aim.angle(), 0.35)

	# --- LASER: continuous piercing beam (weapon 3) -----------------------
	# Does not spawn bullets. Drains energy per second while firing and
	# applies damage on a short tick so it is not insane per-frame.
	laser_firing = false
	if weapon == W_LASER:
		_handle_laser(delta, want_fire)
		return

	var w: Dictionary = WEAPONS[weapon]
	var cost: float = w.cost
	var cd: float = w.cd
	# Class modifiers.
	cost *= fire_cost_mult
	cd *= cooldown_mult
	# Roguelite fire-rate upgrade: divide cd (>1 = faster). Keep class cd too.
	if up_firerate_mult > 0.0:
		cd /= up_firerate_mult
	# Rapid buff: cheaper + faster.
	if buf_rapid > 0.0:
		cost *= 0.55
		cd *= 0.55
	if want_fire and fire_timer <= 0.0 and energy >= cost:
		_fire()
		energy -= cost
		fire_timer = cd
		muzzle_flash = 0.06
		var nose = player_pos + Vector2.RIGHT.rotated(player_rot) * (PLAYER_RADIUS + 6.0)
		fx.muzzle(nose, Vector2.RIGHT.rotated(player_rot))
		# Throttle shoot sound (so SPIRAL does not spam every frame).
		if _shoot_snd_t <= 0.0:
			sfx.play("shoot")
			_shoot_snd_t = 0.06


func _laser_params() -> Dictionary:
	# Level scales damage, beam width, length, and tick rate.
	var lvl: int = int(weapon_level[W_LASER])
	var length: float = LASER_BASE_LEN + 60.0 * float(lvl - 1)
	var half_w: float = LASER_BASE_HALFW + 2.0 * float(lvl - 1)
	var dmg: int = LASER_BASE_DMG + p_dmg_bonus + int(lvl / 2.0)
	# Higher levels tick a touch faster (more total DPS).
	var tick: float = max(0.04, LASER_TICK - 0.008 * float(lvl - 1))
	# Roguelite: fire-rate upgrade speeds the damage tick; multishot widens the
	# beam (LASER's analogue of extra projectiles). Damage_mult is applied at
	# the damage point (_laser_damage_tick) so crits can layer on top.
	if up_firerate_mult > 0.0:
		tick = max(0.025, tick / up_firerate_mult)
	half_w += 2.5 * float(up_multishot)
	return {"len": length, "half_w": half_w, "dmg": dmg, "tick": tick}


func _handle_laser(delta: float, want_fire: bool) -> void:
	# Per-second energy drain, scaled by class fire_cost_mult and rapid buff.
	var drain: float = LASER_COST_PER_SEC * fire_cost_mult
	if buf_rapid > 0.0:
		drain *= 0.55
	if laser_tick_t > 0.0:
		laser_tick_t -= delta
	if not (want_fire and energy > 0.0):
		laser_tick_t = 0.0
		return
	# Active this frame.
	laser_firing = true
	energy = max(0.0, energy - drain * delta)
	var lp: Dictionary = _laser_params()
	var dir: Vector2 = Vector2.RIGHT.rotated(player_rot)
	var nose: Vector2 = player_pos + dir * (PLAYER_RADIUS + 6.0)
	laser_end = nose + dir * float(lp.len)
	muzzle_flash = 0.06
	fx.muzzle(nose, dir)
	# Damage tick.
	if laser_tick_t <= 0.0:
		laser_tick_t = float(lp.tick)
		_laser_damage_tick(nose, dir, float(lp.len), float(lp.half_w), int(lp.dmg))
		if _shoot_snd_t <= 0.0:
			sfx.play("shoot")
			_shoot_snd_t = 0.08


# Apply a hit's damage to an enemy with roguelite damage-mult + crit + lifesteal.
# `raw` is the pre-upgrade damage already including class/level bonuses. Returns
# the actual damage dealt (so callers could juice off it). Kills are routed by
# the caller via the normal _on_enemy_killed path after checking e.hp.
func _deal_damage(e: Dictionary, raw: int) -> int:
	var dmg: float = float(raw) * up_damage_mult
	if up_crit_chance > 0.0 and randf() < up_crit_chance:
		dmg *= up_crit_mult
	var final_dmg: int = max(1, int(round(dmg)))
	e.hp = int(e.hp) - final_dmg
	# Lifesteal: accumulate fractional HP, heal whole points, cap at max HP.
	if up_lifesteal > 0.0 and player_hp > 0:
		_lifesteal_acc += float(final_dmg) * up_lifesteal
		if _lifesteal_acc >= 1.0:
			var gain: int = int(_lifesteal_acc)
			_lifesteal_acc -= float(gain)
			player_hp = min(p_max_hp, player_hp + gain)
	return final_dmg


func _laser_damage_tick(origin: Vector2, dir: Vector2, length: float, half_w: float, dmg: int) -> void:
	# Damage every enemy/boss whose center is within (half_w + radius) of the
	# beam segment [origin, origin + dir*length]. Kills route through the
	# normal kill path so score/XP/combo/drops/bomb-charge all work.
	for e in enemies:
		if int(e.hp) <= 0:
			continue
		var ep: Vector2 = e.pos
		var to_e: Vector2 = ep - origin
		var proj: float = clamp(to_e.dot(dir), 0.0, length)
		var closest: Vector2 = origin + dir * proj
		var er: float = _e_radius(e)
		if closest.distance_to(ep) <= half_w + er:
			var type: String = e.type
			_deal_damage(e, dmg)
			if type == "boss":
				_add_trauma(0.04)
			if int(e.hp) <= 0:
				_on_enemy_killed(type, e.pos, bool(e.get("elite", false)))
	enemies = enemies.filter(func(en): return int(en.hp) > 0)


func _fire() -> void:
	var nose = player_pos + Vector2.RIGHT.rotated(player_rot) * (PLAYER_RADIUS + 6.0)
	var extra = buf_spread > 0.0
	var lvl: int = int(weapon_level[weapon])
	# Base damage = 1 + class bonus; level effects layered per weapon.
	var dmg: int = 1 + p_dmg_bonus
	var pierce: int = 0
	match weapon:
		0:  # SINGLE â€” extra parallel bolts, +dmg, L5 pierces.
			dmg += int(lvl / 2.0)          # +1 dmg every 2 levels
			if lvl >= 5:
				pierce = 1                 # L5 bolts pierce one enemy
			# Bolt count: L1=1, L2=2, L3=3, L4=3, L5=4.
			var bolts: int = clampi(lvl, 1, 3)
			if lvl >= 5:
				bolts = 4
			for off in _fan_offsets(bolts, 0.10):
				_spawn_bullet(nose, player_rot + off, dmg, pierce)
			if extra:
				_spawn_bullet(nose, player_rot - 0.22, dmg, pierce)
				_spawn_bullet(nose, player_rot + 0.22, dmg, pierce)
			# Multishot: extra parallel bolts at a small symmetric spread.
			for mi in up_multishot:
				var ms_off: float = 0.14 * float(mi + 1)
				_spawn_bullet(nose, player_rot - ms_off, dmg, pierce)
				_spawn_bullet(nose, player_rot + ms_off, dmg, pierce)
		1:  # TRIPLE â€” pellet count + spread widen with level.
			dmg += int(lvl / 3.0)          # small damage bump at higher levels
			var pellets: int = clampi(3 + (lvl - 1), 3, 7)  # L1=3 .. L5=7
			var width: float = 0.18 + 0.05 * float(lvl - 1)
			for off in _fan_offsets(pellets, width):
				_spawn_bullet(nose, player_rot + off, dmg, 0)
			if extra:
				_spawn_bullet(nose, player_rot - (width + 0.22), dmg, 0)
				_spawn_bullet(nose, player_rot + (width + 0.22), dmg, 0)
			# Multishot: extra pellets just outside the existing spread.
			for mi in up_multishot:
				var ms_w: float = width + 0.14 * float(mi + 1)
				_spawn_bullet(nose, player_rot - ms_w, dmg, 0)
				_spawn_bullet(nose, player_rot + ms_w, dmg, 0)
		2:  # SPIRAL â€” more arms + faster emission with level.
			spiral_angle += 0.55 + 0.10 * float(lvl - 1)
			var arms: int = clampi(1 + lvl, 2, 5)  # L1=2 .. L5=5 (capped)
			for i in arms:
				var a: float = player_rot + spiral_angle + TAU * float(i) / float(arms)
				_spawn_bullet(player_pos, a, dmg, 0)
			if extra:
				_spawn_bullet(player_pos, player_rot + spiral_angle + PI * 0.5, dmg, 0)
				_spawn_bullet(player_pos, player_rot + spiral_angle + PI * 1.5, dmg, 0)
		4:  # HOMING â€” guided missiles. Level scales count (1->3), turn, dmg.
			dmg += int(lvl / 2.0)
			var missiles: int = clampi(1 + int((lvl - 1) / 2.0), 1, 3)  # L1=1 L3=2 L5=3
			var turn: float = HOMING_BASE_TURN + 0.6 * float(lvl - 1)
			var spread: float = 0.18
			var offs: Array = _fan_offsets(missiles, spread)
			for off in offs:
				_spawn_homing(nose, player_rot + off, dmg, turn)
			if extra:
				_spawn_homing(nose, player_rot - (spread + 0.20), dmg, turn)
				_spawn_homing(nose, player_rot + (spread + 0.20), dmg, turn)
			# Multishot: extra guided missiles fanned out a little wider.
			for mi in up_multishot:
				var ms_a: float = spread + 0.20 + 0.16 * float(mi + 1)
				_spawn_homing(nose, player_rot - ms_a, dmg, turn)
				_spawn_homing(nose, player_rot + ms_a, dmg, turn)


func _fan_offsets(count: int, spacing: float) -> Array:
	# `count` symmetric angular offsets centered on 0.
	var offs: Array = []
	if count <= 1:
		offs.append(0.0)
		return offs
	var start: float = -spacing * float(count - 1) * 0.5
	for i in count:
		offs.append(start + spacing * float(i))
	return offs


func _spawn_bullet(from: Vector2, ang: float, dmg: int = 1, pierce: int = 0) -> void:
	# Roguelite pierce upgrade adds to every player bullet's pierce. Damage-mult
	# / crit are applied later in _deal_damage (so they are not baked in here).
	bullets.append({
		"pos": from,
		"vel": Vector2.RIGHT.rotated(ang) * BULLET_SPEED,
		"life": BULLET_LIFE,
		"dmg": dmg,
		"pierce": pierce + up_pierce_bonus,
	})


func _spawn_homing(from: Vector2, ang: float, dmg: int, turn: float) -> void:
	# A homing missile is a normal player bullet (dmg/pierce honored by the
	# collision path) plus a "homing" flag + turn rate used in _update_bullets.
	bullets.append({
		"pos": from,
		"vel": Vector2.RIGHT.rotated(ang) * HOMING_SPEED,
		"life": HOMING_LIFE,
		"dmg": dmg,
		"pierce": up_pierce_bonus,
		"homing": true,
		"turn": turn,
	})


# ============================  SPAWNING / WAVES  ==========================
func _handle_spawning(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_interval = max(SPAWN_MIN, spawn_interval * SPAWN_RAMP)
		# Difficulty scales the wait between spawns (lower = faster spawns).
		spawn_timer = spawn_interval * float(_diff().spawn_mult)


func _spawn_pos() -> Vector2:
	match randi() % 4:
		0: return Vector2(randf() * arena.x, -24)
		1: return Vector2(randf() * arena.x, arena.y + 24)
		2: return Vector2(-24, randf() * arena.y)
		_: return Vector2(arena.x + 24, randf() * arena.y)


func _spawn_enemy() -> void:
	var pos = _spawn_pos()
	var r = randf()
	var type = "grunt"
	var hp = 1
	if r < 0.16:
		type = "tank"
		hp = 3
	elif r < 0.44:
		type = "fast"
		hp = 1
	# Elite roll: small chance, scales slightly with wave.
	var elite_ch: float = clamp(0.06 + float(wave) * 0.015, 0.06, 0.30)
	var is_elite: bool = randf() < elite_ch
	var rscale = 1.0
	if is_elite:
		hp = int(round(float(hp) * 3.0))
		rscale = 1.35
	# Difficulty scales enemy hp (min 1).
	hp = max(1, int(round(float(hp) * float(_diff().enemy_hp_mult))))
	enemies.append({
		"pos": pos, "type": type, "hp": hp, "maxhp": hp, "spin": randf() * TAU,
		"elite": is_elite, "rscale": rscale, "glow": randf() * TAU,
	})


func _spawn_boss() -> void:
	var bhp: int = max(1, int(round(float(BOSS_HP) * float(_diff().boss_hp_mult))))
	enemies.append({
		"pos": Vector2(arena.x * 0.5, -BOSS_RADIUS),
		"type": "boss", "hp": bhp, "maxhp": bhp,
		"spin": 0.0, "fire_t": 2.0,
		"pattern": 0, "pattern_t": BOSS_PATTERN_TIME,
		"telegraph": 0.0, "telegraphing": false,
		"spiral_t": 0.0, "spiral_a": 0.0,
		"elite": false, "rscale": 1.0, "glow": 0.0,
	})
	banner_t = 1.8
	banner_text = "BOSS WAVE %d" % wave
	sfx.play("wave")
	_add_trauma(0.7)


func _next_wave() -> void:
	wave += 1
	wave_kills = 0
	wave_quota = 6 + wave * 3
	spawn_interval = max(SPAWN_MIN, spawn_interval * 0.85)
	banner_t = 1.6
	banner_text = "WAVE %d" % wave
	sfx.play("wave")
	if wave >= 10:
		_unlock_ach("wave10")
	if wave % 3 == 0:
		_spawn_boss()


func _register_kill() -> void:
	wave_kills += 1
	if wave_kills >= wave_quota:
		# Wave cleared: open the upgrade draft and DEFER the next wave until the
		# player picks. _next_wave() (banner + possible boss spawn) runs only
		# after the draft closes, so wave progression is never blocked.
		if not drafting:
			draft_pending_wave = true
			_open_draft(false)


# ============================  UPGRADE DRAFT  ============================
# Roll up to 3 distinct upgrades (still below their max_stacks), freeze the game,
# and present cards. Picking one applies it for the rest of the run, then play
# resumes (and any deferred wave start fires).
func _open_draft(is_boss: bool) -> void:
	if is_boss:
		draft_pending_boss = true
	# Build the pool of upgrades still allowed to appear (below max_stacks).
	var pool: Array = []
	for u in UPGRADES:
		var uid: String = String(u.id)
		var stacks: int = int(taken_upgrades.get(uid, 0))
		if stacks < int(u.max_stacks):
			pool.append(u)
	# Nothing left to offer (everything maxed): skip the draft entirely so wave
	# progression is never blocked.
	if pool.is_empty():
		_finish_draft_no_pick()
		return
	pool.shuffle()
	draft_offers = []
	var n: int = min(3, pool.size())
	for i in n:
		draft_offers.append(pool[i])
	_layout_draft_cards()
	drafting = true
	Engine.time_scale = 1.0
	sfx.play("wave")
	queue_redraw()


# Edge case: draft was requested but there is nothing to offer. Just resume
# (running any deferred wave start) without showing a UI.
func _finish_draft_no_pick() -> void:
	drafting = false
	draft_offers = []
	draft_cards = []
	_resume_after_draft()


func _layout_draft_cards() -> void:
	# Three stacked cards centered vertically, sized to the 600x920 window.
	draft_cards = []
	var n: int = draft_offers.size()
	if n <= 0:
		return
	var margin: float = 30.0
	var card_w: float = arena.x - margin * 2.0
	var gap: float = 16.0
	var card_h: float = 96.0
	var total_h: float = float(n) * card_h + float(n - 1) * gap
	var start_y: float = arena.y * 0.5 - total_h * 0.5 + 30.0
	for i in n:
		var top: float = start_y + float(i) * (card_h + gap)
		draft_cards.append(Rect2(Vector2(margin, top), Vector2(card_w, card_h)))


func _pick_draft(idx: int) -> void:
	if not drafting:
		return
	if idx < 0 or idx >= draft_offers.size():
		return
	var u: Dictionary = draft_offers[idx]
	var uid: String = String(u.id)
	var uname: String = String(u.name)
	var accent: Color = u.accent
	_apply_upgrade(uid)
	taken_upgrades[uid] = int(taken_upgrades.get(uid, 0)) + 1
	sfx.play("powerup")
	fx.shockwave(player_pos, accent)
	_push_toast("UPGRADED: " + uname)
	drafting = false
	draft_offers = []
	draft_cards = []
	_resume_after_draft()


func _resume_after_draft() -> void:
	# Run any wave start that was deferred while drafting, then clear flags so
	# play resumes cleanly. Boss-only drafts don't start a new wave.
	Engine.time_scale = 1.0
	var start_wave: bool = draft_pending_wave
	draft_pending_wave = false
	draft_pending_boss = false
	if start_wave:
		_next_wave()
	queue_redraw()


func _apply_upgrade(id: String) -> void:
	# Each branch mutates the run-scoped upgrade vars. Caps that the pool's
	# max_stacks doesn't already enforce are clamped here defensively.
	match id:
		"overcharge":
			up_damage_mult += 0.25
		"rapidfire":
			up_firerate_mult += 0.20
		"piercing":
			up_pierce_bonus += 1
		"crit":
			up_crit_chance = min(0.85, up_crit_chance + 0.12)
		"vampiric":
			up_lifesteal = min(0.5, up_lifesteal + 0.06)
		"multishot":
			up_multishot += 1
		"adrenaline":
			up_move_mult += 0.15
		"battery":
			up_regen_bonus += 12.0
			p_energy_max += 20.0
			energy = p_energy_max
		"scholar":
			up_xp_mult += 0.30
		"munitions":
			up_bomb_gain_mult += 0.40
		"lucky":
			up_pickup_luck = min(0.6, up_pickup_luck + 0.12)
		"vitality":
			p_max_hp += 1
			player_hp = p_max_hp
		"glasscannon":
			up_damage_mult += 0.40
			p_max_hp = max(1, p_max_hp - 1)
			player_hp = min(player_hp, p_max_hp)
		_:
			pass


# ============================  WEAPON UPGRADES  ===========================
func _gain_weapon_xp(amount: float) -> void:
	# XP feeds the CURRENTLY selected weapon. Maxed weapons gain none.
	if int(weapon_level[weapon]) >= WEAPON_LEVEL_MAX:
		return
	weapon_xp += amount
	while weapon_xp >= weapon_xp_next and int(weapon_level[weapon]) < WEAPON_LEVEL_MAX:
		weapon_xp -= weapon_xp_next
		weapon_xp_next *= 1.6
		_level_up_weapon(weapon)
	if int(weapon_level[weapon]) >= WEAPON_LEVEL_MAX:
		weapon_xp = 0.0


func _level_up_weapon(idx: int) -> void:
	var cur: int = int(weapon_level[idx])
	if cur >= WEAPON_LEVEL_MAX:
		return
	cur += 1
	weapon_level[idx] = cur
	var wname: String = WEAPONS[idx].name
	banner_text = "WEAPON UP! %s Lv%d" % [wname, cur]
	banner_t = 1.6
	fx.shockwave(player_pos, hull_color)
	sfx.play("powerup")
	if cur >= WEAPON_LEVEL_MAX:
		_unlock_ach("maxed")


# ============================  ENEMY HELPERS  =============================
func _enemy_radius(type: String) -> float:
	match type:
		"boss": return BOSS_RADIUS
		"tank": return 21.0
		"fast": return 10.0
		_: return 14.0


func _e_radius(e: Dictionary) -> float:
	# Effective collision/draw radius including any elite scaling.
	var base: float = _enemy_radius(String(e.type))
	return base * float(e.get("rscale", 1.0))


func _enemy_speed(type: String) -> float:
	match type:
		"boss": return BOSS_SPEED
		"tank": return 58.0
		"fast": return 170.0
		_: return 96.0


func _enemy_score(type: String) -> int:
	match type:
		"boss": return 50
		"tank": return 5
		"fast": return 2
		_: return 1


func _enemy_color(type: String) -> Color:
	match type:
		"boss": return Color(1.0, 0.4, 0.9)
		"tank": return Color(0.66, 0.36, 0.86)
		"fast": return Color(1.0, 0.62, 0.2)
		_: return Color(0.92, 0.28, 0.34)


# ============================  UPDATES  ===================================
func _update_bullets(delta: float) -> void:
	for b in bullets:
		var vel: Vector2 = b.vel
		# Homing missiles gradually rotate their velocity toward the nearest
		# enemy, leaving a small fx trail.
		if bool(b.get("homing", false)):
			var tgt = _nearest_enemy()
			if tgt != null:
				var cur_ang: float = vel.angle()
				var want_ang: float = (tgt - b.pos).angle()
				var turn: float = float(b.get("turn", HOMING_BASE_TURN))
				var new_ang: float = rotate_toward(cur_ang, want_ang, turn * delta)
				vel = Vector2.RIGHT.rotated(new_ang) * HOMING_SPEED
				b.vel = vel
			fx.burst(b.pos, Color(1.0, 0.6, 0.3, 0.8), 1, 40.0)
		b.pos += vel * delta
		b.life -= delta
	bullets = bullets.filter(func(b):
		var p: Vector2 = b.pos
		return b.life > 0.0 and p.x > -24 and p.x < arena.x + 24 \
			and p.y > -24 and p.y < arena.y + 24)


func _update_enemy_bullets(delta: float) -> void:
	for b in enemy_bullets:
		var vel: Vector2 = b.vel
		b.pos += vel * delta
		b.life -= delta
	enemy_bullets = enemy_bullets.filter(func(b):
		var p: Vector2 = b.pos
		return b.life > 0.0 and p.x > -24 and p.x < arena.x + 24 \
			and p.y > -24 and p.y < arena.y + 24)


func _update_enemies(delta: float) -> void:
	for e in enemies:
		var type: String = e.type
		var epos: Vector2 = e.pos
		var to_player: Vector2 = player_pos - epos
		if to_player.length() > 0.01:
			var espd: float = _enemy_speed(type) * float(_diff().enemy_speed_mult)
			epos += to_player.normalized() * espd * delta
		e.pos = epos
		e.spin = float(e.spin) + delta * (1.0 if type == "boss" else 2.0)
		if bool(e.get("elite", false)):
			e.glow = float(e.get("glow", 0.0)) + delta * 5.0
		if type == "boss":
			_update_boss(e, epos, delta)


func _update_boss(e: Dictionary, epos: Vector2, delta: float) -> void:
	# Pattern cycle: switch pattern every BOSS_PATTERN_TIME seconds.
	var pt: float = float(e.get("pattern_t", BOSS_PATTERN_TIME)) - delta
	if pt <= 0.0:
		pt = BOSS_PATTERN_TIME
		e.pattern = (int(e.get("pattern", 0)) + 1) % 3
	e.pattern_t = pt

	# Ongoing spiral sweep (pattern 2) fires continuously while active.
	var sp_t: float = float(e.get("spiral_t", 0.0))
	if sp_t > 0.0:
		sp_t -= delta
		e.spiral_t = sp_t
		e.spiral_a = float(e.get("spiral_a", 0.0)) + delta * 6.0
		_boss_spiral_tick(e, epos)

	# Telegraph countdown -> fire when it reaches zero.
	if bool(e.get("telegraphing", false)):
		var tg: float = float(e.get("telegraph", 0.0)) - delta
		e.telegraph = tg
		if tg <= 0.0:
			e.telegraphing = false
			_boss_fire_pattern(e, epos)
	else:
		var ft: float = float(e.get("fire_t", 2.0)) - delta
		if ft <= 0.0:
			ft = 2.2
			e.telegraphing = true
			e.telegraph = BOSS_TELEGRAPH
		e.fire_t = ft


func _boss_fire_pattern(e: Dictionary, epos: Vector2) -> void:
	match int(e.get("pattern", 0)):
		0:
			_boss_volley(epos)
		1:
			_boss_aimed(epos)
		2:
			# Start a timed rotating spiral sweep.
			e.spiral_t = 1.5
			e.spiral_a = randf() * TAU
			_boss_spiral_tick(e, epos)
			sfx.play("shoot")
			_add_trauma(0.1)
		_:
			_boss_volley(epos)


func _ebullet_speed() -> float:
	return BOSS_BULLET_SPEED * float(_diff().ebullet_speed_mult)


func _boss_volley(from: Vector2) -> void:
	# P0: full radial volley.
	var n = 16
	var base: float = (player_pos - from).angle()
	var bs: float = _ebullet_speed()
	for i in n:
		var a = base + TAU * float(i) / float(n)
		enemy_bullets.append({
			"pos": from,
			"vel": Vector2.RIGHT.rotated(a) * bs,
			"life": 4.0,
		})
	sfx.play("shoot")
	_add_trauma(0.12)


func _boss_aimed(from: Vector2) -> void:
	# P1: 3-5 shot spread aimed at the player.
	var base: float = (player_pos - from).angle()
	var n: int = 3 + (randi() % 3)   # 3..5
	var spread: float = 0.34
	for i in n:
		var frac = 0.0
		if n > 1:
			frac = float(i) / float(n - 1) - 0.5
		var a: float = base + frac * spread * 2.0
		enemy_bullets.append({
			"pos": from,
			"vel": Vector2.RIGHT.rotated(a) * (_ebullet_speed() * 1.4),
			"life": 4.0,
		})
	sfx.play("shoot")
	_add_trauma(0.1)


func _boss_spiral_tick(e: Dictionary, from: Vector2) -> void:
	# P2: a couple of bullets along a steadily rotating angle.
	var a: float = float(e.get("spiral_a", 0.0))
	var bs: float = _ebullet_speed()
	for k in 2:
		var aa: float = a + float(k) * PI
		enemy_bullets.append({
			"pos": from,
			"vel": Vector2.RIGHT.rotated(aa) * bs,
			"life": 4.0,
		})


func _update_pickups(delta: float) -> void:
	for pk in pickups:
		var vel: Vector2 = pk.vel
		pk.pos += vel * delta
		pk.vel = vel * 0.96
		pk.life -= delta
	pickups = pickups.filter(func(pk): return pk.life > 0.0)


func _nearest_enemy():
	var best = null
	var bd = INF
	for e in enemies:
		var d: float = player_pos.distance_to(e.pos)
		if d < bd:
			bd = d
			best = e.pos
	return best


func _maybe_drop(type: String, pos: Vector2, elite: bool = false) -> void:
	var chance = 0.10
	if type == "tank":
		chance = 0.30
	elif type == "boss":
		chance = 1.0
	if elite:
		chance = max(chance, 0.55)   # elites drop more often
	# Lucky upgrade adds flat drop chance (capped at 1.0).
	chance = min(1.0, chance + up_pickup_luck)
	if randf() > chance:
		return
	var kinds = ["rapid", "spread", "shield", "heal", "energy"]
	pickups.append({
		"pos": pos,
		"vel": Vector2.RIGHT.rotated(randf() * TAU) * 24.0,
		"type": _roll_pickup_kind(kinds),
		"life": 8.0,
	})


func _roll_pickup_kind(kinds: Array) -> String:
	# "upgrade" is a rare special drop; otherwise a standard powerup.
	if randf() < 0.10:
		return "upgrade"
	return kinds[randi() % kinds.size()]


func _apply_pickup(kind: String) -> void:
	match kind:
		"rapid": buf_rapid = 7.0
		"spread": buf_spread = 7.0
		"shield": shield = 3
		"heal": player_hp = min(p_max_hp, player_hp + 1)
		"energy": energy = p_energy_max
		"upgrade": _level_up_weapon(weapon)  # instant +1 to current weapon
	fx.shockwave(player_pos, _pickup_color(kind))
	sfx.play("powerup")


func _pickup_color(kind: String) -> Color:
	match kind:
		"rapid": return Color(1.0, 0.85, 0.3)
		"spread": return Color(0.5, 1.0, 0.6)
		"shield": return Color(0.4, 0.7, 1.0)
		"heal": return Color(1.0, 0.4, 0.5)
		"upgrade": return Color(1.0, 0.55, 1.0)
		_: return Color(0.3, 0.9, 1.0)  # energy


func _on_enemy_killed(type: String, pos: Vector2, elite: bool = false) -> void:
	var base = _enemy_score(type)
	if elite:
		base *= 3        # elites are worth ~3x score / XP / bomb
	combo = min(COMBO_MAX, combo + 1)
	combo_t = COMBO_WINDOW
	# Difficulty score multiplier folds into scoring (and XP / bomb gains).
	var sm: float = float(_diff().score_mult)
	score += int(round(float(base * combo) * sm))
	# Weapon XP: scaled by enemy value, combo, difficulty, and Scholar upgrade.
	_gain_weapon_xp(float(base) * float(combo) * sm * up_xp_mult)
	# Bomb charge: scaled by enemy value, combo, difficulty, Munitions upgrade.
	bomb_charge = min(BOMB_MAX,
		bomb_charge + (float(base) * 0.9 * float(combo) + 1.5) * sm * up_bomb_gain_mult)
	# Meta currency: +1 per kill scaled by enemy value + difficulty (rounded up
	# so every kill is worth at least 1). Accumulated; persisted on game over.
	run_credits += max(1, int(round(float(CREDITS_PER_KILL) * float(base) * sm)))
	# --- Achievement tracking ---
	run_kills += 1
	_unlock_ach("first_blood")
	if combo >= COMBO_MAX:
		_unlock_ach("combo25")
	if type == "boss":
		_unlock_ach("boss_slayer")
	if elite:
		elite_kills_total += 1
		if elite_kills_total >= 10:
			_unlock_ach("elite_hunter")
		else:
			_save_ach()   # persist the running lifetime elite count
	var col = _enemy_color(type)
	if elite:
		col = col.lightened(0.2)
	if type == "boss":
		for i in 6:
			fx.explosion(pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0, 40),
				col, randf_range(1.2, 2.2))
		fx.shockwave(pos, col)
		_add_trauma(0.9)
		_trigger_hitstop()
	else:
		fx.explosion(pos, col, 0.7 if type == "fast" else 1.0)
		_add_trauma(0.18 if type == "tank" else 0.10)
		if elite:
			fx.shockwave(pos, Color(1.0, 0.84, 0.25))
	sfx.play("explode")
	_maybe_drop(type, pos, elite)
	# A boss kill always grants an upgrade draft (flagged so the banner reads
	# differently). _register_kill below may also flag a wave-clear draft; the
	# guard in _open_draft prevents opening two at once, and any deferred wave
	# start still fires when the (single) draft closes.
	if type == "boss":
		draft_pending_boss = true
	_register_kill()
	# If the boss did not also complete the wave quota, _register_kill won't
	# have opened a draft -> open the boss draft now so it never gets skipped.
	if draft_pending_boss and not drafting and not draft_pending_wave:
		_open_draft(true)


func _damage_player() -> void:
	# Shield absorbs first.
	if shield > 0:
		shield -= 1
		invuln = 0.6
		fx.shockwave(player_pos, Color(0.4, 0.7, 1.0))
		sfx.play("hit")
		_add_trauma(0.2)
		return
	player_hp -= 1
	invuln = 1.1
	fx.burst(player_pos, Color(1.0, 0.5, 0.4), 18, 200.0)
	sfx.play("hit")
	_add_trauma(0.5)
	_trigger_hitstop()
	if player_hp <= 0:
		game_over = true


# ============================  COLLISIONS  ================================
func _resolve_collisions() -> void:
	# Player bullets vs enemies. Bullets carry dmg + pierce; a piercing bullet
	# survives the hit (pierce decremented) instead of being consumed.
	var spent = {}
	for bi in bullets.size():
		var b: Dictionary = bullets[bi]
		var bp: Vector2 = b.pos
		var bdmg: int = int(b.get("dmg", 1))
		var bpierce: int = int(b.get("pierce", 0))
		for e in enemies:
			if int(e.hp) <= 0:
				continue
			var type: String = e.type
			var er: float = _e_radius(e)
			if bp.distance_to(e.pos) <= er + BULLET_RADIUS:
				_deal_damage(e, bdmg)
				if type == "boss":
					_add_trauma(0.06)
				if int(e.hp) <= 0:
					_on_enemy_killed(type, e.pos, bool(e.get("elite", false)))
				# Consume the bullet unless it can still pierce.
				if bpierce > 0:
					bpierce -= 1
					b.pierce = bpierce
				else:
					spent[bi] = true
					break
	if not spent.is_empty():
		var kept = []
		for i in bullets.size():
			if not spent.has(i):
				kept.append(bullets[i])
		bullets = kept
	enemies = enemies.filter(func(e): return int(e.hp) > 0)

	# Enemy bullets vs player.
	if invuln <= 0.0:
		var keep_eb = []
		var hit = false
		for eb in enemy_bullets:
			var p: Vector2 = eb.pos
			if not hit and p.distance_to(player_pos) <= BULLET_RADIUS + PLAYER_RADIUS:
				hit = true
				continue
			keep_eb.append(eb)
		enemy_bullets = keep_eb
		if hit:
			_damage_player()

	# Enemy bodies vs player.
	if invuln <= 0.0 and not game_over:
		for e in enemies:
			var _type: String = e.type
			if e.pos.distance_to(player_pos) <= _e_radius(e) + PLAYER_RADIUS:
				e.pos += (e.pos - player_pos).normalized() * 70.0
				_damage_player()
				break

	# Pickups vs player.
	if not pickups.is_empty():
		var kept_pk = []
		for pk in pickups:
			var ppos: Vector2 = pk.pos
			if ppos.distance_to(player_pos) <= PLAYER_RADIUS + 14.0:
				var kind: String = pk.type
				_apply_pickup(kind)
			else:
				kept_pk.append(pk)
		pickups = kept_pk


# ============================  HUD LAYOUT  ================================
# Drawing-only constants for a clean, consistent HUD on a 480x720 screen.
# Changing these never affects gameplay/input/persistence.
const HUD_MARGIN: float = 22.0      # screen-edge margin (roomy "여백")
const GAUGE_X: float = 22.0         # left-edge gauge stack x
const GAUGE_Y: float = 22.0         # first gauge top y
const GAUGE_W: float = 160.0        # gauge bar width
const GAUGE_H: float = 13.0         # gauge bar height
const GAUGE_GAP: float = 10.0       # vertical gap between gauges
const HUD_FONT: int = 14            # standard label font size
const HUD_FONT_SM: int = 12         # compact tag font size
const SCORE_FONT: int = 22          # score font size
const BANNER_FONT: int = 30         # wave/weapon-up banner font
const TOAST_FONT: int = 16          # achievement toast font


# ============================  THEME / UI KIT  ===========================
# A small cohesive palette + drawing helpers shared by every menu, panel and
# button so the whole UI speaks one visual language ("tactical HUD" look).
# Drawing-only: none of this touches gameplay/input/persistence.
const TH_BG: Color = Color(0.04, 0.06, 0.11)        # deep navy base
const TH_BG2: Color = Color(0.02, 0.02, 0.05)       # near-black (gradient foot)
const TH_PANEL: Color = Color(0.07, 0.09, 0.14, 0.92)   # panel fill
const TH_ACCENT: Color = Color(0.30, 0.78, 1.0)     # primary cyan
const TH_ACCENT2: Color = Color(1.0, 0.78, 0.32)    # warm gold
const TH_DANGER: Color = Color(1.0, 0.38, 0.40)     # red
const TH_TEXT: Color = Color(0.95, 0.97, 1.0)       # near-white
const TH_TEXT_DIM: Color = Color(0.62, 0.68, 0.80)  # grey-blue


# Centered text (cx = horizontal center).
func _text_center(cx: float, baseline_y: float, text: String, size: int, color: Color) -> void:
	var tw: float = _text_width(text, size)
	draw_string(_font, Vector2(cx - tw * 0.5, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# Glowing centered text: a few low-alpha offset copies under a crisp top layer.
func _text_glow(cx: float, baseline_y: float, text: String, size: int, color: Color, glow: Color) -> void:
	var tw: float = _text_width(text, size)
	var x: float = cx - tw * 0.5
	var g: Color = Color(glow.r, glow.g, glow.b, 0.16)
	for off in [Vector2(0, 2), Vector2(2, 0), Vector2(-2, 0), Vector2(0, -2), Vector2(3, 3)]:
		draw_string(_font, Vector2(x, baseline_y) + off, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, g)
	draw_string(_font, Vector2(x, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# Themed panel: drop shadow + fill + accent border + top accent bar + corner
# ticks. CanvasItem has no rounded-rect, so polish is faked with layered rects.
func _panel(rect: Rect2, accent: Color, hot: bool = false) -> void:
	# Drop shadow (offset, ~30% black).
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.30), true)
	# Body fill (slightly brighter when hot).
	var fill: Color = TH_PANEL
	if hot:
		fill = Color(0.10, 0.14, 0.20, 0.95)
	draw_rect(rect, fill, true)
	# Thin top accent bar.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)),
		Color(accent.r, accent.g, accent.b, 0.85 if hot else 0.55), true)
	# 1px accent border (glow brighter when hot).
	var bcol: Color = accent.lerp(Color.WHITE, 0.35) if hot else Color(accent.r, accent.g, accent.b, 0.65)
	if hot:
		draw_rect(rect.grow(2.0), Color(accent.r, accent.g, accent.b, 0.22), false, 3.0)
	draw_rect(rect, bcol, false, 1.5 if not hot else 2.0)
	# L-shaped corner ticks.
	var tk: float = 10.0
	var p0: Vector2 = rect.position
	var p1: Vector2 = rect.position + Vector2(rect.size.x, 0)
	var p2: Vector2 = rect.position + rect.size
	var p3: Vector2 = rect.position + Vector2(0, rect.size.y)
	var tcol: Color = accent.lerp(Color.WHITE, 0.5)
	draw_line(p0, p0 + Vector2(tk, 0), tcol, 2.0)
	draw_line(p0, p0 + Vector2(0, tk), tcol, 2.0)
	draw_line(p1, p1 + Vector2(-tk, 0), tcol, 2.0)
	draw_line(p1, p1 + Vector2(0, tk), tcol, 2.0)
	draw_line(p2, p2 + Vector2(-tk, 0), tcol, 2.0)
	draw_line(p2, p2 + Vector2(0, -tk), tcol, 2.0)
	draw_line(p3, p3 + Vector2(tk, 0), tcol, 2.0)
	draw_line(p3, p3 + Vector2(0, -tk), tcol, 2.0)


# Themed button. hot = hovered/selected (brighter fill + glow border).
func _btn(rect: Rect2, label: String, hot: bool, accent: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 2), rect.size), Color(0, 0, 0, 0.28), true)
	var fill: Color = Color(accent.r, accent.g, accent.b, 0.22) if hot \
		else Color(0.10, 0.13, 0.19, 0.92)
	draw_rect(rect, fill, true)
	if hot:
		draw_rect(rect.grow(2.0), Color(accent.r, accent.g, accent.b, 0.25), false, 3.0)
	var bcol: Color = accent.lerp(Color.WHITE, 0.4) if hot else Color(accent.r, accent.g, accent.b, 0.55)
	draw_rect(rect, bcol, false, 2.0 if hot else 1.5)
	var lsize: int = 18
	var tcol: Color = Color.WHITE if hot else TH_TEXT
	_text_center(rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.5 + lsize * 0.36, label, lsize, tcol)


# A small labeled stat mini-bar (used on class cards). frac in [0,1].
func _stat_bar(pos: Vector2, w: float, frac: float, label: String, value: String, accent: Color) -> void:
	var bar_h: float = 6.0
	var lab_size: int = 11
	# Label (left) + value (right) above the bar.
	draw_string(_font, pos + Vector2(0, -2), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, lab_size, TH_TEXT_DIM)
	_draw_text_right(pos.x + w, pos.y - 2, value, lab_size, TH_TEXT)
	var by: float = pos.y + 2.0
	draw_rect(Rect2(Vector2(pos.x, by), Vector2(w, bar_h)), Color(0, 0, 0, 0.5), true)
	draw_rect(Rect2(Vector2(pos.x, by), Vector2(w * clamp(frac, 0.0, 1.0), bar_h)), accent, true)
	draw_rect(Rect2(Vector2(pos.x, by), Vector2(w, bar_h)), Color(1, 1, 1, 0.18), false, 1.0)


# Full-screen menu backdrop: navy→near-black gradient + drifting accent glow +
# soft vignette, driven by `t` so menus feel alive. Stars are drawn separately.
func _draw_menu_bg() -> void:
	# Vertical gradient as a stack of translucent bands.
	var bands: int = 10
	for i in bands:
		var f: float = float(i) / float(bands - 1)
		var c: Color = TH_BG.lerp(TH_BG2, f)
		var y0: float = arena.y * float(i) / float(bands)
		var y1: float = arena.y * float(i + 1) / float(bands)
		draw_rect(Rect2(Vector2(0, y0), Vector2(arena.x, y1 - y0 + 1.0)), c, true)
	# Two slow drifting accent glows.
	var g1: Vector2 = Vector2(arena.x * (0.5 + 0.32 * sin(t * 0.25)),
		arena.y * (0.30 + 0.10 * cos(t * 0.21)))
	var g2: Vector2 = Vector2(arena.x * (0.5 + 0.28 * cos(t * 0.18)),
		arena.y * (0.72 + 0.08 * sin(t * 0.16)))
	draw_circle(g1, 220.0, Color(TH_ACCENT.r, TH_ACCENT.g, TH_ACCENT.b, 0.05))
	draw_circle(g2, 200.0, Color(TH_ACCENT2.r, TH_ACCENT2.g, TH_ACCENT2.b, 0.04))
	# Soft vignette: darker rims top + bottom.
	draw_rect(Rect2(ZERO, Vector2(arena.x, 70.0)), Color(0, 0, 0, 0.28), true)
	draw_rect(Rect2(Vector2(0, arena.y - 70.0), Vector2(arena.x, 70.0)), Color(0, 0, 0, 0.32), true)


# Measure rendered width of a string at a given size.
func _text_width(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Draw left-aligned text with a baseline at (x, baseline_y).
func _draw_text_left(x: float, baseline_y: float, text: String, size: int, color: Color) -> void:
	draw_string(_font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# Draw text right-aligned so its right edge sits at right_x (never clips off-screen).
func _draw_text_right(right_x: float, baseline_y: float, text: String, size: int, color: Color) -> void:
	var tw: float = _text_width(text, size)
	draw_string(_font, Vector2(right_x - tw, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# ============================  DRAW  ======================================
func _draw() -> void:
	# --- Class-select screen ---
	if state == STATE_SELECT:
		draw_set_transform(ZERO, 0.0, ONE)
		_draw_menu_bg()
		_draw_stars()
		_draw_class_select()
		return

	# --- WORLD (shaken) ---
	draw_set_transform(shake_offset, 0.0, ONE)
	_draw_background()
	_draw_stars()
	for pk in pickups:
		_draw_pickup(pk)
	for e in enemies:
		_draw_enemy(e)
	for b in enemy_bullets:
		_draw_enemy_bullet(b)
	for b in bullets:
		_draw_bullet(b)
	if laser_firing and not game_over:
		_draw_laser()
	if not game_over:
		_draw_player()
	# --- HUD/UI (no shake) ---
	draw_set_transform(ZERO, 0.0, ONE)
	_draw_ui()
	_draw_gauges()
	_draw_hud()
	_draw_banner()
	_draw_toasts()
	if game_over:
		_draw_game_over()
	if paused and not game_over:
		_draw_pause()
	if drafting and not game_over:
		_draw_draft()


func _draw_background() -> void:
	if textures.has("background"):
		var tex: Texture2D = textures["background"]
		var ts = tex.get_size()
		if ts.x > 0 and ts.y > 0:
			draw_set_transform(shake_offset, 0.0, Vector2(arena.x / ts.x, arena.y / ts.y))
			draw_texture(tex, ZERO)
			draw_set_transform(shake_offset, 0.0, ONE)
		return
	draw_rect(Rect2(ZERO, arena), Color(0.04, 0.05, 0.09))


func _draw_stars() -> void:
	if textures.has("background"):
		return
	for s in stars:
		var spd: float = s.spd
		var sz: float = s.size
		var a: float = 0.4 + 0.6 * absf(sin(t * 2.0 + spd))
		draw_circle(s.pos, sz, Color(0.8, 0.85, 1.0, a))


func _draw_sprite(key: String, pos: Vector2, radius: float, rot: float, tint: Color = Color.WHITE) -> void:
	var tex: Texture2D = textures[key]
	var ts = tex.get_size()
	var maxdim: float = max(ts.x, ts.y)
	var sc = (radius * 2.0) / max(maxdim, 1.0)
	draw_set_transform(pos + shake_offset, rot, Vector2(sc, sc))
	draw_texture(tex, -ts * 0.5, tint)
	draw_set_transform(shake_offset, 0.0, ONE)


func _draw_player() -> void:
	if invuln > 0.0 and int(invuln * 14.0) % 2 == 0:
		# Still show shield ring even while blinking.
		if shield > 0:
			_draw_shield()
		return
	var pkey: String = "pship" + str(class_idx)
	if not textures.has(pkey):
		pkey = "player"
	if textures.has(pkey):
		# Per-class ship sprite, tinted toward the class color.
		_draw_sprite(pkey, player_pos, (PLAYER_RADIUS + 6.0) * hull_scale, player_rot, hull_color.lerp(Color.WHITE, 0.45))
		if shield > 0:
			_draw_shield()
		return

	draw_set_transform(player_pos + shake_offset, player_rot, Vector2(hull_scale, hull_scale))
	if thrust > 0.05:
		var flame = 10.0 + thrust * 14.0 + sin(t * 40.0) * 4.0
		var fpts = PackedVector2Array([
			Vector2(-12, -5), Vector2(-12 - flame, 0), Vector2(-12, 5)])
		draw_colored_polygon(fpts, Color(1.0, 0.7, 0.2, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12, -3), Vector2(-12 - flame * 0.6, 0), Vector2(-12, 3)]),
			Color(1.0, 0.95, 0.6, 0.95))
	var hull = PackedVector2Array([
		Vector2(22, 0), Vector2(2, -13), Vector2(-14, -15),
		Vector2(-8, 0), Vector2(-14, 15), Vector2(2, 13)])
	# Hull tinted by the class color (procedural fallback only).
	draw_colored_polygon(hull, hull_color)
	draw_polyline(hull + PackedVector2Array([hull[0]]), hull_color.lerp(Color.WHITE, 0.55), 2.0)
	draw_circle(Vector2(4, 0), 5.0, Color(0.85, 0.97, 1.0))
	draw_circle(Vector2(4, 0), 2.5, Color(0.2, 0.4, 0.7))
	if muzzle_flash > 0.0:
		draw_circle(Vector2(24, 0), 7.0, Color(1.0, 0.95, 0.6, 0.9))
	draw_set_transform(shake_offset, 0.0, ONE)

	if shield > 0:
		_draw_shield()


func _draw_shield() -> void:
	var pulse = 0.6 + 0.4 * sin(t * 6.0)
	var col = Color(0.4, 0.7, 1.0, 0.35 + 0.25 * pulse)
	var ring_r: float = PLAYER_RADIUS * hull_scale + 9.0
	draw_set_transform(shake_offset, 0.0, ONE)
	draw_arc(player_pos, ring_r, 0, TAU, 40, col, 3.0)
	for i in shield:
		var a = -PI / 2.0 + TAU * float(i) / 3.0
		draw_circle(player_pos + Vector2.RIGHT.rotated(a) * ring_r,
			2.5, Color(0.7, 0.9, 1.0))


func _draw_enemy(e: Dictionary) -> void:
	var type: String = e.type
	var r: float = _e_radius(e)
	var spin: float = e.spin
	var epos: Vector2 = e.pos

	# Boss telegraph: pulsing warning ring just before a volley.
	if type == "boss" and bool(e.get("telegraphing", false)):
		var tg: float = clamp(float(e.get("telegraph", 0.0)) / BOSS_TELEGRAPH, 0.0, 1.0)
		var warn = Color(1.0, 0.9, 0.2, 0.4 + 0.4 * (1.0 - tg))
		draw_arc(epos + shake_offset, r + 14.0 + (1.0 - tg) * 16.0, 0, TAU, 44, warn, 4.0)

	# Elite glow ring (drawn under the body, in screen space).
	if bool(e.get("elite", false)) and type != "boss":
		var gp: float = sin(float(e.get("glow", 0.0))) * 0.5 + 0.5
		var gold = Color(1.0, 0.84, 0.25)
		var gc = Color(gold.r, gold.g, gold.b, 0.35 + gp * 0.35)
		draw_arc(epos + shake_offset, r + 6.0 + gp * 5.0, 0, TAU, 28, gc, 3.0)
		draw_arc(epos + shake_offset, r + 2.0, 0, TAU, 24, gold, 2.0)

	# Boss has bespoke drawing + HP bar.
	if type == "boss":
		draw_set_transform(epos + shake_offset, spin, ONE)
		var body_col = Color(0.55, 0.12, 0.45)
		if bool(e.get("telegraphing", false)):
			body_col = body_col.lightened(0.5)   # flash before a volley
		var ring = _ngon(8, r)
		draw_colored_polygon(ring, body_col)
		draw_polyline(ring + PackedVector2Array([ring[0]]), Color(1.0, 0.5, 0.9), 3.0)
		draw_circle(ZERO, r * 0.55, Color(1.0, 0.3, 0.8))
		draw_circle(ZERO, r * 0.28, Color(1.0, 0.9, 0.6))
		draw_set_transform(shake_offset, 0.0, ONE)
		var frac: float = float(e.hp) / float(e.maxhp)
		var bw = 90.0
		var bp = epos + Vector2(-bw * 0.5, -r - 16.0) + shake_offset
		draw_rect(Rect2(bp, Vector2(bw, 7)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bp, Vector2(bw * frac, 7)), Color(1.0, 0.3, 0.5))
		draw_rect(Rect2(bp, Vector2(bw, 7)), Color(1, 1, 1, 0.7), false, 1.0)
		return

	# Sprite path for normal enemies: face the player (Kenney art points "down").
	if textures.has(type):
		_draw_sprite(type, epos, r, (player_pos - epos).angle() - PI / 2.0)
		return

	draw_set_transform(epos + shake_offset, spin, ONE)
	match type:
		"tank":
			var hexp = _ngon(6, r)
			draw_colored_polygon(hexp, Color(0.66, 0.36, 0.86))
			draw_polyline(hexp + PackedVector2Array([hexp[0]]), Color(0.9, 0.7, 1.0), 2.0)
			draw_circle(ZERO, r * 0.45, Color(1.0, 0.85, 0.3))
		"fast":
			var tri = PackedVector2Array([
				Vector2(r, 0), Vector2(-r * 0.7, -r * 0.8), Vector2(-r * 0.7, r * 0.8)])
			draw_colored_polygon(tri, Color(1.0, 0.62, 0.2))
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(1.0, 0.85, 0.5), 1.5)
		_:
			var spike = _star(4, r, r * 0.5)
			draw_colored_polygon(spike, Color(0.92, 0.28, 0.34))
			draw_polyline(spike + PackedVector2Array([spike[0]]), Color(1.0, 0.6, 0.6), 1.5)
			draw_circle(ZERO, r * 0.35, Color(1.0, 0.95, 0.9))
			draw_circle(ZERO, r * 0.16, Color(0.1, 0.0, 0.0))
	# Elite: brighter inner core overlay.
	if bool(e.get("elite", false)):
		draw_circle(ZERO, r * 0.5, Color(1.0, 0.95, 0.55, 0.55))
	draw_set_transform(shake_offset, 0.0, ONE)


func _draw_bullet(b: Dictionary) -> void:
	var p: Vector2 = b.pos
	var v: Vector2 = b.vel
	# Homing missiles get a distinct orange dart + tail (always procedural).
	if bool(b.get("homing", false)):
		var dir: Vector2 = v
		if dir.length() < 0.001:
			dir = Vector2.RIGHT.rotated(player_rot)
		dir = dir.normalized()
		var tailh = p - dir * 14.0
		draw_line(tailh, p, Color(1.0, 0.55, 0.2, 0.55), 5.0)
		draw_circle(p, BULLET_RADIUS + 1.5, Color(1.0, 0.5, 0.2, 0.4))
		draw_circle(p, BULLET_RADIUS - 1.0, Color(1.0, 0.85, 0.5))
		draw_line(p, p + dir * 6.0, Color(1.0, 0.95, 0.7), 2.0)
		return
	if textures.has("bullet"):
		_draw_sprite("bullet", p, BULLET_RADIUS + 3.0, v.angle())
		return
	var tail = p - v.normalized() * 10.0
	draw_line(tail, p, Color(1.0, 0.8, 0.3, 0.5), 4.0)
	draw_circle(p, BULLET_RADIUS + 2.0, Color(1.0, 0.85, 0.4, 0.35))
	draw_circle(p, BULLET_RADIUS, Color(1.0, 0.97, 0.7))


func _draw_laser() -> void:
	# Bright core line + outer glow + a muzzle spark. Drawn only while firing.
	var dir: Vector2 = Vector2.RIGHT.rotated(player_rot)
	var nose: Vector2 = player_pos + dir * (PLAYER_RADIUS + 6.0)
	var lp: Dictionary = _laser_params()
	var half_w: float = float(lp.half_w)
	var col: Color = hull_color.lerp(Color(0.6, 1.0, 1.0), 0.4)
	# Outer glow.
	draw_line(nose, laser_end, Color(col.r, col.g, col.b, 0.22), half_w * 2.4)
	draw_line(nose, laser_end, Color(col.r, col.g, col.b, 0.40), half_w * 1.3)
	# Bright core.
	draw_line(nose, laser_end, Color(1.0, 1.0, 1.0, 0.95), max(2.0, half_w * 0.5))
	# Muzzle spark + a soft endpoint flare.
	draw_circle(nose, half_w * 0.9, Color(1.0, 1.0, 0.9, 0.8))
	draw_circle(laser_end, half_w * 0.8, Color(col.r, col.g, col.b, 0.5))


func _draw_enemy_bullet(b: Dictionary) -> void:
	var p: Vector2 = b.pos
	draw_circle(p, BULLET_RADIUS + 2.0, Color(1.0, 0.3, 0.6, 0.35))
	draw_circle(p, BULLET_RADIUS, Color(1.0, 0.55, 0.85))


func _draw_pickup(pk: Dictionary) -> void:
	var p: Vector2 = pk.pos
	var kind: String = pk.type
	var life: float = pk.life
	# Blink near despawn.
	if life < 2.0 and int(life * 8.0) % 2 == 0:
		return
	var col = _pickup_color(kind)
	var bob = sin(t * 4.0 + p.x) * 2.0
	var c = p + Vector2(0, bob)
	draw_circle(c, 12.0, Color(col.r, col.g, col.b, 0.25))
	draw_arc(c, 12.0, 0, TAU, 24, col, 2.0)
	var letter = kind.substr(0, 1).to_upper()
	draw_string(_font, c + Vector2(-5, 5), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


# ----- HUD -----
func _draw_ui() -> void:
	var mp = get_global_mouse_position()
	# --- FIRE button (circular hit-target; keep center/radius). ---
	var fhot = mp.distance_to(fire_btn) <= fire_btn_r \
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fhover: bool = mp.distance_to(fire_btn) <= fire_btn_r
	if fhot or fhover:
		draw_circle(fire_btn, fire_btn_r + 4.0, Color(1.0, 0.35, 0.4, 0.18))
	draw_circle(fire_btn, fire_btn_r, Color(0.85, 0.22, 0.28, 0.9 if fhot else 0.55))
	draw_arc(fire_btn, fire_btn_r, 0, TAU, 40,
		Color(1.0, 0.7, 0.7, 1.0 if fhot else 0.85), 2.5 if fhot else 2.0)
	draw_arc(fire_btn, fire_btn_r - 6.0, 0, TAU, 36, Color(1.0, 0.8, 0.8, 0.35), 1.5)
	var fsize: int = 20
	_text_center(fire_btn.x, fire_btn.y + fsize * 0.35, "FIRE", fsize, Color.WHITE)

	# --- WEAPON button (circular hit-target; keep center/radius). ---
	var whover: bool = mp.distance_to(weapon_btn) <= weapon_btn_r
	if whover:
		draw_circle(weapon_btn, weapon_btn_r + 4.0, Color(TH_ACCENT.r, TH_ACCENT.g, TH_ACCENT.b, 0.18))
	draw_circle(weapon_btn, weapon_btn_r, Color(0.14, 0.34, 0.55, 0.85 if whover else 0.6))
	draw_arc(weapon_btn, weapon_btn_r, 0, TAU, 36,
		TH_ACCENT.lerp(Color.WHITE, 0.3) if whover else Color(0.7, 0.85, 1.0, 0.85), 2.0)
	var wname: String = WEAPONS[weapon].name
	_text_center(weapon_btn.x, weapon_btn.y - 1.0, wname, HUD_FONT_SM, Color.WHITE)
	_text_center(weapon_btn.x, weapon_btn.y + 13.0, "Lv%d" % int(weapon_level[weapon]),
		HUD_FONT_SM, TH_ACCENT2)


func _draw_gauges() -> void:
	# Left-edge GAUGE STACK (HP, EN, BOMB, XP) on a subtle dark panel.
	# Four evenly-spaced thin bars; consistent width/height/gaps/margins.
	var stack_count: int = 4
	var stack_h: float = stack_count * GAUGE_H + (stack_count - 1) * GAUGE_GAP
	# Themed panel behind the stack; padded so it clears the inline labels.
	var pad: float = 10.0
	var label_room: float = 46.0
	_panel(Rect2(
		Vector2(GAUGE_X - pad, GAUGE_Y - pad),
		Vector2(GAUGE_W + label_room + pad, stack_h + pad * 2.0)),
		TH_ACCENT, false)

	var gy: float = GAUGE_Y
	# HP.
	_draw_bar(Vector2(GAUGE_X, gy), Vector2(GAUGE_W, GAUGE_H),
		float(player_hp) / float(max(1, p_max_hp)),
		Color(0.35, 0.9, 0.4), "HP")
	gy += GAUGE_H + GAUGE_GAP
	# ENERGY (flashes red when below current shot cost).
	var w: Dictionary = WEAPONS[weapon]
	var cur_cost: float = float(w.cost) * fire_cost_mult
	var low = energy < cur_cost
	var ecol = Color(0.95, 0.4, 0.4) if (low and int(t * 10.0) % 2 == 0) \
		else Color(0.3, 0.8, 1.0)
	_draw_bar(Vector2(GAUGE_X, gy), Vector2(GAUGE_W, GAUGE_H), energy / p_energy_max, ecol, "EN")
	gy += GAUGE_H + GAUGE_GAP
	# BOMB (magenta; pulses when ready).
	var bomb_frac: float = clamp(bomb_charge / BOMB_MAX, 0.0, 1.0)
	var bomb_ready: bool = bomb_charge >= BOMB_MAX
	var bcol: Color = Color(1.0, 0.35, 0.9)
	if bomb_ready:
		var pulse: float = sin(bomb_pulse) * 0.5 + 0.5
		bcol = Color(1.0, 0.4 + 0.4 * pulse, 0.5)
	_draw_bar(Vector2(GAUGE_X, gy), Vector2(GAUGE_W, GAUGE_H), bomb_frac, bcol, "BOMB")
	gy += GAUGE_H + GAUGE_GAP
	# Weapon XP toward next level (or MAX).
	var maxed: bool = int(weapon_level[weapon]) >= WEAPON_LEVEL_MAX
	var xp_frac: float = 1.0 if maxed else clamp(weapon_xp / weapon_xp_next, 0.0, 1.0)
	var xp_col: Color = Color(1.0, 0.85, 0.3) if maxed else Color(1.0, 0.55, 1.0)
	_draw_bar(Vector2(GAUGE_X, gy), Vector2(GAUGE_W, GAUGE_H), xp_frac, xp_col, "MAX" if maxed else "XP")


func _draw_bar(pos: Vector2, size: Vector2, frac: float, color: Color, label: String) -> void:
	frac = clamp(frac, 0.0, 1.0)
	draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(pos, Vector2(size.x * frac, size.y)), color)
	draw_rect(Rect2(pos, size), Color(1, 1, 1, 0.7), false, 1.5)
	draw_string(_font, pos + Vector2(size.x + 8, size.y - 3), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _draw_hud() -> void:
	var right_x: float = arena.x - HUD_MARGIN

	# --- Top-right column: SCORE, then a single consolidated status line,
	#     then WAVE. All right-aligned so nothing clips the right edge. ---
	_draw_text_right(right_x, GAUGE_Y + SCORE_FONT, "SCORE  %d" % score, SCORE_FONT, Color.WHITE)

	# One compact status line: [CLASS] WEAPON Lvn | DIFF (| MUTE).
	var wname: String = WEAPONS[weapon].name
	var wlvl: int = int(weapon_level[weapon])
	var dd: Dictionary = _diff()
	var status: String = "[%s]  %s Lv%d  |  %s" % [class_label, wname, wlvl, String(dd.name)]
	if sfx.is_muted():
		status += "  |  MUTE"
	_draw_text_right(right_x, GAUGE_Y + SCORE_FONT + HUD_FONT + 6.0, status, HUD_FONT_SM,
		Color(0.78, 0.82, 0.9))

	# WAVE + progress.
	_draw_text_right(right_x, GAUGE_Y + SCORE_FONT + HUD_FONT + HUD_FONT_SM + 12.0,
		"WAVE %d   %d/%d" % [wave, wave_kills, wave_quota], HUD_FONT_SM, Color(0.8, 0.9, 1.0))

	# --- COMBO: upper-center, only when combo > 1. Clear of the gauge stack
	#     (left) and the score column (right). Timer bar centered below it. ---
	if combo >= 2:
		var ctxt: String = "COMBO x%d" % combo
		var csize: int = 18
		var ccol: Color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.4, 0.2), float(combo) / COMBO_MAX)
		var cy: float = 130.0
		var ctw: float = _text_width(ctxt, csize)
		draw_string(_font, Vector2(arena.x * 0.5 - ctw * 0.5, cy), ctxt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, csize, ccol)
		var cw: float = 110.0
		var cfrac: float = clamp(combo_t / COMBO_WINDOW, 0.0, 1.0)
		var cbar: Vector2 = Vector2(arena.x * 0.5 - cw * 0.5, cy + 6.0)
		draw_rect(Rect2(cbar, Vector2(cw, 5)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(cbar, Vector2(cw * cfrac, 5)), Color(1.0, 0.7, 0.2))

	# --- Bottom-left buff chips (single row, right-edge guarded). ---
	var bx: float = HUD_MARGIN
	var by: float = arena.y - 58.0
	var chip_w: float = 78.0
	var chip_max_x: float = arena.x - HUD_MARGIN
	if buf_rapid > 0.0 and bx + chip_w <= chip_max_x:
		_draw_buff_chip(Vector2(bx, by), "RAPID", _pickup_color("rapid"), buf_rapid / 7.0)
		bx += chip_w + 6.0
	if buf_spread > 0.0 and bx + chip_w <= chip_max_x:
		_draw_buff_chip(Vector2(bx, by), "SPREAD", _pickup_color("spread"), buf_spread / 7.0)
		bx += chip_w + 6.0
	if shield > 0 and bx + chip_w <= chip_max_x:
		_draw_buff_chip(Vector2(bx, by), "SHLD %d" % shield, _pickup_color("shield"), 1.0)

	# --- Bottom-left state line: DASH + BOMB READY (compact, side by side). ---
	var dlabel: String = "DASH READY" if dash_cd <= 0.0 else "DASH %.1f" % dash_cd
	var dcol: Color = Color(0.5, 1.0, 0.7) if dash_cd <= 0.0 else Color(0.6, 0.65, 0.75)
	var sy: float = arena.y - 34.0
	_draw_text_left(HUD_MARGIN, sy, dlabel, HUD_FONT, dcol)
	if bomb_charge >= BOMB_MAX:
		var p2: float = sin(bomb_pulse) * 0.5 + 0.5
		var bomb_x: float = HUD_MARGIN + _text_width("DASH READY", HUD_FONT) + 14.0
		_draw_text_left(bomb_x, sy, "BOMB [E]", HUD_FONT, Color(1.0, 0.6 + 0.3 * p2, 0.3))

	# --- Help text: bottom-LEFT, small, ends well before the FIRE/WEAPON
	#     buttons (bottom-right). Falls back to a shorter form if the long
	#     string would reach the weapon button (measured, never clipped). ---
	var help: String = "WASD move   SHIFT dash   E bomb   Q weapon   ESC pause"
	var help_max_x: float = weapon_btn.x - weapon_btn_r - 10.0
	if HUD_MARGIN + _text_width(help, HUD_FONT_SM) > help_max_x:
		help = "WASD   SHIFT dash   E bomb   Q wpn"
	_draw_text_left(HUD_MARGIN, arena.y - 14.0, help, HUD_FONT_SM, Color(0.7, 0.75, 0.85))


func _draw_buff_chip(pos: Vector2, label: String, col: Color, frac: float) -> void:
	var sz = Vector2(72, 20)
	draw_rect(Rect2(pos, sz), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(pos, Vector2(sz.x * clamp(frac, 0.0, 1.0), sz.y)),
		Color(col.r, col.g, col.b, 0.45))
	draw_rect(Rect2(pos, sz), col, false, 1.5)
	draw_string(_font, pos + Vector2(5, 15), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_toasts() -> void:
	# Achievement toasts: their OWN center band (~y=250+), well below the
	# banner band (~y=170) so the two never overlap.
	if toasts.is_empty():
		return
	var y: float = 250.0
	for to in toasts:
		var life: float = float(to.life)
		var maxl: float = float(to.max_life)
		var a: float = clamp(life / max(0.001, maxl) * 1.4, 0.0, 1.0)
		draw_string(_font, Vector2(0, y), String(to.text),
			HORIZONTAL_ALIGNMENT_CENTER, int(arena.x), TOAST_FONT,
			Color(0.5, 1.0, 0.7, a))
		y += float(TOAST_FONT) + 8.0


func _draw_banner() -> void:
	# Wave / weapon-up banner: upper-center band (~y=170), clear of the top HUD
	# above and the toast band below.
	if banner_t <= 0.0:
		return
	var a: float = clamp(banner_t, 0.0, 1.0)
	draw_string(_font, Vector2(0, 170.0), banner_text,
		HORIZONTAL_ALIGNMENT_CENTER, int(arena.x), BANNER_FONT, Color(1.0, 0.9, 0.5, a))


func _draw_pause() -> void:
	# Dim the frozen world, then a centered themed panel.
	draw_rect(Rect2(ZERO, arena), Color(0.02, 0.03, 0.06, 0.72))
	var cx: float = arena.x * 0.5
	var pw: float = min(arena.x - 80.0, 360.0)
	var ph: float = 250.0
	var panel: Rect2 = Rect2(Vector2(cx - pw * 0.5, arena.y * 0.5 - ph * 0.5),
		Vector2(pw, ph))
	_panel(panel, TH_ACCENT, false)
	_text_glow(cx, panel.position.y + 50.0, "PAUSED", 40, TH_ACCENT, TH_ACCENT)

	# Menu rows as themed buttons (keyboard-driven; hover is purely visual).
	var mp = get_global_mouse_position()
	var bw: float = pw - 48.0
	var bh: float = 38.0
	var bx: float = cx - bw * 0.5
	var by: float = panel.position.y + 78.0
	var gap: float = 12.0
	var rows: Array = [["RESUME   [ESC / P]", TH_ACCENT], ["RESTART   [R]", TH_ACCENT2],
		["CLASS SELECT   [C]", TH_TEXT_DIM]]
	for ri in rows.size():
		var row: Array = rows[ri]
		var br: Rect2 = Rect2(Vector2(bx, by + float(ri) * (bh + gap)), Vector2(bw, bh))
		var rcol: Color = row[1]
		_btn(br, String(row[0]), br.has_point(mp), rcol)


func _draw_draft() -> void:
	# Dim the frozen world, then a header + the offered upgrade cards. Reuses the
	# theme kit (_panel/_text_glow/_text_center) so it matches the pro menus.
	draw_rect(Rect2(ZERO, arena), Color(0.02, 0.03, 0.06, 0.78))
	var cx: float = arena.x * 0.5
	var mp = get_global_mouse_position()
	# Header.
	var header: String = "CHOOSE AN UPGRADE"
	var sub: String = "BOSS REWARD" if draft_pending_boss else "WAVE %d CLEARED" % wave
	var head_y: float = arena.y * 0.5
	if not draft_cards.is_empty():
		head_y = float(draft_cards[0].position.y) - 46.0
	_text_glow(cx, head_y, header, 30, TH_ACCENT2, TH_ACCENT2)
	_text_center(cx, head_y + 22.0, sub, 14, TH_TEXT_DIM)

	# Cards.
	for i in draft_offers.size():
		if i >= draft_cards.size():
			break
		var u: Dictionary = draft_offers[i]
		var r: Rect2 = draft_cards[i]
		var accent: Color = u.accent
		var hot: bool = r.has_point(mp)
		_panel(r, accent, hot)
		var pad: float = 16.0
		var lx: float = r.position.x + pad
		# Number key chip (top-left).
		var chip_w: float = 30.0
		var chip: Rect2 = Rect2(Vector2(lx, r.position.y + 14.0), Vector2(chip_w, 26.0))
		draw_rect(chip, Color(accent.r, accent.g, accent.b, 0.85), true)
		_text_center(chip.position.x + chip.size.x * 0.5, chip.position.y + 19.0,
			"%d" % (i + 1), 15, Color(0.05, 0.07, 0.12))
		# Name + description.
		_draw_text_left(lx + chip_w + 12.0, r.position.y + 34.0,
			String(u.name), 20, accent.lerp(Color.WHITE, 0.5))
		_draw_text_left(lx + chip_w + 12.0, r.position.y + 56.0,
			String(u.desc), 13, TH_TEXT)
		# Current stack count (if any) on the right.
		var uid: String = String(u.id)
		var stacks: int = int(taken_upgrades.get(uid, 0))
		if stacks > 0:
			_draw_text_right(r.position.x + r.size.x - pad, r.position.y + 34.0,
				"OWNED x%d" % stacks, 12, accent.lerp(Color.WHITE, 0.3))
		# Pick hint (bottom-right).
		_draw_text_right(r.position.x + r.size.x - pad, r.position.y + r.size.y - 12.0,
			"[%d]  PICK" % (i + 1), 12, TH_TEXT_DIM)

	# Footer hint.
	if not draft_cards.is_empty():
		var last: Rect2 = draft_cards[draft_cards.size() - 1]
		_text_center(cx, last.position.y + last.size.y + 26.0,
			"Press 1 / 2 / 3 or click a card", 13, TH_TEXT_DIM)


func _draw_game_over() -> void:
	draw_rect(Rect2(ZERO, arena), Color(0.03, 0.02, 0.04, 0.68))
	var cx: float = arena.x * 0.5
	var pw: float = min(arena.x - 70.0, 380.0)
	var ph: float = 300.0
	var panel: Rect2 = Rect2(Vector2(cx - pw * 0.5, arena.y * 0.5 - ph * 0.5),
		Vector2(pw, ph))
	_panel(panel, TH_DANGER, false)
	var py: float = panel.position.y
	_text_glow(cx, py + 52.0, "GAME OVER", 40, TH_DANGER, TH_DANGER)

	# Final score, large.
	_text_center(cx, py + 96.0, "SCORE", 13, TH_TEXT_DIM)
	_text_center(cx, py + 128.0, "%d" % score, 38, TH_TEXT)

	# Class + difficulty line.
	_text_center(cx, py + 154.0,
		"%s  ·  %s" % [class_label, String(_diff().name)], 13,
		hull_color.lerp(Color.WHITE, 0.4))

	# Run stats if available (wave reached + kills).
	_text_center(cx, py + 176.0, "WAVE %d   ·   %d KILLS   ·   +%d CR" % [wave, run_kills, run_credits],
		12, TH_TEXT_DIM)

	# Best (+ NEW BEST badge when beaten).
	if new_best:
		var badge_w: float = 140.0
		var badge: Rect2 = Rect2(Vector2(cx - badge_w * 0.5, py + 192.0),
			Vector2(badge_w, 26.0))
		var bpulse: float = 0.5 + 0.5 * sin(t * 5.0)
		draw_rect(badge, Color(0.4 + 0.3 * bpulse, 1.0, 0.5, 0.9), true)
		draw_rect(badge, Color.WHITE, false, 2.0)
		_text_center(cx, badge.position.y + 18.0, "NEW BEST!", 16, Color(0.04, 0.1, 0.05))
	else:
		_text_center(cx, py + 208.0, "BEST  %d" % _best_for(class_label),
			16, TH_ACCENT2)

	# Restart / select hints.
	_text_center(cx, py + ph - 30.0, "R  replay same class", 13, TH_TEXT)
	_text_center(cx, py + ph - 12.0, "C  choose class", 13, TH_TEXT_DIM)


# ============================  CLASS SELECT  =============================
func _draw_class_select() -> void:
	var cx: float = arena.x * 0.5
	var mp = get_global_mouse_position()

	# --- Title: glowing GAME TITLE with a gentle pulse + accent rule. ---
	var pulse: float = 1.0 + 0.04 * sin(t * 2.2)
	var title_size: int = int(44.0 * pulse)
	var title_y: float = arena.y * 0.11
	_text_glow(cx, title_y, "SPACE INVADERS", title_size, TH_ACCENT, TH_ACCENT)
	# Accent underline rule centered under the title.
	var rule_w: float = min(arena.x - 80.0, 360.0)
	var ry: float = title_y + 14.0
	draw_rect(Rect2(Vector2(cx - rule_w * 0.5, ry), Vector2(rule_w, 2.0)),
		Color(TH_ACCENT.r, TH_ACCENT.g, TH_ACCENT.b, 0.7), true)
	draw_rect(Rect2(Vector2(cx - 24.0, ry - 1.0), Vector2(48.0, 4.0)), TH_ACCENT2, true)
	# Tagline.
	_text_center(cx, title_y + 34.0, "ARCADE  ·  ROGUELITE  ·  SURVIVE THE WAVES",
		12, TH_TEXT_DIM)
	# Section header.
	_text_center(cx, arena.y * 0.225, "SELECT YOUR SHIP", 18, TH_ACCENT2)

	# --- Class cards (rects are the hit-targets; keep their geometry). ---
	for i in class_cards.size():
		var r: Rect2 = class_cards[i]
		var c: Dictionary = CLASSES[i]
		var col: Color = c.color
		var hot: bool = r.has_point(mp)
		_draw_class_card(r, i, c, col, hot)

	# --- Difficulty: segmented EASY | NORMAL | HARD inside diff_row_rect. ---
	var dr: Rect2 = diff_row_rect
	var dhot: bool = dr.has_point(mp)
	var dd: Dictionary = _diff()
	var dcol: Color = dd.color
	_panel(dr, dcol, dhot)
	var dpad: float = 10.0
	var lab_w: float = 92.0
	_draw_text_left(dr.position.x + dpad, dr.position.y + dr.size.y * 0.5 + 6.0,
		"DIFFICULTY", 13, TH_TEXT_DIM)
	# Three connected segments fill the right portion of the row.
	var seg_x0: float = dr.position.x + dpad + lab_w
	var seg_x1: float = dr.position.x + dr.size.x - dpad - 28.0   # leave room for ◄ ►
	var seg_total: float = seg_x1 - seg_x0
	var seg_w: float = seg_total / 3.0
	var seg_y: float = dr.position.y + 6.0
	var seg_h: float = dr.size.y - 12.0
	for di in DIFFS.size():
		var ddi: Dictionary = DIFFS[di]
		var active: bool = di == difficulty
		var sr: Rect2 = Rect2(Vector2(seg_x0 + float(di) * seg_w, seg_y),
			Vector2(seg_w - 2.0, seg_h))
		var segcol: Color = ddi.color
		if active:
			draw_rect(sr, Color(segcol.r, segcol.g, segcol.b, 0.85), true)
			draw_rect(sr, segcol.lerp(Color.WHITE, 0.4), false, 2.0)
		else:
			draw_rect(sr, Color(0.10, 0.13, 0.19, 0.9), true)
			draw_rect(sr, Color(segcol.r, segcol.g, segcol.b, 0.45), false, 1.0)
		var stext: Color = Color.WHITE if active else TH_TEXT_DIM
		_text_center(sr.position.x + sr.size.x * 0.5,
			sr.position.y + sr.size.y * 0.5 + 5.0, String(ddi.name), 13, stext)
	# ◄ ► hint at the right edge.
	_draw_text_right(dr.position.x + dr.size.x - dpad,
		dr.position.y + dr.size.y * 0.5 + 6.0, "◄ ►", 14,
		dcol.lerp(Color.WHITE, 0.4))

	# --- Footer strip: BEST (highlighted class) + achievements + hints. ---
	var foot_h: float = 56.0
	var foot: Rect2 = Rect2(Vector2(24.0, arena.y - foot_h - 16.0),
		Vector2(arena.x - 48.0, foot_h))
	_panel(foot, TH_ACCENT2, false)
	var fpad: float = 12.0
	var fcx: float = foot.position.x + fpad
	var hl_col: Color = CLASSES[class_idx].color
	# Row 1: BEST for the currently-highlighted class + achievements count.
	_draw_text_left(fcx, foot.position.y + 22.0,
		"BEST  [%s]  %d" % [String(CLASSES[class_idx].name), _best_for(String(CLASSES[class_idx].name))],
		14, TH_ACCENT2)
	_draw_text_right(foot.position.x + foot.size.x - fpad, foot.position.y + 22.0,
		"ACHIEVEMENTS  %d/%d" % [ach_unlocked.size(), ACHIEVEMENTS.size()],
		13, hl_col.lerp(Color.WHITE, 0.3))
	# Row 2: control hints (left) + lifetime meta currency (right).
	_draw_text_left(fcx, foot.position.y + 44.0,
		"1 / 2 / 3 or click  ·  ◄ ► difficulty  ·  M mute",
		12, TH_TEXT_DIM)
	_draw_text_right(foot.position.x + foot.size.x - fpad, foot.position.y + 44.0,
		"CREDITS  %d" % total_credits, 12, TH_ACCENT2)

	_draw_toasts()


# One class card rendered inside its hit-rect `r`. Header bar + preview +
# tagline + labeled stat mini-bars + key hint. Hover/focus lifts + glows.
func _draw_class_card(r: Rect2, i: int, c: Dictionary, col: Color, hot: bool) -> void:
	var focused: bool = i == class_idx
	# Subtle lift for the hovered/focused card (drawn within bounds, no clip).
	var draw_r: Rect2 = r
	if hot or focused:
		draw_r = Rect2(r.position - Vector2(0, 2.0), r.size)
	_panel(draw_r, col, hot or focused)

	var pad: float = 14.0
	var lx: float = draw_r.position.x + pad
	var top: float = draw_r.position.y
	# Header band with class name + number key chip.
	var head_h: float = 28.0
	draw_rect(Rect2(Vector2(draw_r.position.x, top + 3.0),
		Vector2(draw_r.size.x, head_h)), Color(col.r, col.g, col.b, 0.16), true)
	_draw_text_left(lx, top + head_h - 3.0, String(c.name), 22, col.lerp(Color.WHITE, 0.55))
	# Key hint chip top-right.
	var chip_w: float = 30.0
	var chip: Rect2 = Rect2(
		Vector2(draw_r.position.x + draw_r.size.x - chip_w - pad, top + 7.0),
		Vector2(chip_w, 20.0))
	draw_rect(chip, Color(col.r, col.g, col.b, 0.85), true)
	_text_center(chip.position.x + chip.size.x * 0.5, chip.position.y + 15.0,
		"%d" % (i + 1), 14, Color(0.05, 0.07, 0.12))

	# Tagline (one line).
	_draw_text_left(lx, top + head_h + 20.0, String(c.desc), 12, TH_TEXT_DIM)

	# Ship preview, centered in a reserved column on the right.
	var prev_cx: float = draw_r.position.x + draw_r.size.x - 46.0
	var prev_cy: float = top + draw_r.size.y * 0.62
	_draw_class_preview(Vector2(prev_cx, prev_cy), col, float(c.hull_scale), i)

	# Stat mini-bars (relative to sensible maxima across all classes).
	var bx: float = lx
	var bw: float = draw_r.size.x - pad * 2.0 - 78.0   # leave room for preview column
	var b0: float = top + head_h + 42.0
	var bgap: float = 19.0
	var hp_f: float = clamp(float(c.max_hp) / 8.0, 0.05, 1.0)
	var spd_f: float = clamp(float(c.speed) / 320.0, 0.05, 1.0)
	# FIRE rating: lower fire_cost_mult = better, map ~[0.7..1.15] -> [1..0].
	var fire_f: float = clamp((1.25 - float(c.fire_cost_mult)) / 0.55, 0.05, 1.0)
	# DASH rating: lower dash_cd = better, map ~[0.55..1.35] -> [1..0].
	var dash_f: float = clamp((1.45 - float(c.dash_cd)) / 0.90, 0.05, 1.0)
	_stat_bar(Vector2(bx, b0), bw, hp_f, "HP", "%d" % int(c.max_hp), col)
	_stat_bar(Vector2(bx, b0 + bgap), bw, spd_f, "SPEED", "%d" % int(c.speed), col)
	_stat_bar(Vector2(bx, b0 + bgap * 2.0), bw, fire_f, "FIRE", "x%.2f" % float(c.fire_cost_mult), col)
	_stat_bar(Vector2(bx, b0 + bgap * 3.0), bw, dash_f, "DASH", "%.2fs" % float(c.dash_cd), col)

	# BEST score for this class, small, bottom-left of card.
	_draw_text_left(lx, draw_r.position.y + draw_r.size.y - 8.0,
		"BEST %d" % _best_for(String(c.name)), 11, TH_ACCENT2)


func _draw_class_preview(pos: Vector2, col: Color, scl: float, idx: int = 0) -> void:
	# Soft glow disc behind the hull for a crisp, centered look.
	draw_circle(pos, 22.0 * scl, Color(col.r, col.g, col.b, 0.12))
	var pkey: String = "pship" + str(idx)
	if not textures.has(pkey):
		pkey = "player"
	if textures.has(pkey):
		var ptex: Texture2D = textures[pkey]
		var psz = ptex.get_size()
		var psc: float = 52.0 / max(psz.x, psz.y)
		draw_set_transform(pos, -PI / 2.0, Vector2(psc, psc))
		draw_texture(ptex, -psz * 0.5, col.lerp(Color.WHITE, 0.45))
		draw_set_transform(ZERO, 0.0, ONE)
		return
	draw_set_transform(pos, -PI / 2.0, Vector2(scl, scl))
	var hull = PackedVector2Array([
		Vector2(22, 0), Vector2(2, -13), Vector2(-14, -15),
		Vector2(-8, 0), Vector2(-14, 15), Vector2(2, 13)])
	draw_colored_polygon(hull, col)
	draw_polyline(hull + PackedVector2Array([hull[0]]), col.lerp(Color.WHITE, 0.6), 2.0)
	draw_circle(Vector2(4, 0), 5.0, Color(0.9, 0.97, 1.0))
	draw_circle(Vector2(4, 0), 2.5, Color(0.2, 0.4, 0.7))
	draw_set_transform(ZERO, 0.0, ONE)


# --- polygon helpers ------------------------------------------------------
func _ngon(n: int, r: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in n:
		var a = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in points * 2:
		var a = TAU * float(i) / float(points * 2)
		var rad = outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * rad)
	return pts
