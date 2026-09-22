# 2026-09-12 测试自由验收

本轮增量：胜利奖励 50→300、失败 20→150；全卡试用不写收藏；构筑和开局统一检查所有权。原来只能收集后测试 SSR，现在可开启试用直接组入，关闭试用则保留选择并提示收藏不足。

`npm test`：161 / 161；`npm run smoke`：30 / 30 完成、崩溃/非法命令/软锁均 0；`npm run audit`：103 检查、0 错误。cache:sync 已同步。

实际浏览器回归：选择未收藏 SSR，验证试用开关持久化、关掉试用阻止开局、重新开启允许开局、收藏存储不变。桌面 1440×1000、平板 820×1180、移动 390×844 检查无横向溢出并人工查看截图：

- [桌面](trial-desktop.png)
- [平板](trial-tablet.png)
- [移动](trial-mobile.png)

试用构筑在桌面完整对局，11 次升勾、14 次出牌、8 次攻击、12 次结束回合，惜败结算实际发放 150 御札，页面与控制台报错均 0，见 [完整日志](trial-match.log)。本轮未重复三档完整战斗及三次 WebGL 生命周期验证；这些不受本轮收藏入口改变，先前验收记录在 redesign-acceptance.md。

Godot 实测命令见 prototypes/godot-content-probe/README.md，输出 GODOT_CONTENT_OK units=8 cards=138。只验证数据导入，不等同可玩迁移；Unity 尚未建立工程或做性能实测。

闪卡独立 DOM 夹具验证：指针视差实际 1.75px，收敛后 framePending=false；切换 reduced-motion 后图像 transform=none、activeCards=0、framePending=false。见 trial-holo-check.log 与 trial-holo.png（夹具截图，不是实际对局）。媒体偏好切换需等待浏览器派发 change 和更新 CSS，验收按最终状态判断。
