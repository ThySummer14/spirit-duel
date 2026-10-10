export function isPhoenixSpellSource(unit) {
  return Boolean(unit?.phoenixSpellTrigger);
}

export function phoenixNonCombatBonus(unit) {
  if (!unit || unit.hp <= 0) return 0;
  return Number(unit.formRules?.nonCombatDamageBonus ?? 0);
}

export function phoenixDamagePreview(card, unit) {
  if (!card?.phoenixSpell) return 0;
  let amount = Number(card.phoenixBaseDamage ?? card.value ?? 0) + phoenixNonCombatBonus(unit);
  if (card.phoenixEnhancement) amount += Number(unit.phoenixAvatarHits ?? 0);
  return amount;
}

export function phoenixTriggersForSpell(state, playerIndex, card, sourceIndex) {
  if (card.type !== 'spell' || state.winner !== null) return [];
  const player = state.players[playerIndex];
  const triggers = [];
  player.units.forEach((unit, index) => {
    if (!isPhoenixSpellSource(unit) || unit.hp <= 0 || unit.level < 1) return;
    if (index !== sourceIndex && !unit.awakened) return;
    const trigger = { sourceIndex: index, uid: unit.uid };
    if (index === sourceIndex && unit.formRules?.fortuneGenerate) {
      trigger.fortune = { ...unit.formRules.fortuneGenerate };
    }
    triggers.push(trigger);
  });
  return triggers;
}

export function recordPhoenixAvatarHit(state, ownerIndex, sourceIndex, victimPlayerIndex, dealt) {
  if (dealt <= 0 || victimPlayerIndex === ownerIndex || sourceIndex < 0) return;
  const unit = state.players[ownerIndex].units[sourceIndex];
  if (!isPhoenixSpellSource(unit)) return;
  unit.phoenixAvatarHits = Number(unit.phoenixAvatarHits ?? 0) + 1;
}
