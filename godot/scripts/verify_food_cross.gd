extends SceneTree
const GS := preload("res://scripts/game_state.gd")
const Food := preload("res://scripts/cooking_rules.gd")
const Content := preload("res://scripts/content_loader.gd")
const AI := preload("res://scripts/game_ai.gd")
var checks := 0
var failures := 0
func check(ok: bool, detail: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FOOD_CROSS_FAIL ", detail)
func game(ids: Array, enemy: Array = ["yaoginshi","bingyong","shantong","hetong"]) -> GS:
 var gs := GS.create(ids, enemy, 20261103)
 for side in gs.players:
  side.hand.clear();side.energy=40;side.levelUpUsed=true
  for u in side.units:u.level=3
 gs.rule_events.clear()
 return gs
func give(gs, id: String, owner: int = 0) -> int:
 gs.player(owner).hand.append({"definitionId":id,"instanceId":"food-cross-%d"%gs.next_card_id});gs.next_card_id+=1
 return gs.player(owner).hand.size()-1
func play(gs,id: String,target=null,owner: int=0) -> void:
 check(gs.play_card(owner,give(gs,id,owner),target),"actual play "+id)
func foods(gs) -> Array:
 return gs.rule_events.filter(func(e):return e.kind=="food-used")
func neutral_source_and_marks() -> void:
 var gs:=game(["wuwu","shiling","sanweihu","bingyong"]);var p:Dictionary=gs.player(0)
 var inst:=Food.gain_ingredient(gs,0,0,"mountain");var target:Dictionary=p.units[3];var power:=int(target.attack)
 gs._knockout_unit(p.units[0]);p.units[1].frozen=2
 check(gs.hand_card_def(0,0).unitId=="" and gs._source_index(0,gs.hand_card_def(0,0))==-1,"food has no generator affiliation")
 check(gs.effective_card_cost(0,gs.hand_card_def(0,0))==1,"three-tail shikigami first-card discount does not discount neutral food")
 check(gs.play_card(0,0,target.uid),"food usable after generator knockout with ally stun")
 check(target.attack==power+3 and p.energy==39 and not p.get("threeTailFirstUsed",false),"exact food amount and paid fire preserve first shikigami use")
 check(foods(gs).size()==1 and foods(gs)[0].sourceIndex==-1,"food event has player actor")
 inst=Food.gain_ingredient(gs,0,1,"sea");inst.handCharm={"kind":"ward","effects":["instant","draw","hit-enemy"]}
 var deck:int=p.deck.size();var avatar:=int(gs.player(1).avatarHp)
 check(gs.play_card(0,0,target.uid),"neutral hand blessing traverses normal play")
 check(p.energy==39 and p.deck.size()==deck-1 and gs.player(1).avatarHp==avatar-3,"neutral instant draw and enemy-avatar effects settle once")
 check(gs.rule_events.any(func(e):return e.kind=="neutral-card-announced" and e.sourceIndex==-1),"neutral announcement does not impersonate last shikigami")
 check(gs.resolution_stack.is_empty() and gs.pending_choice.is_empty(),"neutral marked card completes stack")
 gs=game(["wuwu","shiling","sanweihu","bingyong"]);p=gs.player(0);p.avatarHp=20
 inst=Food.gain_ingredient(gs,0,0,"mountain");inst.handCharm={"kind":"erosion","effects":["hurt-source"]};var last:=int(p.units[3].hp)
 check(gs.play_card(0,0,p.units[3].uid),"source-less unit-specific erosion safely resolves")
 check(p.units[3].hp==last and p.avatarHp==20,"missing source is never replaced by last unit or avatar")
 p.units[3].formRules={"armorBreakToDamage":true};Food.gain_unknown(gs,0,0);var enemy:Dictionary=gs.player(1).units[1];var hp:int=enemy.hp
 check(gs.play_card(0,0,enemy.uid),"actual neutral unknown food with a damage-converting ally")
 check(enemy.hp==hp and enemy.armorBreak==4,"neutral food cannot inherit last ally armor-break conversion")
func observer_scope_and_counter() -> void:
 var gs:=game(["wuwu","fenghuanghuo","yaohu","shimengmo"]);var p:Dictionary=gs.player(0);var foe:Dictionary=gs.player(1)
 p.units[1].awakened=true;p.units[2].awakened=true;p.units[3].formRules={"dreamOnSpell":true}
 for u in foe.units:gs._grow_unit(u,0,30)
 foe.units[1].front=1
 var hp:int=foe.units.reduce(func(acc,u):return acc+int(u.hp),0)+int(foe.avatarHp);var inst:=Food.gain_ingredient(gs,0,0,"mountain")
 check(gs.play_card(0,0,p.units[0].uid),"food with three spell observers")
 check(gs.rule_events.filter(func(e):return str(e.kind).begins_with("phoenix")).is_empty(),"Phoenix shikigami-spell ability excludes player food")
 check(foe.units.reduce(func(acc,u):return acc+int(u.hp),0)+int(foe.avatarHp)==hp-2,"awakened fox observes you-use-spell food once")
 check(gs.VerifiedRules.BondDream.nightmare_total(gs,1)==1,"dream you-use-spell observes neutral food once")
 gs=game(["wuwu","shiling","bingyong","shantong"]);p=gs.player(0);foe=gs.player(1)
 give(gs,"c12807",1);var power:=int(p.units[2].attack);Food.gain_ingredient(gs,0,0,"mountain")
 check(gs.play_card(0,0,p.units[2].uid),"food declaration enters actual automatic counter pipeline")
 check(p.units[2].attack==power and foods(gs).is_empty() and foe.hand.is_empty(),"magic interference consumes actual counter and cancels whole food")
 check(p.energy==39 and gs.rule_events.any(func(e):return e.kind=="card-nullified" and e.uid=="avatar-0"),"cancelled food remains paid with source-less actor")
 check(gs.resolution_stack.is_empty(),"cancel continuation finishes")
func revival_and_summon_chain() -> void:
 var gs:=game(["maozhanggui","yixigong","qianji","wuwu"]);var p:Dictionary=gs.player(0)
 gs.VerifiedRules.Weaver.leave_front(gs,0);p.hand.clear();gs.rule_events.clear()
 play(gs,"c24604");p.hand.clear();Food.gain_ingredient(gs,0,0,"sea")
 play(gs,"qianji-song")
 var spear:Dictionary=gs.front_unit(0)
 check(spear.get("rtSpear",false) and spear.maxHp==5 and spear.hp==5,"awakened cat automatically feeds actual spear entity")
 check(p.hand.is_empty() and foods(gs).size()==1 and foods(gs)[0].automatic,"summon auto-food consumes hand without charging an extra fire")
 var energy:=int(p.energy);play(gs,"c24903")
 var candy:Dictionary=gs.front_unit(0)
 check(spear.get("removed",false) and candy.get("scCandy",false),"candy entry replaces and removes spear via shared front lifecycle")
 check(p.hand.filter(func(i):return i.definitionId=="qianji-song").size()==1,"spear leave gives one actual song")
 check(p.energy==energy-1,"form and automatic summons pay once")
 p.hand.clear();Food.gain_feast(gs,0,1,[{"attack":1,"hp":0}])
 check(gs.play_card(0,0,p.units[3].uid),"actual hand feast while sugar master is installed")
 check(gs.front_unit(0).get("scCandy",false) and gs.front_unit(0).get("unyielding",false) and gs.front_unit(0).get("scFusionCount",0)==1,"hand feast triggers actual big candy fusion")
 play(gs,"c24905");p.hand.clear();gs._knockout_unit(p.units[3])
 Food.gain_feast(gs,0,1,[{"attack":2,"hp":0},{"attack":0,"hp":3},{"keyword":"pierce"}])
 check(gs.valid_targets(0,gs.hand_card_def(0,0)).has(p.units[3].uid),"feast revival form exposes knocked-out target")
 check(gs.play_card(0,0,p.units[3].uid),"actual feast revives knocked-out shikigami")
 check(p.units[3].hp==p.units[3].maxHp and p.units[3].cookingFoodAttack==2 and gs.VerifiedRules.Combat.has(p.units[3],"pierce"),"revive then apply combined feast parts")
 check(gs.rule_events.any(func(e):return e.kind=="peach-revive" and e.uid=="avatar-0" and e.target==p.units[3].uid),"neutral revival source actor preserved")
 check(gs.front_unit(0).get("scCandy",false) and gs.front_unit(0).get("unyielding",false),"previously fused candy survives master form replacement")
 check(gs.resolution_stack.is_empty(),"food summon fusion chain drains")
func automatic_marked_food() -> void:
 var gs:=game(["maozhanggui","yixigong","qianji","wuwu"]);var p:Dictionary=gs.player(0)
 gs.VerifiedRules.Weaver.leave_front(gs,0);p.hand.clear();gs.rule_events.clear()
 play(gs,"c24604");p.hand.clear();var inst:=Food.gain_ingredient(gs,0,0,"sea")
 inst.handCharm={"kind":"ward","effects":["draw","hit-enemy"]};var deck:int=p.deck.size();var energy:int=p.energy;var hp:int=gs.player(1).avatarHp
 play(gs,"qianji-song")
 check(p.deck.size()==deck-1 and p.hand.size()==1,"automatic hand food preserves actual attached draw charm")
 check(gs.player(1).avatarHp==hp-3 and p.energy==energy-1,"automatic marked food resolves charm once without paying food fire")
 check(foods(gs).size()==1 and foods(gs)[0].automatic and foods(gs)[0].fromHand,"automatic actual instance retains origin and use scope")
 check(gs.resolution_stack.is_empty(),"automatic marked food drains before continuation")
func arakawa_and_ai() -> void:
 var gs:=game(["huangchuanzhizhu","wuwu","bingyong","shantong"]);var p:Dictionary=gs.player(0)
 check(not Content.unit_def("qianji-spear").is_empty() and not Content.playable_units().any(func(u):return u.id=="qianji-spear"),"derived spear registered without selectable deck entry")
 var hp:int=gs.player(1).units.reduce(func(acc,u):return acc+int(u.hp),0)
 Food.gain_ingredient(gs,0,1,"mountain");Food.gain_ingredient(gs,0,1,"sea")
 check(gs.play_card(0,0,p.units[2].uid),"first food counts for Arakawa")
 check(gs.play_card(0,0,p.units[2].uid),"second food counts for Arakawa")
 check(gs.VerifiedRules.Arakawa.count(gs,0)==2 and gs.player(1).units.reduce(func(acc,u):return acc+int(u.hp),0)==hp-1,"Arakawa sees actual second neutral card")
 Food.gain_unknown(gs,0,1);var card:Dictionary=gs.hand_card_def(0,0)
 for target in gs.valid_targets(0,card):
  check(gs.can_play_card(0,0,target).ok,"AI candidate is legal "+str(target))
  check(AI._score_card(gs,0,card,target)>0,"AI can score neutral target "+str(target))
func _initialize() -> void:
 neutral_source_and_marks();observer_scope_and_counter();revival_and_summon_chain();automatic_marked_food();arakawa_and_ai()
 if failures==0:print("FOOD_CROSS_OK checks=",checks)
 else:printerr("FOOD_CROSS_FAILED checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
