# 双实现对拍（浏览器 JS ↔ Godot）

目的：用同一确定性样本验证 `game-core.js` 与 `godot/scripts/game_state.gd` 在可观察状态上一致，作为纵向切片的迁移门槛。

## 运行

```sh
# 默认样本
./scripts/godot-parity.sh

# 指定样本与输出目录
./scripts/godot-parity.sh scripts/parity/sample-keywords.json scripts/parity/out
```

输出：`*-js.json` / `*-godot.json` / `*-report.json`。`PARITY_MATCH` 表示最终快照与逐步快照一致。

## 样本

| 文件 | 覆盖 |
| --- | --- |
| `sample-origin.json` | 升勾→出牌→出击→形态→结束回合 核心环（原创四人） |
| `sample-keywords.json` | 贯通 / 连击 / 先攻 / 远程 / 暴击 战斗牌 |
| `sample-response.json` | 响应窗口 pass 优先权（双方放弃后原效果结算） |
| `sample-response-play.json` | 响应打出嵌套 LIFO：见切连锁 → 原 assault 再开窗 |
| `sample-divination.json` | 占卜展示顶 3 张、选择置顶、恢复结算栈 |
| `sample-fortune.json` | 鼓舞池累积/出击消耗 + 运势骰 fortune-success 追伤 |

命令中立格式（两边各自解析）：

```json
{ "type": "play-card", "player": 0, "card": "flash-thrust" }
{ "type": "attack", "player": 0, "unit": 0 }
{ "type": "level-up", "player": 0, "unit": 1 }
{ "type": "end-turn", "player": 0 },
{ "type": "pass-response", "player": 1 },
{ "type": "divination-choice", "player": 0, "card": "flash-thrust" }
```

可选注入（对拍专用）：`injectHand` 固定关键牌进手牌，`injectEnergy` 给指定方鬼火（响应牌需付费时用）。

## 快照字段

`turn / current / winner / phase` + 每方 `avatarHp, energy, handCount, deckCount, attackUsed, levelUpUsed, frontUnitId` + 每单位 `hp, maxHp, attack, shield, knockout, frozen, level, awakened, formId, front`。

## 已对齐

- 开局发牌、LCG RNG（`rng = rng*1664525+1013904223`）、Fisher–Yates 洗牌
- 首位角色免费 1 勾、齐头并进升勾、回合开始抽 1、战斗区回退时机
- 出入前线、空前线打核心、气绝 +1 核心、不屈、晶裂
- 贯通溢出 / 连击追伤 / 先攻免反击 / 远程不进前线不反击 / 暴击翻倍
- 形态数值与 formHooks（被动注册表同名 effect）
- **结束回合不强制升勾**（升勾只卡出牌/出击），与 JS 一致

## 响应窗口（已对齐最小链）

- 可响应效果结算前开窗；优先权先给效果控制者对手。
- `pass-response`：第一次放弃只转移优先权，双方连续放弃才结算栈顶。
- 响应牌压入 LIFO 栈（深度 ≤8）；打出后原帧 `responseOffered` 重开，可再次响应。
- 无任何合法响应时自动跳过窗口。响应牌需付鬼火（与 JS `getCardPlayability` 一致）。
- 目标气绝后仍可反击（先攻除外），与 JS `resolveCombat` 一致。

## 明确降级（Godot 侧）

| 能力 | 现状 |
| --- | --- |
| 经典包复杂被动 | 数据能载入；文本简化效果以注册表 hook 为准 |
| 其余关键词资源链 | 烹饪/入夜/蓄力完整树等仍简化；未知 effect 记「效果暂未完全结算」 |

已对齐资源链：**占卜**（pendingChoice + 置顶）、**运势**（骰子 + fortune-success）、**鼓舞**（池累积/出击消耗）、**充能**（回合成长 + chargeCost）。
