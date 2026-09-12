import assert from 'node:assert/strict';
import * as core from '../../game-core.js';
import { chooseAiCommand } from '../../game-ai.js';
const ids = core.UNIT_DEFINITIONS.map(u => u.id);
const deck = unitIds => ({unitIds, cardIds: unitIds.flatMap(id => {
  const cards = core.getCardsForUnit(id);
  const chosen = cards.filter(c => c.rarity === 'ssr').flatMap(c => [c.id,c.id]);
  chosen.push(cards.find(c=>c.type==='awakening').id, cards.find(c=>c.type==='form').id);
  const opener = cards.find(c=>c.level===1 && c.type==='combat') ?? cards.find(c=>c.level===1);
  return [...chosen,opener.id,opener.id];
})});
const played = new Set();
let completed = 0;
for(let seed=1;seed<=16;seed++) {
  const order=ids.slice(seed%8).concat(ids.slice(0,seed%8));
  let state=core.createGame({seed:seed*1349,playerDeckDefinition:deck(order.slice(0,4)),enemyDeckDefinition:deck(order.slice(4))});
  for(let step=0;step<600 && state.winner===null;step++) {
    const owner=state.pendingChoice?.playerIndex ?? state.responseWindow?.playerIndex ?? state.currentPlayer;
    const cmd=chooseAiCommand(state,owner,{aggressive:state.turnCounter>40});
    if(cmd.type==='play-card') played.add(state.players[owner].hand.find(c=>c.instanceId===cmd.instanceId).definitionId);
    const result=cmd.type==='play-card'?core.playCard(state,owner,cmd.instanceId,cmd.targetId):cmd.type==='attack'?core.basicAttack(state,owner,cmd.unitId,cmd.targetId):cmd.type==='level-up'?core.levelUpUnit(state,owner,cmd.unitId):cmd.type==='pass-response'?core.passResponse(state,owner):cmd.type==='divination-choice'?core.resolveDivinationChoice(state,owner,cmd.instanceId):core.endTurn(state,owner);
    assert.equal(result.error,null,`seed ${seed}, ${JSON.stringify(cmd)}`);
    state=core.deserializeGame(core.serializeGame(result.state));
  }
  assert.notEqual(state.winner,null,`seed ${seed} did not finish`); completed++;
}
console.log(JSON.stringify({completed,ssrPlayed:[...played].filter(id=>id.startsWith('ssr-')).sort(),roundTrip:'every action'},null,2));
