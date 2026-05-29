extends Node2D

# Asset-free particle system. All visuals procedural via _draw().
# Public API:
#   explosion(pos, color, scale=1.0)
#   burst(pos, color, count, speed)
#   muzzle(pos, dir)
#   shockwave(pos, color)

const MAX_PARTICLES: int = 400
const DRAG: float = 0.92

# Particle "kind" constants
const KIND_SPARK: int = 0      # fading + shrinking filled circle
const KIND_LINE: int = 1       # fading streak drawn along velocity
const KIND_DEBRIS: int = 2     # spinning fading polygon shard
const KIND_RING: int = 3       # expanding stroked ring (alpha fades)

# Each particle is a Dictionary. Stored in a flat array; oldest recycled when full.
var _particles: Array = []

func _ready() -> void:
	z_index = 50
	set_process(true)

# ---------------------------------------------------------------------------
# Public effects
# ---------------------------------------------------------------------------

func explosion(pos: Vector2, color: Color, scl: float = 1.0) -> void:
	# Radial spark burst
	var spark_count: int = int(round(18.0 * scl))
	for i in range(spark_count):
		var ang: float = randf() * TAU
		var spd: float = randf_range(90.0, 320.0) * scl
		var v: Vector2 = Vector2(cos(ang), sin(ang)) * spd
		_add_spark(pos, v, color, randf_range(0.35, 0.7), randf_range(2.5, 5.5) * scl)
	# A few fast line streaks
	var line_count: int = int(round(6.0 * scl))
	for i in range(line_count):
		var ang2: float = randf() * TAU
		var spd2: float = randf_range(200.0, 420.0) * scl
		var v2: Vector2 = Vector2(cos(ang2), sin(ang2)) * spd2
		_add_line(pos, v2, color.lightened(0.3), randf_range(0.25, 0.45), randf_range(8.0, 16.0) * scl)
	# Debris shards
	var debris_count: int = int(round(5.0 * scl))
	for i in range(debris_count):
		var ang3: float = randf() * TAU
		var spd3: float = randf_range(60.0, 200.0) * scl
		var v3: Vector2 = Vector2(cos(ang3), sin(ang3)) * spd3
		_add_debris(pos, v3, color.darkened(0.1), randf_range(0.5, 0.9), randf_range(4.0, 9.0) * scl)
	# Expanding fading ring (core flash)
	_add_ring(pos, color.lightened(0.4), randf_range(0.3, 0.45), 6.0 * scl, randf_range(70.0, 110.0) * scl)
	# Bright central pop
	_add_spark(pos, Vector2.ZERO, Color(1, 1, 1, 1), 0.18, 9.0 * scl)
	queue_redraw()

func burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	# Generic colored spark spray
	for i in range(count):
		var ang: float = randf() * TAU
		var spd: float = randf_range(speed * 0.4, speed)
		var v: Vector2 = Vector2(cos(ang), sin(ang)) * spd
		_add_spark(pos, v, color, randf_range(0.3, 0.65), randf_range(2.0, 4.5))
	queue_redraw()

func muzzle(pos: Vector2, dir: Vector2) -> void:
	# Short cone flash in the firing direction
	var d: Vector2 = dir
	if d.length() < 0.001:
		d = Vector2.RIGHT
	d = d.normalized()
	var base_ang: float = d.angle()
	for i in range(7):
		var spread: float = randf_range(-0.35, 0.35)
		var ang: float = base_ang + spread
		var spd: float = randf_range(180.0, 360.0)
		var v: Vector2 = Vector2(cos(ang), sin(ang)) * spd
		_add_spark(pos, v, Color(1.0, 0.95, 0.6, 1.0), randf_range(0.08, 0.18), randf_range(2.0, 4.0))
	# A couple of forward streaks
	for i in range(2):
		var ang2: float = base_ang + randf_range(-0.12, 0.12)
		var v2: Vector2 = Vector2(cos(ang2), sin(ang2)) * randf_range(300.0, 460.0)
		_add_line(pos, v2, Color(1.0, 0.9, 0.5, 1.0), randf_range(0.06, 0.12), randf_range(6.0, 12.0))
	# Tiny pop at the muzzle
	_add_spark(pos + d * 4.0, Vector2.ZERO, Color(1, 1, 0.85, 1), 0.1, 5.0)
	queue_redraw()

func shockwave(pos: Vector2, color: Color) -> void:
	# Expanding stroked ring
	_add_ring(pos, color, randf_range(0.4, 0.6), 8.0, randf_range(160.0, 240.0))
	queue_redraw()

# ---------------------------------------------------------------------------
# Particle constructors
# ---------------------------------------------------------------------------

func _add_spark(pos: Vector2, vel: Vector2, color: Color, life: float, size: float) -> void:
	_push({
		"kind": KIND_SPARK,
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": life,
		"color": color,
		"size": size,
		"rot": 0.0,
		"spin": 0.0,
	})

func _add_line(pos: Vector2, vel: Vector2, color: Color, life: float, size: float) -> void:
	_push({
		"kind": KIND_LINE,
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": life,
		"color": color,
		"size": size,
		"rot": 0.0,
		"spin": 0.0,
	})

func _add_debris(pos: Vector2, vel: Vector2, color: Color, life: float, size: float) -> void:
	_push({
		"kind": KIND_DEBRIS,
		"pos": pos,
		"vel": vel,
		"life": life,
		"max_life": life,
		"color": color,
		"size": size,
		"rot": randf() * TAU,
		"spin": randf_range(-8.0, 8.0),
	})

func _add_ring(pos: Vector2, color: Color, life: float, start_radius: float, grow: float) -> void:
	# vel.x repurposed as current radius, vel.y as growth rate (px/sec)
	_push({
		"kind": KIND_RING,
		"pos": pos,
		"vel": Vector2(start_radius, grow),
		"life": life,
		"max_life": life,
		"color": color,
		"size": start_radius,
		"rot": 0.0,
		"spin": 0.0,
	})

func _push(p: Dictionary) -> void:
	if _particles.size() >= MAX_PARTICLES:
		_particles.pop_front()
	_particles.append(p)

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	var i: int = _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		var life: float = p.life
		life -= delta
		if life <= 0.0:
			_particles.remove_at(i)
			i -= 1
			continue
		p.life = life

		var kind: int = p.kind
		if kind == KIND_RING:
			var radius: float = p.vel.x
			var grow: float = p.vel.y
			radius += grow * delta
			p.vel = Vector2(radius, grow)
			p.size = radius
		else:
			var pos: Vector2 = p.pos
			var vel: Vector2 = p.vel
			pos += vel * delta
			vel *= pow(DRAG, delta * 60.0)
			p.pos = pos
			p.vel = vel
			var rot: float = p.rot
			var spin: float = p.spin
			p.rot = rot + spin * delta

		_particles[i] = p
		i -= 1

	queue_redraw()

# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _draw() -> void:
	for p in _particles:
		var kind: int = p.kind
		var life: float = p.life
		var max_life: float = p.max_life
		var t: float = 0.0
		if max_life > 0.0:
			t = clamp(life / max_life, 0.0, 1.0)
		var base_color: Color = p.color
		var col: Color = Color(base_color.r, base_color.g, base_color.b, base_color.a * t)
		var pos: Vector2 = p.pos
		var size: float = p.size

		if kind == KIND_SPARK:
			var r: float = max(0.5, size * t)
			draw_circle(pos, r, col)
		elif kind == KIND_LINE:
			var vel: Vector2 = p.vel
			var dir: Vector2 = vel
			if dir.length() < 0.001:
				dir = Vector2.RIGHT
			dir = dir.normalized()
			var len_px: float = size * (0.5 + 0.5 * t)
			var tail: Vector2 = pos - dir * len_px
			draw_line(tail, pos, col, max(1.0, 2.0 * t))
		elif kind == KIND_DEBRIS:
			var rot: float = p.rot
			var s: float = max(0.5, size * t)
			var pts: PackedVector2Array = PackedVector2Array()
			# triangular shard
			var a0: float = rot
			var a1: float = rot + TAU * 0.36
			var a2: float = rot + TAU * 0.66
			pts.append(pos + Vector2(cos(a0), sin(a0)) * s)
			pts.append(pos + Vector2(cos(a1), sin(a1)) * s * 0.8)
			pts.append(pos + Vector2(cos(a2), sin(a2)) * s)
			draw_colored_polygon(pts, col)
		elif kind == KIND_RING:
			var width: float = max(1.0, 4.0 * t)
			draw_arc(pos, max(1.0, size), 0.0, TAU, 48, col, width)
