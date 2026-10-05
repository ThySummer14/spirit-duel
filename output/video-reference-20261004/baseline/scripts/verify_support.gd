extends RefCounted
## Verification scripts must never alter the player's lineup, decks or collection.

const SaveStore := preload("res://scripts/save_store.gd")
const CollectionStore := preload("res://scripts/collection_store.gd")


static func isolate_stores() -> String:
	var directory := OS.get_cache_dir().path_join("spirit-duel-verify-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	SaveStore.storage_path = directory.path_join("save.json")
	CollectionStore.storage_path = directory.path_join("collection.json")
	return directory


static func cleanup_stores(directory: String) -> void:
	for name in ["save.json", "collection.json"]:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	SaveStore.storage_path = SaveStore.PATH
	CollectionStore.storage_path = CollectionStore.PATH
