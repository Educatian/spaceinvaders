extends Node2D

# ============================================================
# ORBITAL GUNNER  (+ THREAD THE GATES)
# Standalone educational physics episode for SpaceInvaders.
# Gravity-slingshot target shooting + trajectory-matching.
# Self-contained: no reference to Game.gd symbols.
# Godot 4.6.3, window 600x920, gl_compatibility. TABS only.
# ============================================================

# ---- Theme (own consts, matched VALUES) --------------------
const COL_BG := Color(0.05, 0.06, 0.10)
const COL_PANEL := Color(0.07, 0.09, 0.14, 0.92)
const COL_ACCENT := Color(0.30, 0.78, 1.0)
const COL_ACCENT2 := Color(1.0, 0.82, 0.35)
const COL_DANGER := Color(1.0, 0.4, 0.4)
const COL_TEXT := Color(1, 1, 1)
const COL_DIM := Color(0.6, 0.66, 0.78)
const COL_GOOD := Color(0.45, 0.9, 0.5)

# ---- Physics model (own copy) ------------------------------
const GRAV_G := 1.0
const GRAV_MIN_R2 := 900.0
const DT := 0.7
const SIM_STEPS := 220
const PREVIEW_FRAC := 0.35
const DEMO_CAPTURE := false  # dev-only: auto-save gameplay screenshots; ships false

# ---- Aim tuning --------------------------------------------
const POWER_MIN := 3.0
const POWER_MAX := 14.0
const ANGLE_STEP := 0.035
const POWER_STEP := 0.4
const PROJ_RADIUS := 6.0
const ARENA_MARGIN := 60.0

# ---- Window ------------------------------------------------
const W := 600.0
const H := 920.0

# ---- Episode states ----------------------------------------
enum { ST_TITLE, ST_AIM, ST_FLYING, ST_RESULT }
var ep_state: int = ST_TITLE

# ---- Stage / run vars --------------------------------------
var stage_index: int = 0
var shots_used: int = 0
var won: bool = false
var last_stars: int = 0
var stage_stars: Array = []          # best stars per stage (0 = unsolved)

# wells/targets/gates for the active stage (working copies)
var wells: Array = []
var targets: Array = []              # each: {pos, radius, dead:bool}
var gates: Array = []                # each: {pos, radius, passed:bool}
var cannon: Vector2 = Vector2(80, 760)
var stage_type: String = "gunner"

# aim
var aim_angle: float = -0.9          # radians, 0 = +x (right), negative = up
var aim_power: float = 8.0
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

# live projectile
var proj_pos: Vector2 = Vector2.ZERO
var proj_vel: Vector2 = Vector2.ZERO
var proj_alive: bool = false
var trail: PackedVector2Array = PackedVector2Array()
var fx: Array = []                   # expanding rings: {pos, t, color}
var flash_t: float = 0.0
var anim: float = 0.0                 # global animation accumulator (for pulsing/blink)
var result_msg: String = ""
var last_miss_dist: float = 0.0

# telemetry
const TELE_PATH := "user://orbital_telemetry.jsonl"
var tele_buffer: Array = []
var tele_since_flush: int = 0

var _font: Font

# ============================================================
# Stage authoring
# Each: {type, wells:[{pos,mass,radius,name}], cannon,
#        par, hint, and targets:[] or gates:[]}
# Gentle curve: 1 straight, 2 one planet, 3 slingshot,
#               4-5 gates, 6 multi-well.
# ============================================================
const STAGES: Array = [
	{
		"type": "gunner",
		"wells": [],
		"cannon": Vector2(80, 780),
		"targets": [{"pos": Vector2(500, 220), "radius": 26.0}],
		"par": 1,
		"mission": "M1 · ORBITAL DELIVERY",
		"hint": "Launch from Earth straight to the supply depot. No gravity bodies yet: angle picks heading, power picks burn. Aim true."
	},
	{
		"type": "gunner",
		"wells": [{"pos": Vector2(300, 470), "mass": 2200.0, "radius": 42.0, "name": "Luna"}],
		"cannon": Vector2(80, 780),
		"targets": [{"pos": Vector2(520, 470), "radius": 24.0}],
		"par": 2,
		"mission": "M2 · LUNAR FLYBY",
		"hint": "The Moon's gravity bends your probe. The closer you pass, the harder Luna pulls; let it curve you to the depot."
	},
	{
		"type": "gunner",
		"wells": [{"pos": Vector2(320, 430), "mass": 4200.0, "radius": 52.0, "name": "Mars"}],
		"cannon": Vector2(80, 800),
		"targets": [{"pos": Vector2(230, 150), "radius": 24.0}],
		"par": 3,
		"mission": "M3 · MARS SLINGSHOT",
		"hint": "Gravity assist: skim the far side of Mars so its pull whips the probe around toward the station, just like real NASA flybys."
	},
	{
		"type": "gates",
		"wells": [],
		"cannon": Vector2(70, 800),
		"gates": [
			{"pos": Vector2(220, 560), "radius": 34.0},
			{"pos": Vector2(370, 380), "radius": 32.0},
			{"pos": Vector2(510, 210), "radius": 30.0}
		],
		"par": 1,
		"mission": "M4 · DEEP-SPACE CORRIDOR",
		"hint": "Thread one transfer path through every nav-beacon. A single launch must pass through all three rings in the corridor."
	},
	{
		"type": "gates",
		"wells": [{"pos": Vector2(330, 470), "mass": 3000.0, "radius": 44.0, "name": "Jupiter"}],
		"cannon": Vector2(70, 810),
		"gates": [
			{"pos": Vector2(210, 600), "radius": 32.0},
			{"pos": Vector2(330, 300), "radius": 30.0},
			{"pos": Vector2(470, 520), "radius": 30.0}
		],
		"par": 1,
		"mission": "M5 · JUPITER NAV-LANE",
		"hint": "Use Jupiter's pull to curve a single transfer arc through all three nav-beacons of the lane."
	},
	{
		"type": "gunner",
		"wells": [
			{"pos": Vector2(220, 360), "mass": 3000.0, "radius": 40.0, "name": "Castor"},
			{"pos": Vector2(420, 600), "mass": 3000.0, "radius": 40.0, "name": "Pollux"}
		],
		"cannon": Vector2(70, 800),
		"targets": [{"pos": Vector2(520, 200), "radius": 24.0}],
		"par": 3,
		"mission": "M6 · BINARY-STAR TRANSIT",
		"hint": "Two stars form a gravity corridor. Balance the pull of Castor and Pollux to steer between them to the colony."
	}
]

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	_font = ThemeDB.fallback_font
	stage_stars.resize(STAGES.size())
	for i in range(STAGES.size()):
		stage_stars[i] = 0
	set_process(true)
	ep_state = ST_TITLE
	queue_redraw()
	if DEMO_CAPTURE:
		_demo_capture()

func _exit_tree() -> void:
	_tele_flush()

# Dev-only: render two gameplay stages with aim preview and save screenshots
# for the repo docs. Ships false.
func _demo_capture() -> void:
	# Stage 3 (slingshot to far-side target) — show aim + partial preview.
	_load_stage(2)
	ep_state = ST_AIM
	aim_angle = -0.55
	aim_power = 9.5
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var a: Image = get_viewport().get_texture().get_image()
	if a != null:
		a.save_png("user://og_gunner.png")
	# Stage 5 (gates threading around a planet).
	_load_stage(4)
	ep_state = ST_AIM
	aim_angle = -0.7
	aim_power = 8.5
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var b: Image = get_viewport().get_texture().get_image()
	if b != null:
		b.save_png("user://og_gates.png")

# ============================================================
# Stage loading
# ============================================================
func _load_stage(idx: int) -> void:
	stage_index = clampi(idx, 0, STAGES.size() - 1)
	var s: Dictionary = STAGES[stage_index]
	stage_type = String(s["type"])
	cannon = s["cannon"]
	# deep-copy wells
	wells = []
	var src_wells: Array = s.get("wells", [])
	for w in src_wells:
		var wd: Dictionary = w
		wells.append({
			"pos": wd["pos"],
			"mass": float(wd["mass"]),
			"radius": float(wd["radius"]),
			"name": String(wd.get("name", "?"))
		})
	# targets
	targets = []
	if s.has("targets"):
		var src_t: Array = s["targets"]
		for t in src_t:
			var td: Dictionary = t
			targets.append({"pos": td["pos"], "radius": float(td["radius"]), "dead": false})
	# gates
	gates = []
	if s.has("gates"):
		var src_g: Array = s["gates"]
		for g in src_g:
			var gd: Dictionary = g
			gates.append({"pos": gd["pos"], "radius": float(gd["radius"]), "passed": false})
	shots_used = 0
	won = false
	last_stars = 0
	proj_alive = false
	trail = PackedVector2Array()
	fx = []
	flash_t = 0.0
	result_msg = ""
	aim_angle = -0.9
	aim_power = 8.0
	ep_state = ST_AIM
	queue_redraw()

# ============================================================
# Physics
# ============================================================
func _grav_accel(p: Vector2) -> Vector2:
	var a: Vector2 = Vector2.ZERO
	for w in wells:
		var wd: Dictionary = w
		var wp: Vector2 = wd["pos"]
		var dir: Vector2 = wp - p
		var r2: float = dir.length_squared()
		if r2 < 0.0001:
			continue
		a += dir.normalized() * (GRAV_G * float(wd["mass"]) / max(r2, GRAV_MIN_R2))
	return a

# Forward-integrate. Stops on leaving bounds (with margin) or well capture.
func _simulate(start: Vector2, vel: Vector2, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var p: Vector2 = start
	var v: Vector2 = vel
	pts.append(p)
	for i in range(steps):
		v += _grav_accel(p) * DT
		p += v * DT
		pts.append(p)
		# out of bounds
		if p.x < -ARENA_MARGIN or p.x > W + ARENA_MARGIN or p.y < -ARENA_MARGIN or p.y > H + ARENA_MARGIN:
			break
		# captured by a well
		var captured: bool = false
		for w in wells:
			var wd: Dictionary = w
			var wp: Vector2 = wd["pos"]
			if p.distance_to(wp) <= float(wd["radius"]):
				captured = true
				break
		if captured:
			break
	return pts

func _aim_velocity() -> Vector2:
	return Vector2(cos(aim_angle), sin(aim_angle)) * aim_power

# ============================================================
# Process / live integration
# ============================================================
func _process(delta: float) -> void:
	anim += delta
	# decay fx + flash always
	if flash_t > 0.0:
		flash_t = max(0.0, flash_t - delta * 3.0)
	var keep: Array = []
	for r in fx:
		var rd: Dictionary = r
		rd["t"] = float(rd["t"]) + delta * 2.4
		if float(rd["t"]) < 1.0:
			keep.append(rd)
	fx = keep

	if ep_state == ST_FLYING and proj_alive:
		_step_projectile()

	queue_redraw()

func _step_projectile() -> void:
	# one physics step per frame using the SAME model as the preview
	proj_vel += _grav_accel(proj_pos) * DT
	proj_pos += proj_vel * DT
	trail.append(proj_pos)
	if trail.size() > 80:
		trail.remove_at(0)

	# gate passing (any order)
	if stage_type == "gates":
		for g in gates:
			var gd: Dictionary = g
			if not bool(gd["passed"]):
				var gp: Vector2 = gd["pos"]
				if proj_pos.distance_to(gp) <= float(gd["radius"]):
					gd["passed"] = true
					_spawn_ring(gp, COL_GOOD)
		if _all_gates_passed():
			_resolve_win()
			return

	# target hits
	if stage_type == "gunner":
		for t in targets:
			var td: Dictionary = t
			if not bool(td["dead"]):
				var tp: Vector2 = td["pos"]
				if proj_pos.distance_to(tp) <= float(td["radius"]) + PROJ_RADIUS:
					td["dead"] = true
					flash_t = 1.0
					_spawn_ring(tp, COL_ACCENT2)
		if _all_targets_dead():
			_resolve_win()
			return

	# end conditions: out of bounds or captured by a well = miss
	if proj_pos.x < -ARENA_MARGIN or proj_pos.x > W + ARENA_MARGIN or proj_pos.y < -ARENA_MARGIN or proj_pos.y > H + ARENA_MARGIN:
		_resolve_miss()
		return
	for w in wells:
		var wd: Dictionary = w
		var wp: Vector2 = wd["pos"]
		if proj_pos.distance_to(wp) <= float(wd["radius"]):
			_spawn_ring(wp, COL_DANGER)
			_resolve_miss()
			return

func _spawn_ring(pos: Vector2, color: Color) -> void:
	fx.append({"pos": pos, "t": 0.0, "color": color})

func _all_targets_dead() -> bool:
	for t in targets:
		var td: Dictionary = t
		if not bool(td["dead"]):
			return false
	return true

func _all_gates_passed() -> bool:
	if gates.is_empty():
		return false
	for g in gates:
		var gd: Dictionary = g
		if not bool(gd["passed"]):
			return false
	return true

func _gates_passed_count() -> int:
	var c: int = 0
	for g in gates:
		var gd: Dictionary = g
		if bool(gd["passed"]):
			c += 1
	return c

# closest approach of current trail to nearest unsolved objective
func _closest_unsolved_dist() -> float:
	var best: float = 99999.0
	var samples: PackedVector2Array = trail
	if samples.is_empty():
		samples = PackedVector2Array([proj_pos])
	if stage_type == "gunner":
		for t in targets:
			var td: Dictionary = t
			if bool(td["dead"]):
				continue
			var tp: Vector2 = td["pos"]
			for sp in samples:
				best = min(best, sp.distance_to(tp))
	else:
		for g in gates:
			var gd: Dictionary = g
			if bool(gd["passed"]):
				continue
			var gp: Vector2 = gd["pos"]
			for sp in samples:
				best = min(best, sp.distance_to(gp))
	return best

# ============================================================
# Win / miss resolution
# ============================================================
func _resolve_win() -> void:
	proj_alive = false
	won = true
	last_stars = _compute_stars(shots_used, STAGES[stage_index]["par"])
	if last_stars > int(stage_stars[stage_index]):
		stage_stars[stage_index] = last_stars
	result_msg = "STAGE CLEAR"
	ep_state = ST_RESULT
	_tele_shot("win")
	_tele_stage_win()
	queue_redraw()

func _resolve_miss() -> void:
	proj_alive = false
	last_miss_dist = _closest_unsolved_dist()
	result_msg = "MISS - press R to retry, or re-aim"
	_tele_shot("miss")
	# back to aim so player can try again (shots already counted)
	ep_state = ST_AIM
	queue_redraw()

func _compute_stars(used: int, par_v) -> int:
	var par: int = int(par_v)
	if used <= par:
		return 3
	elif used <= par + 2:
		return 2
	else:
		return 1

# ============================================================
# Fire
# ============================================================
func _fire() -> void:
	if ep_state != ST_AIM:
		return
	shots_used += 1
	proj_pos = cannon
	proj_vel = _aim_velocity()
	proj_alive = true
	trail = PackedVector2Array()
	trail.append(proj_pos)
	last_miss_dist = 0.0
	ep_state = ST_FLYING
	queue_redraw()

# ============================================================
# Input
# ============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and dragging:
		_update_drag_from_pos(event.position)
		queue_redraw()

func _handle_key(event: InputEventKey) -> void:
	var kc: int = event.keycode
	# global back
	if kc == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	if ep_state == ST_TITLE:
		if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
			_load_stage(0)
		return

	if ep_state == ST_AIM:
		if kc == KEY_LEFT:
			aim_angle -= ANGLE_STEP
		elif kc == KEY_RIGHT:
			aim_angle += ANGLE_STEP
		elif kc == KEY_UP:
			aim_power = clampf(aim_power + POWER_STEP, POWER_MIN, POWER_MAX)
		elif kc == KEY_DOWN:
			aim_power = clampf(aim_power - POWER_STEP, POWER_MIN, POWER_MAX)
		elif kc == KEY_SPACE:
			_fire()
		elif kc == KEY_R:
			_load_stage(stage_index)
		queue_redraw()
		return

	if ep_state == ST_RESULT:
		if kc == KEY_R:
			_load_stage(stage_index)
		elif kc == KEY_N:
			if won:
				if stage_index + 1 < STAGES.size():
					_load_stage(stage_index + 1)
				else:
					ep_state = ST_TITLE
					queue_redraw()
		elif kc == KEY_SPACE:
			if won and stage_index + 1 < STAGES.size():
				_load_stage(stage_index + 1)
			elif won:
				ep_state = ST_TITLE
				queue_redraw()
		return

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if ep_state == ST_TITLE:
			_load_stage(0)
			return
		if ep_state == ST_RESULT:
			if _in_back_box(event.position):
				get_tree().change_scene_to_file("res://scenes/Main.tscn")
				return
			if won and stage_index + 1 < STAGES.size():
				_load_stage(stage_index + 1)
			elif won:
				ep_state = ST_TITLE
				queue_redraw()
			else:
				_load_stage(stage_index)
			return
		if ep_state == ST_AIM:
			if _in_back_box(event.position):
				get_tree().change_scene_to_file("res://scenes/Main.tscn")
				return
			dragging = true
			drag_start = cannon
			_update_drag_from_pos(event.position)
			queue_redraw()
	else:
		# release -> fire if was dragging
		if dragging:
			dragging = false
			_update_drag_from_pos(event.position)
			_fire()

func _update_drag_from_pos(mpos: Vector2) -> void:
	var d: Vector2 = mpos - cannon
	if d.length() < 1.0:
		return
	aim_angle = d.angle()
	aim_power = clampf(d.length() * 0.045, POWER_MIN, POWER_MAX)

func _in_back_box(p: Vector2) -> bool:
	var r: Rect2 = Rect2(W - 96, 14, 82, 34)
	return r.has_point(p)

# ============================================================
# Telemetry
# ============================================================
func _tele_shot(result: String) -> void:
	var gp: int = 0
	if stage_type == "gates":
		gp = _gates_passed_count()
	var ev: Dictionary = {
		"event": "shot",
		"stage": stage_index + 1,
		"stage_type": stage_type,
		"angle": snappedf(aim_angle, 0.001),
		"power": snappedf(aim_power, 0.001),
		"num_wells": wells.size(),
		"result": result,
		"gates_passed": gp,
		"miss_dist": snappedf(_closest_unsolved_dist(), 0.1)
	}
	_tele_push(ev)

func _tele_stage_win() -> void:
	var ev: Dictionary = {
		"event": "stage_win",
		"stage": stage_index + 1,
		"shots_used": shots_used,
		"par": int(STAGES[stage_index]["par"]),
		"stars": last_stars
	}
	_tele_push(ev)

func _tele_push(ev: Dictionary) -> void:
	tele_buffer.append(JSON.stringify(ev))
	tele_since_flush += 1
	if tele_since_flush >= 3:
		_tele_flush()

func _tele_flush() -> void:
	if tele_buffer.is_empty():
		return
	var f: FileAccess
	if FileAccess.file_exists(TELE_PATH):
		f = FileAccess.open(TELE_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(TELE_PATH, FileAccess.WRITE)
	if f == null:
		return
	for line in tele_buffer:
		f.store_line(String(line))
	f.close()
	tele_buffer = []
	tele_since_flush = 0

# ============================================================
# Drawing helpers
# ============================================================
func _text_width(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _text_left(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_center(cx: float, y: float, text: String, size: int, color: Color) -> void:
	var w: float = _text_width(text, size)
	draw_string(_font, Vector2(cx - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

# Tactical-readout frame: dark translucent fill, 1px accent border,
# a thin accent bar along the top edge, and L-shaped corner brackets.
func _panel(rect: Rect2) -> void:
	draw_rect(rect, COL_PANEL, true)
	draw_rect(rect, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.30), false, 1.0)
	# thin accent bar along the top edge
	var bar: Rect2 = Rect2(rect.position.x, rect.position.y, rect.size.x, 3.0)
	draw_rect(bar, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.55), true)
	# L-shaped corner brackets
	_corner_brackets(rect, 12.0, COL_ACCENT)

# Short L-shaped ticks at each corner of a rect (HUD console look).
func _corner_brackets(rect: Rect2, len: float, color: Color) -> void:
	var c: Color = Color(color.r, color.g, color.b, 0.9)
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.position.x + rect.size.x
	var y1: float = rect.position.y + rect.size.y
	var th: float = 2.0
	# top-left
	draw_line(Vector2(x0, y0), Vector2(x0 + len, y0), c, th)
	draw_line(Vector2(x0, y0), Vector2(x0, y0 + len), c, th)
	# top-right
	draw_line(Vector2(x1, y0), Vector2(x1 - len, y0), c, th)
	draw_line(Vector2(x1, y0), Vector2(x1, y0 + len), c, th)
	# bottom-left
	draw_line(Vector2(x0, y1), Vector2(x0 + len, y1), c, th)
	draw_line(Vector2(x0, y1), Vector2(x0, y1 - len), c, th)
	# bottom-right
	draw_line(Vector2(x1, y1), Vector2(x1 - len, y1), c, th)
	draw_line(Vector2(x1, y1), Vector2(x1, y1 - len), c, th)

func _glow(pos: Vector2, r: float, color: Color, layers: int) -> void:
	for i in range(layers):
		var f: float = 1.0 - float(i) / float(max(layers, 1))
		var a: float = 0.10 + 0.10 * f
		var rr: float = r * (1.0 + float(i) * 0.55)
		draw_circle(pos, rr, Color(color.r, color.g, color.b, a))
	draw_circle(pos, r, color)

# ------------------------------------------------------------
# Procedural celestial bodies (asset-free)
# ------------------------------------------------------------
# Base palette per destination body, switched on its name.
func _planet_palette(nm: String) -> Color:
	var n: String = nm.to_lower()
	if n == "luna":
		return Color(0.62, 0.64, 0.70)
	elif n == "mars":
		return Color(0.72, 0.32, 0.20)
	elif n == "jupiter":
		return Color(0.78, 0.64, 0.46)
	elif n == "castor" or n == "pollux":
		return Color(1.0, 0.92, 0.62)
	else:
		return Color(0.30, 0.42, 0.66)

# Earth at the launch point: atmosphere glow, ocean, day-side,
# landmasses, crisp rim, and a pulsing launch marker on the rim.
func _draw_earth(p: Vector2) -> void:
	var r: float = 16.0
	# atmosphere glow
	for i in range(4):
		var f: float = 1.0 - float(i) / 4.0
		var rr: float = r + 4.0 + float(i) * 5.0
		draw_circle(p, rr, Color(0.35, 0.70, 1.0, 0.05 + 0.06 * f))
	# ocean body
	draw_circle(p, r, Color(0.10, 0.32, 0.62))
	# lighter day-side (offset toward upper-right)
	draw_circle(p + Vector2(-r * 0.30, -r * 0.30), r * 0.78, Color(0.18, 0.45, 0.78))
	# green landmass blobs
	draw_circle(p + Vector2(-r * 0.25, -r * 0.20), r * 0.34, Color(0.22, 0.55, 0.30))
	draw_circle(p + Vector2(r * 0.35, r * 0.10), r * 0.28, Color(0.26, 0.58, 0.32))
	draw_circle(p + Vector2(r * 0.05, r * 0.42), r * 0.20, Color(0.20, 0.50, 0.28))
	# crisp rim
	draw_arc(p, r, 0, TAU, 40, Color(0.55, 0.82, 1.0, 0.85), 1.5)
	# pulsing launch marker on the rim, pointing along aim_angle
	var dir: Vector2 = Vector2(cos(aim_angle), sin(aim_angle))
	var mp: Vector2 = p + dir * r
	var pulse: float = 0.55 + 0.45 * sin(anim * 5.0)
	draw_circle(mp, 3.0 + 2.0 * pulse, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, 0.5 + 0.5 * pulse))
	draw_line(mp, mp + dir * 8.0, COL_ACCENT2, 2.0)
	# tiny EARTH label under the planet
	_text_center(p.x, p.y + r + 16.0, "EARTH", 11, COL_DIM)

# A destination body (well), richer per name.
func _draw_planet(wp: Vector2, rad: float, nm: String) -> void:
	var base: Color = _planet_palette(nm)
	var n: String = nm.to_lower()
	_glow(wp, rad, Color(base.r * 0.7, base.g * 0.7, base.b * 0.9), 4)
	if n == "castor" or n == "pollux":
		# bright glowing star
		draw_circle(wp, rad, base)
		draw_circle(wp, rad * 0.62, Color(1.0, 1.0, 0.86))
		var fl: float = 0.6 + 0.4 * sin(anim * 4.0)
		draw_arc(wp, rad + 4.0, 0, TAU, 40, Color(1.0, 0.86, 0.45, 0.35 + 0.30 * fl), 2.0)
		return
	# rocky/gas planet body
	draw_circle(wp, rad, base)
	# day-side highlight
	draw_circle(wp + Vector2(-rad * 0.28, -rad * 0.28), rad * 0.74, Color(base.r * 1.18, base.g * 1.18, base.b * 1.18))
	if n == "luna":
		# grey craters
		draw_circle(wp + Vector2(-rad * 0.25, rad * 0.10), rad * 0.20, Color(0.48, 0.50, 0.55))
		draw_circle(wp + Vector2(rad * 0.30, -rad * 0.20), rad * 0.13, Color(0.50, 0.52, 0.57))
		draw_circle(wp + Vector2(rad * 0.10, rad * 0.38), rad * 0.10, Color(0.46, 0.48, 0.53))
	elif n == "mars":
		# polar cap dot
		draw_circle(wp + Vector2(rad * 0.05, -rad * 0.62), rad * 0.20, Color(0.92, 0.94, 0.98, 0.9))
		# a dusty marking
		draw_circle(wp + Vector2(-rad * 0.20, rad * 0.20), rad * 0.18, Color(0.55, 0.24, 0.16))
	elif n == "jupiter":
		# horizontal tint bands
		var bands: Array = [-0.45, -0.15, 0.18, 0.46]
		for by in bands:
			var yy: float = wp.y + float(by) * rad
			var half: float = sqrt(max(rad * rad - pow(float(by) * rad, 2.0), 0.0))
			var bc: Color = Color(base.r * 0.82, base.g * 0.74, base.b * 0.66, 0.8)
			draw_line(Vector2(wp.x - half, yy), Vector2(wp.x + half, yy), bc, 4.0)
		# great red spot
		draw_circle(wp + Vector2(rad * 0.28, rad * 0.18), rad * 0.16, Color(0.78, 0.34, 0.26))
	# crisp rim
	draw_arc(wp, rad, 0, TAU, 40, Color(base.r * 1.3, base.g * 1.3, base.b * 1.3, 0.7), 1.5)
	draw_arc(wp, rad + 6.0, 0, TAU, 40, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.25), 1.0)
	# name + mass label is drawn by the caller (_draw_arena)

# Target rendered as a space-station / docking-ring icon.
func _draw_station(tp: Vector2, trad: float, pulse: float) -> void:
	_glow(tp, 4.0 + 2.0 * pulse, COL_ACCENT2, 3)
	# outer docking ring
	draw_arc(tp, trad * (0.92 + 0.08 * pulse), 0, TAU, 32, COL_ACCENT2, 2.0)
	# inner ring
	draw_arc(tp, trad * 0.55, 0, TAU, 24, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, 0.7), 1.5)
	# cross ticks at 4 compass points
	for k in range(4):
		var ang: float = float(k) * PI * 0.5
		var d: Vector2 = Vector2(cos(ang), sin(ang))
		draw_line(tp + d * (trad * 0.55), tp + d * trad, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, 0.8), 1.5)
	# core
	draw_circle(tp, 4.0, COL_DANGER)

# Small check mark for a passed gate.
func _draw_check(c: Vector2, s: float, col: Color) -> void:
	draw_line(c + Vector2(-s * 0.5, 0.0), c + Vector2(-s * 0.1, s * 0.45), col, 3.0)
	draw_line(c + Vector2(-s * 0.1, s * 0.45), c + Vector2(s * 0.6, -s * 0.5), col, 3.0)

# ============================================================
# Draw
# ============================================================
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), COL_BG, true)
	_draw_starfield()
	if ep_state == ST_TITLE:
		_draw_title()
	else:
		_draw_arena()
		_draw_hud()
		if ep_state == ST_AIM:
			_draw_aim()
		if ep_state == ST_RESULT:
			_draw_result()
	if ep_state != ST_TITLE:
		_draw_back_box()

func _draw_starfield() -> void:
	# deterministic faint stars
	var seedv: int = 12345
	for i in range(60):
		seedv = (seedv * 1103515245 + 12345) & 0x7fffffff
		var x: float = float(seedv % 600)
		seedv = (seedv * 1103515245 + 12345) & 0x7fffffff
		var y: float = float(seedv % 920)
		draw_circle(Vector2(x, y), 1.0, Color(1, 1, 1, 0.10))

func _draw_title() -> void:
	_text_center(W * 0.5, 220, "ORBITAL GUNNER", 46, COL_ACCENT)
	_text_center(W * 0.5, 262, "Launch from Earth - slingshot through gravity to your target", 16, COL_DIM)
	var box: Rect2 = Rect2(70, 360, 460, 230)
	_panel(box)
	# blinking console-style launch prompt
	var blink: float = 0.55 + 0.45 * sin(anim * 4.0)
	_text_center(W * 0.5, 402, ">> TAP / SPACE TO LAUNCH <<", 22, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, blink))
	_text_left(Vector2(100, 446), "FLIGHT DECK:", 16, COL_TEXT)
	_text_left(Vector2(100, 474), "Drag from Earth = launch vector (dir=heading, length=burn)", 14, COL_DIM)
	_text_left(Vector2(100, 498), "Arrows = trim heading/burn   Space = launch", 14, COL_DIM)
	_text_left(Vector2(100, 522), "R = re-launch   N = next mission   Esc = abort", 14, COL_DIM)
	_text_left(Vector2(100, 546), "DELIVERY: reach the station   CORRIDOR: thread every beacon", 14, COL_DIM)
	var total: int = 0
	for s in stage_stars:
		total += int(s)
	_text_center(W * 0.5, 650, "Mission stars: " + str(total) + " / " + str(STAGES.size() * 3), 16, COL_ACCENT2)
	_text_center(W * 0.5, 706, "An educational orbital-mechanics episode", 13, COL_DIM)

func _draw_arena() -> void:
	# faint arena border
	draw_rect(Rect2(8, 80, W - 16, H - 96), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.10), false, 1.0)
	# wells (destination bodies)
	for w in wells:
		var wd: Dictionary = w
		var wp: Vector2 = wd["pos"]
		var rad: float = float(wd["radius"])
		var nm: String = String(wd.get("name", "?"))
		_draw_planet(wp, rad, nm)
		var mk: float = float(wd["mass"]) / 1000.0
		var label: String = nm + "  M=" + str(snappedf(mk, 0.1)) + "k"
		_text_center(wp.x, wp.y + rad + 20.0, label, 13, COL_DIM)
	# targets = docking-ring stations (pulsing)
	if stage_type == "gunner":
		var pulse: float = 0.5 + 0.5 * sin(anim * 3.0)
		for t in targets:
			var td: Dictionary = t
			if bool(td["dead"]):
				continue
			var tp: Vector2 = td["pos"]
			var trad: float = float(td["radius"])
			_draw_station(tp, trad, pulse)
	# gates (nav-beacon rings)
	if stage_type == "gates":
		var gp_pulse: float = 0.5 + 0.5 * sin(anim * 3.5)
		for g in gates:
			var gd: Dictionary = g
			var gp: Vector2 = gd["pos"]
			var grad: float = float(gd["radius"])
			if bool(gd["passed"]):
				# locked / green: filled + check
				draw_circle(gp, grad, Color(COL_GOOD.r, COL_GOOD.g, COL_GOOD.b, 0.22))
				draw_arc(gp, grad, 0, TAU, 40, COL_GOOD, 3.0)
				_draw_check(gp, grad * 0.5, COL_GOOD)
			else:
				# pending: bright ring
				var br: float = 0.7 + 0.3 * gp_pulse
				draw_arc(gp, grad, 0, TAU, 40, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, br), 2.5)
				draw_arc(gp, grad - 6.0, 0, TAU, 40, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.35), 1.0)
	# launch point = Earth
	_draw_earth(cannon)
	# live projectile (rocket/probe) + trail
	if proj_alive or ep_state == ST_FLYING:
		_draw_trail()
		if proj_alive:
			_draw_rocket(proj_pos, proj_vel)
	# fx rings
	for r in fx:
		var rd: Dictionary = r
		var tt: float = float(rd["t"])
		var rp: Vector2 = rd["pos"]
		var rc: Color = rd["color"]
		draw_arc(rp, 8.0 + tt * 60.0, 0, TAU, 40, Color(rc.r, rc.g, rc.b, 1.0 - tt), 3.0 * (1.0 - tt))
	if flash_t > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.25 * flash_t), true)

func _draw_trail() -> void:
	var n: int = trail.size()
	if n < 2:
		return
	for i in range(n - 1):
		var a: float = float(i) / float(max(n - 1, 1))
		var col: Color = Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, 0.15 + 0.55 * a)
		draw_line(trail[i], trail[i + 1], col, 2.0 + 1.5 * a)

# A small triangular craft oriented along its velocity, with a flame tail.
func _draw_rocket(p: Vector2, vel: Vector2) -> void:
	var dir: Vector2 = vel
	if dir.length() < 0.001:
		dir = Vector2(cos(aim_angle), sin(aim_angle))
	dir = dir.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var L: float = PROJ_RADIUS + 4.0
	var Wd: float = PROJ_RADIUS * 0.7
	# soft glow halo
	_glow(p, PROJ_RADIUS * 0.7, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, 1.0), 3)
	# flame tail (flickers with anim)
	var flick: float = 0.7 + 0.3 * sin(anim * 22.0)
	var tail: Vector2 = p - dir * (L * (0.9 + 0.5 * flick))
	var fl: PackedVector2Array = PackedVector2Array([
		p - dir * (L * 0.5) + perp * Wd,
		p - dir * (L * 0.5) - perp * Wd,
		tail
	])
	draw_colored_polygon(fl, Color(1.0, 0.55, 0.2, 0.85))
	# craft body (triangle nose along dir)
	var nose: Vector2 = p + dir * L
	var body: PackedVector2Array = PackedVector2Array([
		nose,
		p - dir * (L * 0.4) + perp * Wd,
		p - dir * (L * 0.4) - perp * Wd
	])
	draw_colored_polygon(body, COL_TEXT)
	draw_polyline(PackedVector2Array([nose, p - dir * (L * 0.4) + perp * Wd, p - dir * (L * 0.4) - perp * Wd, nose]), COL_ACCENT, 1.5)

func _draw_aim() -> void:
	# aim direction line
	var dir: Vector2 = Vector2(cos(aim_angle), sin(aim_angle))
	var endp: Vector2 = cannon + dir * (40.0 + aim_power * 6.0)
	draw_line(cannon, endp, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.8), 2.0)
	draw_circle(endp, 4.0, COL_ACCENT)
	# partial preview (first PREVIEW_FRAC of points), dotted + fading
	var pts: PackedVector2Array = _simulate(cannon, _aim_velocity(), SIM_STEPS)
	var total: int = pts.size()
	var shown: int = int(float(total) * PREVIEW_FRAC)
	if shown < 2:
		shown = min(2, total)
	var step: int = 2
	var i: int = 0
	while i < shown - 1:
		var a: float = 1.0 - float(i) / float(max(shown - 1, 1))
		var col: Color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.10 + 0.45 * a)
		draw_line(pts[i], pts[i + 1], col, 2.0)
		i += step
	# power gauge (left edge)
	var gx: float = 24.0
	var gy0: float = 540.0
	var gh: float = 230.0
	draw_rect(Rect2(gx, gy0, 14, gh), Color(0.12, 0.15, 0.22), true)
	var frac: float = (aim_power - POWER_MIN) / (POWER_MAX - POWER_MIN)
	var fh: float = gh * clampf(frac, 0.0, 1.0)
	draw_rect(Rect2(gx, gy0 + (gh - fh), 14, fh), COL_ACCENT2, true)
	draw_rect(Rect2(gx, gy0, 14, gh), Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, 0.5), false, 1.0)
	_text_left(Vector2(gx - 4, gy0 - 8), "PWR", 12, COL_DIM)
	# angle readout
	var deg: float = rad_to_deg(aim_angle)
	_text_left(Vector2(gx - 4, gy0 + gh + 22), "ang " + str(int(round(-deg))) + "d", 12, COL_DIM)

func _draw_hud() -> void:
	var s: Dictionary = STAGES[stage_index]
	var panel: Rect2 = Rect2(8, 8, W - 16, 64)
	_panel(panel)
	var mlabel: String = String(s.get("mission", "MISSION %d" % (stage_index + 1)))
	_text_left(Vector2(20, 34), mlabel, 18, COL_ACCENT)
	var pv: int = int(s["par"])
	_text_left(Vector2(20, 56), "Launches: " + str(shots_used) + "   Par: " + str(pv) + "   (Esc/ABORT = main game)", 13, COL_DIM)
	# learning hint panel
	var hp: Rect2 = Rect2(8, H - 56, W - 16, 48)
	_panel(hp)
	_text_left(Vector2(20, H - 26), String(s["hint"]), 13, COL_TEXT)
	# gates progress
	if stage_type == "gates":
		_text_left(Vector2(W - 220, 56), "Gates: " + str(_gates_passed_count()) + "/" + str(gates.size()), 13, COL_GOOD)

func _draw_result() -> void:
	var box: Rect2 = Rect2(80, 300, 440, 260)
	_panel(box)
	var blink: float = 0.5 + 0.5 * sin(anim * 4.0)
	if won:
		_text_center(W * 0.5, 350, "[ MISSION COMPLETE ]", 30, COL_GOOD)
		_draw_stars(W * 0.5, 392, last_stars)
		_text_center(W * 0.5, 446, "Launches: " + str(shots_used) + "   Par: " + str(int(STAGES[stage_index]["par"])), 15, COL_DIM)
		if stage_index + 1 < STAGES.size():
			_text_center(W * 0.5, 498, ">> N / SPACE : NEXT MISSION <<", 16, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, blink))
		else:
			_text_center(W * 0.5, 498, ">> ALL MISSIONS CLEAR - N : TITLE <<", 15, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, blink))
		_text_center(W * 0.5, 524, "R = re-launch   Esc = abort to game", 13, COL_DIM)
	else:
		_text_center(W * 0.5, 360, "[ TRANSIT FAILED ]", 30, COL_DANGER)
		_text_center(W * 0.5, 410, "Closest approach: " + str(int(last_miss_dist)) + " px", 15, COL_DIM)
		_text_center(W * 0.5, 470, ">> R : RE-LAUNCH <<", 16, Color(COL_ACCENT2.r, COL_ACCENT2.g, COL_ACCENT2.b, blink))
		_text_center(W * 0.5, 500, "Esc = abort to game", 13, COL_DIM)

func _draw_stars(cx: float, y: float, n: int) -> void:
	var spacing: float = 44.0
	var startx: float = cx - spacing
	for i in range(3):
		var on: bool = i < n
		var col: Color = COL_ACCENT2
		if not on:
			col = Color(0.3, 0.34, 0.42)
		_draw_star(Vector2(startx + float(i) * spacing, y), 16.0, col)

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var ang: float = -PI * 0.5 + float(i) * PI / 5.0
		var rad: float = r
		if i % 2 == 1:
			rad = r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)

func _draw_back_box() -> void:
	# HUD chip: bracketed label + corner ticks, no filled pill.
	var r: Rect2 = Rect2(W - 96, 14, 82, 34)
	_corner_brackets(r, 8.0, COL_DANGER)
	_text_center(r.position.x + r.size.x * 0.5, r.position.y + 23, "◄ ABORT", 13, COL_DANGER)
