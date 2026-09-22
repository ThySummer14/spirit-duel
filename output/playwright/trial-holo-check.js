async page => {
 await page.emulateMedia({reducedMotion:"no-preference"});
 await page.goto("http://localhost:4173");
 const result=await page.evaluate(async()=>{
   const {initPreviewHolo,holoLayers,getHoloDiagnostics}=await import('./card-holo.js');
   const host=document.createElement('aside');host.style.cssText='position:fixed;left:30px;top:30px;z-index:99999;width:240px;height:360px';
   host.innerHTML='<div class="hand-preview-card is-holo is-holo-epic" style="width:240px;height:360px"><span class="card-art"><img src="assets/ember.svg" alt=""></span><strong class="card-name">闪卡分层验证</strong><span class="card-text">文字保持稳定，图片响应指针</span></div>';
   const card=host.firstElementChild;card.append(...holoLayers(true));document.body.append(host);initPreviewHolo(host,host);
   window.trialHoloHost=host;window.trialHoloDiagnostics=getHoloDiagnostics;
   return {fixture:true};
 });
 await page.locator('#result-dialog').evaluate(d=>d.close());
 await page.mouse.move(220,90);await page.waitForTimeout(1800);
 const normal=await page.evaluate(()=>({depth:window.trialHoloHost.firstElementChild.style.getPropertyValue('--holo-depth-x'),...window.trialHoloDiagnostics()}));
 if(!normal.depth || normal.framePending)throw Error('parallax missing or idle loop persists '+JSON.stringify(normal));
 await page.screenshot({path:'output/playwright/trial-holo.png'});
 await page.emulateMedia({reducedMotion:'reduce'});
 await page.waitForFunction(()=>window.trialHoloDiagnostics().reducedMotion && window.trialHoloDiagnostics().activeCards === 0 && getComputedStyle(window.trialHoloHost.querySelector("img")).transform === "none");
 const reduced=await page.evaluate(()=>({transform:getComputedStyle(window.trialHoloHost.querySelector('img')).transform,...window.trialHoloDiagnostics()}));
 if(reduced.transform!=='none'||reduced.framePending)throw Error('reduced motion failed '+JSON.stringify(reduced));
 await page.evaluate(()=>window.trialHoloHost.remove());await page.emulateMedia({reducedMotion:'no-preference'});
 return {result,normal,reduced};
}
