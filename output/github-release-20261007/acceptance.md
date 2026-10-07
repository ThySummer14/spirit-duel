# GitHub 推送前验收与清理 · 2026-10-07

本次同步已完成的原版规则修复、目标与选择交互、AI、回归脚本及研究记录。具体角色范围与未核验边界以 [并行验收](../godot-parallel-20261007/acceptance.md) 和各轮研究记录为准；不表示全库已还原。

## 本次验证

- Godot 4.6.3 stable 导入和 Web 导出成功，Pages 成品 89.1 MiB。见 [构建日志](web-build.log)、[导入日志](web-import.log)、[导出日志](web-export.log)。
- `npm test`：164 通过、0 失败；见 [日志](node-tests.log)。
- `npm run audit`：385 checks、0 errors；见 [日志](catalog-audit.log)。
- 原生完整验证及 143 场对局已通过，详见 [本轮全量记录](../godot-parallel-20261007/full-verify.log)。
- 全库规则审计仍按约束失败，旧近似项和未核验项未清零，详见 [还原审计](../godot-parallel-20261007/rule-fidelity.json)。

## 清理结果

按用户授权删除了 3969 个可重建文件，共 1,130,269,356 字节（1077.91 MiB）。

清理范围为 `.build/godot-web-src/`、`.build/pages/`、技能录像原始 AVI，以及战斗 MP4 已编码的 64 张连续帧。两段最终 MP4 均再次完整解码通过；最终录像、验收截图、采样时间、研究资料、源素材、构建工具和正在使用的 Godot 导入缓存保留。详细路径、字节数与最终录像 SHA-256 见 [清理清单](cleanup.json)。

构建副本可重新运行 `scripts/build-pages.py` 生成；清理只涉及本项目目录。官方原始卡图继续保留本地并加入忽略规则。
