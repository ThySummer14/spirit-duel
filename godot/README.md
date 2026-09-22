# 灵枢战线 · Godot 纵向切片

`godot/` 是《灵枢战线》可玩纵向切片：4v4 编成、升勾→出牌→出击/交战→气绝→复归→核心扣血→胜负、确定性命令日志、简易贪心 AI。规则为纯 GDScript（`scripts/game_state.gd`），与浏览器版 `game-core.js` 数据同源（`content/content.json`），**不是**第二套完整规则实现。

## 运行

```sh
# 重新导出内容（同时写 probe 与 godot/content/content.json）
node scripts/export-godot-content.mjs

# 打开编辑器 / 运行游戏
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot

# 无头验收（内容契约 + 模拟对局 + 启动冒烟）
./scripts/godot-verify.sh
```

Godot 4.8.dev5（本机路径见上）。主场景 `scenes/main_menu.tscn`。

## 界面

| 界面 | 说明 |
| --- | --- |
| 主菜单 | 灵枢战线 · 快速对战 / 编成 / 设置 / 退出 |
| 编成 | 从 content 选 4 名角色，看被动与卡牌稀有度色 |
| 对战 | 五行：敌方准备/敌方前线/指令条/己方前线/己方准备；左侧核心 HP；右侧战报；底部手牌滚动与悬停全文 |
| 结果 | 朱印式胜负章 |

键盘：`Enter` 结束回合 · `1-9` 出手牌 · `Tab` 循环查看己方角色。

## 规则要点（与 JS 对齐的切片）

- 双方 4 角色，核心 30，鬼火 2，手牌上限 12，气绝 2 回合复归，勾玉 0–3，齐头并进升勾
- 初始最左角色免费 1 勾；0 勾不可选中/出击/用其牌
- 出击进入前线；敌方前线空则打核心；反击（眩晕则不反击）；击破额外对核心 1 伤
- 效果：assault / damage / heal / heal-avatar / shield / fortify / draw / revive / freeze / apply-brittle / apply-keyword / grant-unyielding / damage-enemy-front / burn-all / form / realm / awaken 等
- 未知 action：不结算并记「效果暂未完全结算」，内容仍可加载
- 形态：应用攻/血加成并回满血，`formAbility` 作提醒文案；少数 formHooks 以简化触发模拟
- 种子 RNG（xorshift32）+ `command_log`，可供回放

## 目录

```
godot/
  project.godot
  content/content.json
  assets/*.svg          # 原创占位（非官方立绘）
  scenes/main_menu.tscn
  scripts/content_loader.gd
  scripts/game_state.gd
  scripts/game_ai.gd
  scripts/verify.gd
  scripts/ui/*.gd
scripts/export-godot-content.mjs
scripts/godot-verify.sh
```

## 简化说明

- 响应窗口 / 占卜选牌 / 烹饪集齐 / 夜幕预约 / 蓄力树：多为 no-op 日志或单步近似
- 关键词 combat（连击/先攻/贯通/远程）只做基础出击；fusion/encourage 折算为 +攻/+血
- AI 为贪心打分，不搜索
- 美术为 `assets/*.svg` 与色块，**不使用官方 NetEase 立绘**


## 游玩舒适度（2026-09-22）

- 编成：资料包筛选（全部/灵枢原创/经典包/不夜之火）+ 名称搜索；三列卡片点选即选用；卡表隐藏衍生牌并显示原案。
- 战局：升勾阶段金色高亮可升角色并列出名字；手牌底部显示不可用原因（先升勾/对手回合/费用等）；检视浮层含被动/觉醒全文与破甲/充能/气绝倒计时。
- 快捷键：`P` 放弃响应，`Esc` 取消选目标，`Enter` 结束回合，`1-9` 出牌，`Tab` 切换角色。
