# 224 位式神结算复核（2026-11-09）

本轮按 Godot 构筑角色 ID 去重，复核 224 个原版式神位。其中 110 位在上一轮 114 位的清单之外。上一轮的式神也检查了新发现的目标、召唤生命周期、协战归属和牌区边界。共 38 位有可定位的实际规则改动。各组采用项目此前选定的国服基础牌文及已登记来源。指定的 2026-10-04 原版录像路径当前不可用。

## 实际结算修复

- 跳跳妹妹、不知火、烟烟罗共用战斗区离场流程。被替换的召唤物先离场，再登记新召唤物进场。百目鬼《诅咒之眼》的随机消灭只纳入存活式神。狸猫《饮啖醉饱》用手牌实际归属判定协战牌的瞬发和弃牌，同一实例只结算一次。 [番茄与烬染规则](34-tomato-fire-rules.md) · [官方协战说明](https://www.taptap.cn/moment/651548966009177378)
- 花鸟卷《入画》、星熊童子《酒碗》及小松丸、入内雀、入殓师、白泽、鲤鱼精、寻香行、於菊虫、海忍、黑童子、荒川之主、孔雀明王、书翁·志行的相关牌修正零勾、普通召唤物、帷幕和牌库顶交互。入殓师《离魂》在实际气绝后才发放织雪和抽牌。 [融合三位式神](62-fusion-trio-rules.md) · [尘世轮回](113-wave7-dusk-and-grove.md) · [龙渊秘境](114-dragon-abyss-rules.md)
- 椒图、琅琊子、三目、盗人神、荒·启命、童男童女及纸舞修正角色和式神范围、协战牌归属和附咒记录。纸舞《落纸》记录游记、咒纱、折敷、神通和己方勾玉等实际灵咒。三目的手牌计数接入《星坠》从手牌使用的极星，同一张牌的追加结算不重复计数。 [十二位基础规则](112-twelve-shikigami-rules.md) · [三目委托规则](107-sanmu-rules.md)
- 歌留多《花月乱舞》的随机伤害包含普通召唤物。初翎山风、吸血姬·曦忆、凤凰火·净羽、因幡辉夜姬及待宵姑获鸟的相应牌按式神范围执行移动、伤害、成长、消灭或迅捷。指定类效果保留合格的零勾式神和帷幕限制。 [花札祈梦牌文范围](116-stars-cosmos-hanafuda-rules.md)
- 龙珏《千江映月》、封阳君《封阳刀法》按实际战斗区式神判定追加破甲或连击。白藏主·砺心、鬼金羊及封阳君的相应选靶允许零勾式神，鬼金羊《鬼星之主》的直击门槛也只读前排式神。璇的极星允许合法零勾式神，专精《天璇》排除普通召唤物。白泽·缘起的成长、伤害和蓬莱倒计时采用式神范围。 [星缘与斗转](116-stars-cosmos-hanafuda-rules.md) · [命运抉择](117-destiny-rules.md)

另修复本项目原创雷音《连环雷》。按项目保留的设计文字，从敌方牌手与存活场上角色中抽取最多两个不同目标，各造成 2 点伤害。只有敌方牌手存活时只命中一次。Godot 实际用牌、AI 目标和演出反馈已通过。旧 JavaScript 模块在载入时仍被已有全库校验错误拦截。单牌 JavaScript 验证使用临时副本，仅在该副本隔离无关牌的校验错误。正式入口的校验规则保留。

## 角色与专项清单

表中 **修** 表示本轮调整了该角色的实际规则。检查数按角色专项脚本计，同一脚本的复跑和另行测试的共享场景不重复计入角色专项。四组总名单可通过原角色 ID 与 `godot/content/content.json` 对照。

### 经典版至鬼女红叶（73 位）

| 专项 | 式神 | 检查数 |
| --- | --- | ---: |
| `verify_steel_wind` | 大天狗·钢风 | 115 |
| `verify_yaoginshi` | 妖琴师 | 132 |
| `verify_datiangou` | 大天狗 | 115 |
| `verify_yimulian` | 一目连 | 128 |
| `verify_zhen` | 鸩 | 125 |
| `verify_phoenix` | 凤凰火 | 122 |
| `verify_peach` | 桃花妖 | 120 |
| `verify_firefly` | 萤草 | 126 |
| `verify_yaodao` | 妖刀姬 | 277 |
| `verify_shuten` | 酒吞童子 | 97 |
| `verify_bingyong` | 兵俑 | 112 |
| `verify_archer_mountain` | 白狼、山童 | 146 |
| `verify_judge_tide` | 判官、海坊主 | 147 |
| `verify_snow_crane` | 雪童子、姑获鸟 | 139 |
| `verify_xuenv` | 雪女 | 78 |
| `verify_dog_demon` | 犬神、茨木童子 | 148 |
| `verify_light_healer` | 青行灯、青坊主、座敷童子 | 600 |
| `verify_yijin` | 以津真天 | 154 |
| `verify_poison_pair` | 跳跳弟弟、清姬 | 667 |
| `verify_book_jue` | 书翁、觉 | 139 |
| `verify_fortune_pair` | 青蛙瓷器、山兔 | 170 |
| `verify_fox_suzuka` | 妖狐、铃鹿御前 | 91 |
| `verify_tomato_fire` | 跳跳妹妹 **修**、不知火 **修** | 351 |
| `verify_sun_smoke` | 日和坊、烟烟罗 **修** | 163 |
| `verify_movement` | 小鹿男、镰鼬、鸦天狗 | 244 |
| `verify_armor_blood` | 久次良、吸血姬 | 154 |
| `verify_huang` | 荒 | 594 |
| `verify_mengpo` | 孟婆 | 203 |
| `verify_huibishou` | 惠比寿 | 50 |
| `verify_coin_river` | 铁鼠、河童 | 112 |
| `verify_wind_night_mask` | 山风、泷夜叉姬、般若 | 127 |
| `verify_eye_crab` | 百目鬼 **修**、蟹姬 | 132 |
| `verify_bond_dream` | 缘结神、食梦貘 | 124 |
| `verify_monk_cleaner` | 独眼小僧、垢尝 | 102 |
| `verify_tree_sakura` | 人面树、樱花妖 | 167 |
| `verify_owl_insect` | 薰、巫蛊师 | 148 |
| `verify_moon_bamboo` | 追月神、辉夜姬 | 189 |
| `verify_pipe_fox` | 管狐、白藏主 | 164 |
| `verify_oni_asura` | 鬼童丸、阿修罗 | 167 |
| `verify_rebirth` | 九命猫、荒骷髅 | 129 |
| `verify_fox_lotus` | 玉藻前、帝释天 | 164 |
| `verify_raccoon` | 狸猫 **修** | 89 |
| `verify_samurai` | 武士之灵 | 89 |
| `verify_mountain_realm` | 不见岳 | 123 |
| `verify_maple` | 鬼女红叶 | 115 |

该组角色专项 45 组，合计 7,848 项。

### 花鸟卷至荒川之主及龙渊秘境（57 位）

| 专项 | 式神 | 检查数 |
| --- | --- | ---: |
| `verify_paint` | 花鸟卷 **修** | 107 |
| `verify_star_bear` | 星熊童子 **修** | 138 |
| `verify_pine` | 小松丸 **修** | 116 |
| `verify_sparrow` | 入内雀 **修** | 174 |
| `verify_headless` | 首无 | 118 |
| `verify_yaksha` | 夜叉 | 141 |
| `verify_puppet` | 傀儡师 | 103 |
| `verify_enma` | 阎魔 | 137 |
| `verify_weaver` | 入殓师 **修** | 136 |
| `verify_goldfish` | 金鱼姬 | 124 |
| `verify_vine` | 藤姬 | 104 |
| `verify_wind_raccoon` | 风狸 | 140 |
| `verify_otakemaru` | 大岳丸 | 120 |
| `verify_onikiri` | 鬼切 | 109 |
| `verify_house` | 天井下 | 112 |
| `verify_three_tail` | 三尾狐 | 105 |
| `verify_glutton` | 饿鬼 | 107 |
| `verify_doll` | 丑时之女 | 102 |
| `verify_spider_lily` | 彼岸花 | 133 |
| `verify_cotton` | 一反木绵 | 120 |
| `verify_butterfly` | 蝴蝶精 | 151 |
| `verify_garuda` | 迦楼罗 | 133 |
| `verify_yitiao` | 一条 | 135 |
| `verify_jorogumo` | 络新妇 | 127 |
| `verify_whale` | 化鲸 | 140 |
| `verify_crocodile` | 影鳄 | 104 |
| `verify_baize` | 白泽 **修** | 198 |
| `verify_susanoo` | 须佐之男 | 108 |
| `verify_koi_fragrance` | 鲤鱼精 **修**、寻香行 **修** | 279 |
| `verify_toxic_pair` | 虫师、蝎女 | 168 |
| `verify_silk_ninja` | 於菊虫 **修**、海忍 **修** | 181 |
| `verify_sea_butterfly` | 灵海蝶 | 148 |
| `verify_lantern` | 古笼火 | 135 |
| `verify_futakuchi` | 二口女 | 185 |
| `verify_black_white` | 黑童子 **修**、白童子 | 204 |
| `verify_two_faces` | 两面佛 | 124 |
| `verify_box_maiden` | 匣中少女 | 141 |
| `verify_yujiazhu` | 御馔津 | 162 |
| `verify_mianqiling` | 面灵气 | 183 |
| `verify_yi` | 弈 | 190 |
| `verify_arakawa` | 荒川之主 **修** | 83 |
| `verify_dusk_grove` | 孔雀明王 **修**、季、判官·悬墨、言灵、姑获鸟·玉响、桃花妖·落英 | 290 |
| `verify_dragon_abyss` | 鸦天狗·秋叶、书翁·志行 **修**、祸津神、四饼、大岳丸·渝心、螭璃 | 343 |

该组角色专项 43 组，合计 6,358 项。

### 派系、烹饪、启悟及赐能（52 位）

| 专项 | 式神 | 检查数 |
| --- | --- | ---: |
| `verify_red_purple` | 火取魔、源九郎狐 | 265 |
| `verify_blue_green` | 樱雪姬、净琉璃御前 | 221 |
| `verify_mirror_song` | 云外镜、松 | 336 |
| `verify_charged_pair` | 万年竹、数珠 | 163 |
| `verify_zhenjian_duel` | 季沧海、无尘 | 225 |
| `verify_rednight_walnut` | 宁红夜、土御门胡桃 | 313 |
| `verify_ape_sleeve` | 川猿、小袖之手 | 194 |
| `verify_cooking_core` | 五丸、食灵 | 152 |
| `verify_sugar_cat` | 猫掌柜、饴细工 | 231 |
| `verify_rabbit_tide` | 兔丸、千姬 | 126 |
| `verify_hair_power` | 食发鬼 | 80 |
| `verify_music_fire` | 紧那罗、铃彦姬 | 138 |
| `verify_serpent_ghost` | 鬼使黑·鬼使白、八岐大蛇 | 136 |
| `verify_essence_feast` | 粉婆婆、椒图 **修**、饭笥 | 278 |
| `verify_fear_wing` | 天逆每 | 119 |
| `verify_wisdom_lamp` | 慧明灯 | 115 |
| `verify_langyazi` | 琅琊子 **修** | 91 |
| `verify_commission` | 三目 **修** | 59 |
| `verify_guishihei` | 鬼使黑（湮灭双生独立版） | 75 |
| `verify_treasure` | 盗人神 **修** | 87 |
| `verify_insight` | 天照 | 60 |
| `verify_astral` | 荒·启命 **修** | 53 |
| `verify_chen` | 辰 | 65 |
| `verify_rain` | 雨女 | 54 |
| `verify_bone` | 骨女 | 55 |
| `verify_water_moon` | 追月神·水月 | 86 |
| `verify_lunar_cat_izanami` | 月读、武士之灵·猫侍、伊邪那美 | 89 |
| `verify_yanmie_trio` | 鬼使白、萤草·蒲蒲、童男童女 **修** | 142 |
| `verify_charm_realms` | 纸舞 **修**、二瞳、阿莱娜 | 145 |
| `verify_gift_energy` | 泷、烟烟罗·浮缈、日和坊·晴阳 | 208 |

该组角色专项 30 组，合计 4,361 项。

### 重制角色、商店、花札与命运抉择（42 位）

| 专项 | 式神 | 检查数 |
| --- | --- | ---: |
| `verify_scroll_wind_faction` | 蜃气楼、一目连·灵籁、山兔／座敷童子、面灵气·心宿、猫川、攸宁 | 300 |
| `verify_wave7_reworks` | 犬神·历战、妖刀姬·呪刃、青行灯·辉火、酒吞童子·忘空、茨木童子·旅立、青坊主·凡尘 | 376 |
| `verify_star_realms` | 小鹿男·千守、缘结神·遂愿、铁鼠·豪贾、以津真天·千寻、白藏主·砺心 **修**、鬼金羊 **修**、胧车 | 404 |
| `verify_cosmos_dragons` | 龙珏 **修**、封阳君 **修** | 78 |
| `verify_cosmos_native` | 禅心云外镜、贫乏神、猫掌柜·焕宴、烬天玉藻前 | 191 |
| `verify_cosmos_market` | 招财猫 | 38 |
| `verify_hanafuda` | 歌留多 **修**、初翎山风 **修**、吸血姬·曦忆 **修**、樱花妖·璃景、凤凰火·净羽 **修**、因幡辉夜姬 **修**、待宵姑获鸟 **修** | 487 |
| `verify_slayer_duo` | 炭治郎／祢豆子 | 57 |
| `verify_coffin` | 跳跳哥哥 | 34 |
| `verify_time_rewind` | 时曜泷夜叉姬 | 70 |
| `verify_shenqi_huang` | 神启荒 | 78 |
| `verify_xuan` | 璇 **修** | 183 |
| `verify_grudge` | 御怨般若 | 70 |
| `verify_baize_yuanqi` | 白泽·缘起 **修** | 91 |
| `verify_himiko` | 卑弥呼 | 69 |
| `verify_luohou` | 罗睺 | 210 |

该组角色专项 16 组，合计 2,736 项。

角色专项统计 134 套，共 21,303 项；生产改动 38 位。

## 集成与审计

Godot 4.6.3 的相关共享回归通过，覆盖战斗、护甲与破甲、瞬发、抽牌、协战、战斗状态和法术演出。实际鼠标检查覆盖 1280×800 与 1600×740 两种窗口。Web 导入和本地导出通过。

`npm run audit:rules` 返回 1。卡牌有 3 张已知近似、265 张未核对、1,858 张待核验和 208 张已有资料及可执行原生规则，保留 18 条诊断。《连环雷》修复后从已知近似归入未核对的项目自创牌。仍带近似标记的《飞扑撕咬》《命运骰子》《星火点点》来自旧扩展的自创构筑，仓库现存文字未提供足够的原版或独立设计规则。复杂触发的先后顺序与随机权重仍保留待核。 [旧衍生卡组来源说明](34-tomato-fire-rules.md) · [审计范围](116-stars-cosmos-hanafuda-rules.md)
