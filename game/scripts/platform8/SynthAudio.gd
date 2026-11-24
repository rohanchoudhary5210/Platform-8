class_name SynthAudio
extends RefCounted

## Builds short PCM sounds in code so the greybox needs no audio files.
# shortcut: synthesized placeholders; swap for recorded SFX in the art/audio pass.

const RATE := 22050

## fn(t: float) -> float in [-1, 1]. Loops are seamless when every frequency fits a whole number of cycles.
static func make(seconds: float, fn: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(fn.call(float(i) / RATE), -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s

static func hum() -> AudioStreamWAV:
	return make(1.0, func(t): return 0.22 * sin(TAU * 50 * t) + 0.12 * sin(TAU * 100 * t) + 0.05 * sin(TAU * 150 * t), true)

## Low tunnel rumble: a few low partials (whole cycles in 4 s) with a slow swell.
static func rumble() -> AudioStreamWAV:
	var parts := [[23.25, 0.0], [31.5, 1.3], [38.75, 2.1], [44.0, 0.7], [57.25, 2.9], [66.5, 1.8]]
	return make(4.0, func(t):
		var v := 0.0
		for p in parts:
			v += sin(TAU * p[0] * t + p[1])
		return v / parts.size() * (0.6 + 0.4 * sin(TAU * 0.25 * t)), true)

## Faint wheel screech for a train you never see.
static func screech() -> AudioStreamWAV:
	return make(3.0, func(t):
		var env := sin(PI * t / 3.0)
		return 0.35 * env * env * sin(TAU * 2750 * t + 6.0 * sin(TAU * 5 * t)))

static func footstep() -> AudioStreamWAV:
	return make(0.2, func(t): return (randf_range(-0.5, 0.5) + 0.6 * sin(TAU * 85 * t)) * exp(-t * 30.0))

## Two-tone PA chime.
static func chime() -> AudioStreamWAV:
	return make(1.4, func(t: float):
		var f := 659.0 if t < 0.55 else 523.0
		var local := t if t < 0.55 else t - 0.55
		return 0.5 * sin(TAU * f * t) * exp(-local * 3.5))
