class_name HandBlessingRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const WARD := "ward"
const EROSION := "erosion"
const LABELS := {
	"instant":"获得瞬发", "heal-self":"使用后恢复自身全部生命", "hit-enemy":"使用后对敌方牌手造成3伤害",
	"spell+1":"法术伤害+1", "encourage":"使用后鼓舞+2力量/+1护甲", "draw":"使用后抽一张牌",
	"combat+1+1":"战斗加成+1力量/+1护甲", "form+1+1":"形态+1力量/+1生命", "form+2+0":"形态+2力量", "form+0+2":"形态+2生命",
	"gain-swift":"形态获得迅捷", "gain-pierce":"形态获得贯通，+1力量", "gain-pursuit":"形态获得追猎，+1力量",
	"gain-unyielding":"形态获得不屈", "gain-barrier":"形态获得屏障", "gain-inspired":"形态获得昂扬，+1生命",
	"realm+4":"幻境进场耐久+4", "realm-others":"幻境进场使其他己方幻境耐久+1",
	"no-instant":"失去瞬发", "hurt-avatar":"使用后对己方牌手造成3伤害", "heal-enemy":"使用后为敌方牌手恢复3生命", "hurt-source":"使用后对所属式神造成3伤害",
	"spell-2":"法术伤害-2（最低0）", "suppress":"使用后己方压制-2力量/-1护甲", "combat-2-1":"战斗加成-2力量/-1护甲", "combat-1-2":"战斗加成-1力量/-2护甲",
	"form-2-1":"形态-2力量/-1生命", "form-1-2":"形态-1力量/-2生命", "form-0-3":"形态-3生命",
	"lose-swift":"形态失去迅捷，-1力量", "lose-pierce":"形态失去贯通，-1力量", "lose-first-strike":"形态失去先攻，-1力量", "lose-pursuit":"形态失去追猎，-1力量",
	"lose-unyielding":"形态失去不屈，-1生命", "lose-veil":"形态失去帷幕，-1生命", "lose-barrier":"形态失去屏障，-1生命", "lose-inspired":"形态失去昂扬，-1生命",
	"realm-half":"幻境进场后耐久减半", "cancel":"抵消已有的加护/蚀印"
}
static func kind(inst: Dictionary) -> String:
	return str(inst.get("handCharm",{}).get("kind",""))
static func pool(card: Dictionary, which: String) -> Array:
	var list: Array=["instant","heal-self","hit-enemy"] if which==WARD else ["no-instant","hurt-avatar","heal-enemy","hurt-source"]
	match str(card.get("type","")):
		"spell","awakening": list.append_array(["spell+1","encourage","draw"] if which==WARD else ["spell-2","suppress"])
		"combat": list.append_array(["combat+1+1"] if which==WARD else ["combat-2-1","combat-1-2"])
		"form": list.append_array(["form+1+1","form+2+0","form+0+2","gain-swift","gain-pierce","gain-pursuit","gain-unyielding","gain-barrier","gain-inspired"] if which==WARD else ["form-2-1","form-1-2","form-0-3","lose-swift","lose-pierce","lose-first-strike","lose-pursuit","lose-unyielding","lose-veil","lose-barrier","lose-inspired"])
		"realm": list.append_array(["realm+4","realm-others"] if which==WARD else ["realm-half"])
	return list
static func eligible(gs, owner: int, which: String) -> Array:
	return gs.player(owner if which==WARD else 1-owner).hand.filter(func(i):return kind(i)!=which)
static func start(gs, owner: int, which: String, context: Dictionary={}) -> void:
	var cards:=eligible(gs,owner,which)
	if cards.is_empty(): return
	gs._shuffle(cards)
	var count: int=mini(cards.size(),2+gs.VerifiedRules.KoiFragrance.extra(gs,owner,which))
	var choices: Dictionary={}; var ids: Array=[]
	for i in count:
		var inst: Dictionary=cards[i]; var effects: Array=[]
		if kind(inst)!="": effects=["cancel"]
		else:
			var effects_pool:=pool(Content.card_def(str(inst.definitionId)),which); gs._shuffle(effects_pool)
			for n in mini(effects_pool.size(),2 if gs.VerifiedRules.KoiFragrance.dual(gs,owner,which) else 1): effects.append(effects_pool[n])
		ids.append(str(inst.instanceId)); choices[str(inst.instanceId)]=effects
	gs.pending_choice={"type":"hand-blessing","playerIndex":owner,"zoneOwner":owner if which==WARD else 1-owner,"which":which,"instanceIds":ids,"offeredIds":ids.duplicate(),"effects":choices,"context":context.duplicate(true),"heading":"加 护" if which==WARD else "蚀 印","title":"选择一张手牌及其展示的随机效果","hint":"选择后只改变这一张真实手牌；加护和蚀印会相互抵消。"}
	gs.phase="choice"
static func instance(gs, owner: int, iid: String) -> Dictionary:
	for inst in gs.player(owner).hand:
		if str(inst.instanceId)==iid: return inst
	return {}
static func apply_mark(gs, actor: int, owner: int, inst: Dictionary, which: String, effects: Array) -> bool:
	if kind(inst)==which: return false
	var cancelled:=kind(inst)!=""
	if cancelled:
		inst.revealed=bool(inst.handCharm.get("baseRevealed",false)); inst.erase("handCharm")
	else:
		inst.handCharm={"kind":which,"effects":effects.duplicate(),"baseRevealed":inst.get("revealed",false),"sourceOwner":actor}
		if which==EROSION: inst.revealed=true
	gs.VerifiedRules.event(gs,"hand-charm-attached",{"player":actor,"victimPlayer":owner,"instanceId":inst.instanceId,"card":inst.definitionId,"which":which,"effects":effects.duplicate(),"cancelled":cancelled})
	return not cancelled
static func choice_card(gs, _owner: int, iid: String):
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="hand-blessing": return null
	var owner:=int(c.zoneOwner); var inst:=instance(gs,owner,iid)
	if inst.is_empty(): return {}
	var card: Dictionary=gs.hand_card_def(owner,gs.player(owner).hand.find(inst)).duplicate(true)
	var tips: Array=[]
	for effect in c.effects[iid]: tips.append(str(LABELS[effect]))
	card.effectReplacementText=tips; card.choiceExplanation="；".join(tips); card.currentCardStats=("加护 · " if c.which==WARD else "蚀印 · ")+" / ".join(tips)
	card.text+="\n选择后："+"；".join(tips)
	return card
static func resolve_choice(gs, owner: int, iid: String) -> bool:
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="hand-blessing" or int(c.playerIndex)!=owner or iid not in c.instanceIds: return false
	var zone:=int(c.zoneOwner); var inst:=instance(gs,zone,iid)
	if inst.is_empty(): return false
	var card:=Content.card_def(str(inst.definitionId)); var which:=str(c.which)
	gs._record("resolve_divination_choice",{"instanceId":iid,"card":inst.definitionId,"choice":"hand-blessing","which":which},owner)
	var applied:=apply_mark(gs,owner,zone,inst,which,c.effects[iid])
	gs.pending_choice={}; gs.phase="main"
	if not c.context.is_empty(): gs.resolution_stack.append({"kind":"pair-after-mark","playerIndex":owner,"context":c.context,"unitId":card.get("unitId",""),"selectedId":iid,"offeredIds":c.offeredIds})
	if applied: gs.VerifiedRules.KoiFragrance.charmed(gs,owner,zone,inst,which)
	gs._resolve_resolution_stack(); gs.state_changed.emit(); return true
static func ai_choice(gs, owner: int):
	var c: Dictionary=gs.pending_choice
	if c.get("type")!="hand-blessing": return null
	if int(c.playerIndex)!=owner: return false
	var best:=str(c.instanceIds[0]); var score:=-999
	for iid in c.instanceIds:
		var inst:=instance(gs,int(c.zoneOwner),str(iid)); var card:=Content.card_def(str(inst.definitionId)); var src: int=gs._source_index(int(c.zoneOwner),card)
		var value:=int(card.level)+(10 if src>=0 and int(gs.player(int(c.zoneOwner)).units[src].hp)>0 and int(gs.player(int(c.zoneOwner)).units[src].level)>=int(card.level) else 0)
		if value>score: best=str(iid); score=value
	return resolve_choice(gs,owner,best)
static func describe_card(_gs, _owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
	if inst.get("handCharm",{}).is_empty(): return card
	var c:=card.duplicate(true); var effects: Array=inst.handCharm.effects; c.handCharm=inst.handCharm.duplicate(true)
	var atk:=0; var hp:=0; var armor:=0; var gains: Array=[]; var lost: Array=[]; var tips: Array=[]
	for effect in effects:
		tips.append(str(LABELS[effect]))
		match str(effect):
			"instant":
				if "instant" not in c.keywords: c.keywords.append("instant")
			"no-instant": c.keywords=c.keywords.filter(func(k):return str(k).to_lower()!="instant"); c.handCharmNoInstant=true
			"spell+1": c.handCharmDamage=int(c.get("handCharmDamage",0))+1
			"spell-2": c.handCharmDamage=int(c.get("handCharmDamage",0))-2
			"combat+1+1": atk+=1; armor+=1
			"combat-2-1": atk-=2; armor-=1
			"combat-1-2": atk-=1; armor-=2
			"form+1+1": atk+=1; hp+=1
			"form+2+0": atk+=2
			"form+0+2": hp+=2
			"form-2-1": atk-=2; hp-=1
			"form-1-2": atk-=1; hp-=2
			"form-0-3": hp-=3
			"realm+4": c.realm.hp=int(c.realm.hp)+4
			"realm-half": c.realm.hp=maxi(0,int(c.realm.hp)/2)
			_:
				if str(effect).begins_with("gain-"):
					var key:=str(effect).trim_prefix("gain-"); gains.append(key)
					if key in ["pierce","pursuit"]: atk+=1
					if key=="inspired": hp+=1
				elif str(effect).begins_with("lose-"):
					var key:=str(effect).trim_prefix("lose-"); lost.append(key)
					if key in ["swift","pierce","first-strike","pursuit"]: atk-=1
					else: hp-=1
	if c.type=="combat":
		# Apply power at combat creation: native executors can compute their own bonus.
		c.handCharmCombatAttack=atk
		if not c.has("combatOption"): c.combatOption={}
		c.combatOption.shield=int(c.combatOption.get("shield",0))+armor
	if c.type=="form" and c.get("value") is Dictionary:
		c.value.attack=int(c.value.attack)+atk; c.value.hp=int(c.value.hp)+hp
		for e in c.effects:
			if e.get("value") is Dictionary and e.value.has("attack") and e.value.has("hp"): e.value=c.value.duplicate(true)
		c.formRules.handCharmKeywords=gains; c.formRules.handLostKeywords=lost
		c.keywords=c.keywords.filter(func(k):return k not in lost)
		c.formRules.combatKeywords=c.formRules.get("combatKeywords",[]).filter(func(k):return k not in lost)
	c.handCharmPost=effects.duplicate()
	c.text+="\n"+("加护：" if kind(inst)==WARD else "蚀印：")+"；".join(tips)
	c.effectReplacementText=tips
	c.currentCardStats="；".join(tips)
	return c
static func damage_delta(gs, owner: int, src: int, combat: bool) -> int:
	if combat or gs._card_effect_context.is_empty(): return 0
	var ctx: Dictionary=gs._card_effect_context
	if int(ctx.get("playerIndex",-2))!=owner or (src>=0 and src!=int(ctx.get("sourceIndex",-1))): return 0
	return int(ctx.get("cardOverride",{}).get("handCharmDamage",0))
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
	var u: Dictionary=gs.player(owner).units[src]
	for key in card.get("formRules",{}).get("handCharmKeywords",[]):
		match str(key):
			"swift": u.swift=true
			"barrier": u.barrier=true
			"unyielding": u.unyielding=true
			"inspired": u.inspired=true
	for key in card.get("formRules",{}).get("handLostKeywords",[]):
		if key in ["swift","barrier","unyielding","inspired"]: u[key]=false
static func started(gs, owner: int, src: int, card: Dictionary) -> void:
	var armor:=int(card.get("combatOption",{}).get("shield",0))
	if card.get("type")=="combat" and armor<0:
		var u: Dictionary=gs.player(owner).units[src]; var lost:=mini(int(u.shield),-armor)
		gs.VerifiedRules.StarBear.consumed_armor(u,lost); u.shield=int(u.shield)-lost
		gs.VerifiedRules.ArmorBlood.armor_changed(gs,u)
static func completed(gs, owner: int, src: int, card: Dictionary) -> void:
	var effects: Array=card.get("handCharmPost",[])
	for n in range(effects.size()-1,-1,-1):
		if effects[n] in ["heal-self","hit-enemy","encourage","draw","hurt-avatar","heal-enemy","hurt-source","suppress"]:
			gs.resolution_stack.append({"kind":"hand-charm-post","playerIndex":owner,"sourceIndex":src,"effect":effects[n]})
static func realm_entered(gs, owner: int, card: Dictionary) -> void:
	if "realm-others" not in card.get("handCharmPost",[]): return
	var realms: Array=gs.player(owner).realms
	for i in maxi(0,realms.size()-1): realms[i].hp=int(realms[i].hp)+1
static func resolve_frame(gs, frame: Dictionary) -> bool:
	if frame.get("kind")!="hand-charm-post": return false
	var owner:=int(frame.playerIndex); var src:=int(frame.sourceIndex); var u: Dictionary=gs.player(owner).units[src] if src>=0 else {}
	match str(frame.effect):
		"heal-self":
			if src>=0:gs._heal_unit(u,int(u.maxHp))
		"hit-enemy": gs._damage_avatar(1-owner,3,owner,src)
		"encourage": gs._apply_encourage(owner,2,1)
		"draw": gs._draw(owner,1)
		"hurt-avatar": gs._damage_avatar(owner,3,owner,src)
		"heal-enemy": gs._heal_avatar(1-owner,3)
		"hurt-source":
			if src>=0:gs._damage_unit(owner,src,3,owner,src)
		"suppress": gs._apply_encourage(owner,-2,-1)
	return true
static func can_use(card: Dictionary) -> bool:
	return card.get("type")!="form" or not card.has("handCharm") or not (card.get("value") is Dictionary) or int(card.value.get("hp",0))>0
