# GitHub Pages 网页验收 · 2026-10-06

目标：将最新 Godot 界面及技能演出发布到 `/play/`，保留原 HTML/JS 根入口。

本地构建：Godot 4.6.3 stable，官方单线程 Web release 模板。资源包约 49 MiB，WASM 约 36 MiB，整站 89.0 MiB；网页构建使用 768 长边、质量 0.8 的角色导入副本，原始资产与导入设置未修改。导入、导出、稳定版启动日志没有引擎或脚本错误。

`npm test`：163 通过、0 失败、0 跳过；`npm run audit`：385 checks、0 errors；`git diff --check` 通过。工作流 YAML 与安装 shell 解析通过。

Playwright 在真实浏览器（1600×900）载入完整导出包，检查主城、250 位角色入口、编成角色替换、起手更换、升级、出牌、AI 回合与出击。浏览器控制台没有 error/warning。截图保存在同目录；在线发布结果补记于下方。

本地持久化实测：编成将大天狗换为雪女，出战后刷新网页，主城仍显示妖刀姬 / 酒吞童子 / 兵俑 / 雪女。实际战报确认打出「醉里乾坤」、抽到「天狗风乱」；妖刀姬出击，敌方大岳丸受 3 伤害、己方受 2 反击。AI 回合正常推进至第 2 轮。

保留入口的真实浏览器检查发现既有 `packBadge` 在声明前 append，导致名录初始化中断。已将 append 移至声明后，并通过既有缓存脚本同步所有模块版本；规则测试仍 163 通过，审计仍 385/0，本地重新显示 250 个角色按钮。

发布提交 `3470222`，修复原入口提交 `f2c4992`。两次 GitHub Actions 均成功：

- https://github.com/ThySummer14/spirit-duel/actions/runs/37461310396
- https://github.com/ThySummer14/spirit-duel/actions/runs/37461704738

Linux 构建也完成导入、导出，整站 89.0 MiB；Pages 正式地址 https://thysummer14.github.io/spirit-duel/play/ 。线上浏览器实际载入单线程 WASM、完整资源并进入游戏，未出现引擎或脚本报错。

## 最终线上操作结果

实际加载正式域名的导出包，使用浏览器真实点击：兵俑升至 1 勾玉 → 打出「古尘之盾」 → 妖刀姬获得 5 护盾 → 兵俑出击对方核心，生命 30→29 → 结束回合 → AI 大天狗进入前线攻击兵俑 → 正常回到第 2 轮玩家回合。实际战报与护盾、生命、鬼火的变化吻合，浏览器控制台 0 errors / 0 warnings。

正式域名根入口版本 `ae8562bd`：250 个角色按钮、250 张角色图片均完成加载，`pageerror` / console error 均为空；原入口的声明顺序修复已在线生效。

证据截图：[线上主城](live-headless-menu.png)、[线上出牌战报](live-headless-card-log.png)、[线上出击与 AI 回合](live-headless-turn-log.png)、[原入口 250 角色](live-legacy.png)、[本地刷新后保持阵容](local-lineup-persisted.png)、[本地技能与出击战报](local-commands.png)。

测试以电脑浏览器 1600×900 为准，本轮未验收手机触屏或 Safari。首次载入完整资源需要等待下载；存档、收藏按当前浏览器保存，与本地客户端隔离。GitHub Pages 仅发布构建输出，不包含验收目录。
