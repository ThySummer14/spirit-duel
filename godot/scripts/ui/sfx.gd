class_name Sfx
extends RefCounted
## 音效与背景音乐。资源由 scripts/gen-godot-audio.py 程序化生成。
## 静态入口，首次调用时在场景树根挂一个播放器节点；无头/无音频设备时静默。

const SETTINGS_PATH := "user://spirit_duel/settings.json"
const VOICES := 10

static var _hub: Node
static var _voices: Array = []
static var _music: AudioStreamPlayer
static var _music_name := ""
static var _streams: Dictionary = {}
static var _settings: Dictionary = {}
static var _last_played: Dictionary = {}
static var storage_path: String = SETTINGS_PATH
static var _music_tween: Tween


static func settings() -> Dictionary:
	if _settings.is_empty():
		_settings = {"music": 0.6, "sfx": 0.8}
		if FileAccess.file_exists(storage_path):
			var data = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
			if data is Dictionary:
				for key in ["music", "sfx"]:
					var value = data.get(key)
					if (value is float or value is int) and is_finite(float(value)):
						_settings[key] = clampf(float(value), 0.0, 1.0)
	return _settings


static func set_volume(channel: String, value: float) -> void:
	if channel not in ["music", "sfx"] or not is_finite(value): return
	settings()[channel] = clampf(value, 0.0, 1.0)
	DirAccess.make_dir_recursive_absolute(storage_path.get_base_dir())
	var f := FileAccess.open(storage_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_settings))
	if channel == "music" and _music != null and is_instance_valid(_music):
		if _music_tween != null and is_instance_valid(_music_tween): _music_tween.kill()
		var desired := _stream(_music_name) if _music_name != "" else null
		if desired != null and _music.stream != desired:
			_music.stream = desired
			_music.play()
		_music.volume_db = _db(float(_settings.music)) - 6.0
	if channel == "sfx":
		for voice in _voices:
			if is_instance_valid(voice): voice.volume_db = _db(float(_settings.sfx) * float(voice.get_meta("volume", 1.0)))


static func _db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(linear)


static func _ensure() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _hub != null and is_instance_valid(_hub):
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	_hub = Node.new()
	_hub.name = "SfxHub"
	_hub.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_hub)
	_voices.clear()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		_hub.add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_hub.add_child(_music)
	_music.finished.connect(func(): if _music_name != "": _music.play())
	return true


static func _stream(name: String) -> AudioStream:
	if _streams.has(name): return _streams[name]
	var path := "res://assets/audio/%s.wav" % name
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamWAV and name.begins_with("bgm_"):
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	_streams[name] = s
	return s


## 播放一次音效。pitch_jitter 让重复音效不机械。
static func play(name: String, volume: float = 1.0, pitch: float = 1.0, pitch_jitter: float = 0.04) -> void:
	if not _ensure(): return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 35: return
	_last_played[name] = now
	var stream := _stream(name)
	if stream == null: return
	var player: AudioStreamPlayer = null
	for v in _voices:
		if not v.playing:
			player = v
			break
	if player == null: player = _voices[0]
	if not player.is_inside_tree(): return
	player.stream = stream
	player.set_meta("volume", volume)
	player.volume_db = _db(float(settings().sfx) * volume)
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	player.play()


static func music(name: String) -> void:
	if not _ensure(): return
	if _music_name == name and _music.playing: return
	_music_name = name
	var stream := _stream(name)
	if stream == null: return
	var player := _music
	if not player.is_inside_tree():
		(Engine.get_main_loop() as SceneTree).process_frame.connect(func(): music(name), CONNECT_ONE_SHOT)
		_music_name = ""
		return
	var target := _db(float(settings().music)) - 6.0
	if _music_tween != null and is_instance_valid(_music_tween): _music_tween.kill()
	if player.playing:
		var tw := player.create_tween()
		_music_tween = tw
		tw.tween_property(player, "volume_db", -40.0, 0.5)
		tw.tween_callback(func():
			player.stream = stream
			player.play()
		)
		tw.tween_property(player, "volume_db", target, 0.8)
	else:
		player.stream = stream
		player.volume_db = -40.0
		player.play()
		_music_tween = player.create_tween()
		_music_tween.tween_property(player, "volume_db", target, 1.2)
