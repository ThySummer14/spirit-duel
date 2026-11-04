extends SceneTree
const GS := preload("res://scripts/game_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PAINT_STAR_PINE_FAIL ",detail)

func game() -> GS:
	var gs := GS.create(["huaniajuan","xiaosongwan","xingxiongtongzi","gunvhongye"],["duyanxiaoseng","xiaosongwan","xingxiongtongzi","yaodaoji"],229245251)
	for owner in 2:
		var p: Dictionary = gs.player(owner)
		p.hand.clear(); p.energy=40; p.levelUpUsed=true; p.realms.clear()
		gs.kw_usage(owner,"encourage").attack=0; gs.kw_usage(owner,"encourage").shield=0
		for u in p.units: u.level=3
	return gs

func play(gs, id: String, target = null, owner: int = 0) -> void:
	gs.player(owner).hand.append({"definitionId":id,"instanceId":"paint-star-pine-%d" % gs.next_card_id}); gs.next_card_id+=1
	check(gs.play_card(owner,gs.player(owner).hand.size()-1,target),"actual card "+id)

func summons() -> void:
	var gs := game(); var p: Dictionary=gs.player(0)
	play(gs,"c24508")
	var fruit: Dictionary=p.units.back()
	check(fruit.get("pineSummon",false) and fruit.hp==4,"harvest countdown summons real fruit")
	gs.VerifiedRules.Paint.summon_field(gs,0,0,4,true)
	play(gs,"c22906")
	var scroll: Dictionary=p.units.back()
	check(scroll.get("paintSummon",false) and scroll.hp==7 and fruit.removed,"paint scroll replaces fruit with actual7/7")
	check(p.units[1].get("pineKeywords",[]).size()==1,"fruit departure grants exactly one harvest keyword")
	gs._resolve_resolution_stack()
	check(p.units[1].pineKeywords.size()==1,"departed cleanup cannot repeat fruit reward")
	gs.VerifiedRules.reduce_countdown(gs,0,1,2); gs._resolve_resolution_stack()
	check(scroll.removed and p.units.back().get("pineSummon",false) and p.units.back().hp==4,"later fruit replaces scroll through actual timer")
	check(gs.VerifiedRules.Paint.durability(gs,0)==0,"replacement does not impersonate scroll turn-start destruction")

func countdowns() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var u: Dictionary=p.units[1]
	play(gs,"c24501")
	gs.VerifiedRules.reduce_countdown(gs,0,1,2)
	check(gs.basic_attack(0,1),"curious actual basic attack")
	check(gs.player(1).avatarHp==27 and u.attack==3,"attack-triggered timer growth resolves before this hit")
	check(u.pineCountdownZeros==1 and gs.VerifiedRules.Countdown.timer(u).remaining==3,"one zero is recorded and timer resets")
	gs._knockout_unit(u); gs._resolve_resolution_stack()
	gs.VerifiedRules.Fortune.success(gs,0)
	check(u.hp==0 and u.knockout==1,"shared fortune success reduces real death countdown")
	gs.VerifiedRules.Fortune.success(gs,0)
	check(u.hp==u.maxHp and u.knockout==0 and u.pineCountdownZeros==2,"shared fortune revives and records death timer zero")
	gs.VerifiedRules.Pine.grant_trait(gs,0,1,"unyielding")
	gs._knockout_unit(u); gs._resolve_resolution_stack()
	check(not u.unyielding,"direct destruction clears fruit-granted unyielding without consuming a damage packet")
	gs.VerifiedRules.reduce_countdown(gs,0,1,2); gs._resolve_resolution_stack()
	check(u.hp==u.maxHp and not u.unyielding,"revival cannot inherit an expired fruit keyword")

func redirects() -> void:
	var gs := game(); var p: Dictionary=gs.player(0); var enemy: Dictionary=gs.player(1)
	play(gs,"c25904"); p.night=10
	play(gs,"c25108",enemy.units[1].uid)
	gs._grant_unit_armor(enemy.units[1],2)
	var loss: int=gs._damage_avatar(0,3,0,3)
	check(loss==3 and p.avatarHp==30 and enemy.units[1].hp==3,"cross-side bowl applies maple bonus once before recipient armor")
	check(gs._shell_redirect_chain.is_empty(),"redirect chain restores after cross-side packet")
	gs=game(); p=gs.player(0); enemy=gs.player(1)
	gs.current_player=1; play(gs,"c25108",p.units[1].uid,1); gs.current_player=0
	var hp: int=enemy.units[3].hp
	var hit: Dictionary=gs.VerifiedRules.Combat.strike(gs,0,0,1,3,2,{"halfRemainingHpArmorBreak":true})
	check(hit.get("redirectedPlayer",-1)==0 and hit.redirectedIndex==1,"combat reports actual cross-side recipient")
	check(p.units[1].hp==4 and p.units[1].armorBreak==2,"post-hit rule follows actual recipient owner and index")
	check(enemy.units[3].hp==hp and enemy.units[1].armorBreak==0,"original recipient side receives no false hit or armor break")
	gs._record_combat_strike(0,0,1,3,hit,0)
	check(gs.rule_events.back().victimPlayer==0 and gs.rule_events.back().target==p.units[1].uid,"combat presentation uses actual recipient side")
	gs=game(); p=gs.player(0); enemy=gs.player(1)
	gs.VerifiedRules.Movement.move_to(gs,1,0,1); enemy.units[0].hp=1
	gs._grow_unit(enemy.units[1],20,20)
	play(gs,"c25108",enemy.units[1].uid)
	gs.VerifiedRules.Paint.summon_field(gs,0,0,8,true); p.avatarHp=10
	hp=enemy.units[1].hp
	play(gs,"c22908")
	check(enemy.units[1].hp==hp-8 and enemy.units[0].hp==1 and enemy.avatarHp==30,"redirected paint projectile does not fabricate original-target overflow")
	check(p.avatarHp==18 and gs.VerifiedRules.Paint.durability(gs,0)==0,"paint lifesteal counts actual redirected packet once")
	gs=game(); p=gs.player(0); enemy=gs.player(1)
	play(gs,"c25108",enemy.units[1].uid)
	p.monkImmuneTurn=gs.turn_counter
	gs._damage_avatar(0,2,1,3)
	check(p.avatarHp==30 and enemy.units[1].hp==4,"original avatar immunity does not suppress recipient damage")
	p.units[0].coinPreventDamage=true
	gs._damage_unit(0,0,2,1,3)
	check(p.units[0].coinPreventDamage and enemy.units[1].hp==2,"original coin guard is not consumed by a redirected packet")
	enemy.units[1].barrier=true
	gs._damage_avatar(0,2,1,3)
	check(not enemy.units[1].barrier and enemy.units[1].hp==2,"actual bowl bearer barrier prevents redirected damage")
	enemy.units[1].coinPreventDamage=true
	gs._damage_avatar(0,2,1,3)
	check(not enemy.units[1].get("coinPreventDamage",false) and enemy.units[1].hp==2,"actual bowl bearer coin guard is consumed normally")
	gs=game(); enemy=gs.player(1)
	gs.kw_usage(1,"encourage").shield=3
	play(gs,"c25102",enemy.units[1].uid)
	gs.VerifiedRules.Combat.strip_protection(gs,1,1,true)
	gs._grant_unit_armor(enemy.units[1],4,false)
	gs.VerifiedRules.StarBear.expire_turn(gs)
	check(enemy.units[1].shield==4,"stripped temporary armor cannot remove later permanent armor at expiry")

func _initialize() -> void:
	summons(); countdowns(); redirects()
	print("PAINT_STAR_PINE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
