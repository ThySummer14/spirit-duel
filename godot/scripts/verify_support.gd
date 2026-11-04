extends RefCounted
## Verification scripts must never alter the player's lineup, decks or collection.

const SaveStore := preload("res://scripts/save_store.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")
const Sfx := preload("res://scripts/ui/sfx.gd")


static func isolate_stores() -> String:
	var directory := OS.get_cache_dir().path_join("spirit-duel-verify-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	SaveStore.storage_path = directory.path_join("save.json")
	CollectionStore.storage_path = directory.path_join("collection.json")
	Sfx.storage_path = directory.path_join("settings.json")
	Sfx._settings.clear()
	return directory


static func cleanup_audio() -> void:
	# Native UI checks create the same audio hub as the game. Stop playback
	# before releasing cached streams so exit diagnostics reflect real leaks.
	if Sfx._music_tween != null and is_instance_valid(Sfx._music_tween):
		Sfx._music_tween.kill()
	Sfx._music_tween = null
	Sfx._music_name = ""
	if Sfx._hub != null and is_instance_valid(Sfx._hub):
		for voice in Sfx._hub.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
				voice.stream = null
		Sfx._hub.queue_free()
	Sfx._voices.clear()
	Sfx._music = null
	Sfx._hub = null
	Sfx._streams.clear()
	Sfx._last_played.clear()


static func cleanup_stores(directory: String) -> void:
	for name in ["save.json", "collection.json", "settings.json"]:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	SaveStore.storage_path = SaveStore.PATH
	CollectionStore.storage_path = CollectionStore.PATH
	Sfx.storage_path = Sfx.SETTINGS_PATH
	Sfx._settings.clear()
