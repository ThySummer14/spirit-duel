class_name KeywordGlossary
extends RefCounted
## 关键词显示名与一句话释义，供卡面类型条与检视面板使用。

const ENTRIES := {
	"instant": ["瞬发", "己方回合首张瞬发牌费用为 0。"],
	"response": ["响应", "对方行动匹配时可打断，后出先结算。"],
	"pierce": ["贯通", "击破目标后，溢出伤害转给敌方核心。"],
	"stun": ["眩晕", "目标无法出击与反击，持有者回合结束时递减。"],
	"projectile": ["投射", "伤害优先命中敌方前线；前线为空时打核心。"],
	"combo": ["连击", "目标存活时追加一次等量伤害。"],
	"first-strike": ["先攻", "首次伤害即击破目标时，不受反击。"],
	"cook": ["烹饪", "收集食材，集齐后全体 +1/+1。"],
	"unyielding": ["不屈", "受到致命伤害时保留 1 点生命。"],
	"remote": ["远程", "原地出击，不进入前线，也不受反击。"],
	"crit": ["暴击", "本次出击伤害翻倍。"],
	"origin": ["起源", "将同名牌洗回牌库。"],
	"charged": ["蓄力", "附着式神，回合开始推进，成熟后自动结算。"],
	"divination": ["占卜", "检视牌库顶数张，选一张置顶。"],
	"fortune": ["运势", "掷骰达到阈值时触发额外效果。"],
	"encourage": ["鼓舞", "下一次出击获得攻击与护盾加成。"],
	"chain": ["连引", "抽取牌库中下一张同式神牌。"],
	"bestow": ["赐能", "消耗充能解锁强化效果。"],
	"burst": ["爆能", "出击时消耗全部充能，每点转为攻击加成。"],
	"countdown": ["倒计时", "幻境每回合递减，归零时触发。"],
	"coop": ["协战", "本回合已有其他友方出击时获得加成。"],
	"charge": ["充能", "回合开始时积累充能。"],
	"fusion": ["融合", "重复使用同名牌叠加攻防。"],
	"incarnation": ["化身", "满足条件时自动免费使用。"],
	"focus": ["专注", "本回合首张牌时追加抽牌。"],
	"nightfall": ["入夜", "预约在指定回合生效的延迟效果。"],
}


static func label(keyword: String) -> String:
	var entry: Array = ENTRIES.get(keyword.to_lower(), [])
	return str(entry[0]) if not entry.is_empty() else ""


static func detail(keyword: String) -> String:
	var entry: Array = ENTRIES.get(keyword.to_lower(), [])
	return str(entry[1]) if not entry.is_empty() else ""
