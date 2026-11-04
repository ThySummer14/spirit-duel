# 原版完整卡面

按用户要求，将已有本地原版素材用于游戏内行动牌，保留透明边缘及战斗、法术、形态、幻境各自的外框。目前覆盖山风、泷夜叉姬、般若、铁鼠、河童、百目鬼、蟹姬、缘结神、食梦貘、独眼小僧、垢尝、人面树、樱花妖、薰、巫蛊师、追月神、辉夜姬、管狐、白藏主、鬼童丸、阿修罗、九命猫、荒骷髅、玉藻前、帝释天、狸猫、武士之灵、不见岳、鬼女红叶、花鸟卷、星熊童子、小松丸、入内雀、首无、夜叉、傀儡师、阎魔、入殓师、金鱼姬、藤姬、风狸、大岳丸、鬼切、天井下、三尾狐、饿鬼、丑时之女、彼岸花、一反木绵、蝴蝶精、迦楼罗、一条、络新妇、化鲸、影鳄、白泽、须佐之男、鲤鱼精、寻香行、虫师、蝎女、於菊虫、海忍、灵海蝶、古笼火520张主体牌（65位角色）。幸运钱币、妖酒、魂鬼、织雪及觉醒·傀儡术派生形态、金鱼、藤色、幻役及分身·风狸、八尺琼曲玉、挪移、三种鬼斩、妖怪屋及其两种灵力、饱腹、勤勉修行、蛛群、母亲的守护、鬼鳄、达知、雷冢未找到独立完整素材，继续使用现有绘制。

素材来自项目内 `art-reference-official/卡面-按版本/`，按内容ID复制，文件未经裁切或重绘。同步命令：

```sh
python3 scripts/sync-godot-card-art.py shanfeng longyechaji banruo tieshu hetong
python3 scripts/sync-godot-card-art.py baimugui xieji
python3 scripts/sync-godot-card-art.py jieshen shimengmo
python3 scripts/sync-godot-card-art.py duyanxiaoseng gouchang
python3 scripts/sync-godot-card-art.py renmianshu yinghuayao
python3 scripts/sync-godot-card-art.py xun wuguishi
python3 scripts/sync-godot-card-art.py zhuiyueshen huiyeji
python3 scripts/sync-godot-card-art.py guanhu baizangzhu
python3 scripts/sync-godot-card-art.py gitongwan axiuluo
python3 scripts/sync-godot-card-art.py jiumingmao huangkulou
python3 scripts/sync-godot-card-art.py yuzaoqian dishitian
python3 scripts/sync-godot-card-art.py limao
python3 scripts/sync-godot-card-art.py wushizhiling bujianyue gunvhongye
python3 scripts/sync-godot-card-art.py huaniajuan xingxiongtongzi xiaosongwan
python3 scripts/sync-godot-card-art.py rurineque shouwu yecha
python3 scripts/sync-godot-card-art.py kuileishi yanmo rulianshi
python3 scripts/sync-godot-card-art.py jinyuji tengji fengli
python3 scripts/sync-godot-card-art.py dayueling guiqie tianjingxia
python3 scripts/sync-godot-card-art.py sanweihu egui choushizhinv
python3 scripts/sync-godot-card-art.py biyehua
python3 scripts/sync-godot-card-art.py yifanmumian
python3 scripts/sync-godot-card-art.py hudiejing
python3 scripts/sync-godot-card-art.py jialouluo
python3 scripts/sync-godot-card-art.py yitiao
python3 scripts/sync-godot-card-art.py luoxinfu
```

后续修复角色时以同一命令追加对应 `unitId`，没有素材的牌保留原有显示。素材为网易《阴阳师：百闻牌》官方卡面。战斗数值、支付、瞬发/响应标记仍读取当前规则；卡牌检视另外显示当前完整效果，避免图片中的静态文字遮蔽增强或已接入的版本差异。

怨缚草人、诅咒草人、替身草人三张原客户端完整PNG另从[原版图集](https://moegirl.icu/百闻牌:丑时之女)取得，原文件和来源说明保存在`output/godot-fox-glutton-doll-20261021/doll/`，未裁切或重绘，按`doll-resent`、`doll-curse`、`doll-substitute`接入真实召唤物。该批累计379张原版PNG；其后彼岸花、一反木绵、蝴蝶精、迦楼罗、一条和络新妇各增加8张，当前共427张。逐字节一致清单见各批`card-art-manifest.json`。

化鲸8张完整主体牌按27801–27808原PNG同步；母亲的守护中文派生完整原图仍缺失。

```sh
python3 scripts/sync-godot-card-art.py huajing
```

影鳄8张完整主体牌按27901–27908原PNG同步；鬼鳄旧版中文派生完整原图仍缺失。

```sh
python3 scripts/sync-godot-card-art.py yinge
```

白泽8张完整主体牌按27301–27308原PNG同步；达知中文派生完整原图仍缺失。当前总计451张PNG。

```sh
python3 scripts/sync-godot-card-art.py baize
```

须佐之男8张完整主体牌按28101–28108原PNG同步；雷冢中文独立完整原图仍缺失，官方曝光词条仅用于规则核对。当批累计459张原版PNG。

```sh
python3 scripts/sync-godot-card-art.py xuzuozhinan
```

鲤鱼精、寻香行16张完整主体牌按28201–28208、28801–28808原PNG同步；不混入后续协战牌。当批累计59位角色472张主体、3张草人派生，合计475张原版PNG。

虫师、蝎女16张完整主体牌按28301–28308、28401–28408原PNG同步；百蝎之毒采用完整PNG3/9。展翅虫群本地无独立完整原图，继续用虫师素材呈现真实1/3召唤物。当前共61位角色488张主体、3张草人派生，合计491张原版PNG。

於菊虫、海忍16张完整主体牌按28501–28508、28601–28608原PNG同步。当前共63位角色504张主体、3张草人派生，合计507张原版PNG。

```sh
python3 scripts/sync-godot-card-art.py yujuchong hainren
```

灵海蝶8张完整主体牌按28701–28708原PNG同步；碧海之蝶采用完整PNG与官网基础卡库的2/6版本。当前共64位角色512张主体、3张草人派生，合计515张原版PNG。

```sh
python3 scripts/sync-godot-card-art.py linghaidie
```

古笼火8张完整主体牌按29301–29308原PNG同步，已执行Godot源项目素材导入并验证真实纹理路径。当前共65位角色520张主体、3张草人派生，合计523张原版PNG。

```sh
python3 scripts/sync-godot-card-art.py gulonghuo
```
