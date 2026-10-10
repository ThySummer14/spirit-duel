import verifiedOverlay from './godot/content/verified_rules.json' with { type: 'json' };

function clonePatch(patch) {
  return JSON.parse(JSON.stringify(patch));
}

/** 返回核对数据覆盖后的定义（不修改冻结的原始卡库对象）。 */
export function mergeVerifiedDefinition(base, patch) {
  if (!base || !patch) return base;
  const merged = { ...base, ...clonePatch(patch) };
  if (patch.passive) merged.passive = clonePatch(patch.passive);
  if (patch.awakenedPassive) merged.awakenedPassive = clonePatch(patch.awakenedPassive);
  if (patch.effects) merged.effects = clonePatch(patch.effects);
  if (patch.formRules) merged.formRules = clonePatch(patch.formRules);
  if (!merged.sourceSnapshotText && base.officialText) merged.sourceSnapshotText = base.officialText;
  return merged;
}

export function verifiedUnitPatch(unitId) {
  return verifiedOverlay.units?.[unitId] ?? null;
}

export function verifiedCardPatch(cardId) {
  return verifiedOverlay.cards?.[cardId] ?? null;
}

export function verifiedSourceIds() {
  return {
    units: Object.keys(verifiedOverlay.units ?? {}),
    cards: Object.keys(verifiedOverlay.cards ?? {}),
  };
}
