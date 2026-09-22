# Godot 内容契约探针

此目录只验证原型内容能否被 Godot 读取，不是第二套规则引擎，也不是可玩的 Godot 版本。

在仓库根目录运行 `node scripts/export-godot-content.mjs` 重新生成 `content.json`，然后运行：

```sh
/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-content-probe --script verify.gd
```

验证 JSON schema、重复卡 ID 与角色归属。2026-09-12 本机 4.8.dev5 输出 `GODOT_CONTENT_OK units=8 cards=138`。导出文件来自原创内容，不含参考项目的官方美术。效果名称能作为数据保留，但 JS 效果执行器、时序与存档兼容性尚未移植或验证。
