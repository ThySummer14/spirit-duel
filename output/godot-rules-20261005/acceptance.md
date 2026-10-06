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

## Iteration 3: overflow draws preserve the player's held cards

Godot removed the first card from hand when exceeding 12, while the browser baseline retains the first 12 and burns the new overflow. Drawing into a full hand could therefore destroy a card the player was saving. The overflow now removes the newly drawn card.

- Four direct cases cover 11/12 held cards and one/three draws; the previous implementation failed retained-card and first-free-slot checks, and the fix passes.
- Parity snapshots now compare ordered hand and deck card identities in addition to counts, closing the blind spot that hid this bug.
- All nine fixtures pass the expanded comparison, including the new full-hand end-turn fixture and damaged-awakening fixture.

## Iteration 4: existing energy and stat-growth effects resolve

The content catalog contains 56 `energy-gain` and 190 `buff-stats` effect references. These previously fell through to the unsupported-effect log. Godot now implements the JS baseline's energy cap of four and permanent stat growth for source, selected ally/enemy, all allies/enemies and all other allies. Missing selected targets do not silently buff the source; dead units are excluded and growth preserves existing damage.

- Direct effect regression: 149 checks passed across all six target scopes, missing targets, dead units, damaged units, and energy caps.
- Real-card parity fixture: four successful plays exercise energy and selected/self/other-ally growth, matching JS including ordered hand/deck contents.
- This covers these two effect primitives, not every card's remaining complex mechanisms or passive timing.
- A separate observed token-generation ordering difference is being investigated; it is not hidden by disabling identity comparison.

## Iteration 5: turn draw precedes passive-generated cards

Expanded hand-identity comparisons exposed a real opening/turn ordering difference: Godot generated passive tokens before the turn draw, while JS draws before its turn-start event. The new token fixture failed with four swapped hand positions before the fix. Godot now draws first, then emits turn-start and its hooks only if the match remains active. This also prevents token/growth passives after deck exhaustion has already ended the match.

- Two-turn real-card fixture now matches ordered hand/deck snapshots.
- Seven direct checks verify opening order, later-turn order, and no token or stat growth after exhaustion defeat.
- Existing card wording and passive definitions are unchanged; this aligns the established browser resolution order.

## Iteration 6: battle-owned presentation timers release old matches

The representative UI test passed its prior 119 assertions but emitted an ObjectDB leak and a GameState resource-in-use error at shutdown. A new weak-reference assertion reproduced the retained old state immediately after freeing a battle screen with pending AI/presentation work.

AI, result and visual delays now use one-shot child timers owned by the battle screen. Restart and exit cancel those timers; delayed callbacks identify the match without retaining its GameState. Existing animation durations, input locks and AI scheduling are preserved.

- Before fix: 120 checks, one failed teardown assertion, leaked resource reported.
- After fix: all 120 presentation checks passed, no leaked-instance/resource-in-use errors.
- Actual UI signal regression: 30 checks passed.
- Reference workflow regression: 187 checks passed (opening replacement, formation slots, collection workflow, and battle/results flow).

These checks used an isolated project with unchanged game source/content and a representative eight-character portrait subset. They do not establish full 250-character rendered-art coverage.

### Serial import diagnostic

Writable XDG paths alone did not solve import exits with status 137. A minimal one-portrait project imported the unchanged 1024×1536 RGB image in 8.45 seconds at 717,360 KiB peak child RSS. Explicitly setting `editor/import/use_multiple_threads=false` in the isolated QA project then imported 52 representative resources successfully in 19.65 seconds at 720,188 KiB peak RSS, below a 1.2 GB stop threshold. Original assets were unchanged. This is a verified working configuration; the prior termination cause has not been conclusively established. [Godot 4.6 setting documentation](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-editor-import-use-multiple-threads).

## Iteration 7: aiming uses current viewport input and excludes unrelated HUD

The actual native selection capture showed a gold diagonal ending at the extreme top-right. The image alone cannot identify whether its cursor position came from synthetic native input or from a pointer outside the game. Source inspection established that the guide polled global mouse position every frame and accepted unbounded coordinates, so both situations could draw the same unexplained line.

The guide now uses the latest viewport-local mouse event, converted into the current canvas. Window mouse exit, focus loss, screen resize and match restart invalidate that evidence. The line is hidden outside the battlefield, hand and targetable enemy-core regions, including header/end-turn/opponent-hand HUD. Valid unit snapping and explicit invalid-unit feedback remain intact.

- New focused regression: old code failed 14 of 19 checks; fixed code passes all 19.
- Coverage: fresh pointer evidence, four outside-window edges, header/HUD, non-finite coordinates, valid allies, invalid enemies, mouse exit/re-entry, focus loss and translated canvas coordinates. Pointer changes must not execute game commands.
- Existing UI checks remain clean: 120 presentation, 30 interaction and 187 reference-workflow checks passed with no script/resource errors.
- Native after-fix image verification is pending a coordinated resource window; this entry does not claim that it has already happened.

Coordinate conversion follows [Godot 4.6 CanvasItem documentation](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html#class-canvasitem-method-get-canvas-transform).


### Native targeting follow-up, 2026-10-05 19:48 UTC

The four-state native fixture has now run in the X11 renderer. All four capture writes succeeded and pixels were inspected: unrelated HUD has no guide, a valid ally has a green snapped guide, an enemy target for the ally spell has a red guide, and window exit hides the guide without losing selection. No game command was executed. These are genuine native viewport captures with test-injected pointer events, not physical-pointer recordings or original-game footage. All images are 1180×812; [capture hashes and scope](native-aim-manifest.json) identify the retained task artifacts. The game window was absent after the auto-quitting fixture; no separate native process exit code was available.

## Iteration 8: self-damage is paid before subsequent rewards

The existing `damage-self` action was unsupported. In the real `c19302` (切腹) card, this made the source gain three attack without paying its three-damage cost. Before the fix, a successful card-play fixture differed from JS in HP, attack and knockout countdown. Godot now routes this action through ordinary source-unit damage, retaining shields, brittle, unyielding and knockout cleanup; the following growth effect correctly excludes a knocked-out source.

- 39 direct checks cover both players, nonzero source index, shield absorption, lethal removal from front, unyielding, brittle, card-value fallback and no growth after knockout.
- The successful real-card fixture now matches JS. This implements the established browser baseline, whose action targets the source unit even where some catalog text says “you”; it does not reinterpret original-game rules.
- The catalog has 22 references to this primitive. This does not establish full correctness of every compound card or damage-trigger passive; those remain separate parity work.

All six focused rule suites passed (239 checks/cases total), and all 12 ordered-state JS/Godot parity samples matched after this change.

## Iteration 9: first instant card uses the existing free-play allowance

A successful 醉里乾坤 play exposed a cost mismatch: JS kept two energy while Godot charged one. The existing keyword specification makes the owner's first instant card free on their own action turn, outside response windows. Godot now shares this effective-cost calculation between legality and payment, consumes the allowance on a successful zero-cost instant play and resets it on the owner's next turn.

- 12 direct checks cover repeated pure cost queries, ordinary cards, opposing turns, response windows, reset and actual play at zero energy.
- A six-command real-card fixture exercises three consecutive instant cards, both turn transitions and a fresh free instant; every command succeeds and ordered snapshots match JS.
- This aligns this keyword only. Printed card-face cost remains the printed definition; legal-play feedback now reflects the actual discounted cost.

After the change, all seven focused suites passed (251 checks/cases), and all 13 JS/Godot parity samples matched.

## Iteration 10: automatic spells reject injected targets; missing selection stays missing

A bounded four-card audit exercised 献祭, 血华散, 血绽 and 觉醒·武士之灵. It found that Godot accepted an explicit enemy target for an automatic-target spell even though JS rejected the command. After rejecting that target, the same card exposed a second mismatch: a missing `selected-enemy` target silently damaged the enemy core (or front unit) in Godot. The JS baseline leaves that selected-target effect unresolved.

Godot now rejects extraneous targets on automatic non-assault cards before payment and does not redirect missing selected-enemy damage. Existing assault targeting is unchanged. Nine direct checks cover rejection without player-state or command-log changes, successful untargeted play, source damage, missing front/core targets and a genuine selected enemy. The five-command fixture has four successful compound plays and one deliberately rejected command, with matching ordered snapshots.

This preserves the current catalog/baseline semantics. c66301 (血绽)'s automatic target paired with a selected-enemy effect remains a content inconsistency to clarify against the original reference; no new targeting rule is invented here.

Final focused verification: all eight rule suites passed (260 checks/cases) and all 14 JS/Godot samples matched. Save/collection and vertical-slice checks passed immediately before this target-only change. No new native UI or full-asset import was run in these three rule iterations.

## Iteration 11: signed stat adjustment matches the selected-enemy baseline

墨笔夺魂 (`c12201`) previously did nothing in Godot, while JS applied its −2 attack/−1 HP. A successful full-card fixture reproduced differences in attack, HP and maximum HP. The missing `debuff-stats` handler now uses the exact established signed deltas on a living selected enemy; it does not infer negation or area scope from its name. The direct HP adjustment and subsequent stat recalculation follow JS in the same order.

- 14 direct checks cover both owners, damaged units, HP floor, repeated reductions, living-enemy selection, dead/ally exclusion, positive deltas and absent-target behavior.
- Four successful real-card plays compare repeated 墨笔夺魂, the positive-valued 枕霜而眠 and the all-enemy-labelled 诸善奉行. All intermediate/final states match JS.
- Unresolved catalog intent: 57 effects use `debuff-stats`; only c12201 supplies negative values. Ten effects name all-enemy scope, but the existing JS handler still operates on a selected enemy only. Positive deltas therefore remain positive, and absent selected targets remain no-ops. These contradictions are recorded, not silently rebalanced or described as original-game fidelity.

Final verification: nine focused suites passed (274 checks/cases) and all 15 JS/Godot samples matched. No native UI/full-asset or original-recording validation was added.

## Iteration 12: Wind Fan returns the target before the spell follow-up

A four-command real match put an enemy into the front and played 风神一扇 (`c10504`). Godot applied damage but ignored `bounce-to-reserve`, leaving that surviving enemy in combat. Adding the missing return exposed the owner's spell-trigger follow-up: JS redirects that follow-up to the newly unguarded core, while Godot previously dropped it. Both now match the established baseline, including resolution order.

- The full-card fixture originally differed in enemy core HP, front identity, front flag and target HP; all four fields now match.
- 16 direct checks cover both players, retained HP/shield, no automatic replacement front, invalid/missing targets, occupied-front preference and exposed-core spell follow-up.
- Only the spell-trigger passive gets unconditional empty-front core fallback. Ordinary entry hooks still require their existing fallback flag, and form hooks keep their previous behavior.

Final verification: all 10 focused suites passed (290 checks/cases), and all 16 JS/Godot parity samples matched. Original footage and new native UI capture remain unverified.

## Iteration 13: Wind Guard applies its existing team-shield effect

风符·护 (`c11802`) applied its form but dropped `shield-self-player`. The baseline grants five shield to each living allied unit; a successful real-card fixture differed on exactly those three shield values while a knocked-out teammate correctly remained unshielded. Godot now applies that existing effect additively to living allies.

- 22 direct checks cover either owner, pre-existing shield, repeated stacking, card-value fallback, no HP changes, no revival and unchanged opponents.
- The full-card fixture now matches the baseline, including form stats and dead-unit exclusion.
- This follows the current simplified JS resolution. The card's original countdown wording does not establish an implemented countdown mechanic, and no new timing or avatar-shield rule is inferred.

Final verification: all 11 focused suites passed (312 checks/cases) and all 17 parity fixtures matched. No new native UI or original-video evidence was produced.
