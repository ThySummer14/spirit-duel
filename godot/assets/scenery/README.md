# 环境背景

四张 PNG 由用户指定的 Botcf Image skill、`gpt-image-2.5` 生成，尺寸均为 1536×1024。参照用户录像的月夜港口、青金云水、绀紫室内和浮灯召唤氛围。角色、文字、按钮、卡面和交互控件由游戏现有资源与 Godot 绘制。

| 游戏文件 | 场景 | 生成原图 |
| --- | --- | --- |
| `port.png` | 主城 | `/Users/thysummer/工作流/图片/2026-10-04-灵枢环境美术补跑/02.png` |
| `battle.png` | 战场 | `/Users/thysummer/工作流/图片/2026-10-04-灵枢环境美术补跑/01.png` |
| `table.png` | 编组、角色档案、构筑、商店 | `/Users/thysummer/工作流/图片/2026-10-04-灵枢环境美术/03.png` |
| `summon.png` | 五张秘闻揭晓 | `/Users/thysummer/工作流/图片/2026-10-04-灵枢环境美术补跑/03.png` |

提示词与风格选型保存在 `output/video-reference-20261004/art-prompts.txt`、`art-direction.md`，执行记录在 `art-generation.log` 和 `art-retry.log`。

`scene_backdrop.gd` 按窗口比例居中裁切，图片缺失时采用程序绘制背景。图片没有内嵌文字、角色或按钮，后续替换同名文件即可更新环境美术。
