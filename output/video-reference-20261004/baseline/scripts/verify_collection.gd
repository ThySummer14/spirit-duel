extends SceneTree
## 秘闻阁开包/合成冒烟。

const CollectionStore := preload("res://scripts/collection_store.gd")
const VerifySupport := preload("res://scripts/verify_support.gd")
var _fixture := ""
var _failures := 0
var _checks := 0

func _init() -> void:
	_fixture = VerifySupport.isolate_stores()
	var data := CollectionStore.load_collection()
	if int(data.balance) < 100:
		printerr("COLLECTION_FAIL starting balance")
		_finish(1)
		return
	var r1 := CollectionStore.open_pack(12345)
	if not r1.get("ok", false):
		printerr("COLLECTION_FAIL pack ", r1.get("error"))
		_finish(1)
		return
	if (r1.get("cards") as Array).size() != 5:
		printerr("COLLECTION_FAIL pack size")
		_finish(1)
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
		_finish(1)
		return
	_verify_pity()
	print("COLLECTION_CHECKS checks=%d failures=%d" % [_checks, _failures])
	if _failures == 0:
		print("COLLECTION_OK pack=%d crafted=%s reward=%d" % [(r1.get("cards") as Array).size(), str(crafted), reward])
	_finish(0 if _failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("COLLECTION_FAIL ", description)


func _verify_pity() -> void:
	var data := CollectionStore._default()
	data.balance = 100000
	CollectionStore.save_collection(data)
	var pack := CollectionStore.open_pack(1)
	var epic_hit := false
	var ssr_hit := false
	for card in pack.cards:
		epic_hit = epic_hit or card.rarity in ["epic", "ssr"]
		ssr_hit = ssr_hit or card.rarity == "ssr"
	data = CollectionStore.load_collection()
	_check(int(data.pitySinceEpic) == (0 if epic_hit else 1), "epic pity advances once per pack")
	_check(int(data.pitySinceSsr) == (0 if ssr_hit else 1), "SSR pity advances once per pack")

	data.pitySinceEpic = 24
	data.pitySinceSsr = 0
	CollectionStore.save_collection(data)
	pack = CollectionStore.open_pack(12345)
	data = CollectionStore.load_collection()
	_check(pack.cards.all(func(card): return card.rarity == "epic"), "25th-pack epic pity matches the browser rules")
	_check(int(data.pitySinceEpic) == 0 and int(data.pitySinceSsr) == 1, "epic resets only its own pity")

	data.pitySinceEpic = 24
	data.pitySinceSsr = 39
	CollectionStore.save_collection(data)
	pack = CollectionStore.open_pack(12345)
	data = CollectionStore.load_collection()
	_check(pack.cards.all(func(card): return card.rarity == "ssr"), "SSR pity takes priority when both are due")
	_check(int(data.pitySinceEpic) == 0 and int(data.pitySinceSsr) == 0, "SSR resets both pity counters")

	data.version = 1
	data.pitySinceEpic = 20
	data.pitySinceSsr = 35
	var owned: Dictionary = data.owned.duplicate()
	var balance := int(data.balance)
	CollectionStore.save_collection(data)
	data = CollectionStore.load_collection()
	_check(int(data.version) == 2 and int(data.pitySinceEpic) == 4 and int(data.pitySinceSsr) == 7, "v1 card counters migrate to pack counters")
	_check(data.owned == owned and int(data.balance) == balance, "migration preserves currency and owned cards")
	var reloaded := CollectionStore.load_collection()
	_check(int(reloaded.version) == 2 and int(reloaded.pitySinceEpic) == 4 and int(reloaded.pitySinceSsr) == 7, "migration is not reapplied on subsequent loads")


func _finish(code: int) -> void:
	VerifySupport.cleanup_stores(_fixture)
	quit(code)
