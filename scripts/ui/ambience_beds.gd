extends RefCounted
## The background sound of each place: wind through the Ruins, the Fen's damp
## hum, the Steppe's gusts, the Frostspine's whistle, rain and thunder-rumble
## at the Storm Crown, the Crucible's furnace, and the quiet workshop hum of
## the map, laboratory and Codex. All of it is synthesised the first time a
## place is heard (no audio files) from a fixed seed, so it is the same every
## time, and kept for the rest of the session.

const Synth = preload("res://addons/hatchery/audio/synth.gd")

## Each layer: [kind, decibels, ...shape]. wind: [seconds, smooth];
## hiss: [seconds]; drone: [seconds, root hz, ratios].
const BEDS: Dictionary = {
	"workshop": [["drone", -25.0, 8.0, 55.0, [1.0, 1.5, 2.0]], ["wind", -24.0, 7.0, 0.008]],
	"ruins": [["wind", -15.0, 9.0, 0.015], ["drone", -27.0, 8.0, 49.0, [1.0, 1.5]]],
	"fen": [["wind", -21.0, 9.0, 0.03], ["hiss", -33.0, 5.0], ["drone", -28.0, 8.0, 73.0, [1.0, 1.25, 1.5]]],
	"steppe": [["wind", -13.0, 9.0, 0.03], ["wind", -17.0, 7.0, 0.008]],
	"frost": [["wind", -15.0, 9.0, 0.06], ["drone", -33.0, 8.0, 330.0, [1.0, 1.5]]],
	"storm": [["hiss", -17.0, 6.0], ["wind", -16.0, 9.0, 0.02], ["drone", -25.0, 8.0, 41.0, [1.0, 1.5]]],
	"crucible": [["drone", -20.0, 8.0, 46.0, [1.0, 1.5, 2.0]], ["hiss", -31.0, 5.0], ["wind", -23.0, 9.0, 0.01]],
}

static var _made: Dictionary = {}


## The layers for Ambience.play_bed; an unknown place falls back to the workshop.
static func layers(bed: String) -> Array:
	if not BEDS.has(bed):
		bed = "workshop"
	if not _made.has(bed):
		_made[bed] = _build(bed)
	return _made[bed]


static func _build(bed: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(bed)
	var result: Array = []
	var index: int = 0
	for layer in BEDS[bed]:
		var stream: AudioStreamWAV
		match String(layer[0]):
			"wind":
				stream = Synth.wind_loop(rng, float(layer[2]), float(layer[3]))
			"hiss":
				stream = Synth.hiss_loop(rng, float(layer[2]))
			"drone":
				stream = Synth.drone_loop(float(layer[3]), layer[4], float(layer[2]))
		# Layers start at different points so their swells do not line up.
		result.append({"stream": stream, "db": float(layer[1]), "offset": 0.37 * index})
		index += 1
	return result
