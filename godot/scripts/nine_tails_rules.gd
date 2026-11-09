extends RefCounted

const Content := preload("res://scripts/content_loader.gd")
const Choice := preload("res://scripts/restored_card_choices.gd")
const Flow := preload("res://scripts/dragon_flow_rules.gd")
const ID := "jintianyuzaoqian"
const FOCUS := ["c66002","c66003","c66004","c66005","c66007"]
const ORIGINS := ["c22101","c22102","c22103"]

static func tails(u: Dictionary) -> int:
	return int(u.get("nineTails", 0))

static func describe(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("ninetailsRules", false): return card
	var src := Flow.source(gs, owner, ID)
	if src < 0: return card
	var out := card.duplicate(true)
	var n := tails(gs.player(owner).units[src])
	if int(inst.get("nineFreeTurn", -1)) == gs.turn_counter:
		out.nineFree = true
		out.cost = 0
	if card.id in FOCUS and Content.is_spell(out) and n >= 3 and "instant" not in out.keywords:
		out.keywords.append("instant")
	if card.id == "c66007": out.currentCardStats = "九尾之力 %d 层" % n
	return out

static func gain_focus_card(gs, owner: int, free: bool = false) -> void:
	var id: String = FOCUS[int(gs.next_random() % FOCUS.size())]
	var fields := {"nineFreeTurn":gs.turn_counter} if free else {}
	Choice.give(gs, owner, id, fields)

static func gain(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if int(u.hp) <= 0:
		u.ninePending = int(u.get("ninePending",0))+1
		return
	if tails(u) >= 9:
		var pool := Content.cards_for_unit(ID).filter(func(c): return not c.get("token",false) and int(c.get("deckLimit",2))>0)
		var pick := Choice.sample(gs, pool, 1)
		if not pick.is_empty(): Choice.give(gs, owner, str(pick[0].id))
		return
	u.nineTails = tails(u)+1
	gs.VerifiedRules.event(gs,"charm-attached",{"player":owner,"uid":u.uid,"charm":"九尾之力","count":u.nineTails})
	match int(u.nineTails):
		1,2:
			var attack := int(u.nineTails == 1)
			var hp := int(u.nineTails == 2)
			gs.VerifiedRules.Glutton.record_permanent(u,attack,hp)
			gs._grow_unit(u,attack,hp)
		4: gain_focus_card(gs, owner)
		5: u.spellPower = int(u.get("spellPower",0))+1
		6:
			u.spellPower = int(u.get("spellPower",0))+1
			gain_focus_card(gs, owner)
	if u.awakened: gs.resolution_stack.append({"kind":"cosmos-nine-origin","playerIndex":owner,"sourceIndex":src})

static func upgraded(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if u.id == ID and not u.get("baseRulesSuppressed",false): gain(gs, owner, src)

static func revived(gs, owner: int, src: int) -> void:
	var u: Dictionary = gs.player(owner).units[src]
	if u.id != ID: return
	var n := int(u.get("ninePending",0))
	u.erase("ninePending")
	for _i in n: gain(gs, owner, src)

static func ballad(gs, owner: int, src: int) -> void:
	gs.resolution_stack.append({"kind":"cosmos-nine-card","playerIndex":owner,"sourceIndex":src})
	gain(gs, owner, src)

static func turn_start(gs, owner: int) -> void:
	var src := Flow.active(gs, owner, ID)
	if src >= 0 and gs.player(owner).units[src].get("formRules",{}).get("nineBallad",false):
		ballad(gs,owner,src)

static func focus_health(gs, owner: int, card: Dictionary) -> int:
	if card.get("unitId") != ID: return 0
	var src := Flow.active(gs, owner, ID)
	if src < 0: return 0
	var u: Dictionary = gs.player(owner).units[src]
	if tails(u) < 7: return 0
	return 2 if int(u.hp) > 2 else -1

static func commit_focus_health(gs, owner: int, amount: int) -> void:
	var src := Flow.source(gs, owner, ID)
	if src < 0: return
	var u: Dictionary = gs.player(owner).units[src]
	u.hp = int(u.hp)-amount
	gs.VerifiedRules.event(gs,"cosmos-nine-focus",{"player":owner,"uid":u.uid,"lostHp":amount})

static func focus_completed(gs, owner: int, card: Dictionary) -> void:
	if not card.get("focusPaid",false): return
	var src := Flow.active(gs,owner,ID)
	if src >= 0 and tails(gs.player(owner).units[src])>=9:
		gs.resolution_stack.append({"kind":"cosmos-nine-hit","playerIndex":owner,"sourceIndex":src})

static func avatar_dealt(gs, victim: int, owner: int, src: int, amount: int, combat: bool) -> void:
	if amount <= 0 or combat or owner < 0 or src < 0 or owner == victim: return
	var u: Dictionary = gs.player(owner).units[src]
	if u.id == ID and tails(u) >= 8: gs._heal_unit(u, 1)

static func cast_origin(gs, owner: int, src: int) -> void:
	var deck := ORIGINS.duplicate()
	gs._shuffle(deck)
	for id in deck:
		var card := Content.card_def(id).duplicate(true)
		card.unitId = ID
		var target = gs.VerifiedRules.SpellReplay.random_target(gs, owner, card)
		if target == null and card.get("target","auto") != "auto": continue
		gs._push_card_frames(owner, id, target, card, src, 0, true)
		return

static func resolve_frame(gs, frame: Dictionary) -> bool:
	var owner := int(frame.get("playerIndex",-1))
	var src := int(frame.get("sourceIndex",-1))
	match frame.get("kind"):
		"cosmos-nine-card": gain_focus_card(gs, owner, true)
		"cosmos-nine-origin":
			if int(gs.player(owner).units[src].hp) > 0: cast_origin(gs, owner, src)
		"cosmos-nine-hit":
			var foes := Choice.sample(gs, Flow.random_enemy(gs, owner, true), 1)
			if not foes.is_empty(): Flow.hit(gs, owner, src, foes[0], 3)
		"cosmos-nine-assault":
			if int(gs.player(owner).units[src].hp) > 0: Flow.assault(gs, owner, src, frame.card)
		_: return false
	return true

static func resolve(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, _target: Dictionary, target_id) -> bool:
	if src < 0: return false
	var u: Dictionary = gs.player(owner).units[src]
	var spell_power := int(u.get("spellPower",0))
	var focus := bool(card.get("focusPaid",false))
	var enemy := 1-owner
	match effect.action:
		"ninetails-1":
			var hit := Flow.hit(gs,owner,src,target_id,3+spell_power)
			if hit.get("knocked",false): gain(gs,owner,src)
		"ninetails-2":
			var out := card.duplicate(true)
			var front: int = gs.front_index(enemy)
			if focus:
				out.attackBonus = int(out.attackBonus)+1
				out.combatOption.lethal = true
			gs.resolution_stack.append({"kind":"cosmos-nine-assault","playerIndex":owner,"sourceIndex":src,"card":out})
			if front < 0: gs._damage_avatar(enemy,1,owner,src)
			else:
				var hit: Dictionary = gs._damage_unit(enemy,front,1,owner,src)
				if focus and int(hit.get("dealt",0))>0 and not hit.get("knocked",false): gs.VerifiedRules.Panguan.destroy(gs,owner,src,enemy,front,card)
		"ninetails-3":
			var hit := Flow.hit(gs,owner,src,target_id,3+spell_power)
			if focus and int(hit.get("dealt",0)) > 0: gs._heal_avatar(owner,int(hit.dealt))
		"ninetails-4":
			var front: int = gs.front_index(enemy)
			if front >= 0: gs._damage_unit(enemy,front,4+spell_power,owner,src)
			if focus: gs._damage_avatar(enemy,4+spell_power,owner,src)
		"ninetails-5":
			gain(gs,owner,src)
			if focus: gs.VerifiedRules.ThreeTail.projectile(gs,owner,src,3+int(u.get("spellPower",0)),card.name)
		"ninetails-6":
			gain(gs,owner,src)
			gs._awaken(owner,src,card,effect.value)
		"ninetails-7":
			for _i in tails(u)+spell_power:
				if gs.winner >= 0: break
				var pool := Choice.sample(gs,Flow.random_enemy(gs,owner,true),1)
				if not pool.is_empty(): Flow.hit(gs,owner,src,pool[0],1)
			if focus: cast_origin(gs,owner,src)
		"ninetails-8":
			gs._apply_form(owner,src,card,effect.value)
			ballad(gs,owner,src)
		_: return false
	return true
