extends Node

func play_sound(path: String, volume_db: float = -6.0) -> void:
	var stream = load(path)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.volume_db = volume_db
	player.play()

	# Limpia el reproductor cuando termina.
	if stream is AudioStream:
		var length: float = stream.get_length()
		await get_tree().create_timer(length + 0.1).timeout
		player.queue_free()


func play_tone(frequency: float = 440.0, duration: float = 0.12, volume_db: float = -8.0) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var sample_count := int(duration * wav.mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(wav.mix_rate)
		var envelope := 1.0 - (float(i) / float(sample_count))
		var value := sin(TAU * frequency * t) * envelope
		var sample := int(clamp(value * 32767.0, -32768.0, 32767.0))
		data.encode_s16(i * 2, sample)

	wav.data = data
	player.stream = wav
	player.volume_db = volume_db
	player.play()

	await get_tree().create_timer(duration + 0.1).timeout
	player.queue_free()
