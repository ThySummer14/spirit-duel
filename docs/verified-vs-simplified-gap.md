# 已核对原版规则 vs 实现差距表（Godot 验收轮）

> **范围：** `godot/content/verified_rules.json` 中 **8 式神 + 68 张专属卡**（萤草另含 3 条衍生 token 条目）。  
> **依据：** 核对库来源索引、`research-notes/09`–`16`、`阴阳师百闻牌-机制全景.md`、`AGENTS.md`、录像 `video-200`（叶隐/钢风片段）。  
> **本轮范围（Hal 纠正）：** 仅 **Godot** 可玩竖切按核对规则验收；**Web/JS 本轮不做**（分支上历史凤凰火 Web 改动保留，不再扩展）。

## 验收结论（2026-10-10）

| 式神 | Godot 规则层 | 规则专测 | UI/目标专测 | 本轮 Godot |
| --- | --- | --- | --- | --- |
| 钢风 `datiangou-gangfeng` | `verified_card_rules` + 起源战斗倒计时 | `verify_steel_wind` 115 ✓ | `verify_steel_wind_ui` 44 ✓ | **已对齐核对库** |
| 妖琴师 `yaoginshi` | `countdown_rules.gd` | `verify_yaoginshi` 126 ✓ | `verify_yaoginshi_ui` 30 ✓ | **已对齐核对库** |
| 大天狗 `datiangou` | `spell_replay_rules.gd` | `verify_datiangou` 115 ✓ | `verify_datiangou_ui` 38 ✓ | **已对齐核对库** |
| 一目连 `yimulian` | `form_countdown_rules.gd` | `verify_yimulian` 128 ✓ | `verify_yimulian_ui` 52 ✓ | **已对齐核对库** |
| 鸩 `zhen` | `armor_break_rules.gd` | `verify_zhen` 122 ✓ | `verify_zhen_ui` 48 ✓ | **已对齐核对库** |
| 凤凰火 `fenghuanghuo` | `phoenix_rules.gd` | `verify_phoenix` 122 ✓ | `verify_phoenix_ui` 57 ✓ | **已对齐核对库** |
| 桃花妖 `taohuayao` | `peach_rules.gd` | `verify_peach` 114 ✓ | `verify_peach_ui` 48 ✓ | **已对齐核对库** |
| 萤草 `yingcao` | `firefly_rules.gd` | `verify_firefly` 126 ✓ | `verify_firefly_ui` 54 ✓ | **已对齐核对库** |
| 交叉 | 多式神同局 | `verify_parallel_rules` 41 ✓ | — | **已对齐核对库** |

**复现命令（需 Godot 4.4+ headless，建议先 `export` + `--import`）：**

```bash
export GODOT_BIN=/path/to/Godot_v4.4.1-stable_linux.x86_64
./scripts/godot-verified-eight.sh
```

数据：`ContentLoader` 载入 `content.json` 后 **merge** `verified_rules.json`（与 `research-notes` 一致，不删历史「简化」导出文案）。

### Web/JS（本轮不做）

| 项目 | 状态 |
| --- | --- |
| `game-content*.js` 可玩化映射 | 未改；全库仍大量简化标记 |
| `npm run audit:rules` | 仍失败（`known-approximation` / `unreviewed` 占绝大多数） |
| 分支历史 | 曾接入凤凰火 Web overlay/专规；**本轮不再扩展 Web** |

---

## `verificationPending` 汇总（未删、未猜）

下列条目在核对库中**刻意保留**，表示缺指定录像/版本实机，Godot 采用牌文+公告+专测锁定的**保守实现**；专测中有断言「pending 仍存在」以防误标完成。

| 归属 | 卡/单位 | 待核实内容 | Godot 当前取舍 |
| --- | --- | --- | --- |
| 鸩 | `zhen` 觉醒 | 历史次数是否计入**当前**触发 | 按已完成次数增强；专测覆盖基础 2 破甲与成长 |
| 凤凰火 | `fenghuanghuo` | 魔音反制后「使用法术」帧；气绝前后焚羽快照 | 独立 `phoenix-spell-used` 帧；反制清本体不清已排队投射 |
| 桃花妖 | `taohuayao` | 零实际恢复是否成长；气绝后群复活成长时点 | 仅实际恢复触发；群复活后统一成长（专测） |
| 一目连 | `c11807` 风符·龙 | 两龙不共享次数、同波目标不重复 | 按 2020 细则转载实现；缺原作者视频交叉 |
| 鸩 | `c11604` 毒蚀 | 与屏障、碧羽散华同时存在时的优先级 | 专测有屏障/转换正反例；复杂叠层待录像 |
| 鸩 | `c11605` 觉醒 | 减计时与替换先后、历史是否含当次 | 牌文顺序+已完成次数；专测保留 pending 标记 |
| 鸩 | `c11607` 毒之华 | 奇数生命向下取整 | 向下取整；专测保留 pending |
| 凤凰火 | `c12401` 凤鸣 | 公告 3→2 与旧快照冲突 | **按 2020-02-27 公告取 2** |
| 凤凰火 | `c12405` 炎舞 | 屏障+贯通+破甲精细分配 | 贯通溢出已实现；多层分配待录像 |
| 凤凰火 | `c12406` 出云 | 投射/运势/反制/气绝先后 | 使用事件→投射→运势；专测保留 pending |
| 桃花妖 | `c10801` 等 | 零恢复成长 | 不触发成长；`verify_peach` 断言 pending 非空 |
| 桃花妖 | `c10809` 群复活 | 气绝时自身是否也得成长 | 先复活再统一成长；pending 保留 |
| 萤草 | `c10708` 虹彩等 | 闪烁层叠、多闪烁响应串接 | 力量归零+响应原战斗；多闪烁共用首张合法响应 |

**未写入 pending 的 8 式神：** 钢风、妖琴师、大天狗、一目连（除上表 c11807）、萤草（除上表）在核对库单位级无 `verificationPending`；边界靠 `research-notes` + 专测覆盖。

---

## 分式神要点（Godot = 核对实现；Web = 本轮不做）

### 1. 钢风·大天狗 `datiangou-gangfeng`

- **证据：** `research-notes/09-steel-wind-video-rules.md`，`video-200`，`balance-2023-11-23`，起源替换 `origin-design-2023`。
- **Godot：** 战斗牌起源倒计时（气绝不移除）、叶隐移动/倒计时或抽牌、形态护甲联动倒计时、吾即正义随机法术等 — `verify_steel_wind`。
- **Web：** 本轮不做（仍为旧 assault/加甲映射）。

### 2. 妖琴师 `yaoginshi`

- **证据：** `research-notes/10-yaoginshi-countdown-rules.md`，`balance-2023-10-26`。
- **Godot：** 四歌倒计时、入阵歌 5 点随机分配、觉醒大合奏记录实际种类、魔音与自动复读边界 — `verify_yaoginshi`。
- **Web：** 本轮不做。

### 3. 大天狗 `datiangou`

- **证据：** `research-notes/11-datiangou-spell-replay.md`。
- **Godot：** 法术复读倒计时、吾即正义等级约束随机法术、暴风等 — `verify_datiangou`。
- **Web：** 本轮不做。

### 4. 一目连 `yimulian`

- **证据：** `research-notes/12-yimulian-form-lifecycle.md`。
- **Godot：** 形态进场/消灭触发、风符倒计时、罡风/鼓舞/瞬响应 — `verify_yimulian`；`c11807` 见 pending 表。
- **Web：** 本轮不做。

### 5. 鸩 `zhen`

- **证据：** `research-notes/13-zhen-armor-break.md`，`balance-2020-01-20`。
- **Godot：** 牌手/式神破甲、毒伤转破甲、战斗双向转化、碧羽散华等 — `verify_zhen`；觉醒/毒蚀/毒之华见 pending 表。
- **Web：** 本轮不做。

### 6. 凤凰火 `fenghuanghuo`

- **证据：** `research-notes/14-phoenix-rules.md`。
- **Godot：** 完整 8 牌 + 投射链 — `verify_phoenix`；凤鸣/炎舞/出云见 pending 表。
- **Web：** 本轮不做（分支遗留早期 Web 接入，不扩展）。

### 7. 桃花妖 `taohuayao`

- **证据：** `research-notes/15-peach-rules.md`。
- **Godot：** 治疗/复活成长、检索、形态、迅捷、气绝可用群疗 — `verify_peach`；见 pending 表。
- **Web：** 本轮不做。

### 8. 萤草 `yingcao`

- **证据：** `research-notes/16-firefly-rules.md`，`firefly-may2020-balance`。
- **Godot：** 形态瞬发抽牌、鼓舞、点点手牌增强、虹彩生成 — `verify_firefly`；闪烁边界见 pending 表。
- **Web：** 本轮不做。

---

## `npm run audit:rules`（Web 卡库扫描）

仍 **失败**（预期）：扫描的是 `game-content.js` 全库导出，非 Godot 合并后定义。典型摘要：

- 式神：`known-approximation` ~154，`unreviewed` ~88，`source-backed-native` 少量  
- 卡牌：`known-approximation` ~1071，`unreviewed` ~975  

**不等于** Godot 八式神未还原；仅表示 **Web 全库** 尚未逐条核对。

---

## 变更日志（本分支）

| 轮次 | 内容 |
| --- | --- |
| 前序 | 差距表初稿；Web 凤凰火试验性接入 |
| **本轮** | Godot 八式神专测全绿；`scripts/godot-verified-eight.sh`；`verified_card_rules` / 专测脚本 `ContentLoader` preload；本文档改为 Godot 验收口径 |
