兔丸250 / 千姬247，共16张主体牌；派生海原贝戟1个真实召唤单位、咏流1张法术。`prepare.py`已执行，仅准备本批overlay、原图和manifest；`integrate-runtime.py`由子任务只准备，现已由主任务顺序执行并补齐can_use/AI/status共享接入。

共享接入由主任务顺序完成：

- `VerifiedRules.RabbitTide` preload，event/card_announced/resolve_action转发；GameState resolve_frame转发。
- hand投影调用 `describe_card(gs,owner,card,inst)`；can_play调用`can_use`；valid_targets优先`targets`；AI优先`score_card`；状态标记`marks`。
- `_offer_attack_responses`在原响应前调用`before_combat`。它保存一次战斗continuation，实际使用生成的中立食物牌，待食物/料理之魂触发完成后resume，不重复扣火、不重新吸收鼓舞。
- `Light.roll`的`fortune-result`新增`sourceIndex`，只观察重掷后的最终失败。基础兔丸每全局回合一次，觉醒兔丸每次失败；其他式神的失败不触发。
- `begin_turn`在真实回合开始计数之后调用；全局resolver清理`remove_departed`；千姬第一己方回合召贝戟。
- `Weaver.leave_front`支持`rtSpear`，召唤死亡回调`RabbitTide.summoned_knockout`，形态/死亡/移除后刷新帷幕。`Combat.has(veil)`读取`rtSpearVeil`。
- 贝戟0/2，所有普通离场只给最多1张手中咏流。召唤新贝戟是真实例；觉醒+4仅一次作用于现存及未来贝戟；塑潮使者是实际远程攻击，永生之汐分别处理进场眩晕、在场帷幕、离场2AOE。

`CookingRules`依赖：监听`cooking`与`food-used`；`gain_unknown`、`auto_use_generated`、`cook`真实食物pipeline；`cookingSeenKinds`只在真正获得食材时记录。食谱mountain投射3/sea牌手回血5/vegetable压制-3/-3；不明食材不算第四种增强。咏流实例在千姬使用牌时获得瞬发，与觉醒持续瞬发分别判定。

已知待核：中文派生完整tooltip；原客户端响应和运势重掷/幸运成功倍增的复杂全序；解忧特殊移除不产生咏流等交叉边界。当前元数据保留`verificationPending`，不宣称全库还原。

本次实际规则检查：Godot4.6.3 `--headless --script res://scripts/verify_rabbit_tide.gd -- --rules-only`，`RABBIT_TIDE checks=126 failures=0`，日志`rules-only.log`无SCRIPT ERROR。原生双尺寸验证已通过：1280×800与1600×740，共138项检查、0失败，native.log无SCRIPT ERROR，6张截图已逐图目检。

千姬明确的首个己方回合能力不依赖升勾，已用实际GS.create覆盖4个编成位置及双方首回合，并用真实回合流验证后续不重复、不补发；压制/气绝反例通过。普通active能力仍保留各自激活条件，原客户端具体触发全序继续待核。

派生图已view_image核对：日文原版相关卡贝戟0/2、咏流1勾。贝戟实体与Content定义art统一为`assets/official/tokens/qianji-spear.png`；完整来源图和SHA256见`derivative-art-evidence.json`，咏流图仅作研究证据。模块及专项在此冻结，主任务可统一merge/build。
