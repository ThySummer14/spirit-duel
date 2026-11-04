class_name StunRules
extends RefCounted
## One entry point for character stun and the match-long enemy stun ledger.
static func blocks(gs, owner: int, unit: Dictionary, card: Dictionary = {}) -> bool:
	return int(unit.get("frozen",0))>0 and not card.get("allowStunnedSource",false) and not gs.VerifiedRules.Raccoon.ignores(gs,owner,unit)

static func apply(gs, owner: int, idx: int, duration: int = 1, source_owner: int = -1) -> void:
	if duration <= 0 or gs.winner >= 0: return
	if source_owner < 0: source_owner = 1 - owner
	var p: Dictionary = gs.player(owner)
	if idx >= 0 and int(p.units[idx].hp) <= 0: return
	var target: Dictionary = p if idx < 0 else p.units[idx]
	var key := "avatarFrozen" if idx < 0 else "frozen"
	var first := int(target.get(key, 0)) == 0
	# A stun applied during the target's own turn lasts through its NEXT turn.
	var remaining := duration + (1 if owner == gs.current_player else 0)
	if idx >= 0 and target.has("movementHolders"): target.movementBaseFrozen = maxi(int(target.get("movementBaseFrozen", 0)), remaining)
	if not target.has("stunOwners"): target.stunOwners={}
	target.stunOwners[str(source_owner)]=maxi(int(target.stunOwners.get(str(source_owner),0)),remaining)
	target[key] = maxi(int(target.get(key, 0)), remaining)
	if first and source_owner != owner:
		var enemy: Dictionary = gs.player(1 - owner)
		enemy.enemyStuns = int(enemy.get("enemyStuns", 0)) + 1
	gs.VerifiedRules.event(gs, "stun-applied", {"player": owner, "uid": "" if idx < 0 else target.uid, "remaining": int(target[key]), "newStun": first})
	gs.VerifiedRules.Xuenv.stunned(gs, owner, idx, first, source_owner)
	gs.VerifiedRules.Raccoon.stunned(gs,owner,idx)
	gs._log("%s 陷入眩晕。" % [p.name + "的牌手" if idx < 0 else target.name], gs.TONE_CARD)

static func count(gs, owner: int) -> int:
	var p: Dictionary = gs.player(owner)
	var total := 1 if int(p.get("avatarFrozen", 0)) > 0 else 0
	for unit in p.units:
		if int(unit.hp) > 0 and int(unit.frozen) > 0: total += 1
	return total

static func end_turn(gs, owner: int) -> void:
	var p: Dictionary = gs.player(owner)
	for target in [p]+p.units:
		for owner_key in target.get("stunOwners",{}): target.stunOwners[owner_key]=maxi(0,int(target.stunOwners[owner_key])-1)
	p.avatarFrozen = maxi(0, int(p.get("avatarFrozen", 0)) - 1)
	for unit in p.units:
		if unit.has("movementHolders"):
			unit.movementBaseFrozen = maxi(0, int(unit.get("movementBaseFrozen", 0)) - 1)
			unit.frozen = maxi(1, int(unit.movementBaseFrozen))
		else: unit.frozen = maxi(0, int(unit.frozen) - 1)
	gs.VerifiedRules.Otakemaru.stun_ended_turn(gs,owner)
