# 第四资料包原版参照重绘验收 · 2026-10-05

接续上一轮原版参照重绘，本轮完成第四资料包（吉运善恶）的全部 26 位角色。26 张 1024×1536 无框插画接入 Godot，共 83 位角色使用重绘；此前经典 29 位、第二资料包 9 位、第三资料包 19 位的图片、角色映射与裁切焦点均保留。

## 角色与来源

本轮角色：缘结神、鬼童丸、般若、铁鼠、河童、追月神、百目鬼、武士之灵、鬼使黑/鬼使白、火取魔、源九郎狐、樱雪姬、净琉璃御前、饿鬼、独眼小僧、面灵气、九命猫、阿修罗、八岐大蛇、金鱼姬、荒骷髅、垢尝、帝释天、蟹姬、玉藻前、惠比寿。

使用内置 `image_gen`，每次只输入对应 `art-reference-official/卡面/01_式神/` 的原版角色卡面。26 张首版均经视觉对照选用，本轮没有失败图重试，也没有以已生成图片作为新参考。每张原版编号均与内容库 `officialRole` 对应，运行 PNG 与选中的生成文件逐字节一致，26 个文件独立且均为 1024×1536。

完整提示词、原版输入、生成与选图路径、焦点见 [prompts-wave4.json](../../godot/assets/redrawn/prompts-wave4.json)；运行映射见 [portraits.json](../../godot/assets/redrawn/portraits.json)。逐张观察记录在 [art-review.json](art-review.json)，自动校验在 [asset-check.log](asset-check.log)，全部 83 张的校验值在 [assets.sha256](assets.sha256)。旧 57 张校验结果见 [previous-assets-check.log](previous-assets-check.log)。

对照页左为原版、右为本轮重绘：[1](review/comparison-01.jpg) · [2](review/comparison-02.jpg) · [3](review/comparison-03.jpg) · [4](review/comparison-04.jpg) · [5](review/comparison-05.jpg) · [6](review/comparison-06.jpg) · [7](review/comparison-07.jpg)。逐张核对发型、面部、服饰、配色、武器与角色/伴生造型，未见明显面部崩坏或主体归属错误。这是视觉复核，不是自动相似度评分。

鬼使黑/鬼使白条目的现有原版 `19400_鬼使黑_鬼使白.png` 只显示鬼使黑，本轮保留该黑衣形态，没有另画鬼使白。独眼小僧保留单个中央眼；面灵气、玉藻前保留原版面具；火取魔、金鱼姬、惠比寿保留骑乘主体关系。帝释天等偏离画面中心的脸部配置了独立裁切焦点。

## 实现与画面

新增 `godot/assets/redrawn/wave4/` 26 张 PNG，在 `portraits.json` 添加对应路径与焦点。普通、觉醒状态和所属技能牌继续共用角色插画；觉醒边框由 UI 绘制，缺图继续回退既有 SVG。

`verify_art.gd` 增加第四资料包完整 26 位覆盖要求，并继续检查全部重绘的实际控件纹理、独立角色归属、五种尺寸焦点裁切、比例、觉醒和缺图回退。

`capture_redrawn.gd` 增加 `--pack=<资料包 ID>`。本轮采集四页角色画册、一张编组、七张构筑和七组战场，共 19 张实际 1280×800 游戏截图；七组己方战场覆盖全部 26 位。逐页查看了全部画册、编组、战场及构筑对照，卡面归属和面部裁切正常。分组与截图核对见 [screenshot-check.json](screenshot-check.json)。

本轮开始前保存了相关文件到 `baseline/`，仅此轮相对基线的文本差异见 [changes.diff](changes.diff)。原工作区既有修改保留，本轮没有修改战斗规则或上一轮手感实现。

## 验证结果

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| `./scripts/godot-verify.sh` | `GODOT_VERIFY_ALL_OK`，250 角色 / 2114 卡，21 个 UI 脚本、隔离存档、收藏与启动通过 | [verify.log](verify.log) |
| 交互与录像流程 | 30 / 187 项通过 | 同上 |
| 表现与真实 viewport 输入 | 119 项通过，含目标连线、演出输入锁、鼠标攻击与移动浮字定位 | 同上 |
| 美术 | 1755 项、83 位重绘，0 失败 | 同上 |
| 全角色对局 | 5303 项，63 局覆盖 250 位，0 失败 | 同上 |
| 多局压测 | 60 随机 + 20 响应/占卜对局结束，卡死 0 | 同上 |
| `npm test` | 163 / 163 通过 | [npm-test.log](npm-test.log) |
| `npm run audit` | 385 项，0 错误 | [audit.log](audit.log) |
| 图形截图 | 19 张不同的 1280×800 图片，正常退出，无错误、警告或资源泄漏 | [capture.log](capture.log)、[final-shots](final-shots/) |
| 资源来源与旧图 | 26 张来源编号与选图一致；旧 57 张校验值、映射和焦点一致 | [asset-check.log](asset-check.log)、[previous-assets-check.log](previous-assets-check.log) |
| 文本差异与交付链接 | `git diff --check`、本轮差异空白检查及本页相对链接检查通过 | [final-check.log](final-check.log) |

测试和截图使用隔离存档，没有使用玩家真实收藏、阵容或音量数据。检查不等同于 macOS 物理鼠标人工试玩或主观手感评分。

## 游戏截图

[第一组角色](final-shots/01-wave4-portraits-01.png) · [第二组](final-shots/01-wave4-portraits-02.png) · [第三组](final-shots/01-wave4-portraits-03.png) · [第四组](final-shots/01-wave4-portraits-04.png) · [第四资料包编组](final-shots/02-wave4-formation.png)

[缘结神构筑](final-shots/03-wave4-deck-01.png) · [鬼使构筑](final-shots/03-wave4-deck-03.png) · [荒骷髅构筑](final-shots/03-wave4-deck-06.png) · [玉藻前构筑](final-shots/03-wave4-deck-07.png)。全部七张构筑对照见 [1](review/deck-review-01.jpg) · [2](review/deck-review-02.jpg)。

[第一组战场](final-shots/04-wave4-battle-01.png) · [鬼使与狐妖](final-shots/04-wave4-battle-03.png) · [阿修罗与八岐大蛇](final-shots/04-wave4-battle-05.png) · [帝释天与蟹姬](final-shots/04-wave4-battle-06.png) · [玉藻前与惠比寿](final-shots/04-wave4-battle-07.png)。

## 当前范围

剩余 167 位仍使用原 SVG 占位。角色普通/觉醒与技能牌共用立绘，没有独立觉醒和逐技能插画。复杂关键词、被动与 AI 沿用 Godot 切片现有范围，见 [Godot README](../../godot/README.md)。未提交、推送或发布。

重新采集本批截图：

```sh
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --path godot --script res://scripts/capture_redrawn.gd -- /绝对路径/截图目录 --pack=wave4
```
