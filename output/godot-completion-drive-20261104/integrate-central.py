from pathlib import Path
root=Path(__file__).resolve().parents[2];p=root/'godot/scripts/game_state.gd';s=p.read_text()
a=s.index('func _heal_unit(');b=s.index('\n\nfunc _grant_unit_armor',a)
s=s[:a]+'''func _heal_unit(unit: Dictionary, amount: int) -> void:
	if unit.get("toxicPoisoned",false) or int(unit.hp)<=0 or amount<=0:return
	var healed:=maxi(0,mini(amount,int(unit.maxHp)-int(unit.hp)))
	unit.hp=int(unit.hp)+healed
	if healed>0:
		VerifiedRules.TreeSakura.sync_power(unit)
		_log("%s 恢复 %d 点生命。"%[unit.name,healed],TONE_SUCCESS)
	VerifiedRules.MusicFire.healed(self,unit)
	for owner in 2:
		var idx:=_unit_index_by_uid(owner,str(unit.get("uid","")))
		if idx>=0:
			VerifiedRules.EssenceFeast.healed(self,owner,idx,amount,healed,amount-healed)
			break


func _heal_avatar(p_idx: int, amount: int) -> void:
	if player(p_idx).get("avatarToxicPoisoned",false) or amount<=0:return
	var p:=player(p_idx)
	var healed:=maxi(0,mini(amount,int(p.maxAvatarHp)-int(p.avatarHp)))
	p.avatarHp=int(p.avatarHp)+healed
	if healed>0:
		_log("%s 的核心恢复 %d 点生命。"%[p.name,healed],TONE_SUCCESS)
		var context:=_card_effect_context;_card_effect_context={}
		VerifiedRules.ArmorBlood.healing_recorded(self)
		for src in p.units.size():
			VerifiedRules.ArmorBlood.avatar_healed(self,p_idx,healed,src)
			VerifiedRules.Light.avatar_healed(self,p_idx,healed,src)
		_card_effect_context=context
	VerifiedRules.EssenceFeast.healed(self,p_idx,-1,amount,healed,amount-healed)
'''+s[b:]
def add(a,b):
 global s
 assert s.count(a)==1,(a[:90],s.count(a));s=s.replace(a,b,1)
a='\tif VerifiedRules.Toxic.executes(self,_src_player,source_index,p_idx,unit_index,unshielded,combat):'
add(a,'\tvar ef_cap:=int(u.get("formRules",{}).get("damageCap",0))\n\tvar ef_redirect=VerifiedRules.EssenceFeast.replace_unit_damage(self,p_idx,unit_index,mini(unshielded,ef_cap) if ef_cap>0 else unshielded,_src_player,source_index,combat)\n\tif ef_redirect!=null:\n\t\tunshielded=int(ef_redirect.get("remaining",0))\n\t\tif unshielded<=0:\n\t\t\t_record_spell_damage(p_idx,str(u.uid),0,true)\n\t\t\treturn {"damage":0,"dealt":0,"knocked":int(u.hp)<=0,"overkill":0,"transferredDealt":int(ef_redirect.get("transferredDealt",0))}\n'+a)
a='\tVerifiedRules.SerpentGhost.damage_dealt(self,_src_player,source_index,p_idx,unit_index,taken)'
add(a,a+'\n\tif combat and _src_player>=0 and source_index>=0:VerifiedRules.EssenceFeast.combat_dealt(self,_src_player,source_index,{"dealt":taken})')
a='\tVerifiedRules.SerpentGhost.damage_dealt(self,_src_player,source_index,p_idx,-1,actual_loss)'
add(a,a+'\n\tVerifiedRules.EssenceFeast.avatar_damaged(self,p_idx,actual_loss)\n\tif combat and _src_player>=0 and source_index>=0:VerifiedRules.EssenceFeast.combat_dealt(self,_src_player,source_index,{"dealt":actual_loss})')
a='\tVerifiedRules.knocked_out(u)';add(a,'\tVerifiedRules.EssenceFeast.knocked_out(self,victim,u)\n'+a)
q=root/'godot/scripts/sun_smoke_rules.gd';t=q.read_text();a='\tgs.VerifiedRules.Cooking.reset_ledger(target)';assert t.count(a)==1;t=t.replace(a,'\tgs.VerifiedRules.EssenceFeast.reset_ledger(target)\n'+a,1)
p.write_text(s);q.write_text(t);print('CENTRAL_EFFECT_HOOKS_INTEGRATED')
