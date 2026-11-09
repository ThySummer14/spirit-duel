class_name HairPowerRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
static func source(u: Dictionary) -> bool:return Content.runtime_unit_def(u).get("hairPowerRules",false)
static func active(u: Dictionary) -> bool:return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func amount(u: Dictionary) -> int:return int(u.get("battlePower",0))
static func give(gs, owner: int, idx: int, value: int) -> void:
 if owner<0 or owner>=gs.players.size() or idx<0 or idx>=gs.player(owner).units.size():return
 var u:Dictionary=gs.player(owner).units[idx]
 if int(u.get("hp",0))<=0 or u.get("removed",false):return
 u.battlePower=amount(u)+value
 gs.VerifiedRules.event(gs,"battle-power-changed",{"player":owner,"uid":u.uid,"value":value,"total":amount(u)})
static func clear(u: Dictionary) -> void:u.erase("battlePower")
static func expire(gs, owner: int) -> void:
 for u in gs.player(owner).units:clear(u)
 gs.player(owner).guardDeployments=[]
static func begin_turn(gs, owner: int) -> void:
 for side in 2:
  for i in gs.player(side).units.size():
   var u:Dictionary=gs.player(side).units[i]
   if side!=owner:
    if active(u) and u.get("formRules",{}).get("hairJoy",false):give(gs,side,i,3)
    continue
   if not source(u):continue
   var value:=2+int(u.get("hairAwakeTurns",0)) if u.awakened else 2
   if active(u):give(gs,owner,i,value)
   if u.awakened and not u.get("baseRulesSuppressed",false):u.hairAwakeTurns=int(u.get("hairAwakeTurns",0))+1
   if active(u) and u.get("formRules",{}).get("hairFace",false):gs.resolution_stack.append({"kind":"hair-face","playerIndex":owner,"sourceIndex":i})
static func quote(gs, owner: int, card: Dictionary, payment: Dictionary) -> Dictionary:
 if not gs._kw(card,"swift-card") or int(payment.cost)<=0 or payment.get("usesInstant",false) or (gs.player(owner).attackUsed and guard_count(gs,owner)<=0):return payment
 var q:=payment.duplicate(true);q.usesGuard=guard_count(gs,owner)>0;q.usesSwift=true;q.swiftFireReplaced=int(q.cost);q.cost=0;return q
static func pay(gs, owner: int, payment: Dictionary) -> void:
 if payment.get("usesSwift",false):
  if payment.get("usesGuard",false):gs.player(owner).guardDeployments.pop_front()
  else:gs.player(owner).attackUsed=true
static func damage_bonus(gs, owner: int, src: int, amount_in: int, options: Dictionary) -> int:
 var u:Dictionary=gs.player(owner).units[src]
 if options.get("lightZeroAttack",false) or gs.VerifiedRules.Combat.zero_power(gs,owner,u) or gs.VerifiedRules.Movement.zero_power(gs,u):return amount_in
 var value:int=amount(u) if int(u.hp)>0 else int(options.get("hairPowerSnapshot",0))
 return maxi(0,amount_in+value)
static func before_hit(gs, frame: Dictionary) -> void:
 if frame.get("hairPrepared",false):return
 frame.hairPrepared=true
 var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var victim:=int(frame.options.get("combatVictim",1-owner));var idx:=int(frame.defenderIndex)
 var u:Dictionary=gs.player(owner).units[src];var d:Dictionary=gs.player(victim).units[idx]
 if frame.options.get("combatCard",{}).get("id","")=="c60905":give(gs,victim,idx,-2);give(gs,owner,src,2);frame.options.hairWhip=true
 if amount(u)>0 and int(d.front)==1 and gs.player(owner).realms.any(func(r):return r.get("nativeRealm")=="hair-fear" and int(r.hp)>0):frame.pierce=true
static func started(gs, owner: int, src: int, defender: Dictionary, options: Dictionary) -> void:
 if options.get("hairCombatBegun",false):return
 options.hairCombatBegun=true
 options.hairPowerSnapshot=amount(gs.player(owner).units[src])
 options.hairDefenderPowerSnapshot=amount(defender)
static func finished(gs, owner: int, src: int, defender: Dictionary, options: Dictionary, kills: int) -> void:
 if not options.get("hairCombatBegun",false):return
 var u:Dictionary=gs.player(owner).units[src];var spent:=maxi(0,int(options.get("hairPowerSnapshot",amount(u))))
 if not options.get("wingguardKeepPower",false):clear(u)
 u.erase("hairGuardTraits")
 if not defender.is_empty():clear(defender);defender.erase("hairGuardTraits")
 if kills>0 and options.get("hairWhip",false) and active(u):give(gs,owner,src,spent/2)
static func knockout_snapshot(owner: int,u: Dictionary) -> Dictionary:return {"owner":owner,"front":int(u.front)==1}
static func after_knockout(gs,saved: Dictionary) -> void:
 var owner:=1-int(saved.owner)
 if owner<0 or owner>1 or not saved.front:return
 if gs.player(owner).realms.any(func(r):return r.get("nativeRealm")=="hair-fearless" and int(r.hp)>0):
  gs.player(owner).attackUsed=false;gs.VerifiedRules.event(gs,"hair-deployment-reset",{"player":owner})
static func can_use(gs, owner: int, card: Dictionary) -> bool:
 if card.get("id","")!="c60904":return true
 var src:int=gs._source_index(owner,card);return src>=0 and not gs.player(owner).units[src].awakened
static func describe(gs, owner: int, card: Dictionary) -> Dictionary:
 if card.get("id","")!="c60902":return card
 var c:=card.duplicate(true);var src:int=gs._source_index(owner,c)
 if src>=0:c.currentCardStats="当前战力%d · 本次获得%d护甲"%[maxi(0,amount(gs.player(owner).units[src])),maxi(0,amount(gs.player(owner).units[src]))]
 return c
static func form_entered(gs, owner: int, src: int, card: Dictionary) -> void:
 if card.get("id","")=="c60906":gs.resolution_stack.append({"kind":"hair-face","playerIndex":owner,"sourceIndex":src})
static func resolve_frame(gs, frame: Dictionary) -> bool:
 if frame.get("kind","")=="hair-guard-complete":return true
 if frame.get("kind","")!="hair-face":return false
 var owner:=int(frame.playerIndex);var src:=int(frame.sourceIndex);var u:Dictionary=gs.player(owner).units[src]
 if not active(u) or not u.get("formRules",{}).get("hairFace",false):return true
 var old:Dictionary=gs._card_effect_context;gs._card_effect_context={}
 for target in gs.player(1-owner).units.duplicate():
  if int(target.hp)<=0 or target.get("removed",false):continue
  var result:Dictionary=gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,target.uid),1,owner,src)
  if int(result.get("dealt",result.get("damage",0)))>0:give(gs,owner,src,int(result.get("dealt",result.get("damage",0))))
 gs._card_effect_context=old;return true
static func trigger_realm(_gs,_owner:int,realm:Dictionary) -> bool:return str(realm.get("nativeRealm","")).begins_with("hair-")
static func resolve_action(gs, owner: int, src: int, card: Dictionary, effect: Dictionary, target_id) -> bool:
 var u:Dictionary=gs.player(owner).units[src]
 match str(effect.get("action","")):
  "hair-combat":
   if card.id=="c60902":gs._grant_unit_armor(u,maxi(0,amount(u)))
   var options:Dictionary=card.get("combatOption",{}).duplicate(true);options.combatCard=card.duplicate(true)
   gs._resolve_combat(owner,src,0,bool(options.get("pierce",false)),false,false,false,target_id,false,options)
  "hair-awaken":
   var idx:int=gs._unit_index_by_uid(1-owner,str(target_id));give(gs,1-owner,idx,-2);give(gs,owner,src,2);gs._awaken(owner,src,card,{"attack":1,"hp":1})
  "hair-form":
   if card.id=="c60908":
    if int(u.hp)<=0:gs.VerifiedRules.Peach.revive(gs,owner,src,u,false,false)
    give(gs,owner,src,2)
   gs._install_form(owner,src,card,effect.value)
  "hair-realm":
   gs._deploy_realm(owner,card)
   if card.id=="c60903":give(gs,owner,gs._unit_index_by_uid(owner,str(target_id)),3)
   else:
    for i in gs.player(owner).units.size():give(gs,owner,i,3)
  _:return false
 return true
static func score_card(gs, owner: int, card: Dictionary, target_id):
 if not card.get("hairPowerRules",false):return null
 if card.id=="c60908":return 80 if int(gs.player(owner).units[gs._source_index(owner,card)].hp)<=0 else 30
 if card.id=="c60904":return 75
 if card.id=="c60903":return 40+maxi(0,int(gs._unit_by_uid(gs.player(owner).units,str(target_id)).get("attack",0)))
 return 50
static func marks(u: Dictionary) -> Array:
 var out:Array=[]
 if amount(u)!=0:out.append(("战力+%d" if amount(u)>0 else "乏力%d")%absi(amount(u)))
 if source(u) and u.awakened:out.append("下次己方回合获得%d战力"%(2+int(u.get("hairAwakeTurns",0))))
 return out
static func guard_count(gs,owner:int)->int:return gs.player(owner).get("guardDeployments",[]).size()
static func grant_guard(gs,owner:int,power:int=0,armor:int=0)->void:
 if not gs.player(owner).has("guardDeployments"):gs.player(owner).guardDeployments=[]
 gs.player(owner).guardDeployments.append({"power":power,"armor":armor})
 gs.VerifiedRules.event(gs,"guard-gained",{"player":owner,"count":guard_count(gs,owner),"power":power,"armor":armor})
static func guard_deploy(gs,owner:int,src:int)->bool:
 if guard_count(gs,owner)<=0:return false
 var depth:int=gs.resolution_stack.size()
 var p:Dictionary=gs.player(owner);var u:Dictionary=p.units[src];var entry:Dictionary=p.guardDeployments.pop_front()
 var enc:Dictionary=gs._prepare_encourage(owner)
 var karma:int=gs.VerifiedRules.WisdomLamp.guard_bonus(u)
 give(gs,owner,src,int(entry.power)+int(enc.get("attack",0))+int(enc.get("battlePower",0))+karma)
 var armor:=int(entry.armor)+int(enc.get("shield",0))+karma
 if armor>0:gs._grant_unit_armor(u,armor)
 elif armor<0:gs.VerifiedRules.ArmorBreak.give(gs,owner,src,owner,src,-armor,false)
 if not enc.get("traits",{}).is_empty():u.hairGuardTraits=enc.traits.duplicate(true)
 var old:=int(u.front)
 gs.VerifiedRules.Weaver.leave_front(gs,owner,src);u.front=1
 gs._record("basic_attack",{"unit":src,"target":u.uid,"guard":true},owner)
 if old!=1:
  gs._fire_hooks(owner,src,"unit-entered-front",{});gs._run_form_hooks(owner,src,"unit-entered-front",{})
  gs.VerifiedRules.Movement.moved(gs,owner,src,old)
  gs.VerifiedRules.automatic_response(gs,1-owner,"enemy-entered-front",u.uid,{"kind":"hair-guard-complete","playerIndex":owner,"sourceIndex":src})
 gs.VerifiedRules.PeachGrove.guard_attack(gs, owner, src, depth)
 gs._resolve_resolution_stack();gs.state_changed.emit();return true
