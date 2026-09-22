extends SceneTree
## 秘闻阁开包/合成冒烟。

const CollectionStore := preload("res://scripts/collection_store.gd")

func _init() -> void:
	var data := CollectionStore.load_collection()
	if int(data.balance) < 100:
		printerr("COLLECTION_FAIL starting balance")
		quit(1)
		return
	var r1 := CollectionStore.open_pack(12345)
	if not r1.get("ok", false):
		printerr("COLLECTION_FAIL pack ", r1.get("error"))
		quit(1)
		return
	if (r1.get("cards") as Array).size() != 5:
		printerr("COLLECTION_FAIL pack size")
		quit(1)
		return
	# 合成一张可能未满的卡
	var crafted := false
	for card in CollectionStore.load_collection().owned.keys():
		var r := CollectionStore.craft_card(str(card))
		if r.get("ok", false):
			crafted = true
			break
	var reward := CollectionStore.grant_match_reward(true)
	if reward <= 0:
		printerr("COLLECTION_FAIL reward")
		quit(1)
		return
	print("COLLECTION_OK pack=%d crafted=%s reward=%d balance=%d" % [
		(r1.get("cards") as Array).size(), str(crafted), reward,
		int(CollectionStore.load_collection().balance),
	])
	quit(0)
