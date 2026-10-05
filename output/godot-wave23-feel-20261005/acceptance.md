# 第二、第三资料包重绘与游玩手感验收 · 2026-10-05

接续聊天 `01a10776-7d25-73e2-924a-7cddc9de3205` 中断的最后一轮任务：批量绘制更多式神，始终参照原版角色与画风，失败重试仍以原版为输入，并按用户此前提供的录像迭代 Godot 游玩手感。接续时 28 张图片、映射、目标连线和演出节奏改动已经落盘；本次完成原版复核、真实输入回归、后续修复、最终截图与记录。

## 角色与素材

第二资料包 9 位与第三资料包 19 位全部使用 1024×1536 无框重绘，接入主城、名录、编组、卡组与战场。加上既有经典包 29 位，共 57 位使用重绘。28 张最终图片与上轮所选生成结果逐字节一致，本次没有重新请求生成，也没有修改经典包图片；经典包旧校验表全部匹配。

图像由内置 `image_gen` 生成。提示词与来源见 [prompts-wave2-wave3.json](../../godot/assets/redrawn/prompts-wave2-wave3.json)，运行路径与焦点见 [portraits.json](../../godot/assets/redrawn/portraits.json)。每位原版卡面编号均与内容库中的 `officialRole` 对应。镰鼬初版偏向猫形，重试仅输入原版卡面，最终采用细长鼬面修正版；弃图未接入。

逐张检查发型、五官、衣装、配色、武器和角色/坐骑关系，没有发现明显面部崩坏或角色造型偏离。具体观察和校验值见 [art-review.json](art-review.json)、[asset-check.log](asset-check.log)、[assets.sha256](assets.sha256)。对照页左侧为原版、右侧为最终重绘：[1](review/comparison-01.jpg) · [2](review/comparison-02.jpg) · [3](review/comparison-03.jpg) · [4](review/comparison-04.jpg) · [5](review/comparison-05.jpg) · [6](review/comparison-06.jpg) · [7](review/comparison-07.jpg)。这是视觉复核，不是自动相似度评分。

## 游玩手感与接续修复

录像来源为 `/Users/thysummer/Downloads/LANDrop/Screenrecorder-2026-10-04-11-30-41-829.mp4`，608.36 秒、2772×1280。本次重看战斗样本，约 03:50 的交战帧显示移动卡面上的伤害反馈；此前的整体观察与抽帧见 [video-analysis.md](../video-reference-20261004/video-analysis.md)。本轮保留既有完整 4v4、起手换牌和收藏流程，围绕选目标与动作反馈完善表现。

目标连线跟随指针，合法目标吸附并显示绿色，非法目标显示红色；点错式神时提示原因并保留选择，右键或 Esc 可取消。升勾、玩家出牌与基础交战分别保留 0.38 / 0.48 / 0.85 秒演出节奏，期间点选、拖拽、快捷键与结束回合不能重复消耗行动。对手大卡展示结束后自主继续；重开对局取消旧演出与旧输入锁。

角色进入前线、蓄势、前冲命中与回位使用连续动画。接续复核发现反击浮字仍定位在出击者的回位位置，现改为命中时读取移动卡面的实际绘制位置；伤害、治疗、护盾、气绝、归队和觉醒反馈共用该定位方式。新增回归以真实 viewport 鼠标点选出击者/敌方前线，并发送 Enter；浮字位置检查在修改前源码上明确失败，修复后通过，见 [moving-feedback-before.log](moving-feedback-before.log) 与最终完整验收日志。

同时释放无状态悬停档案中未挂载的空容器，并让动画完成信号使用一次性连接，释放完成回调对动画自身的引用。最终图形截图退出与无头验收均检查脚本错误和资源残留。`verify_ui.gd` 补入新的目标连线脚本。

接续前相关文件保存在 `resume-baseline/`，本次接续相对这些文件的差异见 [resume-changes.diff](resume-changes.diff)。原工作区已有改动继续保留。

## 最终验证

| 检查 | 本次结果 | 证据 |
| --- | --- | --- |
| `./scripts/godot-verify.sh` | `GODOT_VERIFY_ALL_OK`；250 角色 / 2114 卡、21 个脚本加载、隔离存档/收藏与启动冒烟通过 | [verify-resumed.log](verify-resumed.log) |
| UI 与完整流程 | 30 项原交互、187 项录像流程通过，含起手→对局→结果→单次奖励 | 同上 |
| 表现与真实输入 | 119 项通过，含连线合法性、重复输入、右键取消、重开隔离、鼠标攻击、Enter 拦截与移动浮字 | 同上 |
| 美术 | 1207 项通过，57 位重绘导入、所属角色、焦点裁切、觉醒与缺图回退 | 同上 |
| 全角色对局覆盖 | 5303 项通过，63 局覆盖全部 250 位角色 | 同上 |
| 多局压测 | 60 随机 + 20 响应/占卜对局全部结束，卡死 0 | 同上 |
| `npm test` | 163 / 163 通过 | [npm-test.log](npm-test.log) |
| `npm run audit` | 385 项检查，0 错误 | [audit.log](audit.log) |
| 图形渲染 | 18 张不同的 1280×800 最终截图，正常结束 | [capture-resumed.log](capture-resumed.log)、[final-shots](final-shots/) |
| 资源来源 | 28 个原版编号一致、28 个运行 PNG 与最终选图一致；镰鼬一次原版输入重试 | [asset-check.log](asset-check.log) |
| `git diff --check` | 通过 | 本次本地执行 |

测试与截图使用隔离存档，没有使用玩家真实收藏、阵容或音量数据。检查证明输入、动画位置和流程行为；没有将 macOS 物理鼠标人工试玩或主观手感评分列为通过。

## 游戏截图

[第一组角色](final-shots/01-wave23-portraits-01.png) · [第二组](final-shots/01-wave23-portraits-02.png) · [第三组](final-shots/01-wave23-portraits-03.png) · [第四组](final-shots/01-wave23-portraits-04.png) · [第二资料包编组](final-shots/02-wave2-formation.png) · [第三资料包编组](final-shots/02-wave3-formation.png) · [不知火构筑](final-shots/03-buzhinhuo-deck.png)

[合法目标](final-shots/05-legal-target-line.png) · [非法目标](final-shots/06-invalid-target-line.png) · [交战命中与浮字](final-shots/07-attack-impact.png) · [回位](final-shots/08-attack-settled.png)。另有七组战场截图覆盖本批全部 28 位。

## 当前范围

余下 193 位仍使用既有 SVG 占位。普通/觉醒与所属技能牌共用角色插画，本批未增加独立觉醒或逐技能插画。复杂关键词与被动沿用 Godot 纵向切片现有简化范围，见 [Godot README](../../godot/README.md)。未提交、推送或发布。

运行：

```sh
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot
./scripts/godot-verify.sh
```
