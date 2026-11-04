class_name HouseRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const TOKENS := ["yaowu-lingli","yaowu-quan"]
static func source(u: Dictionary) -> bool:
	return bool(Content.runtime_unit_def(u).get("houseRules",false))
static func active(u: Dictionary) -> bool:
	return int(u.hp)>0 and int(u.level)>0 and not u.get("removed",false)
static func armor_bonus(gs, owner: int) -> int:
	if owner<0: return 0
	return gs.player(owner).units.filter(func(u):return active(u) and not u.get("baseRulesSuppressed",false) and u.get("formRules",{}).get("houseJoy",false)).size()
static func break_bonus(gs, _source_owner: int, target_owner: int) -> int:
	return armor_bonus(gs,1-target_owner)
static func enhance(gs, owner: int, amount: int, reason: String) -> void:
	if amount<=0: return
	for entry in gs.player(owner).hand:
		if entry.definitionId not in TOKENS: continue
		entry.houseEnhance=int(entry.get("houseEnhance",0))+amount
		gs.VerifiedRules.event(gs,"house-token-enhanced",{"player":owner,"instanceId":entry.instanceId,"amount":amount,"total":entry.houseEnhance,"reason":reason})
static func turn_start_removed(gs, status_owner: int, idx: int, armor_removed: int, break_removed: int) -> void:
	# Each actual status-removal event adds one to the existing hand instance,
	# regardless of how large the removed value was. Noise is amount-based.
	if armor_removed>0: enhance(gs,status_owner,1,"回合开始移除护甲")
	if break_removed>0: enhance(gs,1-status_owner,1,"回合开始移除破甲")
	if armor_removed>0 or break_removed>0: gs.VerifiedRules.event(gs,"house-natural-removal",{"player":status_owner,"index":idx,"armor":armor_removed,"armorBreak":break_removed})
static func generate(gs, owner: int) -> void:
	for u in gs.player(owner).units:
		if not source(u) or not active(u): continue
		var id: String="yaowu-quan" if u.awakened else "yaowu-lingli"
		if gs.player(owner).hand.any(func(e):return e.definitionId==id): continue
		if gs.player(owner).hand.size()>=int(gs.rules.maxHandSize): continue
		gs.player(owner).hand.append({"definitionId":id,"instanceId":"%s-house-%d" % [gs.player(owner).id,gs.next_card_id],"houseEnhance":0})
		gs.next_card_id+=1
		gs.VerifiedRules.event(gs,"house-token-created",{"player":owner,"uid":u.uid,"card":id})
static func turn_start(gs, owner: int) -> void:
	generate(gs,owner)
static func turn_end(gs, owner: int) -> void:
	generate(gs,owner)
	for src in gs.player(owner).units.size():
		var u: Dictionary=gs.player(owner).units[src]
		if not active(u) or u.get("baseRulesSuppressed",false) or not u.get("formRules",{}).get("houseRenew",false): continue
		if gs.player(owner).units.any(func(t):return active(t) and gs.VerifiedRules.OwlInsect.shikigami(t) and int(t.shield)>=5):
			gs._draw(owner,1)
			gs.VerifiedRules.event(gs,"house-renew-draw",{"player":owner,"uid":u.uid})
static func locate(gs, id) -> Dictionary:
	for owner in 2:
		if str(id)=="avatar-%d" % owner: return {"owner":owner,"index":-1}
		var idx: int=gs._unit_index_by_uid(owner,id)
		if idx>=0: return {"owner":owner,"index":idx}
	return {}
static func status(gs, owner: int, idx: int, key: String) -> int:
	if idx<0: return int(gs.player(owner).get("avatarArmor" if key=="armor" else "avatarArmorBreak",0))
	return int(gs.player(owner).units[idx].get("shield" if key=="armor" else "armorBreak",0))
static func remove_status(gs, owner: int, idx: int, key: String) -> int:
	var amount:=status(gs,owner,idx,key)
	if idx<0:
		gs.player(owner)["avatarArmor" if key=="armor" else "avatarArmorBreak"]=0
	else:
		var u: Dictionary=gs.player(owner).units[idx]
		if key=="armor":
			gs.VerifiedRules.StarBear.consumed_armor(u,amount); u.shield=0; u.shieldExpires=0
			gs.VerifiedRules.ArmorBlood.armor_changed(gs,u)
		else:
			gs.VerifiedRules.StarBear.consumed_break(u,amount); u.armorBreak=0
	gs.VerifiedRules.Poison.refresh_all(gs)
	gs.VerifiedRules.event(gs,"house-status-removed",{"player":owner,"index":idx,"status":key,"amount":amount})
	return amount
static func max_status(gs) -> int:
	var highest:=0
	for owner in 2:
		for idx in range(-1,gs.player(owner).units.size()):
			if idx>=0 and not active(gs.player(owner).units[idx]): continue
			highest=maxi(highest,maxi(status(gs,owner,idx,"armor"),status(gs,owner,idx,"break")))
	return highest
static func start_status_choice(gs, owner: int, src: int, target_id, action: String, keys: Array) -> void:
	if keys.size()==1:
		finish_status(gs,owner,src,target_id,action,str(keys[0])); return
	gs.pending_choice={"type":"house-status","playerIndex":owner,"sourceIndex":src,"targetId":target_id,"action":action,"instanceIds":keys.map(func(k):return "house:"+str(k)),"heading":"骚 声","title":"选择移除护甲或破甲","hint":"只移除所选的一类状态，按实际移除数值增强手中的灵力与灵力之泉。"}
	gs.phase="choice"
static func finish_status(gs, owner: int, src: int, target_id, action: String, key: String) -> void:
	var at:=locate(gs,target_id)
	if at.is_empty(): return
	var amount:=remove_status(gs,int(at.owner),int(at.index),key)
	if action=="noise": enhance(gs,owner,amount,"骚声")
	elif action=="wake": summon(gs,owner,src,amount)
static func choice_card(gs, owner: int, iid: String):
	if gs.pending_choice.get("type")!="house-status" or int(gs.pending_choice.playerIndex)!=owner or iid not in gs.pending_choice.instanceIds: return null
	var at:=locate(gs,gs.pending_choice.targetId)
	if at.is_empty(): return null
	var key:=iid.trim_prefix("house:"); var amount:=status(gs,int(at.owner),int(at.index),key)
	return {"id":iid,"unitId":"tianjingxia","name":"移除%d点%s" % [amount,"护甲" if key=="armor" else "破甲"],"type":"spell","level":1,"cost":0,"text":"只移除此角色上的%s，使手中的灵力与灵力之泉各增强%d。" % ["护甲" if key=="armor" else "破甲",amount]}
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="house-status" or int(c.playerIndex)!=owner or iid not in c.instanceIds: return false
	gs.pending_choice={}; gs.phase="main"
	finish_status(gs,owner,int(c.sourceIndex),c.targetId,str(c.action),iid.trim_prefix("house:"))
	gs._record("resolve_divination_choice",{"choice":"house-status","instanceId":iid},owner)
	gs._resolve_resolution_stack(); gs.state_changed.emit()
	return true
static func best_choice(gs, owner: int):
	if gs.pending_choice.get("type")!="house-status" or int(gs.pending_choice.playerIndex)!=owner: return null
	var at:=locate(gs,gs.pending_choice.targetId)
	if at.is_empty(): return str(gs.pending_choice.instanceIds[0])
	var best:=str(gs.pending_choice.instanceIds[0]); var score:=-1
	for iid in gs.pending_choice.instanceIds:
		var value:=status(gs,int(at.owner),int(at.index),str(iid).trim_prefix("house:"))
		if value>score: score=value; best=str(iid)
	return best
static func ai_choice(gs, owner: int):
	var iid=best_choice(gs,owner)
	return null if iid==null else resolve_choice(gs,owner,str(iid))
static func remove_summon(gs, owner: int, u: Dictionary, reason: String = "离开战斗区") -> void:
	if not u.get("houseSummon",false) or u.get("removed",false): return
	gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),reason)
	gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,u.uid),reason,false)
	u.hp=0; u.front=0; u.knockout=0; u.removed=true; u.houseDepartureRecorded=true
	gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":reason})
static func clear_summons(gs, owner: int) -> void:
	for u in gs.player(owner).units: remove_summon(gs,owner,u,"战斗区被替换")
static func remove_departed(gs) -> void:
	for owner in 2:
		for u in gs.player(owner).units:
			if u.get("houseSummon",false) and int(u.front)==0 and int(u.hp)>0: remove_summon(gs,owner,u)
static func summoned_knockout(gs, owner: int, u: Dictionary) -> void:
	if not u.get("houseSummon",false): return
	u.hp=0; u.front=0; u.knockout=0; u.removed=true; u.houseDepartureRecorded=true
	gs.VerifiedRules.event(gs,"house-summon-died",{"player":owner,"uid":u.uid})
static func revived(_gs, _owner: int, _idx: int) -> void:
	_gs.player(_owner).units[_idx].erase("houseDepartureRecorded")
static func summon(gs, owner: int, src: int, power: int) -> int:
	gs.VerifiedRules.Weaver.leave_front(gs,owner)
	var p: Dictionary=gs.player(owner)
	var u: Dictionary={"uid":"%s:house-%d" % [p.id,gs.next_card_id],"id":"tianjingxia-yaowu","name":"妖怪屋","title":"天井下召唤物","art":Content.unit_def("tianjingxia").art,"color":"#c0a060","baseAttack":power,"baseMaxHp":power,"attack":power,"maxHp":power,"hp":power,"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":"离开战斗区时移除。","charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"houseSummon":true,"removed":false,"summonerUid":p.units[src].uid}
	gs.next_card_id+=1; p.units.append(u)
	var idx: int=p.units.size()-1
	gs.VerifiedRules.Enma.refresh(gs)
	gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":u.summonerUid,"summonKind":"yaowu","power":power})
	if int(u.hp)<=0:
		if not u.get("removed",false): gs._knockout_unit(u,owner,src)
		return idx
	gs._fire_hooks(owner,idx,"unit-entered-front",{}); gs._run_form_hooks(owner,idx,"unit-entered-front",{})
	gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"response-complete"})
	return idx
static func knockout_snapshot(gs, source_owner: int, _source_index: int, victim: int, u: Dictionary, prior_break: int = -1) -> Array:
	var frames: Array=[]
	var marked:=int(u.get("armorBreak",0)) if prior_break<0 else prior_break
	if source_owner<0 or source_owner>=2 or victim<0 or marked<=0 or not gs.VerifiedRules.OwlInsect.shikigami(u): return frames
	for src in gs.player(source_owner).units.size():
		var observer: Dictionary=gs.player(source_owner).units[src]
		if active(observer) and not observer.get("baseRulesSuppressed",false) and observer.get("formRules",{}).get("houseShatter",false): frames.append({"kind":"house-shatter","playerIndex":source_owner,"sourceIndex":src,"victimPlayer":victim,"targetUid":u.uid})
	return frames
static func targets(gs, owner: int, card: Dictionary):
	if not card.get("houseRules",false) or card.get("effect") not in ["house-noise","house-wake","house-power","house-gather"]: return null
	var out: Array=[]
	for side in 2:
		for idx in range(-1,gs.player(side).units.size()):
			if idx<0 and card.effect in ["house-power","house-gather"]: continue
			if idx>=0:
				var u: Dictionary=gs.player(side).units[idx]
				if not active(u) or not gs.VerifiedRules.OwlInsect.shikigami(u): continue
				if side!=owner and (gs.VerifiedRules.Combat.has(u,"veil") or gs.VerifiedRules.Movement.has_veil(u)): continue
			elif side!=owner and gs.VerifiedRules.PipeFox.avatar_veil(gs,side): continue
			if card.effect=="house-noise" and status(gs,side,idx,"armor")<=0 and status(gs,side,idx,"break")<=0: continue
			if card.effect=="house-wake" and status(gs,side,idx,"armor" if side==owner else "break")<=0: continue
			out.append("avatar-%d" % side if idx<0 else str(gs.player(side).units[idx].uid))
	return out
static func can_use(gs, owner: int, card: Dictionary) -> bool:
	if not card.get("houseRules",false): return true
	if card.get("effect")=="house-token": return false
	if card.get("effect")=="house-awaken":
		var src: int=gs._source_index(owner,card)
		return src>=0 and not gs.player(owner).units[src].awakened
	return true
static func describe_card(gs, _owner: int, entry: Dictionary, card: Dictionary) -> Dictionary:
	if not card.get("houseRules",false): return card
	var out:=card.duplicate(true)
	if card.id in TOKENS:
		out.value=1+int(entry.get("houseEnhance",0)); out.effects[0].value=out.value
		out.currentCardStats="当前效果%d · 此实例增强%d次" % [out.value,int(entry.get("houseEnhance",0))]
		out.text+="\n当前实际效果%d。" % int(out.value)
	if card.get("effect")=="house-rain": out.text+="\n当前场上最大护甲/破甲%d。" % max_status(gs)
	return out
static func gather(gs, owner: int, target: Dictionary) -> void:
	var armor:=0; var broken:=0; var expires:=0
	for side in 2:
		for idx in range(-1,gs.player(side).units.size()):
			if idx>=0 and not active(gs.player(side).units[idx]): continue
			var a:=status(gs,side,idx,"armor")
			expires+=a if idx<0 else mini(a,int(gs.player(side).units[idx].get("shieldExpires",0)))
			armor+=remove_status(gs,side,idx,"armor")
			broken+=remove_status(gs,side,idx,"break")
	# Transfer statuses atomically. They are not newly generated effects, so
	# joy must not amplify them or cancel one class against the other.
	target.shield=mini(gs.VerifiedRules.ArmorBreak.STATUS_LIMIT,armor)
	target.shieldExpires=mini(int(target.shield),expires)
	target.armorBreak=mini(gs.VerifiedRules.ArmorBreak.STATUS_LIMIT,broken)
	gs.VerifiedRules.ArmorBlood.armor_changed(gs,target); gs.VerifiedRules.Poison.refresh_all(gs)
	gs.VerifiedRules.event(gs,"house-statuses-transferred",{"player":owner,"uid":target.uid,"armor":armor,"armorBreak":broken})
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target: Dictionary, target_id = null) -> bool:
	match str(effect.get("action","")):
		"house-noise":
			var at:=locate(gs,target_id)
			if at.is_empty(): return true
			var keys: Array=[]
			for key in ["armor","break"]:
				if status(gs,int(at.owner),int(at.index),key)>0: keys.append(key)
			if not keys.is_empty(): start_status_choice(gs,owner,src,target_id,"noise",keys)
		"house-wake":
			var at:=locate(gs,target_id)
			if not at.is_empty(): finish_status(gs,owner,src,target_id,"wake","armor" if int(at.owner)==owner else "break")
		"house-rain": gs._heal_avatar(owner,max_status(gs))
		"house-gather":
			if not target.is_empty() and int(target.hp)>0: gather(gs,owner,target)
		"house-power":
			var at:=locate(gs,target_id)
			if at.is_empty() or int(at.index)<0: return true
			if int(at.owner)==owner: gs._grant_unit_armor(gs.player(owner).units[int(at.index)],int(effect.value))
			else: gs.VerifiedRules.ArmorBreak.give(gs,owner,src,int(at.owner),int(at.index),int(effect.value))
		"house-spring":
			for idx in gs.player(owner).units.size():
				var u: Dictionary=gs.player(owner).units[idx]
				if active(u) and gs.VerifiedRules.OwlInsect.shikigami(u): gs._grant_unit_armor(u,int(effect.value))
			for idx in gs.player(1-owner).units.size():
				var u: Dictionary=gs.player(1-owner).units[idx]
				if active(u) and gs.VerifiedRules.OwlInsect.shikigami(u): gs.VerifiedRules.ArmorBreak.give(gs,owner,src,1-owner,idx,int(effect.value))
		"house-awaken":
			var u: Dictionary=gs.player(owner).units[src]; u.awakened=true; u.passive_hooks=[]
			gs._grow_unit(u,2,2)
			for entry in gs.player(owner).hand:
				if entry.definitionId=="yaowu-lingli": entry.definitionId="yaowu-quan"; entry.erase("originCard")
		"house-token": summon(gs,owner,src,int(effect.get("value",0)))
		_: return false
	return true
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="house-shatter": return false
	gs._damage_avatar(int(frame.victimPlayer),3,int(frame.playerIndex),int(frame.sourceIndex))
	gs.VerifiedRules.event(gs,"house-shatter",{"player":frame.playerIndex,"uid":gs.player(int(frame.playerIndex)).units[int(frame.sourceIndex)].uid,"targetUid":frame.targetUid,"victimPlayer":frame.victimPlayer})
	return true
static func unit_marks(gs, owner: int, idx: int) -> Array:
	var u: Dictionary=gs.player(owner).units[idx]; var out: Array=[]
	if source(u): out.append("回合始末补充"+("灵力之泉" if u.awakened else "灵力"))
	if u.get("houseSummon",false): out.append("妖怪屋 · 原始身材%d/%d · 离开战斗区移除" % [int(u.baseAttack),int(u.baseMaxHp)])
	return out
static func score_card(gs, owner: int, card: Dictionary, target_id = null):
	if not card.get("houseRules",false): return null
	var at:=locate(gs,target_id)
	match str(card.get("effect","")):
		"house-noise":
			return -100 if at.is_empty() else 30+maxi(status(gs,int(at.owner),int(at.index),"armor"),status(gs,int(at.owner),int(at.index),"break"))*3
		"house-wake": return -100 if at.is_empty() else 45+status(gs,int(at.owner),int(at.index),"armor" if int(at.owner)==owner else "break")*5
		"house-gather": return -100 if at.is_empty() or int(at.owner)!=owner else 55
		"house-rain": return mini(30-int(gs.player(owner).avatarHp),max_status(gs))*8
		"house-power": return -100 if at.is_empty() else 45+int(card.value)*2
		"house-spring": return 65+int(card.value)*5
		"house-awaken": return 75
		"form": return 60
	return 0
