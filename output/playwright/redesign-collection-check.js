async page => {
  const errors=[]; page.on('pageerror',e=>errors.push(e.message)); page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.goto('http://localhost:4173');
  await page.locator('#collection-button').click();
  await page.locator('#codex-roster button[data-unit-id="ember"]').click();
  await page.locator('#codex-search').fill('炽步');
  if(await page.locator('.codex-tile').count()!==1) throw Error('search failed');
  const before=Number(await page.locator('#collection-balance').innerText());
  const owned=Number(await page.locator('.codex-tile').getAttribute('data-owned'));
  if(owned<2 && before>=40) {
    await page.locator('.tile-craft').click();
    if(Number(await page.locator('.codex-tile').getAttribute('data-owned'))!==owned+1)throw Error('craft did not grant card');
    if(Number(await page.locator('#collection-balance').innerText())!==before-40)throw Error('craft price mismatch');
    await page.reload(); await page.locator('#collection-button').click(); await page.locator('#codex-search').fill('炽步');
    if(Number(await page.locator('.codex-tile').getAttribute('data-owned'))!==owned+1)throw Error('craft did not persist');
  } else throw Error('test profile needs an uncollected coal-step and 40 currency');
  await page.locator('#codex-search').fill('不存在的牌');
  if(!await page.locator('.codex-empty').isVisible())throw Error('empty state missing');
  await page.locator('#codex-search').fill('');
  await page.locator('#codex-type').selectOption('ssr');
  for(const id of ['ember','basalt','lumen','rime','storm','ink','frostblade','kongo']) {
    await page.locator(`#codex-roster button[data-unit-id="${id}"]`).click();
    if(await page.locator('.codex-tile').count()!==2)throw Error(id+' SSR count');
    if(!await page.locator('.codex-identity').innerText())throw Error('missing passive');
  }
  await page.locator('#codex-roster button[data-unit-id="ember"]').click();
  await page.locator('#codex-type').selectOption('');
  await page.locator('#codex-ownership').selectOption('owned');
  if(await page.locator('.codex-tile[data-owned="0"]').count())throw Error('owned filter failed');
  await page.locator('#codex-ownership').selectOption('');
  const packBefore=Number(await page.locator('#collection-packs').innerText());
  await page.locator('#pack-open-button').click();
  await page.locator('#pack-reveal-close').waitFor({state:'visible'});
  if(await page.locator('#pack-reveal-cards').locator(':scope > *').count()!==5)throw Error('pack did not reveal 5 cards');
  await page.locator('#pack-reveal-close').click();
  if(Number(await page.locator('#collection-packs').innerText())!==packBefore+1)throw Error('pack counter mismatch');
  const results=[];
  for(const [name,width,height] of [['desktop',1440,1000],['tablet',820,1180],['mobile',390,844]]) {
    await page.setViewportSize({width,height});
    await page.locator('#codex-type').selectOption(name==='desktop'?'':'form');
    await page.evaluate(()=>window.scrollTo(0,0));
    await page.waitForTimeout(500);
    const geometry=await page.evaluate(()=>{
      const issues=[];
      if(document.documentElement.scrollWidth>innerWidth)issues.push('horizontal overflow');
      for(const tile of document.querySelectorAll('.codex-tile')) {
        const a=tile.querySelector('.tile-effect').getBoundingClientRect(),b=tile.querySelector('.tile-craft').getBoundingClientRect();
        if(a.bottom>b.top)issues.push('effect overlaps craft');
      }
      return {width:innerWidth,cards:document.querySelectorAll('.codex-tile').length,issues};
    });
    if(geometry.issues.length)throw Error(JSON.stringify(geometry));
    await page.screenshot({path:`output/playwright/redesign-collection-${name}.png`,fullPage:true});results.push(geometry);
  }
  if(errors.length)throw Error(JSON.stringify(errors));
  return {results,craft:'persisted',pack:'five cards',filters:'passed',errors};
}
