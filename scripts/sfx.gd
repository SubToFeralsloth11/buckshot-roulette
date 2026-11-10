extends Node
## Procedural sound effects. Call Sfx.play("shot") etc.

const RATE := 22050
var _streams := {}
var _breath: AudioStreamPlayer

func _ready() -> void:
	_streams["shot"] = _make(0.9, func(t, r): return r * exp(-t * 7.0) * (1.0 if t > 0.004 else t / 0.004) + sin(t * 70.0 * TAU) * exp(-t * 10.0) * 0.6)
	_streams["click"] = _make(0.08, func(t, r): return (r * 0.5 + sin(t * 2400.0 * TAU)) * exp(-t * 90.0))
	_streams["eject"] = _make(0.35, func(t, r): return sin(t * (900.0 + 600.0 * t) * TAU) * exp(-t * 14.0) * 0.5 + r * exp(-t * 40.0) * 0.4)
	_streams["item"] = _make(0.25, func(t, r): return sin(t * (520.0 + 900.0 * t) * TAU) * exp(-t * 9.0) * 0.4)
	_streams["rack"] = _make(0.3, func(t, r): return r * (exp(-t * 60.0) + exp(-maxf(t - 0.15, 0.0) * 60.0) * (1.0 if t > 0.15 else 0.0)) * 0.7)
	_streams["spin"] = _make(0.6, func(t, r): return r * 0.15 * sin(t * 30.0 * TAU) * exp(-t * 3.0))
	_streams["thud"] = _make(0.4, func(t, r): return sin(t * 60.0 * TAU) * exp(-t * 12.0) + r * exp(-t * 30.0) * 0.3)
	_streams["heal"] = _make(0.5, func(t, r): return sin(t * 660.0 * TAU) * 0.3 * exp(-t * 4.0) + sin(t * 990.0 * TAU) * 0.2 * exp(-t * 4.0))
	_streams["hurt"] = _make(0.5, func(t, r): return sin(t * (200.0 - 150.0 * t) * TAU) * 0.6 * exp(-t * 5.0))
	var breath_fn := func(t: float, r: float) -> float:
		var env := pow(maxf(0.0, sin(t / 3.2 * TAU)), 2.0) * 0.6 + pow(maxf(0.0, -sin(t / 3.2 * TAU)), 2.0) * 0.3
		return r * env * 0.12
	var breath := _make(3.2, breath_fn, true)
	_breath = AudioStreamPlayer.new()
	_breath.stream = breath
	_breath.volume_db = -14.0
	add_child(_breath)

func start_breathing() -> void:
	if not _breath.playing:
		_breath.play()

func _make(length: float, f: Callable, loop := false) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var r := randf_range(-1.0, 1.0)
		lp = lerpf(lp, r, 0.35)  # soften the noise
		var v: float = clampf(f.call(float(i) / RATE, lp), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s

func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
