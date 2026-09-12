# 2026-09-12 角色、状态与秘闻阁验收

基线为另一 agent 已推送的 `3210579`。本轮改动尚未提交或推送。原 v6 的实现证据另见 [v6 验收](v6-acceptance.md)。

## 实际变化与前后行为

| 范围 | 修复/调整前 | 修复/调整后 |
| --- | --- | --- |
| 13 张普通形态 | 主要是同质化攻防加成 | 围绕入阵、交战、施术、幻境或前线回合触发持续能力；换形态替换能力 |
| 苍狼王之相 | 换形态后仍遗留被动护盾增幅 | 旧增幅清除；测试覆盖切换、交战和不额外叠盾 |
| SSR | 同名限 1、统一 1 费，多个高冲击效果又带瞬发 | 同名限 2；按资源和强度定 1–2 费；全体控制/保护与主要终结消耗 2 鬼火 |
| 白棱 SSR | 又一张先攻暴击战斗牌 | 碎镜裁决：移除护盾，眩晕目标追加伤害；区别于持续晶裂 |
| 不屈显示 | 结算生效，但状态列表没有显示 | 注册表给出“不屈 生效/待恢复”；已觉醒、未激活、气绝也明确标字 |
| 多状态堆叠 | 徽章堆在肖像上，名称/勾玉/效果容易挤压 | 状态独立在肖像下方，角色所在行自适应增高，不侵占指令带 |
| 秘闻阁阅读 | 所有角色连续平铺，正文藏在 title | 单角色阅读、完整被动与牌文、搜索/类型/收藏筛选 |
| 结束回合直接获胜 | 空牌库抽牌判负后仍设置 AI 忙碌，存档与回放永久禁用 | 按实际控制权设置/清除忙碌；同一第47半回合存档重走末步后可保存终局 |
| 概率说明 | 页面还写旧权重 60/34.5/5.5，缺传说保底 | 从 COLLECTION_RULES 与实际收藏状态生成，经济数值未变 |
| 治疗文案 | 部分复归仍写 3/5 血，形态回满未体现在牌文 | 与已有“复归回满/形态仅自身回满”的结算一致 |

## 自动检查

- [完整测试日志](redesign-test.log)：159/159 通过。
- [常规冒烟](redesign-smoke.log)：30/30 完成，崩溃 0、非法命令 0、软锁 0；先手16/后手14，平均18.5回合、最长25回合。
- [静态 UI 审计](redesign-audit.log)：101 项、0 错误。`git diff --check` 无输出。
- [SSR 构筑专项](redesign-ssr-smoke.log)：16 局全部结算，每个动作都 serialize→deserialize。AI 实际使用 14/16 种 SSR；未被 AI 选中的“墨海无量”“仁王无双”由专项单元测试直接覆盖。此项验证执行与状态合法性，不等于平衡证明。
- [多状态压力检查](redesign-status-stress.log)：三档各 8 张角色，觉醒/形态/护盾/眩晕/晶裂/不屈/充能同时展示，肖像、状态和指令区域无交叠。
- [12 手牌检查](redesign-hand-stress.log)：三档每张牌宽分别108/110/104px，卡身与点击区域一致，最后一张均可完整滚到。
- [秘闻阁流程](redesign-collection-check.log)：搜索/空结果、八角色SSR筛选、已拥有筛选、合成扣款与刷新持久化、开卷五张牌与计数通过；三档无横向溢出、牌文不遮挡合成按钮、控制台错误为空。

## 真实对局与截图

以下脚本通过真实 DOM 点选操作，AI 只对从界面保存的快照给出只读建议，不直接修改实时游戏状态。三档均包含升勾、出牌、交战与结算，pageerror/consoleErrors 均为空；最终 DOM 状态文本改动后额外跑桌面完整局，并对三档补充几何与状态压力验证。

| 模式 | 日志 | 交互截图 |
| --- | --- | --- |
| 桌面 1440×1000 / 3D | [完整局](redesign-desktop-run.log) | [开局](redesign-1440x1000-opening.png) · [中局](redesign-1440x1000-midgame.png) · [结算](redesign-1440x1000-result.png) |
| 平板 820×1180 / 3D | [完整局](redesign-tablet-run.log) | [开局](redesign-820x1180-opening.png) · [中局](redesign-820x1180-midgame.png) · [结算](redesign-820x1180-result.png) |
| 手机 390×844 / 3D | [完整局](redesign-mobile-run.log) | [开局](redesign-390x844-opening.png) · [中局](redesign-390x844-midgame.png) · [结算](redesign-390x844-result.png) |
| 桌面关闭 3D | [完整局](redesign-2d-run.log) | [结算](redesign-1440x1000-2d-result.png) |
| 平板 reduced-motion | [完整局](redesign-reduced-run.log) | [结算](redesign-820x1180-reduced-result.png) |

同一实际对局在只读回放中的三档布局对照：[桌面](redesign-final-desktop.png)、[平板](redesign-final-tablet.png)、[手机](redesign-final-mobile.png)，几何检查见 [日志](redesign-layout.log)。

秘闻阁：[桌面全牌型](redesign-collection-desktop.png)、[平板形态筛选](redesign-collection-tablet.png)、[手机形态筛选](redesign-collection-mobile.png)。多状态极限画面是独立测试快照，不是自然对局截图：[桌面](redesign-status-1440.png)、[平板](redesign-status-820.png)、[手机](redesign-status-390.png)。

末步终局回归：[复现状态](redesign-terminal-reproducer.log)、[修复前禁用入口](redesign-before-terminal-lock.png)、[修复后开放入口](redesign-after-terminal-unlock.png)、[验证日志](redesign-terminal-regression.log)。保存时双方牌库为0、核心14/17，点击结束回合正确判胜；没有控制台错误，终局存档通过一致性校验。

## three.js

three@0.180.0 ESM/importmap/jsdelivr 保留。场景背景、卡牌与大预览物理材质、低频冲击仍为透明表现层；DOM 与 game-core 决定所有规则和交互。卡牌指针效果实测见 [截图](redesign-three-preview.png) 和 [诊断](redesign-three-preview.log)。

[生命周期记录](redesign-lifecycle.log)：初始与三次重入的实际 context 数均为 1；离场释放场景/renderer wrapper，context 复用；关闭3D与reduced-motion的资源数为0。静止500ms采样 renderCount保持12、pendingFrame=false。强制GC后 heap约5.078、5.217、5.451、5.462MB，最后两次差约10KB；未观察到持续的大幅增长，有限三次循环不代表任意长时运行的保证。桌面完整对局未触发操作超时，未额外宣称精确帧率或输入延迟百分位。

## 布局取舍与遗留边界

保留参考图的上下双方、前线与后场、核心资源、底部手牌、回合/战报骨架。状态从角色肖像移到独立底栏；手机采用纵向滚动和完整横向手牌，不把所有字段挤成一屏。秘闻阁延续编成的宣纸画册风，角色页签缩小阅读范围；战场继续墨夜和风。

没有发现尚未解决的本轮功能阻塞。仍需真人长期试玩评估形态回满、护盾/不屈与高勾玉终结的平衡；AI 测试不能保证好玩或公平。卡面沿用现有原创 SVG 素材。WebGL 性能验证限于本机 Chromium，其他 GPU/浏览器需另测。旧版本命令日志可能因内容定义改变而产生不同结果、触发原有回放一致性拒绝；本轮未改动存档版本或校验，也未实现内容快照版本化。

[Godot 评估](../../ENGINE_DIRECTION.md)：当前继续浏览器版，未来先验证一个小规模原生纵向切片；本机版本为开发版4.8.dev5。本轮没有迁移、安装新依赖、提交、推送、发布或对外发送。
