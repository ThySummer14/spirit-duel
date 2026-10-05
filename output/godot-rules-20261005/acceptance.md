# Godot combat parity regression · 2026-10-05

## Iteration 1: stunned defenders cannot regain retaliation on knockout

Godot cleared `frozen` inside knockout handling and checked it afterward when deciding retaliation. A stunned defender killed by the attack therefore dealt counterdamage. Retaliation eligibility and power now use the pre-damage state, matching `game-core.js`.

`verify_combat.gd` exercises the 16 combinations of stunned/normal, lethal/nonlethal, remote/melee, and first-strike/normal attacks. On the original source the lethal stunned melee case failed (`expected_hp=20 got=16`); all 16 cases pass with the fix. Knockout still clears stun and removes the defender from the front.

Validation on installed Godot 4.6.3 stable:
- Pure content/rules verifier: passed, 250 units / 2114 cards.
- Combat regression: 16 cases passed.
- Existing JS/Godot parity: all seven samples matched at every recorded step.
- Browser rules tests: 163 passed, zero failed.

The aggregate asset import was killed while processing the large art collection under cloud memory pressure; it did not reach UI checks. This is not a full visual-verification claim. Tests use isolated writable temporary Godot data/config/cache paths. Existing artwork and generated import metadata are not changed.

## Iteration 2: permanent health growth applies once

`_grow_unit` called `_recalc`, which already increases living HP by the maximum-HP delta, then added the HP bonus again. This healed existing damage twice and could raise a knocked-out unit above zero HP while its knockout countdown remained active. The duplicate adjustment is removed. Explicit form-card full healing remains unchanged.

- Before-fix growth regression: six failures across damaged and knocked-out cases.
- After-fix growth regression: 24 checks passed, including repeated growth.
- New `sample-growth.json`: a damaged character plays an actual awakening card; JS/Godot step and final snapshots match.
- UI script parsing: 21 scripts passed (not a rendered UI check).
- Isolated save and collection checks passed.
- Seeded stress: 60 random matches and 20 focused matches completed, zero stalls; focused matches included nine response games and one choice game.
