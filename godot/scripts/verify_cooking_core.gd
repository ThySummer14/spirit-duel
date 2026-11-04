extends "res://scripts/verify_book_jue_ui.gd"
const GS := preload("res://scripts/game_state.gd")
const AI := preload("res://scripts/game_ai.gd")
const Content := preload("res://scripts/content_loader.gd")
const Cook := preload("res://scripts/cooking_rules.gd")
func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("COOKING_FAIL ",detail)
func game() -> GS:
	var gs:=GS.create(["wuwu","shiling","taohuayao","shuzhu"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],253)
	for p in gs.players:
		p.hand.clear();p.energy=80;p.levelUpUsed=true
		for u in p.units:u.level=3
	return gs
func give(gs, id: String) -> int:
	gs.player(0).hand.append({"instanceId":"cook-test-%d"%gs.next_card_id,"definitionId":id});gs.next_card_id+=1
	return gs.player(0).hand.size()-1
func play(gs, id: String, target=null) -> void:
	check(gs.play_card(0,give(gs,id),target),"actual play "+id)
func use(gs, inst: Dictionary, target) -> void:
	var index:int=gs.player(0).hand.find(inst)
	check(index>=0 and gs.play_card(0,index,target),"actual food "+str(inst.get("definitionId","")))
func events(gs, kind: String) -> Array:
	return gs.rule_events.filter(func(ev):return ev.kind==kind)
func feast(gs, parts: Array=[{"attack":2,"hp":1}]) -> Dictionary:
	return Cook.gain_feast(gs,0,1,parts)
func rules() -> void:
	for n in [252,253]:
		for i in range(1,9):
			var tile:=preload("res://scripts/ui/card_face.gd").new();var id:="c%d%02d"%[n,i]
			tile.data=Content.card_def(id);tile.refresh_art()
			check(tile._original_card!=null and tile._original_card.resource_path=="res://assets/official/cards/%s.png"%id,"official texture "+id);tile.free()
	var gs:=game();var p:Dictionary=gs.player(0);var cat:Dictionary=p.units[0];var chef:Dictionary=p.units[1]
	check(cat.attack==3 and cat.maxHp==4 and chef.attack==2 and chef.maxHp==6,"printed base stats")
	for quality in [1,2,3]:
		chef.level=quality
		var a:=Cook.gain_ingredient(gs,0,1,"mountain");var b:=Cook.gain_ingredient(gs,0,1,"sea");var v:=Cook.gain_ingredient(gs,0,1,"vegetable")
		check(a.foodData.parts[0].attack==quality and b.foodData.parts[0].hp==quality,"source quality %d"%quality)
		check(v.foodData.parts.size()==1 and ["inspired","pierce","swift"].has(v.foodData.parts[0].keyword),"vegetable ONE keyword %d"%quality)
		check(p.hand.size()==3,"direct gain does not combine");p.hand.clear()
	chef.level=3
	var food:=Cook.gain_ingredient(gs,0,1,"mountain");var c:Dictionary=gs.hand_card_def(0,0)
	check(c.unitId=="" and c.neutralFood and c.level==0 and c.cost==1 and gs._source_index(0,c)==-1,"neutral source and printed quote")
	check(not gs.can_play_card(0,0,gs.player(1).units[0].uid).ok,"ordinary food rejects enemy")
	gs._knockout_unit(chef,1,0);gs._resolve_resolution_stack();p.energy=0
	check(not gs.can_play_card(0,0,cat.uid).ok,"food still requires payment")
	p.energy=1;use(gs,food,cat.uid)
	check(cat.attack==6 and p.energy==0 and p.cardsPlayedThisTurn==1,"dead generator food real use/growth/count")
	check(events(gs,"food-used").size()==1 and events(gs,"food-used")[0].sourceIndex==-1,"food event neutral source")
	gs=game();p=gs.player(0);cat=p.units[0]
	var a:=Cook.gain_ingredient(gs,0,1,"mountain");var b:=Cook.gain_ingredient(gs,0,1,"sea");var d:=Cook.gain_ingredient(gs,0,1,"mountain")
	Cook.cook(gs,0,1)
	check(p.hand.size()==2 and p.hand[0].instanceId==a.instanceId and Cook.food_kind(p.hand[1])=="feast","cook uses rightmost two actual old ingredients")
	check(p.hand[1].foodData.mergedFrom.has(b.instanceId) and p.hand[1].foodData.mergedFrom.has(d.instanceId) and p.hand[1].foodData.parts.size()==3,"feast preserves all actual ingredient parts")
	check(Cook.feast_count(gs,0)==1 and p.cookingSeenKinds.has("mountain") and p.cookingSeenKinds.has("sea"),"gain ledger is independent of role forms")
	gs=game();p=gs.player(0)
	Cook.gain_ingredient(gs,0,1,"sea");Cook.gain_ingredient(gs,0,1,"mountain")
	while p.hand.size()<12:give(gs,"c25201")
	Cook.cook(gs,0,1)
	check(p.hand.size()==11 and Cook.hand_food_count(gs,0,"feast")==1 and events(gs,"food-burned").is_empty(),"full hand merges before overflow")
	gs=game();p=gs.player(0);cat=p.units[0]
	var unknown:=Cook.gain_unknown(gs,0,1);Cook.gain_ingredient(gs,0,1,"sea");Cook.cook(gs,0,1)
	check(p.hand.size()==1 and Cook.food_kind(p.hand[0])=="dark" and Cook.feast_count(gs,0)==0,"unknown composition becomes dark and separate gain history")
	check(not Cook.auto_use_from_hand(gs,0,0,cat.uid,"feast") and p.hand.size()==1,"random feast excludes dark")
	use(gs,p.hand[0],cat.uid)
	check(cat.armorBreak==6 and cat.cookingFeastUses==1 and p.cookingFeastUsedTurn==gs.turn_counter,"dark6 break counts as used feast")
	unknown=Cook.gain_unknown(gs,0,1);check(Cook.hand_food_count(gs,0,"ingredient")==1,"unknown is a hand ingredient")
	check(Cook.auto_use_from_hand(gs,0,0,gs.player(1).units[1].uid,"ingredient"),"auto ingredient includes unknown");gs._resolve_resolution_stack()
	check(gs.player(1).units[1].armorBreak==4 and not p.hand.has(unknown),"unknown auto actually consumed and gives4 break")
	gs=game();p=gs.player(0);cat=p.units[0]
	food=Cook.gain_ingredient(gs,0,1,"sea");gs.VerifiedRules.HandBlessing.apply_mark(gs,0,0,food,"ward",["draw"])
	var deck:int=p.deck.size();var energy:int=p.energy
	check(Cook.auto_use_from_hand(gs,0,0,cat.uid,"ingredient"),"auto marked food scheduled");gs._resolve_resolution_stack()
	check(p.deck.size()==deck-1 and p.hand.size()==1 and p.energy==energy and cat.maxHp==7,"auto food preserves draw ward without paying")
	p.hand.clear();food=Cook.gain_ingredient(gs,0,1,"mountain");gs.VerifiedRules.HandBlessing.apply_mark(gs,0,0,food,"erosion",["hurt-avatar"])
	check(Cook.auto_use_from_hand(gs,0,0,cat.uid,"ingredient"),"auto eroded food scheduled");gs._resolve_resolution_stack()
	check(p.avatarHp==27 and p.hand.is_empty(),"auto food preserves erosion post")
	gs=game();p=gs.player(0);cat=p.units[0];chef=p.units[1]
	var h:=give(gs,"c25202");check(gs.hand_card_def(0,h).value==0,"cat combat base bonus0")
	food=Cook.gain_ingredient(gs,0,1,"mountain");use(gs,food,cat.uid);food=feast(gs);use(gs,food,cat.uid)
	check(gs.hand_card_def(0,h).value==3 and gs.hand_card_def(0,give(gs,"c25201")).keywords.has("instant"),"receiver history enhances combat and instant")
	check(gs.hand_card_def(0,give(gs,"c25206")).target=="enemy-unit","enhanced pursuit has selected enemy target")
	gs=game();cat=gs.player(0).units[0];chef=gs.player(0).units[1]
	play(gs,"c25208");check(cat.awakened and cat.attack==4 and cat.maxHp==5 and gs.VerifiedRules.Combat.has(cat,"combo"),"cat awakening exact stats and combo")
	check(not gs.can_play_card(0,give(gs,"c25208")).ok,"reject duplicate cat awakening")
	gs._knockout_unit(cat,1,0);gs.VerifiedRules.Peach.revive(gs,0,2,cat,false,false)
	check(gs.VerifiedRules.Combat.has(cat,"combo"),"awakening combo survives KO")
	gs=game();p=gs.player(0);chef=p.units[1]
	play(gs,"c25304");check(chef.awakened and chef.attack==4 and chef.maxHp==7 and Cook.hand_food_count(gs,0,"ingredient")==1,"chef cooks before awakening, base growth+awake")
	check(not gs.can_play_card(0,give(gs,"c25304")).ok,"reject duplicate chef awakening")
	gs._knockout_unit(chef,1,0);feast(gs);gs._resolve_resolution_stack()
	check(chef.hp>0 and chef.knockout==0,"feast gain resurrects dead awakened chef")
	gs=game();p=gs.player(0);chef=p.units[1]
	var idx:=give(gs,"c25306");var iid:String=p.hand[idx].instanceId
	check(gs.hand_card_def(0,idx).keywords.has("bounce"),"bounce keyword visible before use")
	check(gs.play_card(0,idx),"actual quick cook first use")
	var returned:Array=p.hand.filter(func(i):return i.instanceId==iid)
	check(returned.size()==1 and returned[0].cookingBounceSpent,"same original instance returns once")
	idx=p.hand.find(returned[0]);check(not gs.hand_card_def(0,idx).cookingBounce and not gs.hand_card_def(0,idx).text.contains("弹回"),"returned instance loses bounce")
	check(gs.play_card(0,idx) and not p.hand.any(func(i):return i.instanceId==iid),"second use consumed original instance")
	gs=game();p=gs.player(0);chef=p.units[1]
	play(gs,"c25303");check(Cook.hand_food_count(gs,0,"ingredient")==1 and p.realms.size()==1 and p.realms[0].hp==5,"realm entry cooks once")
	deck=p.deck.size();feast(gs);gs._resolve_resolution_stack();check(p.deck.size()==deck-1,"realm draws on actual feast gain")
	var count:int=events(gs,"cooking").size();gs._trigger_one_realm(0,str(p.realms[0].uid));gs._resolve_resolution_stack()
	check(events(gs,"cooking").size()==count,"realm no fake start-turn cook")
	gs=game();p=gs.player(0);chef=p.units[1]
	play(gs,"c25301");check(gs.end_turn(0),"end turn with backline chef")
	check(events(gs,"cooking").is_empty(),"backline end does not cook")
	check(gs.end_turn(1),"return turn");p.energy=80;chef.front=1
	check(gs.end_turn(0),"front chef end turn");check(events(gs,"cooking").size()==1,"front chef cooks at own end")
	gs=game();p=gs.player(0);cat=p.units[0]
	play(gs,"c25205");check(Cook.hand_food_count(gs,0,"ingredient")==1,"cat day printed entry cooks")
	var enemy_hp:int=gs.player(1).avatarHp;food=feast(gs);use(gs,food,cat.uid)
	check(cat.barrier and gs.player(1).avatarHp<enemy_hp,"cat day feast gives barrier and actual attack")
	gs=game();p=gs.player(0);cat=p.units[0]
	play(gs,"c25207");deck=p.deck.size();energy=p.energy;food=feast(gs);use(gs,food,cat.uid)
	check(p.deck.size()==deck-1 and p.energy==energy,"cat work draws and refunds1 after actual cost")
	gs=game();p=gs.player(0)
	play(gs,"c25305");Cook.cook(gs,0,0)
	check(gs.kw_usage(0,"encourage").get("attack",0)==1 and gs.kw_usage(0,"encourage").get("shield",0)==1,"hot chef cook grants real encourage")
	gs=game();p=gs.player(0);cat=p.units[0];chef=p.units[1]
	play(gs,"c25308");food=Cook.gain_ingredient(gs,0,1,"mountain");energy=p.energy;use(gs,food,cat.uid)
	check(p.energy==energy and cat.attack==6 and chef.attack==9 and p.units[2].attack==4 and events(gs,"food-used").size()==4,"divinity free first and copy exactly all other allies")
	food=Cook.gain_ingredient(gs,0,1,"sea");use(gs,food,cat.uid)
	check(p.energy==energy-1 and events(gs,"food-used").size()==8,"divinity second pays; copies do not recurse")
	gs=game();p=gs.player(0);cat=p.units[0]
	food=feast(gs,[{"attack":2,"hp":3,"keyword":"pierce"}]);use(gs,food,cat.uid)
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,cat,cat.uid)
	check(cat.attack==3 and cat.maxHp==4 and gs.VerifiedRules.Combat.has(cat,"pierce"),"paper reset removes stats and retains keyword")
	gs._knockout_unit(cat,1,0)
	check(cat.attack==3 and cat.maxHp==4 and not gs.VerifiedRules.Combat.has(cat,"pierce"),"KO after reset neither subtracts twice nor keeps food keyword")
	gs=game();cat=gs.player(0).units[0];food=feast(gs,[{"attack":2,"hp":3,"keyword":"pierce"}]);use(gs,food,cat.uid);gs._knockout_unit(cat,1,0)
	check(cat.attack==3 and cat.maxHp==4,"ordinary food stat gains vanish on actual KO")
	gs=game();p=gs.player(0);cat=p.units[0]
	var foe:Dictionary=gs.player(1).units[0];foe.front=1;foe.hp=5;foe.maxHp=5;foe.attack=10
	food=feast(gs,[{"attack":2}]);play(gs,"c25204")
	check(foe.hp==0 and cat.hp==4 and cat.cookingFeastUses==1,"first strike feast resolves BEFORE combat; no retaliatory death")
	gs=game();p=gs.player(0);cat=p.units[0];food=feast(gs);deck=p.deck.size()
	play(gs,"c25203")
	check(cat.attack==5 and p.deck.size()==deck-1 and not p.hand.has(food),"cat spell consumes actual feast before draw")
	gs=game();p=gs.player(0);deck=p.deck.size();play(gs,"c25203")
	check(p.deck.size()==deck-1,"cat spell still draws with no feast")
	gs=game();play(gs,"c25201")
	check(gs.player(1).avatarHp==26 and Cook.hand_food_count(gs,0,"ingredient")==1,"combat+1 then base cat cooks on actual avatar damage")
	gs=game();cat=gs.player(0).units[0];foe=gs.player(1).units[0];foe.front=1;foe.hp=20;foe.maxHp=20;foe.attack=0
	check(gs.basic_attack(0,0),"base cat actual unit combat")
	check(foe.hp==17 and events(gs,"cooking").is_empty(),"base cat does not cook on unit damage")
	gs=game();cat=gs.player(0).units[0];foe=gs.player(1).units[0];foe.front=1;foe.hp=20;foe.maxHp=20;foe.attack=0
	play(gs,"c25208");check(gs.basic_attack(0,0),"awake cat actual combo attack")
	check(foe.hp==12 and events(gs,"cooking").size()==2,"awake cat cooks on each actual combo damage segment")
	gs=game();cat=gs.player(0).units[0];foe=gs.player(1).units[0];foe.front=1;foe.shield=99;foe.attack=0
	play(gs,"c25208");check(gs.basic_attack(0,0),"awake cat attacks shielded front")
	check(events(gs,"cooking").is_empty(),"zero health damage does not cook")
	gs=game();play(gs,"c25302")
	check(gs.player(1).avatarHp==27 and events(gs,"cooking").size()==1 and gs.player(0).units[1].attack==3,"chef cooks and grows BEFORE its actual combat")
	gs=game();p=gs.player(0);chef=p.units[1];feast(gs);feast(gs);var hot:=give(gs,"c25307")
	check(gs.hand_card_def(0,hot).value==4 and gs.hand_card_def(0,hot).combatOption.shield==4,"hot wave grows from actual gained-feast history")
	foe=gs.player(1).units[1];foe.hp=20;foe.maxHp=20;foe.attack=0
	check(gs.play_card(0,hot,foe.uid) and foe.hp==14,"hot wave pursues selected backline with history bonus")
	gs=game();p=gs.player(0);p.units[1].level=1;Cook.gain_ingredient(gs,0,1,"vegetable")
	for seed in range(20):
		if ((seed*1664525+1013904223)&0xffffffff)%3==2:gs.rng_state=seed;break
	Cook.cook(gs,0,1)
	check(p.hand.size()==2 and p.hand[1].foodData.ingredientKind in ["mountain","sea"],"cook falls back when every vegetable keyword already held")
	gs=game();chef=gs.player(0).units[1];Cook.cook(gs,0,0);Cook.cook(gs,0,1)
	check(chef.attack==4,"chef grows for each friendly actual cook")
	gs._knockout_unit(chef,1,0);check(chef.attack==2,"ordinary cooking growth cleared on chef KO")
	gs=game();chef=gs.player(0).units[1];play(gs,"c25304");Cook.cook(gs,0,0)
	gs.VerifiedRules.SunSmoke.reset_character(gs,0,chef,chef.uid)
	check(chef.attack==3 and chef.maxHp==7,"reset clears cooking growth but keeps awakening stats")
	gs._knockout_unit(chef,1,0);check(chef.attack==3,"KO after paper reset does not subtract cooking growth twice")
	for number in [252,253]:
		for n in range(1,9):
			gs=game();var id:="c%d%02d"%[number,n];give(gs,id);var best:Dictionary=AI._best_card(gs,0)
			check(best.ok and best.card_id==id,"AI chooses "+id)
			if best.ok:check(gs.play_card(0,best.hand,best.target),"AI legally plays "+id)
func ui_checks() -> void:
	root.theme=ThemeBuilder.build_theme()
	for physical in [Vector2i(1280,800),Vector2i(1600,740)]:
		root.size=physical;DisplayServer.window_set_size(physical)
		var b:=Battle.new();b.setup(["wuwu","shiling","taohuayao","shuzhu"],["bingyong","fenghuanghuo","yaodaoji","xuenv"],253);b._ai_thinking=true
		for p in b.gs.players:
			p.hand.clear();p.energy=80;p.levelUpUsed=true
			for u in p.units:u.level=3
		root.add_child(b);await create_timer(0.5).timeout
		var p:Dictionary=b.gs.player(0);var target:Dictionary=p.units[0]
		var food:=Cook.gain_ingredient(b.gs,0,1,"mountain");b._last_view={};b._refresh();await settled(b)
		await click(b._hand_row.get_child(0));check(b._pending_target_card==0,"mouse enters neutral target mode")
		await click(b._unit_widget(str(b.gs.player(1).units[0].uid)));check(b._pending_target_card==0,"mouse rejects wrong side food target")
		await capture("%d-food-target"%physical.x)
		await click(b._unit_widget(str(target.uid)));await settled(b)
		check(target.attack==6 and p.hand.is_empty(),"mouse consumes actual neutral food and grows selected unit")
		hand(b,["c25306"]);await settled(b);var iid:String=p.hand[0].instanceId
		await click(b._hand_row.get_child(0));await settled(b)
		check(p.hand.any(func(i):return i.instanceId==iid and i.get("cookingBounceSpent",false)),"mouse quick cooking returns original spent-bounce instance")
		await capture("%d-bounce-and-food"%physical.x)
		hand(b,["c25308"]);await settled(b);await click(b._hand_row.get_child(0));await settled(b)
		p.hand.clear();food=feast(b.gs,[{"attack":1,"hp":2,"keyword":"pierce"}]);b._last_view={};b._refresh();await settled(b)
		var before:int=events(b.gs,"food-used").size();await click(b._hand_row.get_child(0));await click(b._unit_widget(str(target.uid)));await settled(b)
		check(events(b.gs,"food-used").size()==before+4 and p.units.all(func(u):return b.gs.VerifiedRules.Combat.has(u,"pierce")),"mouse feast real divinity copies to all allies")
		await capture("%d-divinity-copies"%physical.x)
		hand(b,["c25206"]);await settled(b);await click(b._hand_row.get_child(0));check(b._pending_target_card==0,"enhanced pursuit mouse selection")
		await capture("%d-enhanced-pursuit"%physical.x)
		await click(b._unit_widget(str(b.gs.player(1).units[1].uid)));await settled(b)
		check(not p.hand.any(func(i):return i.definitionId=="c25206") and int(b.gs.player(1).units[1].hp)<=0,"enhanced pursuit accepts selected backline and resolves")
		b.queue_free();await process_frame
func run() -> void:
	var stores:=Support.isolate_stores();rules()
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty() and not args.has("--rules-only"):
		out=args[0];DirAccess.make_dir_recursive_absolute(out);await ui_checks()
	Support.cleanup_audio();await process_frame;Support.cleanup_stores(stores)
	print("COOKING_CORE_VERIFY ",JSON.stringify({"checks":checks,"failures":failures,"ui":not out.is_empty()}));quit(1 if failures else 0)
