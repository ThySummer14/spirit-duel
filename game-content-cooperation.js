// 协战牌保持单一牌实例，使用时才确定式神与牌面。
export const COOP_CARD_DEFINITIONS = Object.freeze([
  {
    "id": "c101109",
    "name": "刃影鹤唳",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "yaodaoji",
      "guniao"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n妖刀姬－刀影叠岚\n姑获鸟－鹤唳回风",
    "officialText": "选择使用一项：\n妖刀姬－刀影叠岚\n姑获鸟－鹤唳回风",
    "cardArt": "assets/official/cards/c101109.png",
    "coopFaces": [
      {
        "id": "c101109",
        "unitId": "yaodaoji",
        "name": "刀影叠岚",
        "level": 2,
        "coopFaceId": "c101109:yaodaoji",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "auto",
        "effect": "coop-first-blade-awake",
        "value": {
          "attack": 0,
          "hp": 1
        },
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-blade-awake",
            "target": "auto",
            "value": {
              "attack": 0,
              "hp": 1
            }
          }
        ],
        "text": "觉醒（+0/+1）。妖刀姬对敌方牌手造成伤害时，本回合她的战斗牌获得瞬发，并额外获得+1力量/+1护甲。羁绊：姑获鸟发起一次攻击。",
        "officialText": "觉醒（+0/+1）。妖刀姬对敌方牌手造成伤害时，本回合她的战斗牌获得瞬发，并额外获得+1力量/+1护甲。羁绊：姑获鸟发起一次攻击。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "officialSource": "https://www.taptap.cn/moment/712763425637270499",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c101109.png",
        "coopFaceArt": "assets/official/cooperation/c101109-yaodaoji.png"
      },
      {
        "id": "c101109",
        "unitId": "guniao",
        "name": "鹤唳回风",
        "level": 2,
        "coopFaceId": "c101109:guniao",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "auto",
        "effect": "coop-first-crane-awake",
        "value": {
          "attack": 1,
          "hp": 1
        },
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-crane-awake",
            "target": "auto",
            "value": {
              "attack": 1,
              "hp": 1
            }
          }
        ],
        "text": "觉醒（+1/+1）。姑获鸟攻击后移回准备区，获得1点力量并恢复全部生命。羁绊：妖刀姬发起一次攻击。",
        "officialText": "觉醒（+1/+1）。姑获鸟攻击后移回准备区，获得1点力量并恢复全部生命。羁绊：妖刀姬发起一次攻击。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "officialSource": "https://www.taptap.cn/moment/712763425637270499",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c101109.png",
        "coopFaceArt": "assets/official/cooperation/c101109-guniao.png"
      }
    ],
    "evidence": "research-notes/118-cooperation-rules.md#日服对照牌面",
    "officialSource": "https://www.taptap.cn/moment/712763425637270499",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c102111",
    "name": "狂歌豪情",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "jutun-tongzi",
      "caitongzi"
    ],
    "level": 1,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n酒吞童子－醉酒当歌\n茨木童子－地狱豪焰",
    "officialText": "选择使用一项：\n酒吞童子－醉酒当歌\n茨木童子－地狱豪焰",
    "cardArt": "assets/official/cards/c102111.png",
    "coopFaces": [
      {
        "id": "c102111",
        "unitId": "jutun-tongzi",
        "name": "醉酒当歌",
        "level": 1,
        "coopFaceId": "c102111:jutun-tongzi",
        "type": "combat",
        "typeLabel": "战斗牌",
        "target": "auto",
        "effect": "coop-first-drink",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-drink",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "不屈。对酒吞童子造成3点伤害，使其获得等量护甲。羁绊：获得一张茨木童子当前等级的战斗牌。",
        "officialText": "不屈。对酒吞童子造成3点伤害，使其获得等量护甲。羁绊：获得一张茨木童子当前等级的战斗牌。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [
          "unyielding"
        ],
        "officialSource": "https://www.taptap.cn/moment/654370956394889270",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c102111.png",
        "coopFaceArt": "assets/official/cooperation/c102111-jutun-tongzi.png"
      },
      {
        "id": "c102111",
        "unitId": "caitongzi",
        "name": "地狱豪焰",
        "level": 1,
        "coopFaceId": "c102111:caitongzi",
        "type": "combat",
        "typeLabel": "战斗牌",
        "target": "auto",
        "effect": "coop-first-flame",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-flame",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "本次战斗击杀敌方式神时，茨木童子本局随机获得一种未获得的豪焰。羁绊：酒吞童子对自己造成1点伤害，茨木童子获得2点护甲。",
        "officialText": "本次战斗击杀敌方式神时，茨木童子本局随机获得一种未获得的豪焰。羁绊：酒吞童子对自己造成1点伤害，茨木童子获得2点护甲。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "officialSource": "https://www.taptap.cn/moment/654370956394889270",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c102111.png",
        "coopFaceArt": "assets/official/cooperation/c102111-caitongzi.png"
      }
    ],
    "evidence": "research-notes/118-cooperation-rules.md#日服对照牌面",
    "officialSource": "https://www.taptap.cn/moment/654370956394889270",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c106112",
    "name": "冰霜永冻",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "xuenv",
      "xuetongzi"
    ],
    "level": 1,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n雪女－冰封\n雪童子－雪刃",
    "officialText": "选择使用一项：\n雪女－冰封\n雪童子－雪刃",
    "cardArt": "assets/official/cards/c106112.png",
    "coopFaces": [
      {
        "id": "c106112",
        "unitId": "xuenv",
        "name": "冰封",
        "level": 1,
        "coopFaceId": "c106112:xuenv",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "enemy-unit",
        "effect": "coop-first-ice-seal",
        "value": 1,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-ice-seal",
            "target": "enemy-unit",
            "value": 1
          }
        ],
        "text": "眩晕一个敌方式神，获得一张雪球。羁绊：雪童子攻击该式神一次。",
        "officialText": "眩晕一个敌方式神，获得一张雪球。羁绊：雪童子攻击该式神一次。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c106112.png",
        "coopFaceArt": "assets/official/cooperation/c106112-xuenv.png"
      },
      {
        "id": "c106112",
        "unitId": "xuetongzi",
        "name": "雪刃",
        "level": 1,
        "coopFaceId": "c106112:xuetongzi",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-first-snow-blade",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-snow-blade",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "敌方角色陷入眩晕时，按眩晕敌方角色的数量使雪童子获得以下效果直到回合结束。一名时获得1点力量，两名时获得迅捷，至少三名时获得贯通。羁绊：入场时雪女眩晕一个敌方式神。",
        "officialText": "敌方角色陷入眩晕时，按眩晕敌方角色的数量使雪童子获得以下效果直到回合结束。一名时获得1点力量，两名时获得迅捷，至少三名时获得贯通。羁绊：入场时雪女眩晕一个敌方式神。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "realm": {
          "hp": 4,
          "nativeRealm": "coop-first-snow-blade",
          "trigger": "native-continuous"
        },
        "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c106112.png",
        "coopFaceArt": "assets/official/cooperation/c106112-xuetongzi.png"
      }
    ],
    "evidence": "research-notes/118-cooperation-rules.md#日服对照牌面",
    "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c107110",
    "name": "森佑灵矢",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "yingcao",
      "bailang"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n萤草－森佑灵引\n白狼－灵矢贯虹",
    "officialText": "选择使用一项：\n萤草－森佑灵引\n白狼－灵矢贯虹",
    "cardArt": "assets/official/cards/c107110.png",
    "coopFaces": [
      {
        "id": "c107110",
        "unitId": "yingcao",
        "name": "森佑灵引",
        "level": 2,
        "coopFaceId": "c107110:yingcao",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "ally-unit",
        "effect": "coop-first-draw-form",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-draw-form",
            "target": "ally-unit",
            "value": 0
          }
        ],
        "text": "选择一个己方式神，从牌库抽一张其等级或以下的形态牌。该式神存活且力量至少为6时，改为直接使用该牌。羁绊：白狼获得庇佑。",
        "officialText": "选择一个己方式神，从牌库抽一张其等级或以下的形态牌。该式神存活且力量至少为6时，改为直接使用该牌。羁绊：白狼获得庇佑。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "officialSource": "https://www.taptap.cn/moment/712763425637270499",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c107110.png",
        "coopFaceArt": "assets/official/cooperation/c107110-yingcao.png"
      },
      {
        "id": "c107110",
        "unitId": "bailang",
        "name": "灵矢贯虹",
        "level": 2,
        "coopFaceId": "c107110:bailang",
        "type": "combat",
        "typeLabel": "战斗牌",
        "target": "auto",
        "effect": "coop-first-arrow",
        "value": 1,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-arrow",
            "target": "auto",
            "value": 1
          }
        ],
        "text": "本次战斗+1力量/+1护甲。本次攻击白狼获得当前自身法术牌强化效果的力量加成。羁绊：攻击前触发萤草当前形态入场效果，你的出击加成效果在使用此牌时也会生效。",
        "officialText": "本次战斗+1力量/+1护甲。本次攻击白狼获得当前自身法术牌强化效果的力量加成。羁绊：攻击前触发萤草当前形态入场效果，你的出击加成效果在使用此牌时也会生效。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "officialSource": "https://www.taptap.cn/moment/712763425637270499",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c107110.png",
        "coopFaceArt": "assets/official/cooperation/c107110-bailang.png"
      }
    ],
    "evidence": "research-notes/118-cooperation-rules.md#日服对照牌面",
    "officialSource": "https://www.taptap.cn/moment/712763425637270499",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c108184",
    "name": "繁花似锦",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "taohuayao",
      "yinghuayao"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n桃花妖－桃红簇簇\n樱花妖－落英缤纷",
    "officialText": "选择使用一项：\n桃花妖－桃红簇簇\n樱花妖－落英缤纷",
    "cardArt": "assets/official/cards/c108184.png",
    "coopFaces": [
      {
        "id": "c108184",
        "unitId": "taohuayao",
        "name": "桃红簇簇",
        "level": 2,
        "coopFaceId": "c108184:taohuayao",
        "type": "form",
        "typeLabel": "形态牌",
        "target": "auto",
        "effect": "coop-first-peach",
        "value": {
          "attack": 3,
          "hp": 6,
          "setBase": true
        },
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-peach",
            "target": "auto",
            "value": {
              "attack": 3,
              "hp": 6,
              "setBase": true
            }
          }
        ],
        "text": "己方式神进入或离开战斗区时恢复其2点生命。己方准备区式神将受到致命伤害时，无效此次伤害并解除此形态。羁绊：入场时樱花妖为己方全体式神恢复2点生命。",
        "officialText": "己方式神进入或离开战斗区时恢复其2点生命。己方准备区式神将受到致命伤害时，无效此次伤害并解除此形态。羁绊：入场时樱花妖为己方全体式神恢复2点生命。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "formRules": {
          "coopFirstPeach": true
        },
        "officialSource": "https://www.taptap.cn/moment/674015428439182689",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c108184.png",
        "coopFaceArt": "assets/official/cooperation/c108184-taohuayao.png"
      },
      {
        "id": "c108184",
        "unitId": "yinghuayao",
        "name": "落英缤纷",
        "level": 2,
        "coopFaceId": "c108184:yinghuayao",
        "type": "form",
        "typeLabel": "形态牌",
        "target": "auto",
        "effect": "coop-first-sakura",
        "value": {
          "attack": 4,
          "hp": 5,
          "setBase": true
        },
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-sakura",
            "target": "auto",
            "value": {
              "attack": 4,
              "hp": 5,
              "setBase": true
            }
          }
        ],
        "text": "己方回合一次，己方式神复活时，随机对一个敌方式神造成1点伤害，重复该复活式神基础力量的次数，然后切换为晚樱之意。羁绊：入场时桃花妖随机恢复一个受伤己方角色3点生命。",
        "officialText": "己方回合一次，己方式神复活时，随机对一个敌方式神造成1点伤害，重复该复活式神基础力量的次数，然后切换为晚樱之意。羁绊：入场时桃花妖随机恢复一个受伤己方角色3点生命。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "formRules": {
          "coopFirstSakura": "day"
        },
        "officialSource": "https://www.taptap.cn/moment/674015428439182689",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c108184.png",
        "coopFaceArt": "assets/official/cooperation/c108184-yinghuayao.png"
      }
    ],
    "evidence": "research-notes/118-cooperation-rules.md#日服对照牌面",
    "officialSource": "https://www.taptap.cn/moment/674015428439182689",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c114183",
    "name": "跳跳兄弟",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "tiaotiaodidi",
      "tiaotiaogege"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n跳跳弟弟－尸瘴\n跳跳哥哥－棺葬",
    "officialText": "选择使用一项：\n跳跳弟弟－尸瘴\n跳跳哥哥－棺葬",
    "cardArt": "assets/official/cards/c114183.png",
    "coopFaces": [
      {
        "id": "c114183",
        "unitId": "tiaotiaodidi",
        "name": "尸瘴",
        "level": 2,
        "coopFaceId": "c114183:tiaotiaodidi",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-first-miasma",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-miasma",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "瞬发。每回合一次，己方角色获得破甲时，为所有敌方角色附加1点破甲。敌方有破甲的式神力量-1。羁绊：进场时跳跳哥哥倒计时-1。",
        "officialText": "瞬发。每回合一次，己方角色获得破甲时，为所有敌方角色附加1点破甲。敌方有破甲的式神力量-1。羁绊：进场时跳跳哥哥倒计时-1。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [
          "instant"
        ],
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-first-miasma",
          "trigger": "native-continuous"
        },
        "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c114183.png",
        "coopFaceArt": "assets/official/cooperation/c114183-tiaotiaodidi.png"
      },
      {
        "id": "c114183",
        "unitId": "tiaotiaogege",
        "name": "棺葬",
        "level": 2,
        "coopFaceId": "c114183:tiaotiaogege",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-first-burial",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-first-burial",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "每回合一次，己方初始式神气绝时将其变成棺材，此幻境失去2点耐久。若该式神为跳跳弟弟或跳跳妹妹，使其永久获得1点生命，此幻境不失去耐久。羁绊：入场时跳跳弟弟将自身破甲转移给敌方战斗区。",
        "officialText": "每回合一次，己方初始式神气绝时将其变成棺材，此幻境失去2点耐久。若该式神为跳跳弟弟或跳跳妹妹，使其永久获得1点生命，此幻境不失去耐久。羁绊：入场时跳跳弟弟将自身破甲转移给敌方战斗区。",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "keywords": [],
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-first-burial",
          "trigger": "native-continuous"
        },
        "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c114183.png",
        "coopFaceArt": "assets/official/cooperation/c114183-tiaotiaogege.png"
      }
    ],
    "evidence": "research-notes/118-cooperation-rules.md#日服对照牌面",
    "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c116123",
    "name": "致命之羽",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "yijin-zhentian",
      "zhen"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "text": "选择使用一项：\n以津真天－鎏金幻羽\n鸩－蚀刃毒羽",
    "officialText": "选择使用一项：\n以津真天－鎏金幻羽\n鸩－蚀刃毒羽",
    "cardArt": "assets/official/cards/c116123.png",
    "coopFaces": [
      {
        "unitId": "yijin-zhentian",
        "name": "鎏金幻羽",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "不消耗鬼火。使手牌所有黄金羽获得“气绝时可用，伤害+1，使用后以津真天和鸩气绝倒计时-1”。（不可叠加）\n羁绊：鸩倒计时-2。",
        "officialText": "不消耗鬼火。使手牌所有黄金羽获得“气绝时可用，伤害+1，使用后以津真天和鸩气绝倒计时-1”。（不可叠加）\n羁绊：鸩倒计时-2。",
        "target": "auto",
        "effect": "coop-middle-feather",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-feather",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "cost": 0,
        "id": "c116123",
        "level": 2,
        "coopFaceId": "c116123:yijin-zhentian",
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c116123.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c116123-yijin-zhentian.png"
      },
      {
        "unitId": "zhen",
        "name": "蚀刃毒羽",
        "type": "combat",
        "typeLabel": "战斗牌",
        "text": "若攻击有破甲的角色，则攻击后使其获得相同数量的破甲。\n羁绊：以津真天倒计时-2。",
        "officialText": "若攻击有破甲的角色，则攻击后使其获得相同数量的破甲。\n羁绊：以津真天倒计时-2。",
        "target": "auto",
        "effect": "assault",
        "effects": [
          {
            "condition": "always",
            "action": "assault",
            "target": "source",
            "value": 2
          },
          {
            "condition": "always",
            "action": "coop-middle-zhen-bond",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 2,
        "keywords": [],
        "attackBonus": 2,
        "combatOption": {
          "shield": 2,
          "coopMiddleZhen": true
        },
        "id": "c116123",
        "level": 2,
        "coopFaceId": "c116123:zhen",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c116123.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c116123-zhen.png"
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c118128",
    "name": "风之乐章",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "yimulian",
      "yaoginshi"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "text": "选择使用一项：\n一目连－风韵雅乐\n妖琴师－幻音绝弦",
    "officialText": "选择使用一项：\n一目连－风韵雅乐\n妖琴师－幻音绝弦",
    "cardArt": "assets/official/cards/c118128.png",
    "coopFaces": [
      {
        "unitId": "yimulian",
        "name": "风韵雅乐",
        "type": "combat",
        "typeLabel": "战斗牌",
        "text": "触发本局游戏生效过的一目连所有倒计时效果（每种最多1次）。\n羁绊：随机获得1张妖琴师觉醒牌。",
        "officialText": "触发本局游戏生效过的一目连所有倒计时效果（每种最多1次）。\n羁绊：随机获得1张妖琴师觉醒牌。",
        "target": "auto",
        "effect": "coop-middle-wind",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-wind",
            "target": "auto",
            "value": 0
          },
          {
            "condition": "always",
            "action": "coop-middle-wind-bond",
            "target": "auto",
            "value": 0
          },
          {
            "condition": "always",
            "action": "assault",
            "target": "source",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "attackBonus": 0,
        "id": "c118128",
        "level": 2,
        "coopFaceId": "c118128:yimulian",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c118128.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c118128-yimulian.png"
      },
      {
        "unitId": "yaoginshi",
        "name": "幻音绝弦",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "下一个己方回合开始时所有己方式神倒计时-1，若目标式神已气绝则改为气绝倒计时-2。\n羁绊：随机获得1张一目连形态牌。",
        "officialText": "下一个己方回合开始时所有己方式神倒计时-1，若目标式神已气绝则改为气绝倒计时-2。\n羁绊：随机获得1张一目连形态牌。",
        "target": "auto",
        "effect": "coop-middle-music",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-music",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "id": "c118128",
        "level": 2,
        "coopFaceId": "c118128:yaoginshi",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c118128.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c118128-yaoginshi.png"
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c124129",
    "name": "涅槃明灯",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "fenghuanghuo",
      "qingxingdeng"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "text": "选择使用一项：\n凤凰火－涅槃业火\n青行灯－烛火重燃",
    "officialText": "选择使用一项：\n凤凰火－涅槃业火\n青行灯－烛火重燃",
    "cardArt": "assets/official/cards/c124129.png",
    "coopFaces": [
      {
        "unitId": "fenghuanghuo",
        "name": "涅槃业火",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "瞬发。本回合其他式神使用法术时（相同法术只会触发1次），凤凰火随机使用1张不高于该等级的非觉醒法术（不可叠加）。\n羁绊：获得1张明灯。",
        "officialText": "瞬发。本回合其他式神使用法术时（相同法术只会触发1次），凤凰火随机使用1张不高于该等级的非觉醒法术（不可叠加）。\n羁绊：获得1张明灯。",
        "target": "auto",
        "effect": "coop-middle-phoenix",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-phoenix",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [
          "instant"
        ],
        "id": "c124129",
        "level": 2,
        "coopFaceId": "c124129:fenghuanghuo",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c124129.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c124129-fenghuanghuo.png"
      },
      {
        "unitId": "qingxingdeng",
        "name": "烛火重燃",
        "type": "realm",
        "typeLabel": "幻境牌",
        "text": "唯一，气绝时可用。每回合每个己方式神一次，从手牌或启悟区使用法术后复活青行灯，该式神造成的非战斗伤害+1直到回合结束。\n羁绊：进场时获得1张凤火。",
        "officialText": "唯一，气绝时可用。每回合每个己方式神一次，从手牌或启悟区使用法术后复活青行灯，该式神造成的非战斗伤害+1直到回合结束。\n羁绊：进场时获得1张凤火。",
        "target": "auto",
        "effect": "realm",
        "effects": [
          {
            "condition": "always",
            "action": "realm",
            "target": "ally-player",
            "value": null
          },
          {
            "condition": "always",
            "action": "coop-middle-lamp-entry",
            "target": "auto",
            "value": 0
          }
        ],
        "value": null,
        "keywords": [
          "unique"
        ],
        "allowKnockedSource": true,
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-middle-rekindle",
          "unique": true
        },
        "id": "c124129",
        "level": 2,
        "coopFaceId": "c124129:qingxingdeng",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c124129.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c124129-qingxingdeng.png"
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c127130",
    "name": "福星高照",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "shantu",
      "zuofutongzi"
    ],
    "level": 3,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "text": "选择使用一项：\n山兔－幸运兔兔\n座敷童子－鸿运当头",
    "officialText": "选择使用一项：\n山兔－幸运兔兔\n座敷童子－鸿运当头",
    "cardArt": "assets/official/cards/c127130.png",
    "coopFaces": [
      {
        "unitId": "shantu",
        "name": "幸运兔兔",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "增强：本局游戏你骰子投出三次6点，敌方下回合所有卡牌鬼火消耗+1。\n羁绊：座敷童子运势4：直到敌方回合结束，所有敌方式神力量变为0。",
        "officialText": "增强：本局游戏你骰子投出三次6点，敌方下回合所有卡牌鬼火消耗+1。\n羁绊：座敷童子运势4：直到敌方回合结束，所有敌方式神力量变为0。",
        "target": "auto",
        "effect": "coop-middle-bunny",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-bunny",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "id": "c127130",
        "level": 3,
        "coopFaceId": "c127130:shantu",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c127130.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c127130-shantu.png"
      },
      {
        "unitId": "zuofutongzi",
        "name": "鸿运当头",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "己方所有式神随机使用1张他的专属形态牌，生效前运势4：复活所有己方式神。\n羁绊：从牌库抽取1张「这把算我赢」。",
        "officialText": "己方所有式神随机使用1张他的专属形态牌，生效前运势4：复活所有己方式神。\n羁绊：从牌库抽取1张「这把算我赢」。",
        "target": "auto",
        "effect": "coop-middle-fortune",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-fortune",
            "target": "auto",
            "value": 0
          },
          {
            "condition": "always",
            "action": "coop-middle-draw-rabbit-win",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "id": "c127130",
        "level": 3,
        "coopFaceId": "c127130:zuofutongzi",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c127130.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c127130-zuofutongzi.png"
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c164166",
    "name": "日霭相织",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "yanyanluo",
      "rihefang"
    ],
    "level": 1,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "text": "选择使用一项：\n烟烟罗－烟影\n日和坊－煦日",
    "officialText": "选择使用一项：\n烟烟罗－烟影\n日和坊－煦日",
    "cardArt": "assets/official/cards/c164166.png",
    "coopFaces": [
      {
        "unitId": "yanyanluo",
        "name": "烟影",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "召唤一个烟烟罗的分身并使其使用一张等同于烟烟罗当前等级的爆能法术。\n羁绊：日和坊为己方具有充能的式神+1能量。",
        "officialText": "召唤一个烟烟罗的分身并使其使用一张等同于烟烟罗当前等级的爆能法术。\n羁绊：日和坊为己方具有充能的式神+1能量。",
        "target": "auto",
        "effect": "coop-middle-smoke",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-smoke",
            "target": "auto",
            "value": 0
          },
          {
            "condition": "always",
            "action": "coop-middle-smoke-bond",
            "target": "auto",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "id": "c164166",
        "level": 1,
        "coopFaceId": "c164166:yanyanluo",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c164166.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c164166-yanyanluo.png"
      },
      {
        "unitId": "rihefang",
        "name": "煦日",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "使一个其他己方式神结附「晴天娃娃」。\n羁绊：使该式神本回合免疫战斗伤害。\n晴天娃娃：不能叠加。每回合一次，当结附式神攻击或使用卡牌时，获得2能量。",
        "officialText": "使一个其他己方式神结附「晴天娃娃」。\n羁绊：使该式神本回合免疫战斗伤害。\n晴天娃娃：不能叠加。每回合一次，当结附式神攻击或使用卡牌时，获得2能量。",
        "target": "coop-middle-sunny-ally",
        "effect": "coop-middle-sunny",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-sunny",
            "target": "selected",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "id": "c164166",
        "level": 1,
        "coopFaceId": "c164166:rihefang",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c164166.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c164166-rihefang.png"
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c170226",
    "name": "花骸缚骨",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "biyehua",
      "huangkulou"
    ],
    "level": 3,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "text": "选择使用一项：\n彼岸花－黄泉永劫\n荒骷髅－枯骨重塑",
    "officialText": "选择使用一项：\n彼岸花－黄泉永劫\n荒骷髅－枯骨重塑",
    "cardArt": "assets/official/cards/c170226.png",
    "coopFaces": [
      {
        "unitId": "biyehua",
        "name": "黄泉永劫",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "瞬发。选择一个己方基础式神，对双方牌手造成4点伤害，将该式神4张等级为1的卡牌洗入牌库。\n羁绊：荒骷髅改变气绝状态（气绝时有效），将牌库所有等级为1的牌随机顺序置入牌顶。",
        "officialText": "瞬发。选择一个己方基础式神，对双方牌手造成4点伤害，将该式神4张等级为1的卡牌洗入牌库。\n羁绊：荒骷髅改变气绝状态（气绝时有效），将牌库所有等级为1的牌随机顺序置入牌顶。",
        "target": "coop-middle-basic-ally",
        "effect": "coop-middle-yellow-damage",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-yellow-damage",
            "target": "selected",
            "value": 0
          },
          {
            "condition": "always",
            "action": "coop-middle-yellow-shuffle",
            "target": "selected",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [
          "instant"
        ],
        "id": "c170226",
        "level": 3,
        "coopFaceId": "c170226:biyehua",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c170226.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c170226-biyehua.png"
      },
      {
        "unitId": "huangkulou",
        "name": "枯骨重塑",
        "type": "spell",
        "typeLabel": "法术牌",
        "text": "消灭荒骷髅，对敌方所有角色造成3点伤害，随后使荒骷髅气绝倒计时设为1。\n羁绊：将一张「彼岸归航」置入手牌。",
        "officialText": "消灭荒骷髅，对敌方所有角色造成3点伤害，随后使荒骷髅气绝倒计时设为1。\n羁绊：将一张「彼岸归航」置入手牌。",
        "target": "auto",
        "effect": "coop-middle-bone-destroy",
        "effects": [
          {
            "condition": "always",
            "action": "coop-middle-bone-destroy",
            "target": "source",
            "value": 0
          },
          {
            "condition": "always",
            "action": "damage",
            "target": "all-enemies",
            "value": 3
          },
          {
            "condition": "always",
            "action": "coop-middle-bone-timer",
            "target": "source",
            "value": 0
          }
        ],
        "value": 0,
        "keywords": [],
        "id": "c170226",
        "level": 3,
        "coopFaceId": "c170226:huangkulou",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "cardArt": "assets/official/cards/c170226.png",
        "timing": "main",
        "responseTo": [],
        "coopFaceArt": "assets/official/cooperation/c170226-huangkulou.png"
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c175186",
    "name": "鸮羽共鸣",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "shanfeng",
      "xun"
    ],
    "level": 1,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n山风－庇羽\n薰－鸮鸣",
    "officialText": "选择使用一项：\n山风－庇羽\n薰－鸮鸣",
    "cardArt": "assets/official/cards/c175186.png",
    "coopFaces": [
      {
        "unitId": "shanfeng",
        "name": "庇羽",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-late-owl-feather",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-owl-feather",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "每当山风结附灵咒时，倒计时-1，获得1点护甲。羁绊：进场时薰为山风结附一个「鸮之守护」。",
        "officialText": "每当山风结附灵咒时，倒计时-1，获得1点护甲。羁绊：进场时薰为山风结附一个「鸮之守护」。",
        "keywords": [],
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-late-owl-feather"
        },
        "id": "c175186",
        "level": 1,
        "coopFaceId": "c175186:shanfeng",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c175186.png",
        "coopFaceArt": "assets/official/cooperation/c175186-shanfeng.png"
      },
      {
        "unitId": "xun",
        "name": "鸮鸣",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-late-owl-song",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-owl-song",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "每当己方具「鸮之守护」的式神发起攻击时，该式神获得+1力量直到回合结束。羁绊：进场时山风倒计时-2。",
        "officialText": "每当己方具「鸮之守护」的式神发起攻击时，该式神获得+1力量直到回合结束。羁绊：进场时山风倒计时-2。",
        "keywords": [],
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-late-owl-song"
        },
        "id": "c175186",
        "level": 1,
        "coopFaceId": "c175186:xun",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c175186.png",
        "coopFaceArt": "assets/official/cooperation/c175186-xun.png"
      }
    ],
    "evidence": "https://www.bilibili.com/video/BV11FJWzuEvG/",
    "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c179210",
    "name": "海潮深渊",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "jiuciliang",
      "xieji"
    ],
    "level": 1,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n久次良－鲸甲引潮\n蟹姬－钳浪千袭",
    "officialText": "选择使用一项：\n久次良－鲸甲引潮\n蟹姬－钳浪千袭",
    "cardArt": "assets/official/cards/c179210.png",
    "coopFaces": [
      {
        "unitId": "jiuciliang",
        "name": "鲸甲引潮",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-late-whale-tide",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-whale-tide",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "每回合1次，你使用幻境时移动久次良到战斗区并使其获得1护甲。羁绊：进场时随机复制一张你手牌中蟹姬的牌并置入手牌。",
        "officialText": "每回合1次，你使用幻境时移动久次良到战斗区并使其获得1护甲。羁绊：进场时随机复制一张你手牌中蟹姬的牌并置入手牌。",
        "keywords": [],
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-late-whale-tide"
        },
        "id": "c179210",
        "level": 1,
        "coopFaceId": "c179210:jiuciliang",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c179210.png",
        "coopFaceArt": "assets/official/cooperation/c179210-jiuciliang.png"
      },
      {
        "unitId": "xieji",
        "name": "钳浪千袭",
        "type": "realm",
        "typeLabel": "幻境牌",
        "target": "auto",
        "effect": "coop-late-crab-waves",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-crab-waves",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "瞬发。每回合1次，蟹姬使用「钳浪千袭」以外的牌时从牌库抽1张该牌的同名牌。增强：本局游戏每使用过1张此牌，额外召唤1个相同的幻境。羁绊：进场时久次良获得+1力量和+1护甲。",
        "officialText": "瞬发。每回合1次，蟹姬使用「钳浪千袭」以外的牌时从牌库抽1张该牌的同名牌。增强：本局游戏每使用过1张此牌，额外召唤1个相同的幻境。羁绊：进场时久次良获得+1力量和+1护甲。",
        "keywords": [
          "instant"
        ],
        "realm": {
          "hp": 5,
          "nativeRealm": "coop-late-crab-waves"
        },
        "id": "c179210",
        "level": 1,
        "coopFaceId": "c179210:xieji",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c179210.png",
        "coopFaceArt": "assets/official/cooperation/c179210-xieji.png"
      }
    ],
    "evidence": "https://www.bilibili.com/video/BV1z3aizYEfm/",
    "officialSource": "https://www.taptap.cn/moment/712763425637270499",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c180190",
    "name": "海国共主",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "lingyuyuqian",
      "dayueling"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n铃鹿御前－裂甲归潮\n大岳丸－琼玉镇海",
    "officialText": "选择使用一项：\n铃鹿御前－裂甲归潮\n大岳丸－琼玉镇海",
    "cardArt": "assets/official/cards/c180190.png",
    "coopFaces": [
      {
        "unitId": "lingyuyuqian",
        "name": "裂甲归潮",
        "type": "combat",
        "typeLabel": "战斗牌",
        "target": "auto",
        "effect": "coop-late-sea-crack",
        "value": 1,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-sea-crack",
            "target": "auto",
            "value": 1
          }
        ],
        "text": "贯通。若攻击目标有破甲，则铃鹿御前获得等量护甲。羁绊：将八尺琼曲玉结附于铃鹿御前。",
        "officialText": "贯通。若攻击目标有破甲，则铃鹿御前获得等量护甲。羁绊：将八尺琼曲玉结附于铃鹿御前。",
        "keywords": [
          "pierce"
        ],
        "id": "c180190",
        "level": 2,
        "coopFaceId": "c180190:lingyuyuqian",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c180190.png",
        "coopFaceArt": "assets/official/cooperation/c180190-lingyuyuqian.png"
      },
      {
        "unitId": "dayueling",
        "name": "琼玉镇海",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "ally-unit",
        "effect": "coop-late-sea-jade",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-sea-jade",
            "target": "ally-unit",
            "value": 0
          }
        ],
        "text": "将八尺琼曲玉结附于一个己方式神，并使其获得迅捷。本局游戏结附八尺琼曲玉式神攻击时使攻击目标获得2破甲（不可叠加，每个式神每回合1次）。羁绊：铃鹿御前投射：造成1点伤害。",
        "officialText": "将八尺琼曲玉结附于一个己方式神，并使其获得迅捷。本局游戏结附八尺琼曲玉式神攻击时使攻击目标获得2破甲（不可叠加，每个式神每回合1次）。羁绊：铃鹿御前投射：造成1点伤害。",
        "keywords": [],
        "id": "c180190",
        "level": 2,
        "coopFaceId": "c180190:dayueling",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c180190.png",
        "coopFaceArt": "assets/official/cooperation/c180190-dayueling.png"
      }
    ],
    "evidence": "https://www.bilibili.com/video/BV1rPaez8Ei8/",
    "officialSource": "https://www.taptap.cn/moment/712763425637270499",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c213282",
    "name": "同心涟漪",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "liyujing",
      "hetong"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n鲤鱼精－潮汐共舞\n河童－碧波连弹",
    "officialText": "选择使用一项：\n鲤鱼精－潮汐共舞\n河童－碧波连弹",
    "cardArt": "assets/official/cards/c213282.png",
    "coopFaces": [
      {
        "unitId": "liyujing",
        "name": "潮汐共舞",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "ally-unit",
        "effect": "coop-late-koi-tide",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-koi-tide",
            "target": "ally-unit",
            "value": 0
          }
        ],
        "text": "使一个其他己方式神本回合获得+1力量，发起一次攻击。羁绊：本局游戏每当河童攻击时，此牌力量增强效果+1。",
        "officialText": "使一个其他己方式神本回合获得+1力量，发起一次攻击。羁绊：本局游戏每当河童攻击时，此牌力量增强效果+1。",
        "keywords": [],
        "id": "c213282",
        "level": 2,
        "coopFaceId": "c213282:liyujing",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c213282.png",
        "coopFaceArt": "assets/official/cooperation/c213282-liyujing.png"
      },
      {
        "unitId": "hetong",
        "name": "碧波连弹",
        "type": "spell",
        "typeLabel": "法术牌",
        "target": "auto",
        "effect": "coop-late-kappa-wave",
        "value": 0,
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-kappa-wave",
            "target": "auto",
            "value": 0
          }
        ],
        "text": "投射：造成4点伤害，随机1个己方式神获得+1力量/+1生命。羁绊：本局游戏每当己方加护时，此牌随机数值+1。",
        "officialText": "投射：造成4点伤害，随机1个己方式神获得+1力量/+1生命。羁绊：本局游戏每当己方加护时，此牌随机数值+1。",
        "keywords": [
          "projectile"
        ],
        "id": "c213282",
        "level": 2,
        "coopFaceId": "c213282:hetong",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c213282.png",
        "coopFaceArt": "assets/official/cooperation/c213282-hetong.png"
      }
    ],
    "evidence": "https://www.bilibili.com/video/BV1ifJxzqE2w/",
    "officialSource": "https://www.taptap.cn/moment/674574915055128405?group_id=188707",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  },
  {
    "id": "c228244",
    "name": "绮舞华乐",
    "type": "coop",
    "typeLabel": "协战牌",
    "unitId": "",
    "coopPartners": [
      "tengji",
      "song"
    ],
    "level": 2,
    "cost": 1,
    "rarity": "ssr",
    "copies": 2,
    "deckLimit": 2,
    "starterCopies": 0,
    "keywords": [],
    "target": "auto",
    "effect": "coop-select",
    "text": "选择使用一项：\n藤姬－绮幻之舞\n松－浮华鸣乐",
    "officialText": "选择使用一项：\n藤姬－绮幻之舞\n松－浮华鸣乐",
    "cardArt": "assets/official/cards/c228244.png",
    "coopFaces": [
      {
        "unitId": "tengji",
        "name": "绮幻之舞",
        "type": "form",
        "typeLabel": "形态牌",
        "target": "auto",
        "effect": "coop-late-vine-dance",
        "value": {
          "attack": 1,
          "hp": 1,
          "setBase": true
        },
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-vine-dance",
            "target": "auto",
            "value": {
              "attack": 1,
              "hp": 1,
              "setBase": true
            }
          }
        ],
        "text": "每回合1次，己方其他式神角色结附「藤色」时可再结附一个，若结附目标是「幻役」或松时获得迅捷。羁绊：进场时召唤一个力量、生命等同于松等级的「幻役」并结附一个「藤色」。",
        "officialText": "每回合1次，己方其他式神角色结附「藤色」时可再结附一个，若结附目标是「幻役」或松时获得迅捷。羁绊：进场时召唤一个力量、生命等同于松等级的「幻役」并结附一个「藤色」。",
        "keywords": [],
        "formRules": {
          "coopLateVine": true
        },
        "id": "c228244",
        "level": 2,
        "coopFaceId": "c228244:tengji",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c228244.png",
        "coopFaceArt": "assets/official/cooperation/c228244-tengji.png"
      },
      {
        "unitId": "song",
        "name": "浮华鸣乐",
        "type": "form",
        "typeLabel": "形态牌",
        "target": "auto",
        "effect": "coop-late-pine-music",
        "value": {
          "attack": 5,
          "hp": 6,
          "setBase": true
        },
        "effects": [
          {
            "condition": "always",
            "action": "coop-late-pine-music",
            "target": "auto",
            "value": {
              "attack": 5,
              "hp": 6,
              "setBase": true
            }
          }
        ],
        "text": "远程。敌方有存活的准备区式神时，松对战斗区式神造成的战斗伤害改为由敌方随机准备区式神承受。羁绊：进场时为松结附一个「藤色」。",
        "officialText": "远程。敌方有存活的准备区式神时，松对战斗区式神造成的战斗伤害改为由敌方随机准备区式神承受。羁绊：进场时为松结附一个「藤色」。",
        "keywords": [
          "remote"
        ],
        "formRules": {
          "coopLatePine": true,
          "combatKeywords": [
            "remote"
          ]
        },
        "id": "c228244",
        "level": 2,
        "coopFaceId": "c228244:song",
        "cost": 1,
        "rarity": "ssr",
        "verifiedRules": true,
        "timing": "main",
        "responseTo": [],
        "cardArt": "assets/official/cards/c228244.png",
        "coopFaceArt": "assets/official/cooperation/c228244-song.png"
      }
    ],
    "evidence": "https://www.bilibili.com/video/BV1BuYKzjEuC/",
    "officialSource": "https://www.taptap.cn/moment/712763425637270499",
    "verifiedRules": true,
    "effects": [
      {
        "action": "coop-select",
        "condition": "always",
        "target": "auto",
        "value": 0
      }
    ],
    "timing": "main",
    "responseTo": [],
    "pack": "wave9",
    "token": false,
    "skin": false,
    "tags": [
      "协战"
    ]
  }
]);
