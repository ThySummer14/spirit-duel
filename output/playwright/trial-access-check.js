async page => {
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.reload();
 const before=await page.evaluate(()=>localStorage.getItem('nexus-front:collection'));
 await page.locator('#trial-cards-toggle').check();
 await page.reload();
 if(!await page.locator('#trial-cards-toggle').isChecked())throw Error('preference not saved');
 await page.locator('#formation-start-button').click();
 const cards=page.locator('.pool-card');
 const chosen=cards.filter({has:page.locator('button[aria-label^="减少"]:not([disabled])')}).first();
 await chosen.locator('button[aria-label^="减少"]').click();
 const ssr=page.locator('.pool-card[data-rarity="ssr"]').first();
 console.log('SSR matches',await page.locator('.pool-card[data-rarity="ssr"]').count());
 await ssr.locator('button[aria-label^="增加"]').click();
 if(await page.locator('#formation-start-button').isDisabled())throw Error('trial deck blocked');
 await page.locator('#trial-cards-toggle').uncheck();
 if(!await page.locator('#formation-start-button').isDisabled())throw Error('unowned deck allowed');
 if(!(await page.locator('#formation-error').innerText()).includes('收藏不足'))throw Error('missing ownership explanation');
 await page.locator('#trial-cards-toggle').check();
 for(const [name,width,height] of [['desktop',1440,1000],['tablet',820,1180],['mobile',390,844]]){
 await page.setViewportSize({width,height});
 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error(name+' overflow');
 await page.screenshot({path:`output/playwright/trial-${name}.png`,fullPage:true});
 }
 const after=await page.evaluate(()=>localStorage.getItem('nexus-front:collection'));
 if(before!==after)throw Error('trial mutated collection');
 await page.setViewportSize({width:1440,height:1000});
 await page.locator('#formation-start-button').click();
 if(!await page.locator('#battle-stage').isVisible())throw Error('trial did not start');
 console.log(JSON.stringify({trialDeckStarted:true,collectionUnchanged:true,errors}));
 if(errors.length)throw Error(errors.join('\n'));
}
