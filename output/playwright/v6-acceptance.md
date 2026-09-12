# v6「枢夜交战」验收记录

此页补齐 2026-09-11 v6 实现的证据索引；后续觉醒/SSR与秘闻阁迭代的当前结果见 [2026-09-12 验收](redesign-acceptance.md)。历史记录不能代替后续版本验证。

## 修复与保护

| 问题 | 修复前 | 修复后及证据 |
| --- | --- | --- |
| 战场挤压与前线缩小 | 隐式网格/尺寸规则叠加造成角色拥挤，前线被挤小 | 五行显式布局、前后场同级宽度；三档几何检查见 `v6-layout-check.log` |
| 隐藏检视面板撑宽页面 | 卡内 fixed 检视层受祖先 transform 影响产生溢出 | 检视移到独立左栏；移动全页无横向溢出 |
| 升勾按钮报找不到角色 | MouseEvent 被当成 unitId 传入 | 事件包装为无参调用；`v6-lifecycle.log` 的 levelButton passed |
| 气绝角色升勾软阻塞 | 规则允许，UI 却只检查存活角色 | UI 使用规则 facade 查询，最低勾玉包含全员；presentation 回归测试 |
| 重开后不能调度 | 沿用上局调度结束标记 | 新局重置；lifecycle 的 mulliganReset passed |
| 空前线+幻境时缺少核心入口 | 战斗牌目标流程无空前线核心按钮 | 可点空前线完成核心攻击；真实 UI 对局 |
| 3D 第三次重入失效 | 已缓存模块使 loading Promise 清理发生竞态 | 模块获取统一经过 await；三次重入 context 1，资源释放后恢复 |
| 全息静止仍 RAF/移除节点残留 | 指针无变化也持续更新或保留旧节点 | 停帧并清理脱离 DOM 节点；card-holo 测试 |
| realm-chip/AI 卡死历史回归 | 历史 mini 分支曾出错 | 保留 mini 判定与降级，不声称本轮再次复现旧崩溃；三档完整局验证未卡死 |

## 浏览器与 3D

`v6-desktop-run.log`、`v6-tablet-run.log`、`v6-mobile-run.log` 分别记录 1440×1000、820×1180、390×844 真实点选流程：开局、升勾、出牌、交战、结算。`v6-2d-run.log` 和 `v6-reduced-run.log` 分别覆盖关闭 3D 和减少动态效果完整对局，控制台错误均为空。

`v6-lifecycle.log` 记录三次离场/重入 context 始终 1，退出时场景资源为 0，静止时 renderCount 不再变化。每次强制 GC 后 heap 为约 4.64、4.80、5.044、5.048 MB，最后两次趋稳；这是有限时段检查，不是长期内存稳定性的证明。three.js pinned 为 0.180.0，卡牌指针预览见 `v6-three-card-preview.png`。

前后对照：`v6-before-desktop.png`、`v6-before-mobile.png`、`v6-before-level-button.png`；整理后的同局三档只读回放截图为 `v6-final-desktop.png`、`v6-final-tablet.png`、`v6-final-mobile.png`。这些回放对照图与实际交互对局截图分别保存，没有把测试快照当成真实游玩过程。

v6 当时单元测试 132 项、冒烟 30 局、项目内 UI 审计 99 项通过。原外部审计脚本缺失，替换为项目内静态审计的范围见 README；不等同原外部脚本。
