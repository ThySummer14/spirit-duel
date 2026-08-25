"""UI fuzz：随机合法操作连续玩多局，检测 AI 回合停滞（软锁）现场。"""
import random, time, json
from playwright.sync_api import sync_playwright

random.seed(777)

def player_act(page):
    """玩家回合随机做一个合法动作，返回动作描述"""
    acts = []
    # 升勾：升级阶段点击一名可升角色（level-button 或直接点角色卡）
    lvl = page.evaluate("""() => { const b=document.querySelector('#level-button'); return b && !b.disabled; }""")
    # 随机出手牌
    card = page.evaluate("""() => {
      const cs=[...document.querySelectorAll('#player-hand .hand-card[data-block="ready"]')];
      if (!cs.length) return null;
      const c = cs[Math.floor(Math.random()*cs.length)];
      return {name: c.querySelector('.card-name')?.textContent};
    }""")
    # 随机出击
    atk = page.evaluate("""() => {
      const a=[...document.querySelectorAll('button')].find(b=>/出击/.test(b.textContent)&&!b.disabled);
      return !!a;
    }""")
    roll = random.random()
    if card and roll < 0.55:
        page.evaluate("""() => {
          const cs=[...document.querySelectorAll('#player-hand .hand-card[data-block="ready"]')];
          cs[Math.floor(Math.random()*cs.length)].click();
        }""")
        page.wait_for_timeout(350)
        # 目标选择：点第一个可点目标，否则取消
        page.evaluate("""() => {
          const t=document.querySelector('.battle-strip.enemy-battle .unit-card:not([disabled]), #player-units .unit-card:not([disabled]), .realm-chip:not([disabled])');
          if (t) { t.click(); return; }
          const c=[...document.querySelectorAll('button')].find(b=>/取消/.test(b.textContent));
          c?.click();
        }""")
        page.wait_for_timeout(400)
        return f"card:{card['name']}"
    if atk and roll < 0.8:
        page.evaluate("""() => { const a=[...document.querySelectorAll('button')].find(b=>/出击/.test(b.textContent)&&!b.disabled); a?.click(); }""")
        page.wait_for_timeout(300)
        page.evaluate("""() => {
          const t=document.querySelector('.battle-strip.enemy-battle .unit-card:not([disabled])');
          t?.click();
        }""")
        page.wait_for_timeout(400)
        return "attack"
    # 结束回合
    ok = page.evaluate("""() => { const e=document.querySelector('#end-turn-button'); if (e && !e.disabled) { e.click(); return true; } return false; }""")
    return "end-turn" if ok else "stuck-player"

with sync_playwright() as p:
    b = p.chromium.launch()
    for game_id in range(4):
        page = b.new_page(viewport={"width":1600,"height":950})
        errs = []
        page.on("pageerror", lambda e: errs.append("PAGEERROR: "+str(e)))
        page.on("console", lambda m: errs.append("CONSOLE: "+m.text) if m.type=="error" else None)
        page.goto("http://localhost:4173/index.html"); page.wait_for_timeout(400)
        page.get_by_role("button", name="下一步 构筑卡组 →").click(); page.wait_for_timeout(250)
        page.get_by_role("button", name="锁定牌组 进入对局 →").click()
        page.wait_for_selector("#player-hand .hand-card"); page.wait_for_timeout(500)
        page.evaluate("""() => { const d=[...document.querySelectorAll('button')].find(b=>b.textContent.includes('完成调度')); d?.click(); }""")
        page.wait_for_timeout(400)
        stall = None
        last_progress = time.time()
        last_sig = ""
        steps = 0
        while steps < 400:
            steps += 1
            owner = page.evaluate("() => document.querySelector('#turn-owner')?.textContent || ''")
            turn = page.evaluate("() => document.querySelector('#round-number, .turn-pill b, #turn-number')?.textContent || document.body.textContent.match(/第\\s*(\\d+)\\s*回合/)?.[1] || ''")
            sig = f"{owner}|{turn}"
            if sig != last_sig:
                last_sig = sig; last_progress = time.time()
            now = time.time()
            if "失序体" in owner and now - last_progress > 22:
                stall = {"owner": owner, "turn": turn, "steps": steps, "errs": errs[:10]}
                break
            if "巡界者" in owner:
                act = player_act(page)
                if act == "stuck-player":
                    page.wait_for_timeout(800)
                page.wait_for_timeout(250)
            else:
                page.wait_for_timeout(600)
            # 对局结束检测
            over = page.evaluate("""() => !!document.querySelector('#result-dialog[open], dialog.result[open]') || /获胜|败北/.test(document.body.textContent)""")
            if over:
                break
        if stall:
            print(f"GAME {game_id}: STALL -> {stall}")
            page.screenshot(path=f"output/stall-game{game_id}.png")
            # 抓战报文本尾部
            log = page.evaluate("""() => (document.querySelector('#battle-log, .battle-log')?.textContent || '').slice(-1500)""")
            print("LOG TAIL:", log[-600:])
        else:
            print(f"GAME {game_id}: finished/clean, steps={steps}, errs={errs[:3] or 'none'}")
        page.close()
    b.close()
