extends Node

# Synthesized SFX module. All sounds baked once in _ready() as AudioStreamWAV
# from 16-bit signed little-endian PCM, mono, 22050 Hz. No asset files.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 6
const VOLUME_DB: float = -8.0

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

# --- music / mute ---
const MUSIC_VOL_DB: float = -16.0
var _music_player: AudioStreamPlayer = null
var _music_stream: AudioStreamWAV = null
var _muted: bool = false


func _ready() -> void:
	# Build the player pool for overlap.
	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)

	# Dedicated music player.
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOL_DB
	add_child(_music_player)
	_music_stream = _bake_music()

	# Bake every sound once.
	_sounds["shoot"] = _bake(_gen_shoot())
	_sounds["explode"] = _bake(_gen_explode())
	_sounds["hit"] = _bake(_gen_hit())
	_sounds["powerup"] = _bake(_gen_powerup())
	_sounds["dash"] = _bake(_gen_dash())
	_sounds["wave"] = _bake(_gen_wave())
	_sounds["gameover"] = _bake(_gen_gameover())


func play(snd: String) -> void:
	if _muted:
		return
	if not _sounds.has(snd):
		return
	var stream: AudioStreamWAV = _sounds[snd]

	# Prefer a free (non-playing) player; else take the oldest in rotation.
	var chosen: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = _players[_next_player]
		_next_player = (_next_player + 1) % POOL_SIZE

	chosen.stream = stream
	chosen.play()


# --- Music / mute -------------------------------------------------------------

func play_music() -> void:
	if _music_player == null:
		return
	if _music_stream != null:
		_music_player.stream = _music_stream
	_music_player.stream_paused = false
	if not _muted and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	if _music_player == null:
		return
	_music_player.stop()


func toggle_mute() -> bool:
	_muted = not _muted
	if _music_player != null:
		_music_player.stream_paused = _muted
	return _muted


func is_muted() -> bool:
	return _muted


func _bake_music() -> AudioStreamWAV:
	# A short, seamless musical loop: square bass + plucked arpeggio bed.
	var loop_secs: float = 4.0
	var n: int = int(loop_secs * MIX_RATE)
	# Arpeggio (A minor-ish) and bass note tables.
	var arp: Array[float] = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63]
	var bass: Array[float] = [110.0, 110.0, 146.83, 130.81]
	var step_dur: float = loop_secs / float(arp.size())
	var bass_dur: float = loop_secs / float(bass.size())
	var edge: float = 0.02
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(n)
	for i in range(n):
		var tt: float = float(i) / float(MIX_RATE)
		# Arpeggio note (wraps with the loop).
		var ai: int = int(tt / step_dur) % arp.size()
		var af: float = arp[ai]
		var local_a: float = fmod(tt, step_dur) / step_dur
		var aenv: float = pow(1.0 - local_a, 2.0)
		var asig: float = (fmod(tt * af, 1.0) * 2.0 - 1.0) * 0.30 * aenv
		# Bass square.
		var bi: int = int(tt / bass_dur) % bass.size()
		var bf: float = bass[bi]
		var bsig: float = 0.22
		if fmod(tt * bf, 1.0) >= 0.5:
			bsig = -0.22
		# Edge fade to guarantee a click-free seam at the loop point.
		var seam: float = 1.0
		if tt < edge:
			seam = tt / edge
		elif tt > loop_secs - edge:
			seam = (loop_secs - tt) / edge
		samples[i] = clampf((asig + bsig) * seam, -1.0, 1.0)
	var wav: AudioStreamWAV = _bake(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


# --- Bake float [-1,1] samples into a configured AudioStreamWAV ----------------

func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	var idx: int = 0
	for s in samples:
		var v: float = clampf(s, -1.0, 1.0)
		var iv: int = int(round(v * 32767.0))
		iv = clampi(iv, -32768, 32767)
		if iv < 0:
			iv += 65536
		data[idx] = iv & 0xFF
		data[idx + 1] = (iv >> 8) & 0xFF
		idx += 2

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


# --- Synthesis helpers --------------------------------------------------------

func _len(secs: float) -> int:
	return int(secs * MIX_RATE)


# --- Individual sound generators ----------------------------------------------

func _gen_shoot() -> PackedFloat32Array:
	# Short rising zap.
	var n: int = _len(0.12)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerp(420.0, 1500.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env: float = pow(1.0 - t, 1.5)
		out[i] = sin(phase) * env * 0.7
	return out


func _gen_explode() -> PackedFloat32Array:
	# Filtered noise burst with exponential decay.
	var n: int = _len(0.45)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var noise: float = randf_range(-1.0, 1.0)
		# Low-pass smoothing for a duller boom.
		lp = lerp(lp, noise, 0.25)
		var env: float = pow(0.0005, t)  # fast exponential decay
		out[i] = lp * env * 0.95
	return out


func _gen_hit() -> PackedFloat32Array:
	# Low thud: short low-freq sine with quick decay + a touch of noise.
	var n: int = _len(0.14)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerp(180.0, 70.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env: float = pow(1.0 - t, 2.0)
		var body: float = sin(phase)
		var click: float = randf_range(-1.0, 1.0) * pow(1.0 - t, 8.0) * 0.3
		out[i] = (body * 0.85 + click) * env
	return out


func _gen_powerup() -> PackedFloat32Array:
	# Rising 3-note arpeggio.
	var notes: Array[float] = [523.25, 659.25, 783.99]  # C5 E5 G5
	var note_len: float = 0.1
	var n: int = _len(note_len * notes.size())
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var seg: int = _len(note_len)
	var phase: float = 0.0
	for i in range(n):
		var ni: int = clampi(int(float(i) / float(seg)), 0, notes.size() - 1)
		var freq: float = notes[ni]
		phase += TAU * freq / float(MIX_RATE)
		var local_t: float = float(i % seg) / float(seg)
		var env: float = sin(PI * local_t)  # smooth per-note bell
		out[i] = sin(phase) * env * 0.6
	return out


func _gen_dash() -> PackedFloat32Array:
	# Short whoosh: swept band of noise that rises then fades.
	var n: int = _len(0.22)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var noise: float = randf_range(-1.0, 1.0)
		# Sweep the low-pass coefficient up so it "opens" then closes.
		var sweep: float = sin(PI * t)
		var coef: float = lerp(0.05, 0.5, sweep)
		lp = lerp(lp, noise, coef)
		var env: float = sin(PI * t)
		out[i] = lp * env * 0.8
	return out


func _gen_wave() -> PackedFloat32Array:
	# Two-note fanfare.
	var notes: Array[float] = [392.0, 587.33]  # G4 -> D5
	var note_len: float = 0.14
	var n: int = _len(note_len * notes.size())
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var seg: int = _len(note_len)
	var phase: float = 0.0
	for i in range(n):
		var ni: int = clampi(int(float(i) / float(seg)), 0, notes.size() - 1)
		var freq: float = notes[ni]
		phase += TAU * freq / float(MIX_RATE)
		var local_t: float = float(i % seg) / float(seg)
		var env: float = pow(1.0 - local_t, 0.6)
		# Add a harmonic shimmer for fanfare brightness.
		var tone: float = sin(phase) * 0.7 + sin(phase * 1.5) * 0.3
		out[i] = tone * env * 0.6
	return out


func _gen_gameover() -> PackedFloat32Array:
	# Descending tone.
	var n: int = _len(0.5)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerp(440.0, 110.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env: float = pow(1.0 - t, 1.2)
		# Slight vibrato for a mournful feel.
		var vib: float = sin(TAU * 6.0 * t) * 0.02
		out[i] = sin(phase + vib) * env * 0.7
	return out
