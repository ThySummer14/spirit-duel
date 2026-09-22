# 引擎方向：先验证 Godot 的收益，再决定迁移

评估日期：2026-09-12。当前决定是继续交付浏览器版，本轮未迁移，也未创建第二套游戏工程。

这个项目值得长期做；长期维护并不要求现在换引擎。眼下暴露的问题主要是角色设计缺少取舍、状态信息被压缩和页面职责拥挤。它们需要内容与交互设计的改进，Godot 不会自动解决。当前纯 JS 规则已与 DOM、three.js 表现分离，确定性命令、存档和测试都可成为未来迁移的验收资产。

Godot 的价值在于可视化场景编辑、角色动画、粒子和音效编排，以及将来以桌面/移动原生应用为主要载体。若后续大量工作都耗在这类内容制作上，迁移就可能值得；若主要迭代仍是卡牌效果、构筑、状态可读性和浏览器即开即玩，现有实现仍能支撑发展。

| 关注点 | 继续浏览器版 | 迁移到 Godot |
| --- | --- | --- |
| 已有规则与工具 | JS facade、node 测试继续使用 | 一般需移植到 GDScript/C#，或维护额外桥接 |
| 界面 | DOM 布局、文本、ARIA 和响应式现成 | Control 场景要重新实现并验收 |
| 美术与动画制作 | CSS/three.js 编排，需程序支持 | 场景、资源和动画编辑器更适合持续内容制作 |
| 平台 | 浏览器作为当前主平台 | 更适合把桌面或移动原生发行作为主平台 |
| 浏览器降级 | WebGL 失败仍可完整玩 DOM 游戏 | Web 导出需要 WebAssembly 与 WebGL 2 |
| 既有存档/回放 | 沿用当前协议 | 需要兼容层和跨实现一致性测试 |

本机安装位于 `/Users/thysummer/apps/Godot.app`，实际 `--version` 为 `4.8.dev5.official.9552dfb68`，是开发版；未来若开始正式迁移，应选择经过验证的稳定版。本轮没有替换或修改安装。

建议未来的迁移验证只做一个纵向切片：两名角色、一组可复现命令、升勾→形态→交战→气绝→复归→结算，以及一个可复用卡牌组件。用相同的状态与命令样本比对两个实现，观察制作一张新牌/一个特效的实际成本。只有当编辑体验、运行表现和原生发布收益明显，同时规则一致性通过时，再迁移其余内容；不同时维护两份不断分叉的规则。

Godot 官方支持 GDScript、C#，以及通过 GDExtension 使用 C/C++；JavaScript 并不是可将现有项目直接原样搬入的官方脚本路径。[官方脚本语言说明](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_languages.html)。Godot 4 的 Web 导出目前使用 Compatibility/WebGL 2；C# 项目目前不能导出 Web，单线程 Web 导出自 4.3 提供，音频仍有 Web 平台限制。[官方 Web 导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。这些是当前约束，真正启动迁移时应再次核查。

## 2026-09-12：从评估推进到内容读取验证

本次新增隔离的 `prototypes/godot-content-probe/`，通过 `scripts/export-godot-content.mjs` 导出原创角色和卡牌；本机 Godot headless 已读取全部 8 名角色、138 张牌，检查 ID 唯一性和角色归属通过。此前“未创建第二套工程”描述的是上一轮状态；现在有一个验证工程，仍无第二套规则实现。

这证明内容数据可以复用，不能证明规则直接兼容。下一道迁移门槛仍是原文的双角色纵向切片，尤其要对比形态钩子、气绝复归、响应窗口和确定性回放。用户新增资料里的战斗区理论标为社区解释，先用于设计讨论，不替换已有结算。暂时继续浏览器玩法迭代，并保留这个可复跑的 Godot 入口。

## Unity 与 Godot：当前推荐 Godot，先做可玩的迁移切片

针对个人长期制作、以卡牌文字与二维场景为主体、少量三维闪卡与粒子的《灵枢战线》，当前优先推荐 Godot。这是对项目工作量的判断，不是两台引擎的性能实测结论。Unity 也完全能胜任；如果后续转向大量三维角色演出，或已经选定 Unity 专用资产与插件，选择可能反转。

| 项目实际需求 | Godot | Unity | 本项目判断 |
| --- | --- | --- | --- |
| 角色卡、牌组、状态和收藏 UI | Control、容器、主题 | uGUI / UI Toolkit | 两者都需重做 DOM 交互，Godot 足够覆盖当前需求 |
| 闪卡、粒子、镜头演出 | Shader、动画、粒子 | Shader、动画及渲染工具 | 当前低频演出不足以单独推动选择 Unity |
| 规则与回放迁移 | 移植或桥接 JS | 移植或桥接 JS | 都不能靠换工程直接保留规则正确性 |
| 个人长期使用 | MIT 开源许可 | Personal 有免费资格门槛 | Godot 的许可约束更简单 |
| 已有验证 | 本机已读入 8 角色 / 138 卡 | 尚未做本机工程或性能验证 | 优先将 Godot 探针扩展为纵向切片 |

官方核查于 2026-09-12：[Godot UI 文档](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)、[Godot MIT 许可要求](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)、[Unity UI 系统比较](https://docs.unity3d.com/6000.0/Documentation/Manual/UI-system-compare.html)。Unity Personal 当前免费资格涉及过去 12 个月 20 万美元收入/资金门槛，具体以[官方资格说明](https://unity.com/products/unity-personal)为准；Runtime Fee 已取消，不能再用旧收费争议作为当前淘汰理由，见[官方定价更新](https://unity.com/products/pricing-updates)。

实际选择门槛：先让 Godot 切片展示中文长文本、触控选牌、密集状态与一张可复用闪卡，并走通两角色结算及回放对照。如果这一步暴露制作效率或表现上的明确瓶颈，再用同样样本验证 Unity。现在无需安装两套新工作流或维护两份完整游戏；浏览器版继续作为可玩基准。


## 2026-09-22：经典包入库 + Godot 可玩纵向切片

- 浏览器侧合并经典基础包 29 式神（`game-content-classic.js`），编成池扩大到 37 名角色；UI 增加资料包筛选与搜索。
- `godot/` 从内容探针扩展为可玩纵向切片：菜单/编成/五行战场/结果，规则层 GDScript + 确定性命令日志 + 贪心 AI，UI 按墨夜和风重做。
- 验收：`node --test tests/*.test.js` 161 全通过；`./scripts/godot-verify.sh` → `GODOT_VERIFY_ALL_OK`；`node scripts/audit-ui.mjs` 0 errors。
- 仍简化的部分：响应窗口/占卜/部分关键词完整时序、formHooks 全量、连击/贯通/远程在 Godot 侧完整战斗模型。下一步优先把这些与浏览器 `game-core` 做双实现对拍。


## 2026-09-22（续）：双实现对拍起步

- 新增 `scripts/godot-parity.sh` + 中立命令样本：同一 seed/编成/命令序列在 JS 与 Godot 重放并比对快照。
- 已对齐：LCG RNG、发牌/洗牌、升勾（齐头并进）、出入前线、气绝 +1 核心、不屈、贯通/连击/先攻/远程/暴击、formHooks 同名 effect、结束回合不强制升勾。
- `sample-origin.json` → **PARITY_MATCH**。
- 响应窗口仍为 Godot 侧明确降级（无优先权中断）；下一步做最小 pass 连锁后再对拍响应牌样本。


### 2026-09-22（续 2）：响应窗口最小链对拍通过

- Godot 增加结算栈 / 响应窗口 / `pass_response`：优先权、双方放弃结算、LIFO 嵌套、无响应自动跳过。
- 样本 `sample-response.json`、`sample-response-play.json` 与 JS **PARITY_MATCH**（含见切嵌套后再开窗）。
- 顺带对齐：气绝目标仍可反击（先攻除外）。


### 2026-09-22（续 3）：占卜 + 资源关键词链对拍

- Godot 占卜：`pending_choice` 暂停栈、展示顶 N 张、选择置顶后 `resolve_resolution_stack` 续排；战局 UI 可点选。
- 运势骰（fortune-success）、鼓舞池（出击消耗）、充能（回合成长 + chargeCost）与 JS 对齐。
- `sample-divination.json` / `sample-fortune.json` **PARITY_MATCH 5/5**。


### 2026-09-22（续 4）：整体迁入 Godot

主流程已含图鉴、卡组构筑、本地存档；对局吃自定义 8 张构筑。浏览器版仍作规则对拍基准（scripts/godot-parity.sh）。下一步：秘闻阁经济/开包，或命令日志回放 UI。


### 2026-09-22（续 5）：秘闻阁与回放摘要迁入 Godot

收藏/开包/御札/合成与胜负奖励已进引擎；战局与结果页可查看命令日志。浏览器版保留为规则对拍基准。
