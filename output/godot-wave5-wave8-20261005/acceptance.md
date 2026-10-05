# 第五至第八资料包重绘验收 · 2026-10-05

本轮完成第五至第八资料包全部 106 位角色的原版参照重绘、Godot 接入与实际游戏画面复核，累计 189 位。每位一张 1024×1536 无框 PNG 和独立裁切焦点；此前 83 张图片、角色映射及焦点保持一致。

| 资料包 | 新增角色 | 最终对照页 | 游戏截图 |
| --- | ---: | ---: | ---: |
| Wave5 · 繁花喧哗 | 24 | 6 | 16 |
| Wave6 · 空弦鸣雷 | 32 | 8 | 21 |
| Wave7 · 燃灯桃源 | 25 | 7 | 19 |
| Wave8 · 祝星千录 | 25 | 7 | 19 |
| 合计 | 106 | 28 | 75 |

## 来源与视觉复核

全部图像使用内置 `image_gen`。每次生成与重试仅输入对应 `art-reference-official/卡面/01_式神/` 原版，不将弃用的生成图作为新参考。参考编号与内容库 `officialRole`、资料包及角色 ID 一一对应。原版卡面不复制为 Godot 的运行立绘。

完整提示词、原版路径、生成文件、最终选择及裁切焦点见 [Wave5](../../godot/assets/redrawn/prompts-wave5.json)、[Wave6](../../godot/assets/redrawn/prompts-wave6.json)、[Wave7](../../godot/assets/redrawn/prompts-wave7.json)、[Wave8](../../godot/assets/redrawn/prompts-wave8.json)。每位的原版特征、最终文件、对应对照页与复核结果见 [art-review.json](art-review.json)，完整角色清单见 [roster.json](roster.json)。

106 位均检查了人物归属、发型、配色、服饰变体、面部与肢体、武器和伴生主体。傀儡师的人偶、食灵的伴生角色、童男童女双人、山兔/座敷童子的双人坐骑组合、萤草·蒲蒲的植物坐骑、小鹿男·千守的鹿身、猫川的灵猫均保留。第八资料包的鬼使黑与鬼使白分别按各自原版独立重绘，未复用第四资料包的黑衣图。

18 位首版或修正版残留原版印刷的元素标记，已仅用原版重新生成并采用无标记版本，共 19 次修正（季修正两次）。第五包 13 位、第六包寻香行、第七包椒图/季/酒吞童子·忘空、第八包月读的最终选择和原因均有记录。最终 28 页原版对照均已查看；未见明显面部崩坏、主体遗漏或卡面印刷 UI 残留。这是视觉复核，不是自动相似度评分。

伊邪那美首次输出被图像服务以 `sexual` 类别拦截。最终使用同一原版生成完整不透明高领长袖礼服，保留长发、黑红配色、红羽披和银蛇场景。衣装与姿势调整已单独记录在 `designException`，不声称与原版衣装完全一致。

生成过程中，首批 24 张结果超过工具传输容量；后续八张在保存阶段发生错误。已从本地生成目录恢复原文件，通过逐张身份对照、已有运行文件哈希和最终字节校验确认归属。记录见 [Wave5 恢复清单](wave5-recovered-files.json)、[Wave8 恢复清单](wave8-recovered-files.json)，四份提示词中同时保留恢复说明。最后三张结果见 [生成记录](wave8-final-three-results.json)。这些错误均已处理，最终运行资源完整。

## 接入与实际画面

`godot/assets/redrawn/wave5/` 至 `wave8/` 新增 106 张 PNG；[portraits.json](../../godot/assets/redrawn/portraits.json) 添加对应路径与焦点。名录、编组、构筑、主城与战场共用该映射；普通、觉醒和所属技能牌继续共用主人立绘，觉醒边框由 UI 绘制。原 SVG 和缺图回退保留。

`verify_art.gd` 增加第五至第八资料包完整覆盖要求，验证全部 189 位在真实控件中的纹理、五种尺寸焦点裁切、比例、独立角色归属、技能牌/觉醒归属与缺图回退。沿用 `capture_redrawn.gd --pack=<资料包 ID>`，四包逐页画册、编组、每四位构筑与战场全部采集，75 张均为不同的 1280×800 图像。

全部画册、编组、构筑和战场已查看；横向牌图保留人物脸部，双人图在可见区域保留原组合，未发现空白纹理或人物归属错误。四包己方战场分组覆盖全部 106 位。分组与截图核对见 [screenshot-check.json](screenshot-check.json)，75 张原图和全部最终对照页见 [图片索引](image-index.md)。各包视觉验收见 [Wave5](review-wave5.json)、[Wave6](review-wave6.json)、[Wave7](review-wave7.json)、[Wave8](review-wave8.json)。

本轮开始前保存相关文件至 `baseline/`，仅此轮相对基线的五个文本文件变化见 [changes.diff](changes.diff)。既有工作区修改保留，本轮未改动战斗规则或上一轮手感实现。

## 验证结果

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| `./scripts/godot-verify.sh` | `GODOT_VERIFY_ALL_OK`；250 角色 / 2114 卡，21 个 UI 脚本、隔离存档、收藏与启动通过 | [verify.log](verify.log) |
| 交互与录像流程 | 30 / 187 项，0 失败 | 同上 |
| 表现与 viewport 输入 | 119 项，0 失败，含目标连线、演出输入锁与移动浮字 | 同上 |
| 美术 | 3989 项，189 位，0 失败 | 同上 |
| 全角色对局 | 5303 项，63 局覆盖 250 位，0 失败 | 同上 |
| 多局压测 | 60 随机 + 20 响应/占卜对局全部结束，卡死 0 | 同上 |
| `npm test` | 163 / 163 通过，无跳过 | [npm-test.log](npm-test.log) |
| `npm run audit` | 385 项，0 错误 | [audit.log](audit.log) |
| 实际图形截图 | 75 张不同的 1280×800 图片，四包正常退出，无错误/警告/资源泄漏 | [Wave5](capture-wave5.log)、[Wave6](capture-wave6.log)、[Wave7](capture-wave7.log)、[Wave8](capture-wave8.log) |
| 资源完整性 | 新 106 张参考编号、选图字节和焦点一致；累计 189 张哈希独立 | [asset-check.log](asset-check.log)、[assets.sha256](assets.sha256) |
| 旧资源保留 | 此前 83 张哈希、映射与焦点一致 | [previous-assets-check.log](previous-assets-check.log) |
| 文本与交付链接 | `git diff --check`、本轮 diff 空白、全部验收相对链接检查通过 | [final-check.log](final-check.log) |

测试和截图使用隔离存档，未使用玩家真实收藏、阵容或音量数据。截图为实际 Godot viewport 渲染和自动输入流程；不等同于 macOS 物理鼠标人工试玩或主观手感评分。

## 代表画面

[第五包画册](final-shots/wave5/01-wave5-portraits-01.png) · [第六包画册](final-shots/wave6/01-wave6-portraits-01.png) · [第七包双人坐骑](final-shots/wave7/01-wave7-portraits-04.png) · [第八包新角色](final-shots/wave8/01-wave8-portraits-03.png)。

[第五包编组](final-shots/wave5/02-wave5-formation.png) · [第六包编组](final-shots/wave6/02-wave6-formation.png) · [第七包编组](final-shots/wave7/02-wave7-formation.png) · [第八包编组](final-shots/wave8/02-wave8-formation.png)。

[伊邪那美与鬼使战场](final-shots/wave8/04-wave8-battle-03.png) · [饭笥与猫川](final-shots/wave8/04-wave8-battle-05.png) · [小鹿男·千守与日和坊·晴阳](final-shots/wave8/04-wave8-battle-06.png)。

## 当前范围

剩余 61 位角色仍使用原 SVG。普通、觉醒和技能牌共用角色插画，尚无独立觉醒或逐技能插画。复杂规则与 AI 仍沿用 Godot 纵向切片的既有简化范围，见 [Godot README](../../godot/README.md)。未提交、推送或发布。

重新采集某个资料包：

```sh
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/capture_redrawn.gd -- /绝对路径/截图目录 --pack=wave8
```

重跑本批资源与截图校验：

```sh
python3 output/godot-wave5-wave8-20261005/check_assets.py
```
