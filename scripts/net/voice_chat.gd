class_name VoiceChat
extends Node
## Proximity voice for online runs. Captures the microphone, squeezes it down to 8-bit
## 11 kHz mono and sends it to the other players, who hear it from where you stand.
## Talking is also noise: monsters near you hear it too.

signal speaking_changed(speaking: bool)

const BUS := "Mic"
const SEND_INTERVAL := 0.08
const SPEAK_THRESHOLD := 0.015
const HANGOVER := 0.4
const NOISE_RADIUS := 9.0
const NOISE_INTERVAL := 0.6
const GAIN := 2.0

## Shared across runs: the M key toggles it.
static var muted := false

var player: Player
var speaking := false

var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _out := PackedByteArray()
var _sum := 0.0
var _count := 0
var _phase := 0.0
var _hang := 0.0
var _noise_timer := 0.0


func _ready() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, BUS)
		# Muted so you don't hear yourself; the capture effect still records.
		AudioServer.set_bus_mute(bus, true)
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	_capture.clear_buffer()
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = BUS
	add_child(_mic)
	_mic.play()


func _process(delta: float) -> void:
	_noise_timer = maxf(_noise_timer - delta, 0.0)
	var available := _capture.get_frames_available()
	if available <= 0:
		return
	var frames := _capture.get_buffer(available)
	if muted or player == null or not is_instance_valid(player) or not player.is_active():
		_out.clear()
		_hang = 0.0
		_set_speaking(false)
		return

	var step := AudioServer.get_mix_rate() / Player.VOICE_RATE
	var energy := 0.0
	for frame in frames:
		var sample := (frame.x + frame.y) * 0.5 * GAIN
		energy += sample * sample
		_sum += sample
		_count += 1
		_phase += 1.0
		if _phase >= step:
			_phase -= step
			var value := clampf(_sum / _count, -1.0, 1.0)
			_out.append(int(value * 127.0 + 128.0))
			_sum = 0.0
			_count = 0

	if sqrt(energy / frames.size()) > SPEAK_THRESHOLD:
		_hang = HANGOVER
	else:
		_hang = maxf(_hang - delta, 0.0)
	_set_speaking(_hang > 0.0)
	if not speaking:
		_out.clear()
		return
	if _out.size() >= int(Player.VOICE_RATE * SEND_INTERVAL):
		player.send_voice(_out)
		_out = PackedByteArray()
	if _noise_timer <= 0.0:
		_noise_timer = NOISE_INTERVAL
		GameNoise.emit(get_tree(), player.global_position, NOISE_RADIUS, GameNoise.Kind.VOICE)


func _set_speaking(value: bool) -> void:
	if value != speaking:
		speaking = value
		speaking_changed.emit(value)
