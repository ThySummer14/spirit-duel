# 原视频风格续作：技能演出（2026-10-06）

延续 [上一轮界面改造](../godot-video-style-20261006/acceptance.md)，本轮聚焦真实对战中的技能差异与演出时序。参照用户录像中局部连线、羽刃、花瓣治疗、法术命中和变身纹样的表现方式，在当前 Godot 战场中实现可操作的程序绘制演出。工作区仍以同步后的 `62e67db` 为基线；本轮未提交或推送。

## 实际改造

`battle_effect_cues.gd` 从已结算的相邻快照和真实命令提取受伤、治疗、护盾、眩晕、负面状态、形态、觉醒、幻境及资源反馈。角色意象选择刀斩、火羽、冰晶、风刃、雷光、墨符等纹样，治疗区分普通光点与桃花花瓣；共 15 种配色/纹样组合。不以牌文预测伤害，不创建额外规则动作，不消耗规则 RNG。

`battle_spell_effect.gd` 使用 0.18 秒传递和 0.42 秒尾迹，特效期间更新、结束自动释放，不持有 `GameState`，不拦截鼠标。玩家出牌的输入保护由 0.48 秒延长至 0.78 秒，覆盖尾迹；AI 先展示牌面再命中。出击中的目标沿用已有命中坐标，避免回位后反馈落在空槽。

群体伤害分别命中全部实际受伤目标；护盾吸收但生命未减少时显示护盾纹样。响应中的法术不会提前命中；放弃响应或真正打出响应盾后，原法术仍使用原施法者的意象。同一次结算中的护盾和火伤可各自保留来源。形态替换导致攻击下降时只显示形态纹样，不误作诅咒或受伤。

规则代码、2114 张卡的内容导出、AI、250 位角色 PNG 与肖像映射没有变更。现有音频继续复用，未增加依赖或新位图资源。

## 真实游戏画面

`capture_spell_styles.gd` 通过 `Viewport.push_input` 点击实际手牌和目标执行 16 种场景。每个场景保留五张起始手牌，并使用隔离的测试对局。截图为引擎真实渲染，未后期绘制特效。敌方手牌在测试初始化时清空以避免自动打开响应窗口；响应时序另由真实规则回归检查。

| 场景 | 宽屏命中截图 | 普通窗口命中截图 |
| --- | --- | --- |
| 凤凰火·凤火 | [火羽](wide/01-fire-11.png) | [火羽](normal/01-fire-11.png) |
| 雪女·吹雪 | [冰晶](wide/02-ice-11.png) | [冰晶](normal/02-ice-11.png) |
| 雪女·崩雪 | [眩晕](wide/03-freeze-11.png) | [眩晕](normal/03-freeze-11.png) |
| 大天狗·天狗风乱 | [四目标羽刃](wide/04-wind-11.png) | [四目标羽刃](normal/04-wind-11.png) |
| 霆鸢·雷法 | [雷光](wide/05-thunder-11.png) | [雷光](normal/05-thunder-11.png) |
| 玄砚·墨法 | [墨符与晶裂](wide/06-ink-seal-11.png) | [墨符与晶裂](normal/06-ink-seal-11.png) |
| 桃花妖·桃之馨息 | [治疗花瓣](wide/07-petal-heal-11.png) | [治疗花瓣](normal/07-petal-heal-11.png) |
| 弦月·治疗 | [治疗光点](wide/08-heal-11.png) | [治疗光点](normal/08-heal-11.png) |
| 岚岳·固阵 | [护盾](wide/09-shield-11.png) | [护盾](normal/09-shield-11.png) |
| 兵俑·不动如山 | [形态](wide/10-form-11.png) | [形态](normal/10-form-11.png) |
| 妖刀姬·觉醒 | [觉醒](wide/11-awaken-11.png) | [觉醒](normal/11-awaken-11.png) |
| 岚岳·界碑阵列 | [幻境](wide/12-realm-11.png) | [幻境](normal/12-realm-11.png) |
| 霆鸢·抽牌 | [资源粒子](wide/13-resource-11.png) | [资源粒子](normal/13-resource-11.png) |
| 妖刀姬·战意 | [刀斩与反击](wide/14-slash-11.png) | [刀斩与反击](normal/14-slash-11.png) |
| 护盾吸收凤火 | [护盾反馈](wide/15-guard-11.png) | [护盾反馈](normal/15-guard-11.png) |
| 萤草·吸取 | [法术纹样](wide/16-arcane-11.png) | [法术纹样](normal/16-arcane-11.png) |

两种窗口各 48 张 PNG：1600×740 与 1280×800。完整命令与实际出现的纹样见 [宽屏原生结果](wide/native-results.json)、[普通窗口原生结果](normal/native-results.json)。每个场景另有 05、17 两个阶段截图。

[含音频原生录像](native-spells.mp4)：H.264，1600×740，25 FPS，675 帧，27.00 秒；AAC 48 kHz 双声道，文件 3,095,375 字节。由 Godot MovieWriter 录制后转码，未添加后期技能或声音。完整解码无错误；实际音轨平均 -22.1 dB、峰值 -2.2 dB。脚本在退出前停止音频流并等待清理，最终宽屏/普通窗口采集日志均无脚本错误、引擎错误或泄漏。原始 AVI `native-spells.avi` 也已保留在本地；自动审批拒绝了 `rm -f` 清理命令，未执行删除。

## 验证

| 检查 | 实际结果 |
| --- | --- |
| `./scripts/godot-verify.sh` | 23 个验证脚本、种子对战与启动冒烟，`GODOT_VERIFY_ALL_OK` |
| `verify_spell_effects.gd` | 97 项，0 失败：真实法术、群体目标、响应/响应链、护盾吸收、形态替换、原生点击、输入锁与释放 |
| `verify_presentation.gd` | 120 项，0 失败，包含出击坐标、AI 等待、重开与退出生命周期 |
| `verify_aim_pointer.gd` | 19 项，0 失败 |
| `verify_video_layout.gd` | 884 项，0 失败 |
| `verify_reference_workflow.gd` / `verify_interactions.gd` | 187 / 30 项，0 失败 |
| 角色与插画 | 5283 项美术、5304 项入口检查，250 位完整覆盖 |
| 对局覆盖 | 63 局角色覆盖 + 60 局压测 + 20 局响应/选择压测，共 143 局完成，无卡死 |
| `npm test` | 163 通过，0 失败，0 跳过 |
| `npm run audit` | 385 checks，0 errors |
| `git diff --check` | 通过 |
| 规则、内容、肖像范围检查 | 指定文件 `git diff --exit-code` 通过 |

最终记录：[Godot 全套](verify-final.log)、[技能演出](spell-effects.log)、[既有演出](presentation.log)、[JS 测试](node-test.log)、[UI audit](audit.log)、[宽屏采集](capture-wide.log)、[普通窗口采集](capture-normal.log)、[完整录像解码](video-decode.log)、[音轨检查](audio-level.log)。`shape-reproducer.log` 是修复前的失败重现，以最终日志为验收依据。

## 范围与复验

这些是结合原视频风格的效果类别与角色意象演出，尚未逐张复刻 2114 张牌的独有动画。技能牌仍共用所属角色插画，形态牌未增加独立角色美术。原视频、原版素材和玩家真实存档未修改。

复验截图与录像（输出目录先创建，MovieWriter 使用绝对路径）：

```sh
mkdir -p output/spell-preview
"${GODOT_BIN:-/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot}" \
  --path godot --script res://scripts/capture_spell_styles.gd \
  --fixed-fps 25 --disable-vsync \
  --write-movie "$PWD/output/spell-preview/native-spells.avi" \
  -- "$PWD/output/spell-preview/wide"
```

普通窗口不录制时省略 `--write-movie`，将最后两个用户参数设为绝对输出目录与 `normal`。截图及规则测试使用临时隔离存档，完成后清理本次临时数据。
