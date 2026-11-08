class_name MusicFireRules
extends RefCounted
const Content := preload("res://scripts/content_loader.gd")
static func role(u: Dictionary) -> String:
 return str(Content.runtime_unit_def(u).get("musicFireRole",""))
static func active(u: Dictionary) -> bool:
 return int(u.get("hp",0))>0 and int(u.get("level",0))>0 and not u.get("removed",false) and not u.get("baseRulesSuppressed",false)
static func fire(u: Dictionary) -> bool:
 return role(u)=="fire" and u.get("mfFire",false)
static func _frame(gs,kind: String,owner: int,src: int,extra: Dictionary={}) -> void:
 var f:Dictionary={"kind":kind,"playerIndex":owner,"sourceIndex":src};f.merge(extra,true);gs.resolution_stack.append(f)
static func _field(gs,owner: int,kind: String) -> int:
 return gs.player(owner).realms.filter(func(r):return r.get("nativeRealm","")==kind and int(r.hp)>0).size()
static func fortune_threshold(gs,owner: int,src: int,threshold: int) -> int:
 if src<0 or src>=gs.player(owner).units.size():return threshold
 var u:Dictionary=gs.player(owner).units[src]
 if role(u)!="music" or not active(u):return threshold
 if u.awakened or u.get("formRules",{}).get("mfPalace",false) or u.get("formRules",{}).get("mfDollForm",false) or u.get("formRules",{}).get("mfFeatherForm",false):return maxi(1,threshold-int(gs.VerifiedRules.Maple.night_value(gs,owner)/2))
 return threshold
static func _roll(gs,owner: int,src: int,reward: String,extra: Dictionary={}) -> void:
 var depth:int=gs.resolution_stack.size()
 var threshold:int=maxi(1,6-int(gs.VerifiedRules.Maple.night_value(gs,owner)/2))
 if gs.VerifiedRules.Light.roll(gs,owner,threshold,6,src):
  var f:Dictionary={"kind":"mf-reward","playerIndex":owner,"sourceIndex":src,"reward":reward,"repeats":gs.VerifiedRules.Fortune.last_repeats(gs,owner),"effectContext":gs._card_effect_context.duplicate(true)};f.merge(extra,true);gs.resolution_stack.insert(depth,f)
static func rule_event(gs,kind: String,details: Dictionary) -> void:
 if kind!="fortune-result":return
 var owner:int=int(details.get("player",-1));var src:int=int(details.get("sourceIndex",-1))
 if owner<0 or src<0 or src>=gs.player(owner).units.size():return
 var u:Dictionary=gs.player(owner).units[src]
 if role(u)=="music" and active(u):_frame(gs,"mf-music-fortune",owner,src,{"roll":int(details.roll),"awakened":bool(u.awakened),"sourceUid":str(u.uid)})
static func before_attack(gs,frame: Dictionary) -> bool:
 if frame.get("mfPalaceOffered",false):return false
 frame.mfPalaceOffered=true
 var owner:int=int(frame.playerIndex);var victim:int=int(frame.options.get("combatVictim",1-owner));var src:int=int(frame.sourceIndex)
 if not gs.VerifiedRules.OwlInsect.shikigami(gs.player(owner).units[src]):return false
 var sources:Array=[]
 for i in gs.player(victim).units.size():
  var u:Dictionary=gs.player(victim).units[i]
  if active(u) and u.get("formRules",{}).get("mfPalace",false) and int(u.get("mfPalaceTurn",-1))!=gs.turn_counter:u.mfPalaceTurn=gs.turn_counter;sources.append(i)
 if sources.is_empty():return false
 gs.resolution_stack.append({"kind":"mf-resume-attack","combat":frame.duplicate(true)})
 for i in range(sources.size()-1,-1,-1):_frame(gs,"mf-palace",victim,int(sources[i]),{"targetUid":str(gs.player(owner).units[src].uid)})
 return true
static func power_delta(gs,u: Dictionary) -> int:
 var value:int=-int(u.get("mfPowerPenalty",0)) if int(u.get("mfPowerPenaltyTurn",-1))==gs.turn_counter else 0
 if fire(u) and active(u):
  for owner in 2:
   if gs.current_player==owner and gs.player(owner).units.has(u):value+=3*_field(gs,owner,"mf-eternal")
 return value
static func end_turn(gs,_owner: int) -> void:
 for side in gs.players:
  for u in side.units:
   if int(u.get("mfPowerPenaltyTurn",-1))==gs.turn_counter:u.erase("mfPowerPenalty");u.erase("mfPowerPenaltyTurn");gs._recalc(u)
static func reset_ledger(u: Dictionary) -> void:
 u.erase("mfPowerPenalty");u.erase("mfPowerPenaltyTurn")
static func _clear_switch(gs,u: Dictionary) -> void:
 gs.VerifiedRules.StarBear.consumed_armor(u,int(u.shield));gs.VerifiedRules.StarBear.consumed_break(u,int(u.armorBreak))
 u.shield=0;u.shieldExpires=0;u.armorBreak=0
 # Switches preserve charms, stun, ink and enduring gains. Temporary attack is
 # not copied into a different base body; neither is it made permanent.
 u.erase("temporaryAttack")
 var peach:int=int(u.get("peachTemporaryAttack",0))
 if peach!=0:u.attackBonus=int(u.attackBonus)-peach;u.erase("peachTemporaryAttack")
 gs.VerifiedRules.ArmorBlood.armor_changed(gs,u)
static func before_knockout(gs,owner: int,u: Dictionary) -> bool:
 if role(u)!="fire" or fire(u) or u.get("mfSwitchPending",false) or u.get("baseRulesSuppressed",false):return false
 if int(u.level)<1:return false
 u.mfSwitchPending=true;u.hp=0;u.knockout=0
 _frame(gs,"rebirth-mf-switch",owner,gs._unit_index_by_uid(owner,str(u.uid)),{"targetUid":str(u.uid)})
 return true
static func _to_fire(gs,owner: int,idx: int) -> void:
 var u:Dictionary=gs.player(owner).units[idx]
 if not u.get("mfSwitchPending",false):return
 u.erase("mfSwitchPending");_clear_switch(gs,u)
 if not u.get("form",{}).is_empty():gs.VerifiedRules.Forms.remove(gs,owner,idx,"切换为神火铃焰")
 u.mfFire=true;u.presentationId="mf-fire-awakened" if u.get("mfFireAwakened",false) else "mf-fire";u.name="神火铃焰";u.baseAttack=0;u.baseMaxHp=4;u.front=0;u.hp=1;u.knockout=0
 u.art=Content.unit_def(str(u.presentationId)).art;u.awakenedArt=u.art;u.formAbility=Content.unit_def(str(u.presentationId)).passive.text
 gs._recalc(u);u.hp=1
 gs.VerifiedRules.event(gs,"mf-switched",{"player":owner,"uid":u.uid,"body":"fire","hp":1})
static func healed(gs,u: Dictionary) -> void:
 if not fire(u) or not active(u) or int(u.hp)<int(u.maxHp) or u.get("mfFullPending",false):return
 for owner in 2:
  var idx:int=gs._unit_index_by_uid(owner,str(u.uid))
  if idx>=0:u.mfFullPending=true;_frame(gs,"mf-full-fire",owner,idx);return
static func _to_human(gs,owner: int,idx: int) -> void:
 var u:Dictionary=gs.player(owner).units[idx]
 u.erase("mfFullPending")
 if not fire(u) or not active(u) or int(u.hp)<int(u.maxHp):return
 var hit:int=int(u.level) if u.get("mfFireAwakened",false) else 1
 _clear_switch(gs,u);u.mfFire=false;u.erase("presentationId");u.name=Content.unit_def("lingyanji").name;u.baseAttack=3;u.baseMaxHp=4;u.art=Content.unit_def("lingyanji").art;u.awakenedArt=Content.unit_def("lingyanji").awakenedArt;u.formAbility="";gs._recalc(u);u.hp=int(u.maxHp)
 gs.VerifiedRules.event(gs,"mf-switched",{"player":owner,"uid":u.uid,"body":"human","hp":u.hp})
 var targets:Array=[]
 for enemy in gs.player(1-owner).units:
  if int(enemy.hp)>0 and not enemy.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(enemy):targets.append(str(enemy.uid))
 for uid in targets:
  var ti:int=gs._unit_index_by_uid(1-owner,str(uid))
  if ti>=0:gs.VerifiedRules.base_damage_unit(gs,owner,idx,1-owner,ti,hit)
static func after_knockout(gs,owner: int,u: Dictionary) -> void:
 reset_ledger(u);u.erase("mfBathCombat");u.erase("mfFullPending");u.erase("mfSwitchPending")
 if fire(u):
  u.mfFire=false;u.erase("presentationId");u.name=Content.unit_def("lingyanji").name;u.baseAttack=3;u.baseMaxHp=4;u.art=Content.unit_def("lingyanji").art;u.awakenedArt=Content.unit_def("lingyanji").awakenedArt;u.formAbility="";gs._recalc(u);u.hp=0
static func damage_replacement(gs,victim: int,idx: int,amount: int,_source_owner: int,_src: int,combat: bool):
 if idx<0 or amount<=0:return null
 var u:Dictionary=gs.player(victim).units[idx]
 if not active(u):return null
 var bath:bool=combat and u.get("mfBathCombat",false)
 var flame:bool=not combat and fire(u) and gs.current_player==victim and _field(gs,victim,"mf-flame")>0
 if not bath and not flame:return null
 gs._heal_unit(u,amount)
 if bath:gs._heal_avatar(victim,amount)
 gs.VerifiedRules.event(gs,"mf-damage-healed",{"player":victim,"uid":u.uid,"amount":amount,"combat":combat})
 return {"damage":0,"dealt":0,"knocked":false,"overkill":0,"convertedToHealing":true}
static func combat_immune(gs,owner: int,idx: int) -> bool:
 return idx>=0 and fire(gs.player(owner).units[idx]) and gs.current_player==owner and _field(gs,owner,"mf-eternal")>0
static func combat_finished(gs,owner: int,src: int,defender: Dictionary,options: Dictionary) -> void:
 var u:Dictionary=gs.player(owner).units[src]
 u.erase("mfBathCombat")
 if not defender.is_empty():defender.erase("mfBathCombat")
 if options.get("mfBellHeal",false) and int(u.hp)>0:gs._heal_unit(u,3)
static func begin_turn(gs,owner: int) -> void:
 for i in range(gs.player(owner).units.size()-1,-1,-1):
  var u:Dictionary=gs.player(owner).units[i]
  if not active(u):continue
  if fire(u):_frame(gs,"mf-fire-regen",owner,i)
  if u.get("formRules",{}).get("mfFeatherForm",false):_frame(gs,"mf-form-roll",owner,i,{"reward":"draw"})
  if u.get("formRules",{}).get("mfDollForm",false):_frame(gs,"mf-form-roll",owner,i,{"reward":"doll"})
static func form_entered(gs,owner: int,src: int,card: Dictionary) -> void:
 if card.get("formRules",{}).get("mfFeatherForm",false):_roll(gs,owner,src,"draw")
 if card.get("formRules",{}).get("mfDollForm",false):_roll(gs,owner,src,"doll")
static func trigger_realm(gs,owner: int,realm: Dictionary) -> bool:
 var mode:String=str(realm.get("nativeRealm",""))
 if mode not in ["mf-heal","mf-flame","mf-eternal"]:return false
 var src:int=gs._source_index(owner,{"unitId":realm.sourceUnit})
 if mode=="mf-heal":_frame(gs,"mf-heal-field",owner,src)
 if mode=="mf-eternal":
  for u in gs.player(owner).units:gs._recalc(u)
  if src>=0 and fire(gs.player(owner).units[src]) and active(gs.player(owner).units[src]):_frame(gs,"mf-eternal-attack",owner,src)
 return true
static func describe_card(gs,owner: int,inst: Dictionary,card: Dictionary) -> Dictionary:
 if not card.get("musicFireRules",false):return card
 var c:Dictionary=card.duplicate(true)
 if c.id=="c26307":
  c.mfBounce=not inst.get("mfBounceSpent",false);c.mfInstance=inst.duplicate(true)
  if not c.mfBounce:c.keywords=c.keywords.filter(func(k):return k!="bounce");c.text=c.text.replace("弹回。","").replace("，弹回","")
 if c.id in ["c25603","c25604","c25607"]:c.currentCardStats="运势所需%d点 · 入夜%d"%[maxi(1,6-int(gs.VerifiedRules.Maple.night_value(gs,owner)/2)),gs.VerifiedRules.Maple.night_value(gs,owner)]
 if c.id=="c25608":c.currentCardStats="入夜%d · 力量或生命≤%d"%[gs.VerifiedRules.Maple.night_value(gs,owner),gs.VerifiedRules.Maple.night_value(gs,owner)]
 return c
static func can_use(gs,owner: int,card: Dictionary) -> bool:
 if card.get("id","")=="c26306" and gs.current_player!=owner:
  var src:int=gs._source_index(owner,card);return src>=0 and fire(gs.player(owner).units[src])
 return true
static func targets(gs,owner: int,card: Dictionary):
 if card.get("id","")!="c25608":return null
 var out:Array=[];var night:int=gs.VerifiedRules.Maple.night_value(gs,owner)
 for side in [owner,1-owner]:
  if int(gs.player(side).avatarHp)<=night and not (side!=owner and gs.VerifiedRules.PipeFox.avatar_veil(gs,side)):out.append("avatar-%d"%side)
  for u in gs.player(side).units:
   if int(u.hp)<=0 or u.get("removed",false) or not gs.VerifiedRules.OwlInsect.shikigami(u):continue
   if side!=owner and gs.VerifiedRules.Combat.has(u,"veil"):continue
   if int(u.attack)<=night or int(u.hp)<=night:out.append(str(u.uid))
 return out
static func _spell_amount(gs,owner: int,src: int,amount: int) -> int:
 var card:Dictionary=gs._card_effect_context.get("cardOverride",{})
 return amount+int(gs.player(owner).units[src].get("spellPower",0))+int(card.get("foxHandDamageBonus",0))
static func _random_hit(gs,owner: int,src: int,amount: int) -> void:
 var pool:Array=["avatar-%d"%(1-owner)]
 for u in gs.player(1-owner).units:
  if int(u.hp)>0 and not u.get("removed",false) and gs.VerifiedRules.OwlInsect.shikigami(u):pool.append(str(u.uid))
 var uid:String=str(pool[int(gs.next_random()%pool.size())]);var idx:int=gs._unit_index_by_uid(1-owner,uid)
 if idx<0:gs.VerifiedRules.base_damage_avatar(gs,owner,src,1-owner,amount)
 else:gs.VerifiedRules.base_damage_unit(gs,owner,src,1-owner,idx,amount)
static func summon_doll(gs,owner: int,src: int) -> int:
 var swift:bool=int(gs.next_random()%2)==1;var id:String="mf-doll-swift" if swift else "mf-doll-blood";var def:Dictionary=Content.unit_def(id);var master:Dictionary=gs.player(owner).units[src]
 gs.VerifiedRules.Weaver.leave_front(gs,owner)
 var u:Dictionary={"uid":"%s:mf-doll-%d"%[gs.player(owner).id,gs.next_card_id],"id":id,"name":"诡间缚偶","title":"紧那罗召唤物","art":def.art,"color":def.color,"baseAttack":int(def.attack),"baseMaxHp":int(def.maxHp),"attack":int(def.attack),"maxHp":int(def.maxHp),"hp":int(def.maxHp),"shield":0,"shieldExpires":0,"knockout":0,"frozen":0,"brittle":0,"armorBreak":0,"unyielding":false,"level":1,"front":1,"attackBonus":0,"maxHpBonus":0,"awakened":false,"form":{},"formRules":{},"formAbility":def.passive.text,"charge":0,"passive_hooks":[],"summoned":true,"summon":true,"countsAsShikigami":true,"mfDoll":true,"summonerUid":str(master.uid),"swift":swift,"keywords":["swift"] if swift else ["lifesteal"]}
 gs.next_card_id+=1;gs.player(owner).units.append(u);var idx:int=gs.player(owner).units.size()-1
 gs.VerifiedRules.event(gs,"summon-created",{"player":owner,"uid":u.uid,"sourceUid":master.uid,"summonKind":id});gs.VerifiedRules.Weaver.entered(gs,owner,idx);return idx
static func remove_doll(gs,owner: int,u: Dictionary) -> void:
 if not u.get("mfDoll",false) or u.get("removed",false):return
 gs.VerifiedRules.Otakemaru.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),"离开战斗区")
 gs.VerifiedRules.Vine.remove_charm(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),"离开战斗区",false)
 u.hp=0;u.front=0;u.knockout=0;u.removed=true;u.erase("weaverGrave");u.erase("weaverReviveReason")
 gs.VerifiedRules.event(gs,"summon-removed",{"player":owner,"uid":u.uid,"reason":"离开战斗区"})
static func remove_departed(gs) -> void:
 for side in 2:
  for u in gs.player(side).units:
   if u.get("mfDoll",false) and int(u.front)==0 and int(u.hp)>0:remove_doll(gs,side,u)
   healed(gs,u)
static func summoned_knockout(gs,owner: int,u: Dictionary) -> void:
 if not u.get("mfDoll",false):return
 u.hp=0;u.front=0;u.knockout=0;u.removed=true
 gs.VerifiedRules.event(gs,"mf-doll-died",{"player":owner,"uid":u.uid})
static func respond_combat(gs,combat_id: int,owner: int,src: int,card: Dictionary) -> bool:
 if card.get("id","")!="c26306":return false
 for f in gs.resolution_stack:
  if f.get("kind","")=="combat-hit" and int(f.get("combatId",-1))==combat_id:
   var u:Dictionary=gs.player(owner).units[src]
   if not fire(u):return true
   u.mfBathCombat=true;gs.VerifiedRules.Weaver.leave_front(gs,owner,src);var before:int=int(u.front);u.front=1;gs.VerifiedRules.Movement.moved(gs,owner,src,before)
   f.defenderIndex=src;f.avatarResponsePending=true;f.options.directAvatar=false;f.mfBathUid=str(u.uid);return true
 return true
static func completed(gs,frame: Dictionary,card: Dictionary) -> void:
 if card.get("mfBounce",false):
  var inst:Dictionary=card.mfInstance.duplicate(true);inst.mfBounceSpent=true
  _frame(gs,"mf-bounce",int(frame.playerIndex),int(frame.sourceIndex),{"instance":inst})
static func resolve_action(gs,owner: int,src: int,card: Dictionary,effect: Dictionary,target_id) -> bool:
 var action:String=str(effect.get("action",""))
 if not action.begins_with("mf-"):return false
 var u:Dictionary=gs.player(owner).units[src]
 match action:
  "mf-form":gs._install_form(owner,src,card,effect.value)
  "mf-realm":
   gs._deploy_realm(owner,card)
   var realm:Dictionary=gs.player(owner).realms.back()
   if card.id=="c26304":
    var idx:int=gs._unit_index_by_uid(1-owner,str(target_id))
    if idx>=0:gs._damage_unit(1-owner,idx,4,owner,src)
    gs._damage_unit(owner,src,4,owner,src)
   else:trigger_realm(gs,owner,realm)
  "mf-combat":
   var opt:Dictionary=card.get("combatOption",{}).duplicate(true);opt.combatCard=card.duplicate(true)
   if card.id=="c26306":u.mfBathCombat=true
   if card.id=="c26301":opt.mfBellHeal=true
   gs._grant_unit_armor(u,int(opt.get("shield",0)));gs._resolve_combat(owner,src,int(card.value),false,false,false,false,target_id,false,opt)
  "mf-fire-awaken":u.mfFireAwakened=true;if fire(u):u.presentationId="mf-fire-awakened";u.art=Content.unit_def("mf-fire-awakened").art;u.awakenedArt=u.art
  "mf-card":
   match str(card.id):
    "c25601":_frame(gs,"mf-no-moon",owner,src,{"remaining":2 if gs.VerifiedRules.Maple.night_value(gs,owner)==0 else 1})
    "c25603":
     var idx:int=gs.front_index(1-owner)
     if idx>=0:gs._damage_unit(1-owner,idx,_spell_amount(gs,owner,src,4),owner,src)
     _roll(gs,owner,src,"avatar4")
    "c25604":
     var idx:int=gs._unit_index_by_uid(1-owner,str(target_id))
     if idx>=0:gs._damage_unit(1-owner,idx,_spell_amount(gs,owner,src,5),owner,src)
     _roll(gs,owner,src,"aoe1")
    "c25607":_roll(gs,owner,src,"generate2");gs._awaken(owner,src,card,{"attack":1,"hp":1})
    "c25608":
     var side:int=owner if gs._unit_index_by_uid(owner,str(target_id))>=0 else 1-owner;var idx:int=gs._unit_index_by_uid(side,str(target_id))
     if str(target_id).begins_with("avatar-"):side=int(str(target_id).trim_prefix("avatar-"));gs.player(side).avatarHp=0;gs._check_winner()
     elif idx>=0:
      var target:Dictionary=gs.player(side).units[idx]
      if gs.VerifiedRules.Panguan.destroy(gs,owner,src,side,idx,card) and gs.VerifiedRules.Maple.nightfall(gs,owner,10) and int(target.hp)<=0 and int(target.knockout)>0:target.knockout=int(target.knockout)+2
    "c26305":
     if not u.awakened:gs._awaken(owner,src,card,{"attack":2,"hp":0})
     else:gs.VerifiedRules.Glutton.record_permanent(u,2,0);gs._grow_unit(u,2,0)
     gs._push_card_frames(owner,"mf-fire-awakening",null,Content.card_def("mf-fire-awakening"),src,0,true)
    "c26307":
     var uid:String=str(target_id)
     if uid.begins_with("avatar-"):gs._heal_avatar(int(uid.trim_prefix("avatar-")),5)
     else:gs._heal_unit(gs._unit_by_uid(gs._all_units(),uid),5)
 return true
static func resolve_frame(gs,f: Dictionary) -> bool:
 var kind:String=str(f.get("kind",""))
 if not kind.begins_with("mf-") and kind!="rebirth-mf-switch":return false
 if kind=="mf-resume-attack":gs._resolve_combat_entered(f.combat);return true
 var owner:int=int(f.get("playerIndex",0));var src:int=int(f.get("sourceIndex",0));var u:Dictionary=gs.player(owner).units[src]
 match kind:
  "mf-bounce":
   if gs.player(owner).hand.size()<int(gs.rules.maxHandSize):gs.player(owner).hand.append(f.instance.duplicate(true))
  "rebirth-mf-switch":_to_fire(gs,owner,src)
  "mf-full-fire":_to_human(gs,owner,src)
  "mf-fire-regen":
   if fire(u) and active(u):gs._heal_unit(u,1)
  "mf-form-roll":
   if active(u):_roll(gs,owner,src,str(f.reward))
  "mf-palace":
   if active(u):_roll(gs,owner,src,"palace",{"targetUid":f.targetUid})
  "mf-music-fortune":
   if not active(u) or str(u.uid)!=str(f.sourceUid):return true
   if f.awakened:
    _random_hit(gs,owner,src,3)
    if gs.VerifiedRules.Maple.nightfall(gs,owner,10):gs.VerifiedRules.Light.gain_fire(gs,owner,1)
   elif gs.VerifiedRules.Maple.nightfall(gs,owner,int(f.roll)):_random_hit(gs,owner,src,1)
  "mf-reward":
   if not active(u):return true
   var previous_context:Dictionary=gs._card_effect_context;gs._card_effect_context=f.get("effectContext",{})
   for _i in int(f.repeats):
    match str(f.reward):
     "draw":gs._draw(owner,1)
     "doll":summon_doll(gs,owner,src)
     "avatar4":gs._damage_avatar(1-owner,_spell_amount(gs,owner,src,4),owner,src)
     "aoe1":
      gs._damage_avatar(1-owner,_spell_amount(gs,owner,src,1),owner,src)
      for target in gs.player(1-owner).units.duplicate():
       if int(target.hp)>0 and not target.get("removed",false):gs._damage_unit(1-owner,gs._unit_index_by_uid(1-owner,str(target.uid)),_spell_amount(gs,owner,src,1),owner,src)
     "generate2":
      var pool:Array=Content.cards_for_unit("jinnaluo").filter(func(c):return c.id!="c25607" and not c.get("token",false))
      for _n in 2:
       if gs.player(owner).hand.size()>=int(gs.rules.maxHandSize):break
       var card:Dictionary=pool[int(gs.next_random()%pool.size())];gs.player(owner).hand.append({"definitionId":card.id,"instanceId":"mf-generate-%d"%gs.next_card_id});gs.next_card_id+=1
     "palace":
      var target:Dictionary=gs._unit_by_uid(gs._all_units(),str(f.targetUid))
      if not target.is_empty() and int(target.hp)>0:target.mfPowerPenalty=int(target.get("mfPowerPenalty",0))+1;target.mfPowerPenaltyTurn=gs.turn_counter;gs._recalc(target)
   gs._card_effect_context=previous_context
  "mf-no-moon":
   if int(f.remaining)>1:_frame(gs,"mf-no-moon",owner,src,{"remaining":int(f.remaining)-1})
   if gs.VerifiedRules.Maple.nightfall(gs,owner,1):_frame(gs,"mf-draw",owner,src);gs.VerifiedRules.Divination.start(gs,owner,1)
  "mf-draw":gs._draw(owner,1)
  "mf-heal-field":
   gs._heal_avatar(owner,1)
   for target in gs.player(owner).units.duplicate():
    if int(target.hp)>0:gs._heal_unit(target,1)
    if fire(target) and active(target):gs._heal_unit(target,1)
  "mf-eternal-attack":
   if fire(u) and active(u):_frame(gs,"mf-eternal-heal",owner,src);gs._resolve_combat(owner,src,0,false,false,false,false,null,false,{"mfEternalAttack":true})
  "mf-eternal-heal":
   if int(u.hp)>0:gs._heal_unit(u,int(u.maxHp))
 return true
static func score_card(gs,owner: int,card: Dictionary,target_id=null):
 if not card.get("musicFireRules",false):return null
 if str(card.id)=="c25608":return 90 if str(target_id).begins_with("avatar-") and str(target_id)!="avatar-%d"%owner else 65 if gs._unit_index_by_uid(1-owner,str(target_id))>=0 else -100
 if str(card.id)=="c26307":return 50 if str(target_id)=="avatar-%d"%owner or gs._unit_index_by_uid(owner,str(target_id))>=0 else -100
 if str(card.id)=="c26306":return 25
 return 50
static func marks(gs,owner: int,u: Dictionary) -> Array:
 var out:Array=[]
 if role(u)=="music":out.append("入夜%d · 运势阈值%d"%[gs.VerifiedRules.Maple.night_value(gs,owner),fortune_threshold(gs,owner,gs._unit_index_by_uid(owner,str(u.uid)),6)])
 if role(u)=="fire":out.append("神火铃焰 · 满血切回" if fire(u) else "铃彦姬 · 气绝切换")
 if u.get("mfBathCombat",false):out.append("浴火：本次战斗伤害转为自己及牌手治疗")
 return out
