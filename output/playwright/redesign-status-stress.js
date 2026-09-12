async page => {
  if (await page.locator('#result-dialog').evaluate(e=>e.open)) await page.locator('#inspect-button').click();
  const reports=[];
  for(const [width,height] of [[1440,1000],[820,1180],[390,844]]) {
    await page.setViewportSize({width,height});
    const result=await page.evaluate(async()=>{
      const build=document.querySelector('meta[name=build]').content;
      const [{createGame,getCardDefinition,getCardsForUnit},{createBattleRenderer}]=await Promise.all([import(`./game-core.js?v=${build}`),import(`./battle-render.js?v=${build}`)]);
      const state=createGame({seed:70});
      const fixture=document.createElement('div'); fixture.id='status-stress-fixture';fixture.style.cssText='position:absolute;inset:0 0 auto;z-index:10000;background:#0d1220;min-height:100vh';
      const title=document.createElement('p');title.textContent='多状态排版验收 · 独立测试快照';title.style.cssText='padding:16px;color:white';
      const stage=document.createElement('section');stage.className='battle-stage';
      const field=document.createElement('div');field.className='battlefield';
      const board=document.createElement('div');board.className='board-column';
      const renderer=createBattleRenderer({nodes:{},displayedGame:state,replaySession:true,selectionTarget:()=>null,currentSelectedCard:()=>null,frontUidOf:p=>p.frontUnitId,unitByUid:(p,id)=>p.units.find(u=>u.uid===id),visualFeedback:{unitImpacts:new Map()},makeStatus:(text,cls,title)=>{const e=document.createElement('span');e.textContent=text;e.className=cls;e.title=title;return e;}});
      for(const owner of [1,0]) {
        const row=document.createElement('div');row.className='unit-row'; row.setAttribute('aria-label',owner?'敌方准备区':'己方准备区');
        const front=document.createElement('div');front.className='battle-strip';
        state.players[owner].units.forEach((unit,index)=>{
          unit.level=3;unit.shield=12;unit.frozen=2;unit.brittle=3;unit.unyielding=true;unit.awakened=true;
          const form=getCardsForUnit(unit.id).find(c=>c.effect==='form');
          unit.form={cardId:form.id,name:form.name,attackBonus:form.value.attack,hpBonus:form.value.hp};
          if(index===0)state.players[owner].frontUnitId=unit.uid;
          (index===0?front:row).append(renderer.renderUnit(unit,owner,index===0?'front':'reserve'));
        });
        if(owner===1)board.append(row,front);else board.append(front,row);
        if(owner===1){const command=document.createElement('section');command.className='command-line';command.textContent='我的回合 · 升勾后可出牌或出击';board.append(command);}
      }
      field.append(board);stage.append(field);fixture.append(title,stage);document.body.append(fixture);
      const issues=[];
      const cards=[...fixture.querySelectorAll('.unit-card')];
      for(const card of cards){
        const face=card.querySelector('.unit-face').getBoundingClientRect(),status=card.querySelector('.unit-statuses').getBoundingClientRect(),bounds=card.getBoundingClientRect();
        if(status.top<face.bottom-1||status.bottom>bounds.bottom+1)issues.push('status escapes card or overlaps portrait');
        for(const badge of card.querySelectorAll('.unit-statuses span')){const b=badge.getBoundingClientRect();if(b.right>bounds.right+1||b.left<bounds.left-1)issues.push('badge clipped');}
      }
      const boxes=[...cards,fixture.querySelector('.command-line')].map(e=>e.getBoundingClientRect());
      for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++){const a=boxes[i],b=boxes[j];if(Math.min(a.right,b.right)-Math.max(a.left,b.left)>2&&Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top)>2)issues.push('unit or command overlap');}
      return {width:innerWidth,cards:cards.length,issues};
    });
    try {
      if(result.issues.length)throw Error(JSON.stringify(result));
      await page.locator('#status-stress-fixture').screenshot({path:`output/playwright/redesign-status-${width}.png`});reports.push(result);
    } finally {await page.locator('#status-stress-fixture').evaluate(e=>e.remove());}
  }
  return reports;
}
