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
		"hint": "Projectile motion: angle sets direction, power sets speed. No gravity here, aim straight."
	},
	{
		"type": "gunner",
		"wells": [{"pos": Vector2(300, 470), "mass": 2200.0, "radius": 42.0, "name": "Terra"}],
		"cannon": Vector2(80, 780),
		"targets": [{"pos": Vector2(520, 470), "radius": 24.0}],
		"par": 2,
		"hint": "A planet bends your shot. Gravity pulls more when you fly close; let it curve the path."
	},
	{
		"type": "gunner",
		"wells": [{"pos": Vector2(320, 430), "mass": 4200.0, "radius": 52.0, "name": "Vesta"}],
		"cannon": Vector2(80, 800),
		"targets": [{"pos": Vector2(230, 150), "radius": 24.0}],
		"par": 3,
		"hint": "Slingshot! Skim the far side of the planet so its gravity whips you around to the target."
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
		"hint": "Thread the gates: one shot must pass through every ring. Match the trajectory to the arc."
	},
	{
		"type": "gates",
		"wells": [{"pos": Vector2(330, 470), "mass": 3000.0, "radius": 44.0, "name": "Mira"}],
		"cannon": Vector2(70, 810),
		"gates": [
			{"pos": Vector2(210, 600), "radius": 32.0},
			{"pos": Vector2(330, 300), "radius": 30.0},
			{"pos": Vector2(470, 520), "radius": 30.0}
		],
		"par": 1,
		"hint": "Curved threading: use the planet's pull to bend a single shot through all three gates."
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
		"hint": "Two wells make a gravity corridor. Balance their pulls to steer between them to the target."
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

func _panel(rect: Rect2) -> void:
	draw_rect(rect, COL_PANEL, true)
	draw_rect(rect, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.35), false, 2.0)

func _glow(pos: Vector2, r: float, color: Color, layers: int) -> void:
	for i in range(layers):
		var f: float = 1.0 - float(i) / float(max(layers, 1))
		var a: float = 0.10 + 0.10 * f
		var rr: float = r * (1.0 + float(i) * 0.55)
		draw_circle(pos, rr, Color(color.r, color.g, color.b, a))
	draw_circle(pos, r, color)

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
	_text_center(W * 0.5, 262, "Bend your shot through gravity, match the trajectory", 16, COL_DIM)
	var box: Rect2 = Rect2(70, 360, 460, 230)
	_panel(box)
	_text_center(W * 0.5, 400, "TAP / SPACE to start", 24, COL_ACCENT2)
	_text_left(Vector2(100, 446), "Controls:", 16, COL_TEXT)
	_text_left(Vector2(100, 474), "Drag from cannon = aim (dir=angle, length=power)", 14, COL_DIM)
	_text_left(Vector2(100, 498), "Arrows = adjust angle/power   Space = fire", 14, COL_DIM)
	_text_left(Vector2(100, 522), "R = retry   N = next (on win)   Esc = back", 14, COL_DIM)
	_text_left(Vector2(100, 546), "GUNNER: clear targets   GATES: thread every ring", 14, COL_DIM)
	var total: int = 0
	for s in stage_stars:
		total += int(s)
	_text_center(W * 0.5, 650, "Stars earned: " + str(total) + " / " + str(STAGES.size() * 3), 16, COL_ACCENT2)
	_text_center(W * 0.5, 706, "An educational physics episode", 13, COL_DIM)

func _draw_arena() -> void:
	# faint arena border
	draw_rect(Rect2(8, 80, W - 16, H - 96), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.10), false, 1.0)
	# wells
	for w in wells:
		var wd: Dictionary = w
		var wp: Vector2 = wd["pos"]
		var rad: float = float(wd["radius"])
		_glow(wp, rad, Color(0.35, 0.45, 0.7), 4)
		draw_circle(wp, rad, Color(0.20, 0.28, 0.45))
		draw_arc(wp, rad + 6.0, 0, TAU, 40, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.30), 1.5)
		var mk: float = float(wd["mass"]) / 1000.0
		var label: String = String(wd["name"]) + "  M=" + str(snappedf(mk, 0.1)) + "k"
		_text_center(wp.x, wp.y + rad + 20.0, label, 13, COL_DIM)
	# targets (pulsing)
	if stage_type == "gunner":
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.005)
		for t in targets:
			var td: Dictionary = t
			if bool(td["dead"]):
				continue
			var tp: Vector2 = td["pos"]
			var trad: float = float(td["radius"])
			_glow(tp, trad * (0.85 + 0.15 * pulse), COL_ACCENT2, 3)
			draw_arc(tp, trad + 4.0, 0, TAU, 32, COL_ACCENT2, 2.0)
			draw_circle(tp, 4.0, COL_DANGER)
	# gates (rings)
	if stage_type == "gates":
		for g in gates:
			var gd: Dictionary = g
			var gp: Vector2 = gd["pos"]
			var grad: float = float(gd["radius"])
			if bool(gd["passed"]):
				draw_circle(gp, grad, Color(COL_GOOD.r, COL_GOOD.g, COL_GOOD.b, 0.20))
				draw_arc(gp, grad, 0, TAU, 40, COL_GOOD, 3.0)
				_text_center(gp.x, gp.y + 5.0, "PASS", 13, COL_GOOD)
			else:
				draw_arc(gp, grad, 0, TAU, 40, COL_ACCENT, 2.5)
				draw_arc(gp, grad - 6.0, 0, TAU, 40, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.4), 1.0)
	# cannon
	_glow(cannon, 10.0, COL_ACCENT, 3)
	draw_circle(cannon, 14.0, Color(0.15, 0.22, 0.35))
	draw_arc(cannon, 14.0, 0, TAU, 24, COL_ACCENT, 2.0)
	# live projectile + trail
	if proj_alive or ep_state == ST_FLYING:
		_draw_trail()
		if proj_alive:
			_glow(proj_pos, PROJ_RADIUS, COL_ACCENT2, 4)
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
	var tlabel: String = "GUNNER"
	if stage_type == "gates":
		tlabel = "THREAD THE GATES"
	_text_left(Vector2(20, 32), "Stage " + str(stage_index + 1) + "/" + str(STAGES.size()) + "  -  " + tlabel, 18, COL_ACCENT)
	var pv: int = int(s["par"])
	_text_left(Vector2(20, 56), "Shots: " + str(shots_used) + "   Par: " + str(pv) + "   (Esc/BACK = main game)", 13, COL_DIM)
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
	if won:
		_text_center(W * 0.5, 350, "STAGE CLEAR!", 34, COL_GOOD)
		_draw_stars(W * 0.5, 392, last_stars)
		_text_center(W * 0.5, 446, "Shots used: " + str(shots_used) + "   Par: " + str(int(STAGES[stage_index]["par"])), 15, COL_DIM)
		if stage_index + 1 < STAGES.size():
			_text_center(W * 0.5, 496, "N / SPACE = next stage", 16, COL_ACCENT2)
		else:
			_text_center(W * 0.5, 496, "All stages done! N = title", 16, COL_ACCENT2)
		_text_center(W * 0.5, 524, "R = retry   Esc = back to game", 13, COL_DIM)
	else:
		_text_center(W * 0.5, 360, "MISS", 34, COL_DANGER)
		_text_center(W * 0.5, 410, "Closest approach: " + str(int(last_miss_dist)) + " px", 15, COL_DIM)
		_text_center(W * 0.5, 470, "R = retry stage", 16, COL_ACCENT2)
		_text_center(W * 0.5, 500, "Esc = back to game", 13, COL_DIM)

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
	var r: Rect2 = Rect2(W - 96, 14, 82, 34)
	draw_rect(r, Color(0.12, 0.15, 0.22, 0.9), true)
	draw_rect(r, Color(COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, 0.6), false, 1.5)
	_text_center(r.position.x + r.size.x * 0.5, r.position.y + 23, "BACK", 14, COL_DANGER)
