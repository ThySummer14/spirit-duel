# 鲤鱼精、寻香行批次验收（2026-10-24）

本批在Godot接入两位角色基础/觉醒与16张主体牌。真实手牌加护/蚀印、随机候选与双效果、同类排除与异类抵消、持续成长/气绝倒计时、投射、眩晕、候选弃牌、幻境压制及缚梦明香合法手牌限制均有规则结算、玩家选择与AI入口。规则及版本选择详见[研究76](../../research-notes/76-koi-fragrance-rules.md)。旧HTML/JS自有执行器未在本批实现这些专规。

| 检查 | 本次结果与证据 |
| --- | --- |
| 基础来源 | 18个官方定义与本地快照逐字段一致，`official-source-evidence.json`；两组基础/8牌卡面总览`282-card-sheet.jpg`、`288-card-sheet.jpg`。 |
| 指定录像抽查 | 七个明确时间点的画面与总览在`video-samples/`、`video-overview.jpg`；未据此宣称完成逐牌核验或排除整段存在相关画面。 |
| 关键字来源 | 官方加护/蚀印介绍原图`official-keywords-1.jpg`，局部阅览图`official-keywords-detail.jpg`与`official-keywords-bottom.jpg`；随机效果池补充转录与机制记录地址存于研究及来源清单。 |
| 纯规则专项 | Godot 4.6.3，277项，0失败，`rules.log`。覆盖16牌实际使用、正反条件、连续选择、实际候选弃牌、成长寿命、递归合法性纯查询、伤害/战斗/关键词/耐久与使用后效果。 |
| 原生交互专项 | Godot 4.8.dev5，297项（含上述277项），0失败，`native.log`；1280×800与1600×740真实鼠标交互，6张截图在`screenshots/`，逐图目检。 |
| AI | 实际合法使用16张主体牌并完成相关选择，包含在专项中；未使用载入成功或AI对局跑通替代牌效验收。 |
| 相关回归 | 17组通过，`regressions/results.json`及各日志。覆盖须佐之男、书翁/觉选择、白泽、缘结神/食梦貘、抽牌、瞬发、战斗、成长、资源、回合顺序、复活、运势、治疗/灯、追月神/辉夜姬、化鲸、影鳄、护甲吸血。原断言未改。 |
| 完整原PNG | 新增16张与本地原图逐字节一致，`card-art-manifest.json`。累计59位角色472主体及3草人派生，共475张。 |
| 本地Web构建 | Godot 4.6.3导入、导出均通过，164.9 MiB，`build.log`、`import.log`、`export.log`。入口`.build/pages/play/index.html`，未发布远端。 |
| 构建一致性 | 750项GD/PNG/JSON与构建副本哈希一致，`build-source-hashes.json`、`build-validation.json`；既有`content.json`字节未变。 |
| 变更范围 | `changed-files.json`、`continuation.diff`从本批开始时的工作区快照生成，保留既有工作区修改；没有用整个Git脏差异冒充本批改动。 |
| 格式 | `git diff --check`与本批新增/改动文本尾空白检查通过，`final-validation.json`。 |
| 全库还原审计 | `node scripts/audit-rule-fidelity.mjs --out output/godot-minglei-pair-20261024/audit.json`退出1，符合当前未完成事实，`audit.log`与`audit-comparison.json`。 |

原生截图实际覆盖加护候选的随机效果说明及点击附着；蚀印对手真实手牌、菩提愿弃掉未选候选并公开所选；缚梦明香禁止当前不可用的非蚀印手牌，使用合法蚀印牌并完成其选择后解除限制。截图文件名分别含`ward-choice`、`erosion-discard-choice`、`forced-eroded-hand`。

严格全库审计的卡牌已知近似590→582、未核对675→667、待核验655→671、有来源207不变；单位近似101不变、未核对46→44、待核验88→90、有来源15不变。19项既有诊断逐项不变，`fullCatalogRestored=false`。所有本批16张卡及两位基础角色保留待核验字段。

未完成范围：指定实机录像逐牌及组合验证；加护随机池“使用后恢复自身生命”的准确目标/数值（当前按恢复所属式神全部生命执行，仅有补充文字支持恢复，没有完整量值）；抵消是否触发基础能力；特殊形态原生字段、融合/复制/蓄力及随机分布；缚梦明香在响应、起源及多宿主情况下的完整结算顺序。上述不作为原客户端已确认效果，也未通过关闭入口、缩减卡池或放宽既有回归来处理。
