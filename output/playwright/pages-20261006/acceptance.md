# GitHub Pages 网页验收 · 2026-10-06

目标：将最新 Godot 界面及技能演出发布到 `/play/`，保留原 HTML/JS 根入口。

本地构建：Godot 4.6.3 stable，官方单线程 Web release 模板。资源包约 49 MiB，WASM 约 36 MiB，整站 89.0 MiB；网页构建使用 768 长边、质量 0.8 的角色导入副本，原始资产与导入设置未修改。导入、导出、稳定版启动日志没有引擎或脚本错误。

`npm test`：163 通过、0 失败、0 跳过；`npm run audit`：385 checks、0 errors；`git diff --check` 通过。工作流 YAML 与安装 shell 解析通过。

Playwright 在真实浏览器（1600×900）载入完整导出包，检查主城、250 位角色入口、编成角色替换、起手更换、升级、出牌、AI 回合与出击。浏览器控制台没有 error/warning。截图保存在同目录；在线发布结果补记于下方。
