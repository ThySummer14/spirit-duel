class_name FearWingRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
const Power := preload("res://scripts/hair_power_rules.gd")

static func source(u: Dictionary) -> bool:
 return not u.get("baseRulesSuppressed",false) and Content.runtime_unit_def(u).get("fearWingRules",false)
static func active(u: Dictionary) -> bool:
 return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func living(u: Dictionary) -> bool:
 return int(u.get("hp",0))>0 and not u.get("removed",false)
static func night(gs, owner: int) -> bool:
 return gs.player(owner).realms.any(func(r):return r.get("nativeRealm","")=="fear-wing-night" and int(r.get("hp",0))>0)
static func gain(gs, owner: int, count: int=1) -> void:
 var p:Dictionary=gs.player(owner)
 for _n in count:
  var found:Dictionary={}
  for inst in p.hand:
   if inst.get("definitionId","")=="juyi" and int(inst.get("fearStacks",1))<2:found=inst;break
  if not found.is_empty():found.fearStacks=int(found.get("fearStacks",1))+1;continue
  if p.hand.size()>=int(gs.rules.maxHandSize):continue
  p.hand.append({"definitionId":"juyi","instanceId":"fear-wing-%d"%gs.next_card_id,"fearStacks":1});gs.next_card_id+=1
 gs.VerifiedRules.event(gs,"fear-wing-gained",{"player":owner,"count":count})
static func candidates(gs, owner: int, targeted: bool=true) -> Array:
 return gs.player(1-owner).units.filter(func(u):return living(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and u.get("fearCharm",{}).is_empty() and (not targeted or not gs.VerifiedRules.Combat.has(u,"veil")))
static func attach(gs, owner: int, src: int, uid: String) -> bool:
 var idx:int=gs._unit_index_by_uid(1-owner,uid)
 if idx<0:return false
 var u:Dictionary=gs.player(1-owner).units[idx]
 if not living(u) or not gs.VerifiedRules.OwlInsect.shikigami(u) or not u.get("fearCharm",{}).is_empty():return false
 u.fearCharm={"owner":owner,"sourceUid":str(gs.player(owner).units[src].uid)}
 gs.VerifiedRules.event(gs,"fear-attached",{"player":owner,"sourceUid":gs.player(owner).units[src].uid,"uid":uid})
 return true
static func _random_attach(gs, owner: int, src: int) -> void:
 var pool:Array=candidates(gs,owner,false)
 if not pool.is_empty():attach(gs,owner,src,str(pool[int(gs.next_random()%pool.size())].uid))
static func rule_event(gs, kind: String, details: Dictionary) -> void:
 if kind!="battle-power-changed" or int(details.get("value",0))<=0:return
 var owner:int=int(details.get("player",-1));var src:int=gs._unit_index_by_uid(owner,str(details.get("uid",""))) if owner>=0 else -1
 if src<0 or not source(gs.player(owner).units[src]) or not active(gs.player(owner).units[src]):return
 var uid:String=str(gs.player(owner).units[src].uid)
 # Each charm observes the resource gained, rather than current power or printed attack.
 for u in gs.player(1-owner).units.duplicate():
  if living(u) and u.get("fearCharm",{}).get("sourceUid","")==uid and int(u.fearCharm.owner)==owner:
   gs.resolution_stack.append({"kind":"fw-damage","playerIndex":owner,"sourceIndex":src,"targetUid":str(u.uid),"amount":int(details.value)})
static func begin_turn(gs, owner: int) -> void:
 for u in gs.player(owner).units:
  if source(u) and active(u):gain(gs,owner)
static func describe_card(gs, owner: int, inst: Dictionary, card: Dictionary) -> Dictionary:
 if not card.get("fearWingRules",false):return card
 var c:Dictionary=card.duplicate(true);var src:int=gs._source_index(owner,c)
 if c.id=="juyi":
  var n:int=clampi(int(inst.get("fearStacks",1)),1,2)
  c.fearStacks=n;c.value=n;c.target="fw-wing";c.allowKnockedSource=night(gs,owner);c.currentCardStats="惧翼 · 堆叠%d／2"%n;c.text="瞬发，堆叠（最大2）。使天逆每获得%d战力。"%n
 elif c.id=="c61101" and src>=0:
  c.keywords=[]
  if Power.amount(gs.player(owner).units[src])>0:c.keywords.append("first-strike")
 return c
static func targets(gs, owner: int, card: Dictionary):
 if not card.get("fearWingRules",false):return null
 if card.get("target","")=="fw-unfeared":return candidates(gs,owner).map(func(u):return str(u.uid))
 if card.id=="juyi":
  var src:int=gs._source_index(owner,card)
  if src<0:return []
  return gs.player(owner).units.filter(func(u):return living(u) and gs.VerifiedRules.OwlInsect.shikigami(u) and (night(gs,owner) or str(u.uid)==str(gs.player(owner).units[src].uid))).map(func(u):return str(u.uid))
 return null
static func can_use(gs, owner: int, card: Dictionary) -> bool:
 if not card.get("fearWingRules",false):return true
 if card.id=="c61103":
  var src:int=gs._source_index(owner,card)
  return src>=0 and not gs.player(owner).units[src].awakened
 return true
static func _ask_fear(gs, owner: int, src: int) -> void:
 var pool:Array=candidates(gs,owner)
 if pool.is_empty():return
 gs.pending_choice={"type":"fw-fear-target","playerIndex":owner,"sourceIndex":src,"instanceIds":pool.map(func(u):return str(u.uid)),"heading":"惧 中 人","hint":"选择一个未结附「恐惧」的敌方式神。"};gs.phase="choice"
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
 if card.id=="c61105":gs.resolution_stack.append({"kind":"fw-form-target","playerIndex":owner,"sourceIndex":src})
static func trigger_realm(gs, owner: int, realm: Dictionary) -> bool:
 if realm.get("nativeRealm","")!="fear-wing-night":return false
 var src:int=gs._source_index(owner,Content.card_def("c61104"))
 if src>=0:_random_attach(gs,owner,src)
 gain(gs,owner);return true
static func knockout_snapshot(gs, owner: int, u: Dictionary) -> Dictionary:
 return {"owner":owner,"uid":str(u.uid),"isSource":source(u),"feared":not u.get("fearCharm",{}).is_empty(),"shikigami":gs.VerifiedRules.OwlInsect.shikigami(u)}
static func after_knockout(gs, saved: Dictionary) -> void:
 var victim:int=int(saved.owner)
 if victim<0:return
 var idx:int=gs._unit_index_by_uid(victim,str(saved.uid))
 if idx>=0:gs.player(victim).units[idx].erase("fearCharm")
 for side in gs.players:
  for u in side.units:
   if u.get("fearCharm",{}).get("sourceUid","")==str(saved.uid):u.erase("fearCharm")
 if not saved.shikigami:return
 for u in gs.player(1-victim).units:
  if not active(u):continue
  if source(u) and u.awakened:gain(gs,1-victim)
  if saved.feared and u.get("formRules",{}).get("fearWingPerson",false) and int(u.get("fearPersonTurn",-1))!=gs.turn_counter:
   u.fearPersonTurn=gs.turn_counter
   if gs.player(1-victim).hand.size()<int(gs.rules.maxHandSize):
    gs.player(1-victim).hand.append({"definitionId":"c61101","instanceId":"fear-shadow-%d"%gs.next_card_id});gs.next_card_id+=1
static func reset_character(gs, u: Dictionary) -> void:
 var uid:String=str(u.uid)
 for side in gs.players:
  for target in side.units:
   if str(target.get("fearCharm",{}).get("sourceUid",""))==uid:target.erase("fearCharm")
 u.erase("fearCharm");u.erase("fearPersonTurn")
static func before_attack(gs, frame: Dictionary) -> bool:
 if not frame.options.get("fearDouble",false) or frame.options.get("fearDoubleDone",false):return false
 frame.options.fearDoubleDone=true
 var owner:int=int(frame.playerIndex);var src:int=int(frame.sourceIndex);var victim:int=int(frame.options.get("combatVictim",1-owner))
 if frame.options.get("directAvatar",false):return false
 var idx:int=gs.front_index(victim)
 if frame.options.get("pursuit",false) or frame.options.get("reserveTarget",false):idx=gs._unit_index_by_uid(victim,str(frame.get("targetId","")))
 if idx<0 or not gs.VerifiedRules.OwlInsect.shikigami(gs.player(victim).units[idx]):return false
 var value:int=maxi(0,Power.amount(gs.player(owner).units[src]))
 if value<=0:return false
 var depth:int=gs.resolution_stack.size()
 Power.give(gs,owner,src,value)
 if gs.resolution_stack.size()<=depth:return false
 gs.resolution_stack.insert(depth,{"kind":"fw-resume-attack","combat":frame.duplicate(true)})
 return true
static func combat_finished(gs, owner: int, src: int, options: Dictionary, kills: int) -> void:
 if options.get("combatCard",{}).get("id","")!="c61101":return
 for _n in kills:_random_attach(gs,owner,src)
static func _wing_options(gs, owner: int) -> Array:
 return gs.player(owner).hand.filter(func(i):return i.definitionId=="juyi").map(func(i):return str(i.instanceId))
static func _use_wing(gs, owner: int, src: int, iid: String) -> bool:
 for h in gs.player(owner).hand.size():
  var inst:Dictionary=gs.player(owner).hand[h]
  if str(inst.instanceId)!=iid or inst.definitionId!="juyi":continue
  var c:Dictionary=gs.hand_card_def(owner,h).duplicate(true)
  c.playedInstance=gs.take_card_instance(owner,h);c.usedFromHand=true
  gs._push_card_frames(owner,"juyi",str(gs.player(owner).units[src].uid),c,src,0,true)
  gs.VerifiedRules.event(gs,"fear-wing-auto-used",{"player":owner,"instanceId":iid,"stacks":int(c.get("fearStacks",1))})
  return true
 return false
static func _spread(gs, owner: int, src: int, count: int, card: Dictionary) -> void:
 var ids:Array=_wing_options(gs,owner)
 if count<=0 or ids.is_empty():
  gs.resolution_stack.append({"kind":"fw-spread-combat","playerIndex":owner,"sourceIndex":src,"card":card.duplicate(true)});return
 # Different stacks and hand charms are real choices. Identical instances need no modal.
 if ids.size()>1:
  gs.pending_choice={"type":"fw-spread","playerIndex":owner,"sourceIndex":src,"instanceIds":ids,"remaining":count,"card":card.duplicate(true),"zone":"hand","heading":"惧 意 蔓 延","hint":"选择从手牌对天逆每使用的惧翼；剩余%d张。"%count};gs.phase="choice";return
 gs.resolution_stack.append({"kind":"fw-spread","playerIndex":owner,"sourceIndex":src,"remaining":count-1,"card":card.duplicate(true)})
 _use_wing(gs,owner,src,str(ids[0]))
static func choice_card(gs, owner: int, iid: String):
 var q:Dictionary=gs.pending_choice
 if int(q.get("playerIndex",-1))!=owner:return null
 if q.get("type","")=="fw-spread":
  for inst in gs.player(owner).hand:
   if str(inst.instanceId)==iid:return gs.describe_card_instance(owner,inst)
 if q.get("type","")=="fw-fear-target":
  var idx:int=gs._unit_index_by_uid(1-owner,iid)
  if idx>=0:
   var u:Dictionary=gs.player(1-owner).units[idx]
   return {"id":iid,"name":str(u.name),"unitId":str(u.id),"type":"spell","level":int(u.level),"cost":0,"art":str(u.get("art","")),"text":"为%s结附「恐惧」。当前力量%d，生命%d。"%[u.name,int(u.attack),int(u.hp)]}
 return null
static func resolve_choice(gs, owner: int, iid: String) -> bool:
 var q:Dictionary=gs.pending_choice
 if int(q.get("playerIndex",-1))!=owner or not q.get("instanceIds",[]).has(iid):return false
 var src:int=int(q.sourceIndex)
 if q.type=="fw-fear-target":
  if not candidates(gs,owner).any(func(u):return str(u.uid)==iid):return false
  attach(gs,owner,src,iid)
 elif q.type=="fw-spread":
  if not _wing_options(gs,owner).has(iid):return false
  gs.resolution_stack.append({"kind":"fw-spread","playerIndex":owner,"sourceIndex":src,"remaining":int(q.remaining)-1,"card":q.card.duplicate(true)})
  _use_wing(gs,owner,src,iid)
 else:return false
 gs._record("resolve_divination_choice",{"choice":q.type,"instanceId":iid},owner)
 gs.pending_choice={};gs.phase="main";gs._resolve_resolution_stack();gs.state_changed.emit();return true
static func ai_choice(gs, owner: int):
 var q:Dictionary=gs.pending_choice
 if not str(q.get("type","")).begins_with("fw-"):return null
 var ids:Array=q.get("instanceIds",[])
 if ids.is_empty():return false
 var best:String=str(ids[0]);var score:int=-100000
 for iid in ids:
  var value:int=0
  if q.type=="fw-spread":
   var c=choice_card(gs,owner,str(iid));value=int(c.get("fearStacks",1)) if c!=null else 0
  else:
   var u:Dictionary=gs._unit_by_uid(gs.player(1-owner).units,str(iid));value=100-int(u.get("hp",100))+10*int(u.get("front",0))
  if value>score:best=str(iid);score=value
 return resolve_choice(gs,owner,best)
static func resolve_frame(gs, frame: Dictionary) -> bool:
 var kind:String=str(frame.get("kind",""))
 if not kind.begins_with("fw-"):return false
 if kind=="fw-resume-attack":gs._resolve_combat_entered(frame.combat);return true
 var owner:int=int(frame.playerIndex);var src:int=int(frame.sourceIndex)
 match kind:
  "fw-damage":
   var idx:int=gs._unit_index_by_uid(1-owner,str(frame.targetUid))
   if idx>=0 and int(gs.player(1-owner).units[idx].hp)>0:
    var old:Dictionary=gs._card_effect_context;gs._card_effect_context={}
    gs._damage_unit(1-owner,idx,int(frame.amount),owner,src)
    gs._card_effect_context=old
  "fw-form-target":
   if active(gs.player(owner).units[src]) and gs.player(owner).units[src].get("formRules",{}).get("fearWingPerson",false):_ask_fear(gs,owner,src)
  "fw-spread":
   if active(gs.player(owner).units[src]):_spread(gs,owner,src,int(frame.remaining),frame.card)
  "fw-spread-combat":
   if active(gs.player(owner).units[src]):_combat(gs,owner,src,frame.card,null)
 return true
static func _combat(gs, owner: int, src: int, card: Dictionary, target) -> void:
 var opt:Dictionary=card.get("combatOption",{}).duplicate(true);opt.combatCard=card.duplicate(true)
 gs._grant_unit_armor(gs.player(owner).units[src],int(opt.get("shield",0)))
 gs._resolve_combat(owner,src,int(card.get("value",0)),false,false,false,gs._kw(card,"first-strike"),target,false,opt)
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target) -> bool:
 match str(effect.get("action","")):
  "fw-attach-charm":attach(gs,owner,src,str(target))
  "fw-wing":
   var idx:int=gs._unit_index_by_uid(owner,str(target))
   if idx>=0:Power.give(gs,owner,idx,int(card.get("fearStacks",1)))
  "fw-tremble":
   attach(gs,owner,src,str(target));Power.give(gs,owner,src,1);gain(gs,owner,2)
  "fw-awaken":attach(gs,owner,src,str(target));gs._awaken(owner,src,card,{"attack":0,"hp":1})
  "fw-form":gs._install_form(owner,src,card,effect.value)
  "fw-night":
   gs._deploy_realm(owner,card)
   trigger_realm(gs,owner,{"nativeRealm":"fear-wing-night"})
  "fw-all":
   for u in candidates(gs,owner,false):attach(gs,owner,src,str(u.uid))
   gain(gs,owner,2)
  "fw-combat":
   if card.id=="c61108":_spread(gs,owner,src,2,card)
   else:_combat(gs,owner,src,card,target)
  _:return false
 return true
static func score_card(gs, owner: int, card: Dictionary, target):
 if not card.get("fearWingRules",false):return null
 if card.id=="juyi":
  var u:Dictionary=gs._unit_by_uid(gs.player(owner).units,str(target))
  return 65+8*gs.player(1-owner).units.filter(func(t):return active(t) and t.get("fearCharm",{}).get("sourceUid","")==str(u.get("uid",""))).size()
 if card.id in ["c61102","c61103"]:return 75
 if card.id=="c61108":return 55+5*_wing_options(gs,owner).size()
 return 55
static func marks(u: Dictionary) -> Array:
 var result:Array=[]
 if not u.get("fearCharm",{}).is_empty():result.append("恐惧 · 天逆每获得战力时受等量伤害")
 return result
