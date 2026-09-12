async page => {
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.reload();
  await page.locator('#formation-start-button').click();await page.locator('#formation-start-button').click();
  await page.locator('#menu-button').click();await page.locator('#session-button').click();
  await page.locator('#session-load-button').click();
  await page.waitForFunction(()=>document.querySelector('#battle-stage').dataset.turn==='player');
  const before=await page.evaluate(async()=>{const build=document.querySelector('meta[name=build]').content;const core=await import(`./game-core.js?v=${build}`);const state=core.deserializeGame(JSON.parse(localStorage.getItem('nexus-front:session-slot-1')).game);return {turn:state.turnCounter,winner:state.winner,decks:state.players.map(p=>p.deck.length),cores:state.players.map(p=>p.avatarHp)};});
  await page.locator('#end-turn-button').click();
  await page.locator('#result-dialog').waitFor({state:'visible'});
  const result=await page.locator('#result-dialog').innerText();
  await page.locator('#inspect-button').click();
  await page.locator('#menu-button').click();
  if(await page.locator('#session-button').isDisabled())throw Error('Terminal transition still leaves session locked');
  await page.screenshot({path:'output/playwright/redesign-after-terminal-unlock.png',fullPage:true});
  await page.locator('#session-button').click();
  await page.locator('#session-save-button').click();
  if(await page.locator('#session-status').getAttribute('data-state')==='error')throw Error(await page.locator('#session-status').innerText());
  await page.locator('#session-close-button').click();
  if(errors.length)throw Error(JSON.stringify(errors));
  return {before,result,session:'enabled',terminalSave:'passed',errors};
}
