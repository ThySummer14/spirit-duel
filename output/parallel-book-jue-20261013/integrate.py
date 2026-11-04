"""Apply narrow, idempotent integration hooks; usage: python3 integrate.py <godot-dir>."""
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
out=pathlib.Path(__file__).parent
pending_writes={}

def transform(path,changes):
 p=root/path;s=pending_writes.get(p,p.read_text())
 for old,new in changes:
  if new in s:continue
  if s.count(old)!=1:raise RuntimeError(f'{path}: expected unique anchor {old[:90]!r}, found {s.count(old)}')
  s=s.replace(old,new,1)
 pending_writes[p]=s
transform('scripts/verified_card_rules.gd',[
 ('const DogDemon := preload("res://scripts/dog_demon_rules.gd")','const DogDemon := preload("res://scripts/dog_demon_rules.gd")\nconst BookJue := preload("res://scripts/book_jue_rules.gd")'),
 ('\tif Light.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true','\tif BookJue.resolve_action(gs, p_idx, src, card, effect, target): return true\n\tif Light.resolve_action(gs, p_idx, src, card, effect, target, target_id): return true'),
 ('\tXuenv.announced(gs, frame, announced)','\tBookJue.announced(gs, frame, announced)\n\tXuenv.announced(gs, frame, announced)')])
transform('scripts/game_state.gd',[
 ('\tgs._draw(0, int(gs.rules.openingHandSize) - 1)','\tgs._draw(0, int(gs.rules.openingHandSize) - 1 + VerifiedRules.BookJue.opening_extra(gs, 0))'),
 ('\tgs._draw(1, int(gs.rules.openingHandSize) - 1)','\tgs._draw(1, int(gs.rules.openingHandSize) - 1 + VerifiedRules.BookJue.opening_extra(gs, 1))'),
 ('func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n','func resolve_divination_choice(p_idx: int, instance_id: String) -> bool:\n\tif pending_choice.get("type") in ["book-dispatch", "book-mind"]: return VerifiedRules.BookJue.resolve_choice(self, p_idx, instance_id)\n'),
 ('\t\tif p.deck.is_empty():\n\t\t\tif p.avatarHp > 0','\t\tif p.deck.is_empty():\n\t\t\tif VerifiedRules.BookJue.empty_draw(self, p_idx): return\n\t\t\tif p.avatarHp > 0'),
 ('\tvar src := _source_index(p_idx, card)\n\tif src >= 0:\n','\tcard = VerifiedRules.BookJue.describe_card(self, p_idx, p.hand[hand_index], card)\n\tvar src := _source_index(p_idx, card)\n\tif src >= 0:\n'),
 ('func valid_targets(p_idx: int, card: Dictionary) -> Array:\n','func valid_targets(p_idx: int, card: Dictionary) -> Array:\n\tvar book_jue_targets = VerifiedRules.BookJue.targets(self, p_idx, card)\n\tif book_jue_targets != null: return book_jue_targets\n'),
 ('\tVerifiedRules.Light.form_entered(self, p_idx, src, card)','\tVerifiedRules.BookJue.form_entered(self, p_idx, src, card)\n\tVerifiedRules.Light.form_entered(self, p_idx, src, card)'),
 ('\tVerifiedRules.Bailang.damage_dealt(self, _src_player, source_index, p_idx, taken, combat)', '\tVerifiedRules.BookJue.damage_dealt(self, _src_player, source_index, taken)\n\tVerifiedRules.Bailang.damage_dealt(self, _src_player, source_index, p_idx, taken, combat)'),
 ('\tVerifiedRules.Yaodao.avatar_damaged(self, _src_player, source_index, p_idx, amount)','\tVerifiedRules.Yaodao.avatar_damaged(self, _src_player, source_index, p_idx, amount)\n\tVerifiedRules.BookJue.avatar_damaged(self, _src_player, source_index, p_idx, amount)'),
 ('\t\t\t\tVerifiedRules.DogDemon.turn_start(self, p_idx, i)','\t\t\t\tVerifiedRules.DogDemon.turn_start(self, p_idx, i)\n\t\t\t\tVerifiedRules.BookJue.turn_start(self, p_idx, i)'),
 ('\t_draw(p_idx, 1)\n\n\nfunc _trigger_realms','\tif not VerifiedRules.BookJue.turn_draw(self, p_idx): _draw(p_idx, 1)\n\n\nfunc _trigger_realms'),
 ('\t\t"pendingChoice": (not pending_choice.is_empty()),','\t\t"pendingChoice": (not pending_choice.is_empty()),\n\t\t"pendingChoiceState": pending_choice.duplicate(true),')])
transform('scripts/game_ai.gd',[
 ('static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n','static func _score_card(_gs: GameState, p_idx: int, card: Dictionary, _target) -> int:\n\tvar book_jue_score = _gs.VerifiedRules.BookJue.score_card(_gs, p_idx, card, _target)\n\tif book_jue_score != null: return int(book_jue_score)\n'),
 ('static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n','static func _resolve_choice(gs: GameState, p_idx: int) -> bool:\n\tvar book_jue_choice = gs.VerifiedRules.BookJue.ai_choice(gs, p_idx)\n\tif book_jue_choice != null: return bool(book_jue_choice)\n')])
# Revealed cards are clickable; hidden instances stay face down, including duplicates.
p=root/'scripts/ui/battle_screen.gd';s=pending_writes.get(p,p.read_text())
if '# BookJue: inspect every revealed enemy hand instance.' not in s:
 start=s.index('func _fill_enemy_hand(count: int) -> void:');end=s.index('\nfunc ',start+5)
 s=s[:start]+'''func _fill_enemy_hand(count: int) -> void:
	# BookJue: inspect every revealed enemy hand instance.
	for child in _enemy_hand.get_children():
		_enemy_hand.remove_child(child)
		child.queue_free()
	var shown := mini(count, int(gs.rules.maxHandSize))
	for i in shown:
		var inst: Dictionary = gs.player(1 - PLAYER).hand[i]
		var face := CardFace.new()
		face.face_down = not inst.get("revealed", false)
		face.custom_minimum_size = Vector2(43, 70)
		face.set_meta("enemy_instance", str(inst.instanceId))
		if not face.face_down:
			var card: Dictionary = gs.hand_card_def(1 - PLAYER, i)
			face.data = card
			face.tooltip_text = str(card.get("name", ""))
			UIWidgets.attach_click(face, func(): UIWidgets.show_card_modal(self, card))
		else: face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_hand.add_child(face)
		face.pivot_offset = Vector2(18, 54)
		face.rotation = deg_to_rad((i - (shown - 1) * 0.5) * 5.0)
''' + s[end:]
 pending_writes[p]=s
transform('scripts/ui/battle_screen.gd',[
 ('\t\t"resolve_divination_choice": what = ("千羽风之舞转化为「%s」" if a.get("choice") == "feather-transform" else ("青灯夜谈获得「%s」" if a.get("choice") == "lantern-choice" else "占卜置顶「%s」")) % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")','\t\t"resolve_divination_choice":\n\t\t\tif a.get("choice") == "book-mind": what = "明心获得「%s」" % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")\n\t\t\telif a.get("choice") == "book-dispatch": what = "结束调度" if a.get("instanceId") == preload("res://scripts/book_jue_rules.gd").FINISH else "调度「%s」" % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")\n\t\t\telse: what = ("千羽风之舞转化为「%s」" if a.get("choice") == "feather-transform" else ("青灯夜谈获得「%s」" if a.get("choice") == "lantern-choice" else "占卜置顶「%s」")) % ContentLoader.card_def(str(a.get("card", ""))).get("name", "?")'),
 ('\t_choice_layer = Control.new()\n\t_choice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)', '\t_choice_layer = Control.new()\n\t_choice_layer.z_index = 30\n\t_choice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)'),
 ('\t\tfor card in gs.player(PLAYER).get(str(gs.pending_choice.get("zone", "deck")), []):','\t\tfor card in gs.player(int(gs.pending_choice.get("zoneOwner", PLAYER))).get(str(gs.pending_choice.get("zone", "deck")), []):'),
 ('\t\tvar def := ContentLoader.card_def(def_id) if def_id != "" else {}','\t\tvar def := ContentLoader.card_def(def_id) if def_id != "" else {}\n\t\tvar book_jue_choice_card = gs.VerifiedRules.BookJue.choice_card(gs, PLAYER, str(iid))\n\t\tif book_jue_choice_card != null: def = book_jue_choice_card')])
p=root/'content/verified_rules.json';r=json.loads(p.read_text());overlay=json.loads((out/'overlay.json').read_text())
for group in ['units','cards']:r[group].update(overlay[group])
ids={x['id'] for x in r['sources']};r['sources'] += [x for x in overlay['sources'] if x['id'] not in ids]
pending_writes[p]=json.dumps(r,ensure_ascii=False,indent=2)+'\n'
if "--check" not in sys.argv:
 for path,content in pending_writes.items(): path.write_text(content)
print('BOOK_JUE_INTEGRATION_CHECK_OK' if '--check' in sys.argv else 'BOOK_JUE_INTEGRATION_OK',root)
